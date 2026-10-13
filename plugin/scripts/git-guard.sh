#!/usr/bin/env bash
# git-guard.sh – PreToolUse Bash hook that blocks unsafe git calls and secret commits.
#
# Usage:
#   plugin/scripts/git-guard.sh < payload.json   # a PreToolUse Bash hook; exit 2 blocks with a reason on stderr
#
# What it does:
#   1. Allows at once when the payload cannot hold a git call. Blocks when jq is missing or fails.
#   2. Unwraps sh/bash/zsh -c payloads and eval arguments, then folds each quoted string into one word.
#      A command substitution inside double quotes or a heredoc is checked like a top-level command.
#      A heredoc body is data unless a shell reads it or its line pipes it into one.
#   3. Finds git behind a path, env, command or global options, per command segment.
#   4. Blocks pushes with force, +refspec, --mirror, --no-verify, a forcing (+) push refspec
#      or mirror override, or a core.hooksPath override. Abbreviated long options count.
#   5. Blocks commits with -n, --no-verify or a core.hooksPath override.
#   6. Blocks an alias from -c or GIT_CONFIG_*, and git config writes of core.hooksPath,
#      alias.*, remote.*.push or remote.*.mirror.
#   7. Runs gitleaks on every other commit, in the repo of -C, --git-dir, --work-tree, cd,
#      pushd or the payload cwd. A cd inside a subshell or substitution stays there.
#      It scans the staged diff. -a or paths add tracked changes; an earlier git add also
#      untracked files, and an earlier git add -f the ignored files it names.
#   8. Without gitleaks it warns on stderr and allows.

set -euo pipefail

GITLEAKS="${GITLEAKS:-gitleaks}"

payload="$(cat)"
# Quotes, backslashes and JSON \n escapes can split the git word; $'..' escapes can spell it.
stripped="${payload//\\n/}"
stripped="${stripped//[\\\'\"]/}"
[[ "$stripped" == *git* || "$payload" == *"\$'"* ]] || exit 0
command -v jq >/dev/null 2>&1 || { echo 'git-guard: jq not found; Bash is blocked until it is installed.' >&2; exit 2; }

# Prints the payload cwd, then one command segment per line. A payload that is not JSON is
# taken as the command itself. A quoted string becomes one word: separators, blanks and %
# inside it are %XX-encoded, and an empty one is %E. Each body scan_cmd finds adds its own
# segments after the command.
read -r -d '' JQ_PROG <<'JQ' || true
def quoted: "\\$'(?<a>(?:\\\\.|[^'\\\\])*)'|'(?<s>[^']*)'|\"(?<d>(?:\\\\.|[^\"\\\\])*)\"";
def quoted_bare: "\\$'(?:\\\\.|[^'\\\\])*'|'[^']*'|\"(?:\\\\.|[^\"\\\\])*\"";
def num($b): ascii_downcase | explode | reduce .[] as $c (0; . * $b + $c - (if $c >= 97 then 87 else 48 end));
# A NUL, which bash cannot hold, is dropped; an invalid codepoint becomes U+FFFD.
def chr: if . == 0 then "" elif . > 1114111 or (. >= 55296 and . < 57344) then "\uFFFD" else [.] | implode end;
def unq:
  if .a then .a | gsub("\\\\(?:(?<o>[0-7]{1,3})|x(?<x>[0-9A-Fa-f]{1,2})|u(?<u>[0-9A-Fa-f]{1,4})|U(?<w>[0-9A-Fa-f]{1,8})|c(?<k>[\\s\\S])|(?<e>[\\s\\S]))";
      if .o then .o | num(8) % 256 | chr
      elif .x then .x | num(16) | chr
      elif .u then .u | num(16) | chr
      elif .w then .w | num(16) | chr
      elif .k then .k | explode[0] % 32 | chr
      else {a: "\u0007", b: "\b", e: "\u001b", E: "\u001b", f: "\f", n: "\n", r: "\r", t: "\t", v: "\u000b",
            "\\": "\\", "'": "'", "\"": "\"", "?": "?"}[.e] // "\\" + .e end)
  elif .s then .s
  else .d | gsub("\\\\(?<e>[\"\\\\$`\\n])"; if .e == "\n" then "" else .e end) end;
def opt: "(?:[-+][oO]\\s+[^\\s;&|()]+|--[A-Za-z][-A-Za-z]*|[-+][A-Za-z]+)\\s+";
def step:
  gsub("(?<p>^|[\\s;&|(`])(?:\\S*/)?(?:ba|da|k|z)?sh\\s+(?:" + opt + ")*?-[A-Za-z]*c\\s+(?:--\\s+)?(?:"
       + quoted + "|(?<b>[^\\s;&|()]+))";
    "\(.p) ; \(if .b then .b else unq end) ; ")
  | gsub("(?<p>^|[\\s;&|(`])eval(?<x>(?:\\s+(?:" + quoted_bare + "|[^\\s'\";&|()]+))+)";
    "\(.p) ; \(.x | gsub(quoted; unq)) ; ");
def fix: . as $c | step | if . == $c then . else fix end;
def hex: [(. / 16 | floor), (. % 16)] | map("0123456789ABCDEF"[.:. + 1]) | add;
# Codepoints: tab to carriage return, space, % & ( ) ; ` |.
def enc:
  if . == "" then "%E"
  else [explode[] | if IN(9, 10, 11, 12, 13, 32, 37, 38, 40, 41, 59, 96, 124) then "%" + hex | explode[] else . end]
    | implode end;
# Lexer tokens: an opener, a heredoc operator with its delimiter, a run of characters
# that no context treats specially, or one character.
def tok:
  "\\$\\(|\\$'|\\$\"|<<<|<<-?[ \\t]*(?:'[^'\\n]*'|\"[^\"\\n]*\"|\\\\?[^\\s;&|()<>'\"`\\\\$]+)"
  + "|[^\\\\'\"$`()\\n;&|<>]+|[\\s\\S]";
# A word that runs its input as shell commands, behind sudo, env, command, exec or nohup.
def shell: "(?:(?:sudo|env|command|exec|nohup)\\s+)*(?:\\S*/)?(?:(?:ba|da|k|z)?sh|eval|source|\\.)(?=\\s|$)";
def ord: test("^[^\\\\'\"$`()\\n;&|<>]+$");
# Returns the base text t and the bodies o to check as commands. It reads line by line and
# skips heredoc lines that hold no expansion. State: frame stack k over the base frame,
# position [l, p] as line and column, base text edits ed, and the capture of a body from depth e.
# Frames: base, p for $(, g for (, b for a backtick, s, a ($'), d for quotes, h for a heredoc.
# A body is a substitution in a top-level double quote or heredoc, or a heredoc a shell
# reads. Any other heredoc is data. Unclosed text runs to the end.
def scan_cmd:
  split("\n") as $L
  | def cut($a; $b):
      if $a[0] == $b[0] then $L[$a[0]][$a[1]:$b[1]]
      else [$L[$a[0]][$a[1]:]] + $L[$a[0] + 1:$b[0]] + [$L[$b[0]][:$b[1]]] | join("\n") end;
    def n: .k | length;
    def top: .k[-1].c;
    def at: [.l, .p];
    def after($c): if $c == "\n" then [.l + 1, 0] else [.l, .p + ($c | length)] end;
    def push($f; $at):
      .k += [$f]
      | if .e != null then .
        elif $f.c == "h" then (if n == 2 and ($f.i | not) then .e = 2 | .bs = $at else . end)
        elif n == 3 and (.k[1].c | IN("d", "h")) then .e = 3 | .bs = $at
        else . end;
    def emit($to): .o += [cut(.bs; $to)] | .e = null;
    def pop: .k |= .[:-1] | if .e != null and n < .e then emit(at) else . end;
    # ms is where the current command of a command frame starts.
    def cmd($c):
      if top | IN("base", "p", "g") then
        after($c) as $end
        | .k[-1] |= (if $c | test("^[;&|()`\\n]$") then .ms = $end else . end)
      else . end;
    def quote($c; $f): cmd($c) | (if n == 1 then .qa = at | .qo = ($c | length) else . end) | push($f; null);
    def close($c):
      if n == 2 then
        .k[1].c as $q
        | .ed += [[.qa, after($c), ({($q): cut([.qa[0], .qa[1] + .qo]; at)} | unq | enc)]]
        | .k |= .[:-1]
      else pop | cmd($c) end;
    def lit($ch):
      (if top == "base" then .ed += [[[.l, .p - 1], after($ch), (if $ch == "\n" then "" else $ch | enc end)]]
       else . end)
      | cmd($ch);
    def here($c):
      (cut(.k[-1].ms; at) | test("^\\s*" + shell) | not) as $i
      | ($c | capture("^<<(?<tab>-?)[ \\t]*(?:'(?<s>[^']*)'|\"(?<d>[^\"]*)\"|(?<x>\\\\?)(?<u>.+))$")) as $m
      | cmd($c)
      | .k[-1].hd += [{c: "h", w: ($m.s // $m.d // $m.u), q: ($m.s != null or $m.d != null or $m.x != ""),
                       tab: ($m.tab != ""), i: $i, oe: after($c)}];
    def act($c; $f):
      if $f.c == "h" then
        if $c == "\n" then
          if ($L[.l] | if $f.tab then sub("^\t+"; "") else . end) == $f.w then
            (if .e == n then emit([.l, 0]) else . end)
            | (if n == 2 then .ed += [[$f.hs, at, ""]] else . end)
            | .k |= .[:-1]
            | if top == "h" then . else cmd($c) end
          else . end
        elif $f.q then .
        elif $c == "\\" then .x = true
        elif $c == "$(" then push({c: "p", ms: after($c), hd: []}; after($c))
        elif $c == "`" then push({c: "b"}; after($c))
        else . end
      elif $f.c == "s" then (if $c == "'" then close("'") else . end)
      elif $f.c == "a" then (if $c == "\\" then .x = true elif $c == "'" then close($c) else . end)
      elif $f.c == "d" then
        if $c == "\\" then .x = true
        elif $c == "\"" then close($c)
        elif $c == "$(" then push({c: "p", ms: after($c), hd: []}; after($c))
        elif $c == "`" then push({c: "b"}; after($c))
        else . end
      elif $f.c == "b" then (if $c == "\\" then .x = true elif $c == "`" then pop | cmd($c) else . end)
      elif $c == "\\" then .x = true
      elif $c == "'" then quote($c; {c: "s"})
      elif $c == "\"" then quote($c; {c: "d"})
      elif $c == "$'" then quote($c; {c: "a"})
      elif $c == "$\"" then quote($c; {c: "d"})
      elif $c == "\n" then
        $f.hd as $hs | after($c) as $at
        | cmd($c) | .k[-1].hd = []
        | at as $nl
        | reduce ($hs | reverse[]) as $h (.;
            push($h + {hs: $at, i: ($h.i and ($hs | length) == 1 and (cut($h.oe; $nl) | test("\\|\\s*" + shell) | not))}; $at))
      elif ($c | startswith("<<")) and $c != "<<<" then here($c)
      elif $f.c == "base" then cmd($c)
      elif $c == "$(" then cmd($c) | push({c: "p", ms: after($c), hd: []}; after($c))
      elif $c == "(" then cmd($c) | push({c: "g", ms: after($c), hd: []}; null)
      elif $c == ")" then pop | cmd($c)
      elif $c == "`" then cmd($c) | push({c: "b"}; after($c))
      else cmd($c) end;
    def lex($c):
      .k[-1] as $f
      | if .x then
          .x = false | lit($c[:1]) | .p += 1 | reduce ($c[1:] | scan(tok)) as $u (.; lex($u))
        elif ($c | length) > 1 and ($c | ord | not)
          and (if $f.c == "base" then $c == "$(" elif $f.c == "d" then $c != "$("
               else $f.c | IN("s", "a", "b") end)
        then reduce ($c | explode[] | [.] | implode) as $ch (.; lex($ch))
        else act($c; $f) | .p += ($c | length) end;
    [($L | length) - 1, ($L[-1] | length)] as $end
    | reduce range(0; $L | length) as $i (
        {k: [{c: "base", ms: [0, 0], hd: []}], l: 0, p: 0, ed: [], o: [], e: null, x: false};
        .l = $i | .p = 0
        | (if top == "h" and (.k[-1].q or ($L[$i] | test("[$`\\\\]") | not)) then .p = ($L[$i] | length)
           else reduce ($L[$i] | scan(tok)) as $c (.; lex($c)) end)
        | if $i < ($L | length) - 1 then lex("\n") else . end)
    | (if .e != null then emit($end) else . end)
    | (if n > 1 and .k[1].c == "h" then .ed += [[.k[1].hs, $end, ""]] else . end)
    | .ed as $ed
    | {o, t: ([range(0; $ed | length) as $j
               | cut(if $j == 0 then [0, 0] else $ed[$j - 1][1] end; $ed[$j][0]), $ed[$j][2]]
              + [cut(if $ed == [] then [0, 0] else $ed[-1][1] end; $end)] | add)};
# Lines %{ and %} enclose a subshell, a substitution or a body, so a cd inside stays there.
# Backticks in the base text alternate between opening and closing one.
def segs:
  fix | scan_cmd
  | (.t | gsub("(?<=\\S)%E|%E(?=\\S)"; "") | gsub("[;&|\\n]"; "\n")
     | [splits("`")] | reduce .[1:][] as $p ({t: .[0], i: 1}; .t += (if .i % 2 == 1 then "\n%{\n" else "\n%}\n" end) + $p | .i += 1)
     | .t | gsub("\\("; "\n%{\n") | gsub("\\)"; "\n%}\n")),
    (.o[] | "%{", segs, "%}");
. as $raw | (try fromjson catch null) as $j
| ($j.cwd // ""),
  ((if $j == null then $raw else ($j.tool_input.command // "") end) | segs)
JQ
parsed="$(printf '%s' "$payload" | jq -Rrs "$JQ_PROG")" ||
  { echo 'git-guard: jq failed on the payload; Bash is blocked.' >&2; exit 2; }
mapfile -t lines <<< "$parsed"

cwd="${lines[0]:-}"
[[ -n "$cwd" ]] || cwd="$PWD"
dir="$cwd"

gopt='-[Cc]|--git-dir|--work-tree|--namespace|--config-env|--super-prefix|--attr-source'
g="(^|[[:space:]]|/)git([[:space:]]+($gopt)[[:space:]]+[^[:space:]]+|[[:space:]]+-[^[:space:]]+)*[[:space:]]+"
# Git takes any unique prefix of a long option: --m is --mirror, --no-veri is --no-verify.
push_bad='(^|[[:space:]])(--force[^[:space:]]*|--m[a-z]*|--no-veri[a-z]*|-[46nquv]*f[^[:space:]]*|\+[^[:space:]]+)'
commit_bad='(^|[[:space:]])(--no-veri[a-z]*|-[aeiopqsvz]*n[^[:space:]]*)'
# Matched against the lower-cased segment plus every GIT_CONFIG_* assignment before it.
# A key counts only after a carrier: -c, --config-env, GIT_CONFIG_KEY_n or GIT_CONFIG_PARAMETERS.
q="['\"]"
cfg="(^|[[:space:]])(-c[[:space:]]+|--config-env[[:space:]=]+|git_config_key_[0-9]+=$q?|git_config_parameters=[^[:space:]]*$q?)"
hooks_path="${cfg}core\\.hookspath([[:space:]=]|$q|\$)"
push_cfg="${cfg}remote\\.[^[:space:]]+\\.(mirror|push$q?=$q?\\+)|(^|[[:space:]])(git_config_value_[0-9]+=$q?\\+|--config-env[[:space:]=]+remote\\.)"
alias_cfg="${cfg}alias\\.[^[:space:]=]+$q?=|(^|[[:space:]])git_config_key_[0-9]+=$q?alias\\."

tmp=""
trap 'rm -rf "$tmp"' EXIT

# Undoes the jq encoding of a quoted word.
dec() { # dec <word>
  local s="$1"
  [[ "$s" == "%E" ]] && return 0
  s="${s//\\/\\\\}"
  printf '%b' "${s//%/\\x}"
}

resolve() { # resolve <base> <path>
  case "$2" in
    /*) printf '%s' "$2" ;;
    \~) printf '%s' "$HOME" ;;
    \~/*) printf '%s/%s' "$HOME" "${2#\~/}" ;;
    *) printf '%s/%s' "$1" "$2" ;;
  esac
}

# Finds the git call in a segment: words holds its words, si the subcommand index (-1 for
# none) and gdir the repo after each -C, --git-dir and --work-tree.
gitcmd() { # gitcmd <base> <segment>
  local w v i base="$1"
  gdir="$1"
  si=-1
  read -ra words <<< "$2"
  for ((i = 0; i < ${#words[@]}; i++)); do
    [[ "${words[i]}" =~ (^|/)git$ ]] && break
  done
  for ((i++; i < ${#words[@]}; i++)); do
    w="${words[i]}"
    case "$w" in
      -C) i=$((i + 1)); base="$(resolve "$base" "$(dec "${words[i]:-.}")")"; gdir="$base" ;;
      --git-dir | --work-tree | --git-dir=* | --work-tree=*)
        if [[ "$w" == *=* ]]; then v="${w#*=}"; else i=$((i + 1)); v="${words[i]:-.}"; fi
        gdir="$(resolve "$base" "$(dec "$v")")"
        [[ "$w" == --git-dir* ]] && gdir="${gdir%/.git}"
        ;;
      -c | --namespace | --config-env | --super-prefix | --attr-source) i=$((i + 1)) ;;
      -*) ;;
      *) si=$i; return 0 ;;
    esac
  done
  return 0
}

# Sets cdir to the repo a commit segment runs in.
# Sets wide when the commit also takes working-tree content: -a, --all or paths.
commit_scope() { # commit_scope <base> <segment>
  local w i j
  gitcmd "$1" "$2"
  cdir="$gdir"
  wide=false
  for ((i = si + 1; si >= 0 && i < ${#words[@]}; i++)); do
    w="${words[i]}"
    case "$w" in
      --) ((i + 1 < ${#words[@]})) && wide=true; return 0 ;;
      --all | --pathspec-from-file*) wide=true ;;
      --author | --date | --message | --file | --reuse-message | --reedit-message | \
        --template | --cleanup | --trailer | --fixup | --squash) i=$((i + 1)) ;;
      --*) ;;
      -?*)
        for ((j = 1; j < ${#w}; j++)); do
          case "${w:j:1}" in
            a) wide=true ;;
            [mFCct]) ((j + 1 == ${#w})) && i=$((i + 1)); break ;;
          esac
        done
        ;;
      *) wide=true; return 0 ;;
    esac
  done
  return 0
}

# Records the paths a git add -f stages in fdir and fpath; the scratch index replays them.
forced_add() { # forced_add <base> <segment>
  local w i force=false rest=false paths=()
  gitcmd "$1" "$2"
  for ((i = si + 1; si >= 0 && i < ${#words[@]}; i++)); do
    w="${words[i]}"
    if $rest; then paths+=("$(dec "$w")"); continue; fi
    case "$w" in
      --) rest=true ;;
      --f*) force=true ;;
      --pathspec-from-file=*) paths+=(":/") ;;
      --*) ;;
      -*f*) force=true ;;
      -*) ;;
      *) paths+=("$(dec "$w")") ;;
    esac
  done
  $force || return 0
  ((${#paths[@]})) || paths=(":/")
  for w in "${paths[@]}"; do
    fdir+=("$gdir")
    fpath+=("$w")
  done
}

# True when a git config call writes a key that disables hooks, defines an alias or forces a push.
config_write() { # config_write <segment>
  local w i n=0 key=""
  gitcmd . "${1,,}"
  ((si >= 0)) && [[ "${words[si]}" == config ]] || return 1
  for ((i = si + 1; i < ${#words[@]}; i++)); do
    w="${words[i]}"
    case "$w" in
      --get* | -l | --list | --unset* | --remove-section | --rename-section | -e | --edit | \
        get | list | unset | remove-section | rename-section | edit) return 1 ;;
      -f | --file | --blob | --type | --default | --comment | --value | --url) i=$((i + 1)) ;;
      set | -*) ;;
      *) ((n++)) || key="$(dec "$w")" ;;
    esac
  done
  ((n >= 2)) && [[ "$key" =~ ^(core\.hookspath|alias\..+|remote\..+\.(push|mirror))$ ]]
}

# Runs one gitleaks protect pass; a finding blocks.
leaks() { # leaks <repo> [--staged]
  local out rc=0
  out="$("$GITLEAKS" protect ${2:+"$2"} --source "$1" --no-banner --redact -v \
    --log-level error --exit-code 42 2>&1)" || rc=$?
  if [[ "$rc" -eq 42 ]]; then
    printf 'Blocked: gitleaks found secrets in this commit.\n%s\n' "$out" >&2
    exit 2
  elif [[ "$rc" -ne 0 ]]; then
    printf 'git-guard: gitleaks failed (exit %s); commit not scanned.\n%s\n' "$rc" "$out" >&2
  fi
}

# Scans what the commit can contain. Hook time precedes the whole Bash call, so an earlier
# git add has not run yet: a scratch index with untracked files as intent-to-add covers it.
scan() { # scan <repo> <wide> <added>
  if ! command -v "$GITLEAKS" >/dev/null 2>&1; then
    echo "git-guard: gitleaks not found; this commit is not scanned for secrets." >&2
    return 0
  fi
  leaks "$1" --staged
  if [[ "$3" == true ]]; then
    local index k
    tmp="$(mktemp -d)"
    index="$(git -C "$1" rev-parse --path-format=absolute --git-path index 2>/dev/null)" || index=""
    [[ -f "$index" ]] && cp "$index" "$tmp/index"
    GIT_INDEX_FILE="$tmp/index" git -C "$1" add -N -A >/dev/null 2>&1 || true
    for k in "${!fpath[@]}"; do
      GIT_INDEX_FILE="$tmp/index" git -C "${fdir[k]}" add -N -f -- "${fpath[k]}" >/dev/null 2>&1 || true
    done
    GIT_INDEX_FILE="$tmp/index" leaks "$1"
    rm -rf "$tmp"
  elif [[ "$2" == true ]]; then
    leaks "$1"
  fi
}

added=false
env_cfg=""
stack=()
pd=()
fdir=()
fpath=()
for seg in "${lines[@]:1}"; do
  case "$seg" in
    '%{') stack+=("$dir"); continue ;;
    '%}') if ((${#stack[@]})); then dir="${stack[-1]}"; unset 'stack[-1]'; fi; continue ;;
  esac
  if [[ "$seg" =~ ^[[:space:]]*cd(([[:space:]]+-[LPe@]+)*|[[:space:]]+--)([[:space:]]+([^[:space:]]+))?[[:space:]]*$ ]]; then
    target="$(dec "${BASH_REMATCH[4]:-~}")"
    [[ "$target" == "-" ]] || dir="$(resolve "$dir" "$target")"
    continue
  fi
  if [[ "$seg" =~ ^[[:space:]]*pushd([[:space:]]+--)?[[:space:]]+([^-+[:space:]][^[:space:]]*)[[:space:]]*$ ]]; then
    pd+=("$dir")
    dir="$(resolve "$dir" "$(dec "${BASH_REMATCH[2]}")")"
    continue
  fi
  if [[ "$seg" =~ ^[[:space:]]*popd[[:space:]]*$ ]]; then
    if ((${#pd[@]})); then dir="${pd[-1]}"; unset 'pd[-1]'; fi
    continue
  fi
  low="${seg,,}"
  [[ "$low" =~ git_config_(parameters|count|key_[0-9]+|value_[0-9]+)= ]] && env_cfg+=" $low"
  [[ "$seg" =~ $g ]] || continue
  ctx="$low$env_cfg"
  hooks_off=false
  [[ "$ctx" =~ $hooks_path ]] && hooks_off=true
  if config_write "$seg"; then
    echo 'Blocked: git config may not write core.hooksPath, alias.*, remote.*.push or remote.*.mirror.' >&2
    exit 2
  fi
  if [[ "$ctx" =~ $alias_cfg ]]; then
    echo 'Blocked: git -c, --config-env and GIT_CONFIG_* may not define an alias.' >&2
    exit 2
  fi
  if [[ "$seg" =~ ${g}push([[:space:]]|$) ]] &&
    { [[ "$seg" =~ $push_bad ]] || [[ "$ctx" =~ $push_cfg ]] || $hooks_off; }; then
    echo 'Blocked: git push with force, +refspec, --mirror, --no-verify, a forcing (+) push refspec or mirror override, or core.hooksPath is not allowed.' >&2
    exit 2
  fi
  if [[ "$seg" =~ ${g}(add|stage)([[:space:]]|$) ]]; then
    added=true
    forced_add "$dir" "$seg"
  fi
  if [[ "$seg" =~ ${g}commit([[:space:]]|$) ]]; then
    if [[ "$seg" =~ $commit_bad ]] || $hooks_off; then
      echo 'Blocked: git commit with -n, --no-verify or core.hooksPath is not allowed.' >&2
      exit 2
    fi
    commit_scope "$dir" "$seg"
    scan "$cdir" "$wide" "$added"
  fi
done
exit 0
