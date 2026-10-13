#!/usr/bin/env bash
# report-repo-status.sh – list git repos holding work that exists nowhere else
#
# Usage:
#   repo-status [root]          # installed by install-dotfiles.sh; root defaults to ~/r
#
# What it does:
#   1. Finds every repo up to three levels below the root, plus each repo's linked worktrees
#   2. Reports uncommitted changes per worktree, and per repo commits no remote branch contains, stashes and missing remotes
#
# Git remotes are the only durable copy on a machine without backup; anything listed is lost with the disk.
set -euo pipefail
export LC_ALL=C

ROOT="${1:-${REPO_ROOT:-$HOME/r}}"
# git prints worktree paths resolved, so the root must be too for names to come out relative.
[[ -d "$ROOT" ]] && ROOT="$(cd "$ROOT" && pwd -P)"
dirty=0

# report prints one line for a path with issues: report <path> [issue...]
report() {
  local path="$1"
  shift
  [[ $# -gt 0 ]] || return 0
  dirty=1
  printf '\033[1;33m%s\033[0m: %s\n' "${path#"$ROOT"/}" "$(IFS=', '; echo "$*")"
}

while IFS= read -r gitdir; do
  repo="$(dirname "$gitdir")"
  issues=()

  [[ -n "$(git -C "$repo" status --porcelain)" ]] && issues+=("uncommitted changes")

  if git -C "$repo" remote | grep -q .; then
    unpushed="$(git -C "$repo" log --branches --not --remotes --oneline | wc -l)"
    [[ "$unpushed" -gt 0 ]] && issues+=("$unpushed unpushed commit(s)")
  else
    issues+=("no remote")
  fi

  # refs/stash is shared, so every worktree lists the same stashes.
  [[ -n "$(git -C "$repo" stash list)" ]] && issues+=("stashed work")

  report "$repo" ${issues[@]+"${issues[@]}"}

  # Entries after the first are linked worktrees; a missing directory holds nothing to lose.
  while IFS= read -r wt; do
    [[ -d "$wt" && -n "$(git -C "$wt" status --porcelain)" ]] && report "$wt" "uncommitted changes"
  done < <(git -C "$repo" worktree list --porcelain | sed -n 's/^worktree //p' | tail -n +2)
done < <(find "$ROOT" -maxdepth 3 -type d -name .git 2>/dev/null)

if [[ $dirty -eq 0 ]]; then
  printf '\033[1;32mAll repos under %s are pushed and clean.\033[0m\n' "$ROOT"
fi
