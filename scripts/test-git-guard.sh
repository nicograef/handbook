#!/usr/bin/env bash
# test-git-guard.sh – fixture test for scripts/git-guard.sh.
#
# Usage:
#   scripts/test-git-guard.sh    # or: make test-git-guard
#
# What it does:
#   1. Puts a gitleaks stub first on PATH that logs its arguments and reports
#      a finding while a marker file exists. Under a scratch index it also logs
#      the paths git diff shows there.
#   2. Feeds synthetic PreToolUse payloads and asserts block (exit 2) vs allow.
#   3. Asserts which repo and which diff each commit scan covers.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$REPO_ROOT/scripts/git-guard.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC}  $*"; }

FAILED=0
fail() { echo -e "${RED}[FAIL]${NC}  $*" >&2; FAILED=1; }

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

WORK="$FIX/work"
mkdir -p "$WORK/sub" "$FIX/other" "$FIX/my repo" "$FIX/bin"
# A repo with a staged, then edited file, an untracked file and an ignored one.
git -C "$WORK" init -q
printf 'ignored.txt\n' > "$WORK/.gitignore"
echo one > "$WORK/tracked.txt"
git -C "$WORK" add .gitignore tracked.txt
echo two >> "$WORK/tracked.txt"
touch "$WORK/untracked.txt" "$WORK/ignored.txt"
CALLS="$FIX/calls"
LEAK="$FIX/leak"
BROKEN="$FIX/broken"

# The stub honours --exit-code like gitleaks, so the guard's leak code reaches it.
cat > "$FIX/bin/gitleaks" <<EOF
#!/usr/bin/env bash
args="\$*" code=1 src=.
while [[ \$# -gt 0 ]]; do
  [[ "\$1" == --exit-code ]] && code="\$2"
  [[ "\$1" == --source ]] && src="\$2"
  shift
done
if [[ -n "\${GIT_INDEX_FILE:-}" ]]; then
  echo "index \$args| \$(git -C "\$src" diff --name-only | tr '\n' ' ')" >> "$CALLS"
else
  echo "\$args" >> "$CALLS"
fi
[[ -e "$BROKEN" ]] && { echo "FTL stub failure" >&2; exit 1; }
[[ -e "$LEAK" ]] || exit 0
echo "Finding:     aws_access_key_id = REDACTED"
echo "File:        creds.txt"
exit "\$code"
EOF
chmod +x "$FIX/bin/gitleaks"
export PATH="$FIX/bin:$PATH"

ERR="$FIX/stderr"
run() { # run <command> [cwd]; sets rc
  : > "$CALLS"
  rc=0
  jq -n --arg c "$1" --arg d "${2:-$WORK}" '{tool_input: {command: $c}, cwd: $d}' |
    bash "$GUARD" 2> "$ERR" || rc=$?
}

expect() { # expect <rc> <label> <command> [cwd]
  run "$3" "${4:-}"
  if [[ "$rc" -eq "$1" ]]; then log "$2 -> exit $1"; else fail "$2: expected exit $1, got $rc: $3"; fi
}

# 1. Pushes and commits the guard blocks, however they are wrapped.
expect 2 "bash -c wrapper" "bash -c 'git push --force'"
expect 2 "sh -c double-quoted wrapper" 'sh -c "git push -f"'
expect 2 "nested wrappers" "bash -c \"sh -c 'git push --force'\""
expect 2 "eval with bare words" 'eval git push -f'
expect 2 "eval with a quoted argument" "eval 'git push -f'"
expect 2 "git behind a path" '/usr/bin/git push -f'
expect 2 "git behind env" 'env FOO=1 git push --force-with-lease'
expect 2 "git behind command" 'command git push -f'
expect 2 "+refspec behind -C" 'git -C x push +main'
expect 2 "push --mirror" 'git push --mirror origin'
expect 2 "push --no-verify" 'git push --no-verify'
expect 2 "push in a later segment" 'make check && git push -f origin main'
expect 2 "commit -n" 'git commit -n -m x'
expect 2 "commit --no-verify" 'git commit --no-verify -m x'
expect 2 "commit -an cluster" 'git commit -an -m x'
expect 2 "bash -c --" "bash -c -- 'git push -f'"
expect 2 "shell option with an argument" "bash -o pipefail -c 'git push -f'"
expect 2 "ANSI-C quoted wrapper" "bash -c \$'git push -f'"
expect 2 "quoted git word" '"git" push -f'
expect 2 "backslashed git word" '\git push -f'
expect 2 "quoted -f flag" 'git push "-f"'
expect 2 "line continuation" $'git push \\\n  -f'
expect 2 "commit with core.hooksPath" 'git -c core.hooksPath=/dev/null commit -m x'
expect 2 "push with core.hooksPath" 'git -c core.hookspath= push'

# 2. Calls the guard lets through.
expect 0 "quoted -f in a commit message" 'git commit -m "drop the -f flag"'
expect 0 "quoted -n in a wrapped commit message" 'bash -c "git commit -m \"a -n b\""'
expect 0 "plain push" 'git push origin main'
expect 0 "git push -f only inside echo" 'echo "git push -f"'
expect 0 "commit --amend --no-edit" 'git commit --amend --no-edit'
expect 0 "core.hooksPath in a commit message" 'git commit -m "set core.hooksPath"'

# 3. A command without git never reaches jq or gitleaks.
expect 0 "no git" 'ls -la'
if [[ -s "$CALLS" ]]; then fail "no git: gitleaks ran"; else log "no git -> no scan"; fi

# 4. A commit scans the staged diff of the payload cwd.
expect 0 "clean staged commit" 'git commit -m x'
if [[ "$(cat "$CALLS")" == "protect --staged --source $WORK "* && "$(wc -l < "$CALLS")" -eq 1 ]]; then
  log "staged commit -> one staged scan of the cwd"
else
  fail "staged commit: unexpected scans: $(cat "$CALLS")"
fi

# 5. -a, --all and paths add the tracked working-tree changes.
for cmd in 'git commit -am x' 'git commit --all -m x' 'git commit -m "a b" tracked.txt'; do
  run "$cmd"
  if [[ "$(sed -n 2p "$CALLS")" == "protect --source $WORK "* && "$(wc -l < "$CALLS")" -eq 2 ]]; then
    log "$cmd -> staged and working-tree scans"
  else
    fail "$cmd: unexpected scans: $(cat "$CALLS")"
  fi
done

# 6. A git add earlier in the call has not run at hook time: a scratch index shows
#    the tracked edits and the untracked files it can stage, but no ignored file.
for cmd in 'git add untracked.txt && git commit -m x' 'bash -c "git add -A; git commit -m x"'; do
  run "$cmd"
  if [[ "$(sed -n 2p "$CALLS")" == "index protect --source $WORK "*"| tracked.txt untracked.txt " \
    && "$(wc -l < "$CALLS")" -eq 2 ]]; then
    log "$cmd -> staged and scratch-index scans"
  else
    fail "$cmd: unexpected scans: $(cat "$CALLS")"
  fi
done

# 7. The scan follows -C and cd to the repo the commit runs in, quoted or not.
run 'git -C sub commit -m x'
if grep -q -- "--source $WORK/sub " "$CALLS"; then log "-C sub -> scans sub"; else fail "-C: $(cat "$CALLS")"; fi
run "cd $FIX/other && git commit -m x"
if grep -q -- "--source $FIX/other " "$CALLS"; then log "cd dir -> scans dir"; else fail "cd: $(cat "$CALLS")"; fi
run "git -C \"$FIX/my repo\" commit -m x" /
if grep -q -- "--source $FIX/my repo " "$CALLS"; then log "quoted -C -> scans it"; else fail "quoted -C: $(cat "$CALLS")"; fi
run "cd '$FIX/my repo' && git commit -m x" /
if grep -q -- "--source $FIX/my repo " "$CALLS"; then log "quoted cd -> scans it"; else fail "quoted cd: $(cat "$CALLS")"; fi

# 8. A finding blocks, and stderr carries the gitleaks summary.
touch "$LEAK"
expect 2 "gitleaks finding" 'git commit -m "add creds"'
if grep -q 'creds.txt' "$ERR"; then log "finding -> summary on stderr"; else fail "finding: no summary: $(cat "$ERR")"; fi
expect 2 "gitleaks finding inside a wrapper" "bash -c 'git commit -m x'"
rm "$LEAK"

# 9. A broken or absent gitleaks warns and allows.
touch "$BROKEN"
expect 0 "gitleaks failure" 'git commit -m x'
if grep -q 'gitleaks failed' "$ERR"; then log "failure -> warning"; else fail "failure: no warning: $(cat "$ERR")"; fi
rm "$BROKEN"
rc=0
jq -n '{tool_input: {command: "git commit -m x"}, cwd: "/tmp"}' |
  GITLEAKS=gitleaks-absent bash "$GUARD" 2> "$ERR" || rc=$?
if [[ "$rc" -eq 0 ]] && grep -q 'gitleaks not found' "$ERR"; then
  log "gitleaks absent -> warning, allow"
else
  fail "gitleaks absent: rc $rc, stderr: $(cat "$ERR")"
fi

# 10. A payload that is not JSON is checked as the command itself.
rc=0
printf 'git push -f' | bash "$GUARD" 2> /dev/null || rc=$?
if [[ "$rc" -eq 2 ]]; then log "raw payload -> block"; else fail "raw payload: expected exit 2, got $rc"; fi

if [[ "$FAILED" -eq 0 ]]; then
  log "all git-guard checks passed"
else
  echo -e "${RED}[FAIL]${NC}  git-guard test failed" >&2
  exit 1
fi
