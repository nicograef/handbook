#!/usr/bin/env bash
# report-repo-status.sh – list git repos holding work that exists nowhere else
#
# Usage:
#   repo-status [root]          # installed by install-dotfiles.sh; root defaults to ~/r
#
# What it does:
#   1. Finds every repo up to three levels below the root
#   2. Reports uncommitted changes, commits no remote branch contains, stashes and missing remotes
#
# Git remotes are the only durable copy on a machine without backup; anything listed is lost with the disk.
set -euo pipefail
export LC_ALL=C

ROOT="${1:-${REPO_ROOT:-$HOME/r}}"
dirty=0

while IFS= read -r gitdir; do
  repo="$(dirname "$gitdir")"
  name="${repo#"$ROOT"/}"
  issues=()

  [[ -n "$(git -C "$repo" status --porcelain)" ]] && issues+=("uncommitted changes")

  if git -C "$repo" remote | grep -q .; then
    unpushed="$(git -C "$repo" log --branches --not --remotes --oneline | wc -l)"
    [[ "$unpushed" -gt 0 ]] && issues+=("$unpushed unpushed commit(s)")
  else
    issues+=("no remote")
  fi

  [[ -n "$(git -C "$repo" stash list)" ]] && issues+=("stashed work")

  if [[ ${#issues[@]} -gt 0 ]]; then
    dirty=1
    printf '\033[1;33m%s\033[0m: %s\n' "$name" "$(IFS=', '; echo "${issues[*]}")"
  fi
done < <(find "$ROOT" -maxdepth 3 -type d -name .git 2>/dev/null)

if [[ $dirty -eq 0 ]]; then
  printf '\033[1;32mAll repos under %s are pushed and clean.\033[0m\n' "$ROOT"
fi
