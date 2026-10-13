#!/usr/bin/env bash
# test-report-repo-status.sh – fixture test for scripts/report-repo-status.sh.
#
# Usage:
#   scripts/test-report-repo-status.sh    # or: make test-report-repo-status
#
# What it does:
#   1. Builds repos pushed to a bare remote under a temp root, isolated from the user's git config.
#   2. Asserts the clean message for a pushed repo with a clean linked worktree and a pushed tag.
#   3. Adds one kind of unsaved work per repo and asserts each one's line.
#   4. Asserts a missing root exits 1 instead of reporting clean.

set -euo pipefail

# shellcheck source=scripts/lib/test-harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/test-harness.sh"

SCRIPT="$REPO_ROOT/scripts/report-repo-status.sh"
ROOT="$FIX/root"
OUT="$FIX/stdout"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

# pushed_repo creates <path> with one commit on main, pushed to its own bare remote.
pushed_repo() {
  git init -q -b main --bare "$FIX/remotes/$(basename "$1").git"
  git init -q -b main "$1"
  git -C "$1" commit -q --allow-empty -m init
  git -C "$1" remote add origin "$FIX/remotes/$(basename "$1").git"
  git -C "$1" push -q -u origin main
}

# run_status runs the script on the root with colours stripped into OUT; returns its exit code.
run_status() {
  local rc=0
  "$SCRIPT" "$@" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > "$OUT" || rc=$?
  return "$rc"
}

expect_line() {
  grep -qxF "$1" "$OUT" || fail "expected line '$1'; got: $(cat "$OUT")"
}

log "pushed repo with a clean linked worktree is clean"
mkdir -p "$ROOT"
pushed_repo "$ROOT/clean"
git -C "$ROOT/clean" worktree add -q "$ROOT/clean-wt" -b side
git -C "$ROOT/clean-wt" push -q origin side
# A commit the remote holds only under a tag is not unpushed.
git -C "$ROOT/clean" checkout -q --detach
git -C "$ROOT/clean" commit -q --allow-empty -m release
git -C "$ROOT/clean" tag v1
git -C "$ROOT/clean" push -q origin v1
git -C "$ROOT/clean" checkout -q main
run_status "$ROOT" || fail "clean root exited non-zero"
expect_line "All repos under $ROOT are pushed and clean."

log "each kind of unsaved work is reported"
pushed_repo "$ROOT/dirty"
touch "$ROOT/dirty/new-file"

pushed_repo "$ROOT/wt"
git -C "$ROOT/wt" worktree add -q "$ROOT/wt-linked" -b feature
git -C "$ROOT/wt-linked" push -q origin feature
touch "$ROOT/wt-linked/new-file"

pushed_repo "$ROOT/ahead"
git -C "$ROOT/ahead" commit -q --allow-empty -m one
git -C "$ROOT/ahead" commit -q --allow-empty -m two

pushed_repo "$ROOT/detached"
git -C "$ROOT/detached" worktree add -q --detach "$ROOT/detached-wt" HEAD
git -C "$ROOT/detached-wt" commit -q --allow-empty -m detached-only

pushed_repo "$ROOT/stashed"
echo change > "$ROOT/stashed/file"
git -C "$ROOT/stashed" add file
git -C "$ROOT/stashed" stash -q

pushed_repo "$ROOT/both"
echo change > "$ROOT/both/file"
git -C "$ROOT/both" add file
git -C "$ROOT/both" stash -q
touch "$ROOT/both/new-file"

git init -q -b main "$ROOT/local"
git -C "$ROOT/local" commit -q --allow-empty -m init

mkdir -p "$ROOT/a/b"
git init -q -b main "$ROOT/a/b/deep"
git -C "$ROOT/a/b/deep" commit -q --allow-empty -m init

pushed_repo "$ROOT/broken"
echo garbage > "$ROOT/broken/.git/index"

run_status "$ROOT" || fail "dirty root exited non-zero"
expect_line "dirty: uncommitted changes"
expect_line "wt-linked: uncommitted changes"
expect_line "ahead: 2 unpushed commit(s)"
expect_line "detached: 1 unpushed commit(s)"
expect_line "stashed: stashed work"
expect_line "both: uncommitted changes, stashed work"
expect_line "local: no remote"
expect_line "a/b/deep: no remote"
grep -qF "broken: git status failed" "$OUT" || fail "unreadable repo not reported; got: $(cat "$OUT")"
grep -q '^clean' "$OUT" && fail "clean repo or worktree reported: $(grep '^clean' "$OUT")"
grep -qF "pushed and clean" "$OUT" && fail "dirty root reported clean"

log "a missing root exits 1"
if run_status "$FIX/missing"; then
  fail "missing root exited 0"
fi
grep -qF "pushed and clean" "$OUT" && fail "missing root reported clean"

finish
