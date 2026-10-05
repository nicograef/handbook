#!/usr/bin/env bash
# git-guard.sh – PreToolUse Bash hook that blocks unsafe git calls and secret commits.
#
# Usage:
#   Wired as the PreToolUse Bash hook in claude/settings.json; reads the hook payload on stdin.
#   scripts/git-guard.sh < payload.json   # exit 2 blocks with a reason on stderr
#
# What it does:
#   1. Allows at once when the payload cannot hold a git call.
#   2. Unwraps sh/bash/zsh -c payloads and eval arguments, then strips quoted strings.
#   3. Finds git behind a path, env, command or -C/-c options, per command segment.
#   4. Blocks pushes with force, +refspec, --mirror or --no-verify.
#   5. Blocks commits with -n or --no-verify.
#   6. Runs gitleaks on every other commit, in the repo of -C, cd or the payload cwd.
#      -a/--all scans tracked changes, otherwise the staged diff. A finding blocks.
#   7. Without gitleaks it warns on stderr and allows.

set -euo pipefail

GITLEAKS="${GITLEAKS:-gitleaks}"

payload="$(cat)"
[[ "$payload" == *git* ]] || exit 0

# Prints the payload cwd, then one command segment per line with every quoted string gone.
# A payload that is not JSON is taken as the command itself.
# shellcheck disable=SC2016 # $raw, $j and $c are jq variables
mapfile -t lines < <(printf '%s' "$payload" | jq -Rrs '
  def unesc: gsub("\\\\(?<e>[\"\\\\$`])"; .e);
  def unquote: gsub("'"'"'(?<s>[^'"'"']*)'"'"'|\"(?<d>(?:\\\\.|[^\"\\\\])*)\"";
    if .s then .s else (.d | unesc) end);
  def step:
    gsub("(?<p>^|[\\s;&|(`])(?:\\S*/)?(?:ba|da|k|z)?sh\\s+(?:-\\S+\\s+)*?-[A-Za-z]*c\\s+(?:'"'"'(?<s>[^'"'"']*)'"'"'|\"(?<d>(?:\\\\.|[^\"\\\\])*)\"|(?<b>[^\\s;&|()]+))";
      "\(.p) ; \(if .s then .s elif .d then (.d | unesc) else .b end) ; ")
    | gsub("(?<p>^|[\\s;&|(`])eval(?<a>(?:\\s+(?:'"'"'[^'"'"']*'"'"'|\"(?:\\\\.|[^\"\\\\])*\"|[^\\s'"'"'\";&|()]+))+)";
      "\(.p) ; \(.a | unquote) ; ");
  def fix: . as $c | step | if . == $c then . else fix end;
  . as $raw | (try fromjson catch null) as $j
  | ($j.cwd // ""),
    ((if $j == null then $raw else ($j.tool_input.command // "") end)
     | fix
     | gsub("'"'"'[^'"'"']*'"'"'|\"(?:\\\\.|[^\"\\\\])*\""; "")
     | gsub("[;&|()`\\n]"; "\n"))
' 2>/dev/null) || exit 0

cwd="${lines[0]:-}"
[[ -n "$cwd" ]] || cwd="$PWD"
dir="$cwd"

g='(^|[[:space:]]|/)git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+|[[:space:]]+-[^[:space:]]+)*[[:space:]]+'
push_bad='(^|[[:space:]])(--force[^[:space:]]*|--mirror|--no-verify|-[46nquv]*f[^[:space:]]*|\+[^[:space:]]+)'
commit_bad='(^|[[:space:]])(--no-verify|-[aeiopqsvz]*n[^[:space:]]*)'
commit_all='(^|[[:space:]])(--all|-[eiopqsvz]*a[^[:space:]]*)'

# Resolves a path argument against a base directory.
resolve() { # resolve <base> <path>
  case "$2" in
    /*) printf '%s' "$2" ;;
    \~) printf '%s' "$HOME" ;;
    \~/*) printf '%s/%s' "$HOME" "${2#\~/}" ;;
    *) printf '%s/%s' "$1" "$2" ;;
  esac
}

# Prints the directory a git segment runs in: each -C before the subcommand applies in turn.
git_dir() { # git_dir <base> <segment>
  local base="$1" words i found=false
  read -ra words <<< "$2"
  for ((i = 0; i < ${#words[@]}; i++)); do
    if [[ "$found" == false ]]; then
      [[ "${words[i]}" =~ (^|/)git$ ]] && found=true
      continue
    fi
    case "${words[i]}" in
      -C) i=$((i + 1)); base="$(resolve "$base" "${words[i]:-.}")" ;;
      -c) i=$((i + 1)) ;;
      -*) ;;
      *) break ;;
    esac
  done
  printf '%s' "$base"
}

# Runs gitleaks over what the commit would contain; a finding blocks.
scan() { # scan <repo> <all>
  if ! command -v "$GITLEAKS" >/dev/null 2>&1; then
    echo "git-guard: gitleaks not found; this commit is not scanned for secrets." >&2
    return 0
  fi
  local modes=("--staged") mode out rc
  [[ "$2" == true ]] && modes+=("")
  for mode in "${modes[@]}"; do
    rc=0
    out="$("$GITLEAKS" protect ${mode:+"$mode"} --source "$1" --no-banner --redact -v \
      --log-level error --exit-code 42 2>&1)" || rc=$?
    if [[ "$rc" -eq 42 ]]; then
      printf 'Blocked: gitleaks found secrets in this commit.\n%s\n' "$out" >&2
      exit 2
    elif [[ "$rc" -ne 0 ]]; then
      printf 'git-guard: gitleaks failed (exit %s); commit not scanned.\n%s\n' "$rc" "$out" >&2
    fi
  done
}

for seg in "${lines[@]:1}"; do
  if [[ "$seg" =~ ^[[:space:]]*cd([[:space:]]+([^[:space:]]+))?[[:space:]]*$ ]]; then
    target="${BASH_REMATCH[2]:-~}"
    [[ "$target" == "-" ]] || dir="$(resolve "$dir" "$target")"
    continue
  fi
  if [[ "$seg" =~ ${g}push([[:space:]]|$) && "$seg" =~ $push_bad ]]; then
    echo 'Blocked: git push with force, +refspec, --mirror or --no-verify is not allowed.' >&2
    exit 2
  fi
  if [[ "$seg" =~ ${g}commit([[:space:]]|$) ]]; then
    if [[ "$seg" =~ $commit_bad ]]; then
      echo 'Blocked: git commit with -n or --no-verify is not allowed.' >&2
      exit 2
    fi
    all=false
    [[ "$seg" =~ $commit_all ]] && all=true
    scan "$(git_dir "$dir" "$seg")" "$all"
  fi
done
exit 0
