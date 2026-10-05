#!/usr/bin/env bash
# git-guard.sh – PreToolUse Bash hook that blocks unsafe git calls and secret commits.
#
# Usage:
#   scripts/git-guard.sh < payload.json   # a PreToolUse Bash hook; exit 2 blocks with a reason on stderr
#
# What it does:
#   1. Allows at once when the payload cannot hold a git call.
#   2. Unwraps sh/bash/zsh -c payloads and eval arguments, then folds each quoted string into one word.
#      A command substitution inside double quotes is checked like a top-level command.
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
# inside it are %XX-encoded, and an empty one is %E.
# Each $(...) or backtick body inside double quotes adds its own segments after the command.
# A cat heredoc with a quoted delimiter there is inert data, so its body is dropped.
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
def enc:
  if . == "" then "%E"
  else gsub("(?<c>[%\\s;&|()`])"; "%" + (.c | explode[0] | hex)) end;
def words:
  gsub(quoted + "|\\\\(?<e>[\\s\\S])";
    if .e == "\n" then " " elif .e then .e | enc else unq | enc end)
  | gsub("(?<=\\S)%E|%E(?=\\S)"; "")
  | gsub("[;&|()`\\n]"; "\n");
# The $(...) and backtick bodies of a double-quoted string; an unclosed one runs to the end.
def subs:
  reduce scan("\\\\[\\s\\S]|\\$\\(|[\\s\\S]") as $t ({m: 0, n: 0, q: false, b: "", o: []};
    if .m == 0 then
      if $t == "$(" then .m = 1 | .n = 1 | .b = ""
      elif $t == "`" then .m = 2 | .b = ""
      else . end
    elif .m == 2 then
      if $t == "`" then .o += [.b] | .m = 0 else .b += $t end
    elif .q then .q = ($t != "'") | .b += $t
    elif $t == ")" and .n == 1 then .o += [.b] | .m = 0
    else .n += (if $t == ")" then -1 elif $t == "(" or $t == "$(" then 1 else 0 end)
      | .q = ($t == "'") | .b += $t end)
  | .o + (if .m == 0 then [] else [.b] end) | .[];
def bodies:
  gsub("(?<p>^|[\\s;&|(])cat\\s+<<-?\\s*'(?<w>[^'\\s]+)'[ \\t]*\\n(?:[\\s\\S]*?\\n)?[ \\t]*\\k<w>[ \\t]*(?=\\n|$)";
    "\(.p)cat ")
  | subs;
def segs:
  fix
  | words,
    (match(quoted + "|\\\\[\\s\\S]"; "g").captures[] | select(.name == "d") | .string // empty
     | bodies | segs);
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

# Resolves a path argument against a base directory.
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
