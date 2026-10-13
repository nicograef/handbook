#!/usr/bin/env bash
# test-git-guard.sh – fixture test for plugin/scripts/git-guard.sh.
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
#   4. Runs the plugin hook command against a missing and a crashing guard; both block.
#   5. Runs the guard without jq and with a failing jq; both block.

set -euo pipefail

# shellcheck source=scripts/lib/test-harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/test-harness.sh"

GUARD="$REPO_ROOT/plugin/scripts/git-guard.sh"

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
expect 2 "\$(...) inside double quotes" "echo \"\$(git push -f)\""
expect 2 "backticks inside double quotes" "echo \"\`git push --force\`\""
expect 2 "heredoc read by bash" $'bash <<\'EOF\'\ngit push -f\nEOF'
expect 2 "heredoc read by sudo sh" $'sudo sh <<\'EOF\'\ngit push -f\nEOF'
expect 2 "top-level cat heredoc piped to sh" $'cat <<\'EOF\' | sh\ngit push -f\nEOF'
expect 2 "\$(...) in an unquoted python heredoc" $'python3 - <<EOF\nx = "$(git push -f)"\nEOF'
expect 2 "cat heredoc piped to a shell" $'echo "$(cat <<\'EOF\' | bash\ngit push -f\nEOF\n)"'
expect 2 "command after an empty cat heredoc" $'echo "$(cat <<\'EOF\'\nEOF\ngit push -f\nEOF\n)"'
expect 2 "heredoc text in plain double quotes" $'echo "cat <<\'EOF\'\n$(git push -f)\nEOF"'
expect 2 "nested quotes in \$(...)" $'echo "$(echo "a"; git push -f)"'
expect 2 "nested quotes in a commit message \$(...)" $'git commit -m "$(printf "%s" x && git push --force)"'
expect 2 "nested quotes in backticks" $'echo "`echo "a"; git push -f`"'
expect 2 "\$(...) in an unquoted cat heredoc" $'git commit -m "$(cat <<EOF\nrun $(git push -f)\nEOF\n)"'
expect 2 "empty quotes inside the git word" "gi''t push -f"
expect 2 "backslash inside the git word" 'g\it push -f'
expect 2 "double quotes inside the git word" 'g"i"t push -f'
expect 2 "quoted end of the git word" 'gi"t" commit -n -m x'
expect 2 "line continuation inside the git word" $'g\\\nit push -f'
expect 2 "ANSI-C quoted git word" "\$'git' push -f"
expect 2 "ANSI-C hex escape in the git word" "\$'\\x67it' push -f"
expect 2 "ANSI-C octal escapes in the git word" "\$'\\147\\151\\164' push -f"
expect 2 "locale-quoted git word" '$"git" push -f'
expect 2 "--git-dir before push" 'git --git-dir .git push -f'
expect 2 "--work-tree before push" 'git --work-tree . push --force'
expect 2 "--namespace before push" 'git --namespace foo push --force'
expect 2 "--attr-source before push" 'git --attr-source HEAD push -f'
expect 2 "--git-dir before commit -n" 'git --git-dir .git commit -n -m x'
expect 2 "--config-env core.hooksPath" 'HP=/dev/null git --config-env core.hooksPath=HP commit -m x'
expect 2 "abbreviated --no-verify on commit" 'git commit --no-veri -m x'
expect 2 "longer abbreviated --no-verify on commit" 'git commit --no-verif -m x'
expect 2 "abbreviated --no-verify on push" 'git push --no-veri origin main'
expect 2 "abbreviated --mirror" 'git push --mirro origin'
expect 2 "shortest --mirror prefix" 'git push --m origin'
expect 2 "core.hooksPath in GIT_CONFIG_PARAMETERS" "GIT_CONFIG_PARAMETERS=\"'core.hooksPath=/dev/null'\" git commit -m x"
expect 2 "exported GIT_CONFIG_PARAMETERS" "export GIT_CONFIG_PARAMETERS=\"'core.hooksPath=/dev/null'\"; git commit -m x"
expect 2 "+refspec in GIT_CONFIG_VALUE_n" \
  'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=remote.origin.push GIT_CONFIG_VALUE_0=+HEAD:main git push origin'
expect 2 "+refspec through -c" 'git -c remote.origin.push=+HEAD:refs/heads/main push origin'
expect 2 "mirror through -c" 'git -c remote.origin.mirror=true push origin'
expect 2 "alias through -c" 'git -c alias.p="push --force" p origin main'
expect 2 "alias through --config-env" 'P="push -f" git --config-env=alias.p=P p origin main'
expect 2 "alias in GIT_CONFIG_KEY_n" 'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.p GIT_CONFIG_VALUE_0="push -f" git p'
expect 2 "alias in GIT_CONFIG_PARAMETERS" "GIT_CONFIG_PARAMETERS=\"'core.x=1' 'alias.p=push -f'\" git p"
expect 2 "mirror in GIT_CONFIG_KEY_n" 'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=remote.origin.mirror GIT_CONFIG_VALUE_0=true git push origin'
expect 2 "git config writes core.hooksPath" 'git config core.hooksPath /dev/null && git commit -m x'
expect 2 "git config set core.hooksPath" 'git config set core.hooksPath /dev/null'
expect 2 "git config writes an alias" 'git config alias.pf "push -f"; git pf origin main'
expect 2 "git config writes a push refspec" 'git -C x config --add remote.origin.push +HEAD:main'

# 2. Calls the guard lets through.
expect 0 "quoted -f in a commit message" 'git commit -m "drop the -f flag"'
expect 0 "quoted -n in a wrapped commit message" 'bash -c "git commit -m \"a -n b\""'
expect 0 "plain push" 'git push origin main'
expect 0 "git push -f only inside echo" 'echo "git push -f"'
expect 0 "commit --amend --no-edit" 'git commit --amend --no-edit'
expect 0 "core.hooksPath in a commit message" 'git commit -m "set core.hooksPath"'
expect 0 "single-quoted \$(...) in a commit message" "git commit -m 'x \$(git push -f)'"
expect 0 "python heredoc that names a force push" $'python3 - <<\'EOF\'\nprint("bash -c \'git push --force\'")\nEOF'
expect 0 "cat heredoc written to a file" $'cat > notes.md <<\'EOF\'\ngit push -f\nEOF'
expect 0 "quoted cat heredoc as a commit message" $'git commit -m "$(cat <<\'EOF\'\nblock git push -f\nEOF\n)"'
expect 0 "quotes and backticks in a quoted cat heredoc" \
  $'git commit -m "$(cat <<\'EOF\'\ndon\'t "x" `git push -f`\nEOF\n)"'
expect 0 "unquoted cat heredoc as a commit message" $'git commit -m "$(cat <<EOF\nnever run git push -f\nEOF\n)"'
expect 0 "push --no-verbose" 'git push --no-verbose origin main'
expect 0 "push refspec override without +" 'git -c remote.origin.push=HEAD:main push origin'
expect 0 "alias.<x>= in a commit message" 'git commit -m "alias.co=checkout is handy"'
expect 0 "core.hooksPath= in a commit message" 'git commit -m "core.hooksPath=/dev/null skips hooks"'
expect 0 "remote mirror key in a push option" 'git push -o "remote.origin.mirror=true" origin main'
expect 0 "git config reads core.hooksPath" 'git config core.hooksPath'
expect 0 "git config --get core.hooksPath" 'git config --get core.hooksPath'
expect 0 "git config --unset core.hooksPath" 'git config --unset core.hooksPath'
expect 0 "git config reads an alias" 'git config --get alias.pf'
expect 0 "git config writes another key" 'git config user.name x'

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
# A forced add in the same call also stages an ignored file; the scratch index replays it.
run 'git add -f ignored.txt && git commit -m x'
if [[ "$(sed -n 2p "$CALLS")" == "index protect --source $WORK "*"| ignored.txt tracked.txt untracked.txt " ]]; then
  log "git add -f -> scratch index holds the ignored file"
else
  fail "git add -f: unexpected scans: $(cat "$CALLS")"
fi

# 7. The scan follows -C and cd to the repo the commit runs in, quoted or not.
run 'git -C sub commit -m x'
if grep -q -- "--source $WORK/sub " "$CALLS"; then log "-C sub -> scans sub"; else fail "-C: $(cat "$CALLS")"; fi
run "cd $FIX/other && git commit -m x"
if grep -q -- "--source $FIX/other " "$CALLS"; then log "cd dir -> scans dir"; else fail "cd: $(cat "$CALLS")"; fi
run "git -C \"$FIX/my repo\" commit -m x" /
if grep -q -- "--source $FIX/my repo " "$CALLS"; then log "quoted -C -> scans it"; else fail "quoted -C: $(cat "$CALLS")"; fi
run "cd '$FIX/my repo' && git commit -m x" /
if grep -q -- "--source $FIX/my repo " "$CALLS"; then log "quoted cd -> scans it"; else fail "quoted cd: $(cat "$CALLS")"; fi
run "git --git-dir $FIX/other/.git commit -m x"
if grep -q -- "--source $FIX/other " "$CALLS"; then log "--git-dir -> scans its repo"; else fail "--git-dir: $(cat "$CALLS")"; fi
run 'git --work-tree sub commit -m x'
if grep -q -- "--source $WORK/sub " "$CALLS"; then log "--work-tree -> scans it"; else fail "--work-tree: $(cat "$CALLS")"; fi
run "pushd $FIX/other && git commit -m x"
if grep -q -- "--source $FIX/other " "$CALLS"; then log "pushd -> scans it"; else fail "pushd: $(cat "$CALLS")"; fi
run "pushd $FIX/other; popd; git commit -m x"
if grep -q -- "--source $WORK " "$CALLS"; then log "popd -> scans the cwd"; else fail "popd: $(cat "$CALLS")"; fi
run "(cd $FIX/other && git commit -m x)"
if grep -q -- "--source $FIX/other " "$CALLS"; then log "cd in a subshell -> scans it there"; else fail "subshell cd: $(cat "$CALLS")"; fi

# 7b. A cd inside a subshell or a substitution leaves the commit after it in the cwd.
for cmd in "(cd $FIX/other && ls) && git commit -m x" "x=\$(cd $FIX/other && pwd); git commit -m x" \
  "x=\`cd $FIX/other\`; git commit -m x" "echo \"\$(cd $FIX/other)\"; git commit -m x"; do
  run "$cmd"
  if grep -q -- "--source $WORK " "$CALLS" && ! grep -q -- "--source $FIX/other " "$CALLS"; then
    log "$cmd -> scans the cwd"
  else
    fail "$cmd: unexpected scans: $(cat "$CALLS")"
  fi
done

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

# 11. The plugin hook wrapper fails closed: a missing or crashing guard blocks.
HOOK="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$REPO_ROOT/plugin/hooks/hooks.json")"
mkdir -p "$FIX/root-empty" "$FIX/root-crash/scripts"
printf '#!/usr/bin/env bash\nexit 1\n' > "$FIX/root-crash/scripts/git-guard.sh"
chmod +x "$FIX/root-crash/scripts/git-guard.sh"
wrap() { # wrap <expected rc> <label> <plugin root> <command>
  rc=0
  jq -n --arg c "$4" --arg d "$WORK" '{tool_input: {command: $c}, cwd: $d}' |
    CLAUDE_PLUGIN_ROOT="$3" bash -c "$HOOK" 2> "$ERR" || rc=$?
  if [[ "$rc" -eq "$1" ]]; then log "$2 -> exit $1"; else fail "$2: expected exit $1, got $rc: $(cat "$ERR")"; fi
}
wrap 0 "hook wrapper, harmless command" "$REPO_ROOT/plugin" 'ls'
wrap 2 "hook wrapper, force push" "$REPO_ROOT/plugin" 'git push -f'
wrap 2 "hook wrapper, guard missing" "$FIX/root-empty" 'ls'
grep -q 'is missing' "$ERR" || fail "guard missing: no reason on stderr: $(cat "$ERR")"
wrap 2 "hook wrapper, guard crashes" "$FIX/root-crash" 'ls'

# 12. The guard fails closed when jq is missing or fails on the payload.
mkdir -p "$FIX/nojq" "$FIX/badjq"
for tool in cat rm; do ln -s "$(command -v "$tool")" "$FIX/nojq/$tool"; done
printf '#!/usr/bin/env bash\nexit 5\n' > "$FIX/badjq/jq"
chmod +x "$FIX/badjq/jq"
BASH_BIN="$(command -v bash)"
PUSH="$(jq -n '{tool_input: {command: "git push -f"}, cwd: "/tmp"}')"
nojq() { # nojq <expected stderr> <label> <PATH>
  rc=0
  printf '%s' "$PUSH" | PATH="$3" "$BASH_BIN" "$GUARD" 2> "$ERR" || rc=$?
  if [[ "$rc" -eq 2 ]] && grep -q "$1" "$ERR"; then
    log "$2 -> exit 2"
  else
    fail "$2: expected exit 2 with '$1', got $rc: $(cat "$ERR")"
  fi
}
nojq 'jq not found' "jq missing" "$FIX/nojq"
nojq 'jq failed' "jq fails" "$FIX/badjq:$PATH"

finish
