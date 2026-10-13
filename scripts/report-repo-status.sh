#!/usr/bin/env bash
# report-repo-status.sh – list git repos holding work that exists nowhere else
#
# Usage:
#   repo-status [root]          # installed by install-dotfiles.sh; root defaults to ~/r
#
# What it does:
#   1. Finds every repo up to three levels below the root, plus each repo's linked worktrees
#   2. Reports uncommitted changes per worktree, and per repo stashes, missing remotes and commits
#      no remote-tracking ref contains, from any branch or worktree HEAD
#   3. Reports a repo git cannot read, and exits 1 when the root is not a directory
#
# Git remotes are the only durable copy on a machine without backup; anything listed is lost with the disk.
set -euo pipefail
export LC_ALL=C

ROOT="${1:-${REPO_ROOT:-$HOME/r}}"
if [[ ! -d "$ROOT" ]]; then
  printf 'repo-status: %s is not a directory\n' "$ROOT" >&2
  exit 1
fi
# git prints worktree paths resolved, so the root must be too for names to come out relative.
ROOT="$(cd "$ROOT" && pwd -P)"
dirty=0

# report prints one line for a path with issues: report <path> [issue...]
report() {
  local path="$1"
  shift
  [[ $# -gt 0 ]] || return 0
  dirty=1
  local joined
  printf -v joined '%s, ' "$@"
  printf '\033[1;33m%s\033[0m: %s\n' "${path#"$ROOT"/}" "${joined%, }"
}

while IFS= read -r gitdir; do
  repo="$(dirname "$gitdir")"
  issues=()

  if ! status="$(git -C "$repo" status --porcelain)"; then
    issues+=("git status failed")
  elif [[ -n "$status" ]]; then
    issues+=("uncommitted changes")
  fi

  worktrees="$(git -C "$repo" worktree list --porcelain)" || issues+=("git worktree list failed")
  # Branches and worktree HEADs hold local work; tags and notes may come from the remote, which
  # --remotes cannot subtract. An unborn HEAD prints as all zeros.
  mapfile -t heads < <(sed -n '/^HEAD 0*$/d; s/^HEAD //p' <<<"$worktrees")

  if ! remotes="$(git -C "$repo" remote)"; then
    issues+=("git remote failed")
  elif [[ -z "$remotes" ]]; then
    issues+=("no remote")
  elif ! unpushed="$(git -C "$repo" rev-list --count --branches ${heads[@]+"${heads[@]}"} --not --remotes)"; then
    issues+=("git rev-list failed")
  elif [[ "$unpushed" -gt 0 ]]; then
    issues+=("$unpushed unpushed commit(s)")
  fi

  # refs/stash is shared, so every worktree lists the same stashes.
  if ! stashes="$(git -C "$repo" stash list)"; then
    issues+=("git stash failed")
  elif [[ -n "$stashes" ]]; then
    issues+=("stashed work")
  fi

  report "$repo" ${issues[@]+"${issues[@]}"}

  # Entries after the first are linked worktrees; a missing directory holds nothing to lose.
  while IFS= read -r wt; do
    [[ -d "$wt" ]] || continue
    if ! status="$(git -C "$wt" status --porcelain)"; then
      report "$wt" "git status failed"
    elif [[ -n "$status" ]]; then
      report "$wt" "uncommitted changes"
    fi
  done < <(sed -n 's/^worktree //p' <<<"$worktrees" | tail -n +2)
done < <(find "$ROOT" -maxdepth 4 -type d -name .git -prune 2>/dev/null)

if [[ $dirty -eq 0 ]]; then
  printf '\033[1;32mAll repos under %s are pushed and clean.\033[0m\n' "$ROOT"
fi
