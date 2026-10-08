#!/usr/bin/env bash
# git-guard.sh – PreToolUse Bash hook that blocks unsafe git calls and secret commits.
#
# Usage:
#   plugin/scripts/git-guard.sh < payload.json   # a PreToolUse Bash hook; exit 2 blocks with a reason on stderr
#
# What it does:
#   1. Allows at once when the payload cannot hold a git call.
#   2. Unwraps sh/bash/zsh -c payloads and eval arguments, then folds each quoted string into one word.
#      A command substitution inside double quotes or a heredoc is checked like a top-level command.
#      A heredoc body is data unless a shell reads it or its line pipes it into one.
#   3. Finds git behind a path, env, command or -C/-c options, per command segment.
#   4. Blocks pushes with force, +refspec, --mirror, --no-verify or a core.hooksPath override.
#   5. Blocks commits with -n, --no-verify or a core.hooksPath override.
#   6. Runs gitleaks on every other commit, in the repo of -C, cd or the payload cwd.
#      It scans the staged diff. -a or paths add tracked changes; an earlier git add also untracked files.
#   7. Without gitleaks it warns on stderr and allows.

set -euo pipefail

GITLEAKS="${GITLEAKS:-gitleaks}"

payload="$(cat)"
[[ "$payload" == *git* ]] || exit 0

# Prints the payload cwd, then one command segment per line. A payload that is not JSON is
# taken as the command itself. A quoted string becomes one word: separators, blanks and %
# inside it are %XX-encoded, and an empty one is %E. Each body scan_cmd finds adds its own
# segments after the command.
read -r -d '' JQ_PROG <<'JQ' || true
def quoted: "\\$'(?<a>(?:\\\\.|[^'\\\\])*)'|'(?<s>[^']*)'|\"(?<d>(?:\\\\.|[^\"\\\\])*)\"";
def quoted_bare: "\\$'(?:\\\\.|[^'\\\\])*'|'[^']*'|\"(?:\\\\.|[^\"\\\\])*\"";
def unq:
  if .a then .a | gsub("\\\\(?<e>.)"; if .e == "n" then "\n" elif .e == "t" then "\t" else .e end)
  elif .s then .s
  else .d | gsub("\\\\(?<e>[\"\\\\$`\\n])"; .e) end;
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
  "\\$\\(|\\$'|<<<|<<-?[ \\t]*(?:'[^'\\n]*'|\"[^\"\\n]*\"|\\\\?[^\\s;&|()<>'\"`\\\\$]+)"
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
    def quote($c; $f): cmd($c) | (if n == 1 then .qa = at else . end) | push($f; null);
    def close($c):
      if n == 2 then
        .k[1].c as $q
        | .ed += [[.qa, after($c), ({($q): cut([.qa[0], .qa[1] + ($c | length)]; at)} | unq | enc)]]
        | .k |= .[:-1]
      else pop | cmd($c) end;
    def lit($ch):
      (if top == "base" then .ed += [[[.l, .p - 1], after($ch), (if $ch == "\n" then " " else $ch | enc end)]]
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
      elif $f.c == "a" then (if $c == "\\" then .x = true elif $c == "'" then close("$'") else . end)
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
def segs:
  fix | scan_cmd
  | (.t | gsub("(?<=\\S)%E|%E(?=\\S)"; "") | gsub("[;&|()`\\n]"; "\n")),
    (.o[] | segs);
. as $raw | (try fromjson catch null) as $j
| ($j.cwd // ""),
  ((if $j == null then $raw else ($j.tool_input.command // "") end) | segs)
JQ
mapfile -t lines < <(printf '%s' "$payload" | jq -Rrs "$JQ_PROG" 2>/dev/null) || exit 0

cwd="${lines[0]:-}"
[[ -n "$cwd" ]] || cwd="$PWD"
dir="$cwd"

g='(^|[[:space:]]|/)git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+|[[:space:]]+-[^[:space:]]+)*[[:space:]]+'
push_bad='(^|[[:space:]])(--force[^[:space:]]*|--mirror|--no-verify|-[46nquv]*f[^[:space:]]*|\+[^[:space:]]+)'
commit_bad='(^|[[:space:]])(--no-verify|-[aeiopqsvz]*n[^[:space:]]*)'
# Matched against the lower-cased segment: -c, --config-env= and GIT_CONFIG_KEY_n= forms.
hooks_path='(^|[[:space:]=])core\.hookspath([[:space:]=]|$)'

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

# Sets cdir to the repo a commit segment runs in, applying each -C in turn.
# Sets wide when the commit also takes working-tree content: -a, --all or paths.
commit_scope() { # commit_scope <base> <segment>
  local words w i j state=git
  cdir="$1"
  wide=false
  read -ra words <<< "$2"
  for ((i = 0; i < ${#words[@]}; i++)); do
    w="${words[i]}"
    case "$state" in
      git) [[ "$w" =~ (^|/)git$ ]] && state=opt ;;
      opt)
        case "$w" in
          -C) i=$((i + 1)); cdir="$(resolve "$cdir" "$(dec "${words[i]:-.}")")" ;;
          -c) i=$((i + 1)) ;;
          -*) ;;
          *) state=arg ;;
        esac
        ;;
      arg)
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
        ;;
    esac
  done
  return 0
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
    local index
    tmp="$(mktemp -d)"
    index="$(git -C "$1" rev-parse --path-format=absolute --git-path index 2>/dev/null)" || index=""
    [[ -f "$index" ]] && cp "$index" "$tmp/index"
    GIT_INDEX_FILE="$tmp/index" git -C "$1" add -N -A >/dev/null 2>&1 || true
    GIT_INDEX_FILE="$tmp/index" leaks "$1"
    rm -rf "$tmp"
  elif [[ "$2" == true ]]; then
    leaks "$1"
  fi
}

added=false
for seg in "${lines[@]:1}"; do
  if [[ "$seg" =~ ^[[:space:]]*cd(([[:space:]]+-[LPe@]+)*|[[:space:]]+--)([[:space:]]+([^[:space:]]+))?[[:space:]]*$ ]]; then
    target="$(dec "${BASH_REMATCH[4]:-~}")"
    [[ "$target" == "-" ]] || dir="$(resolve "$dir" "$target")"
    continue
  fi
  hooks_off=false
  [[ "${seg,,}" =~ $hooks_path ]] && hooks_off=true
  if [[ "$seg" =~ ${g}push([[:space:]]|$) ]] && { [[ "$seg" =~ $push_bad ]] || $hooks_off; }; then
    echo 'Blocked: git push with force, +refspec, --mirror, --no-verify or core.hooksPath is not allowed.' >&2
    exit 2
  fi
  [[ "$seg" =~ ${g}(add|stage)([[:space:]]|$) ]] && added=true
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
