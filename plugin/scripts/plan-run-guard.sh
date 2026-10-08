#!/usr/bin/env bash
# plan-run-guard.sh – Stop-hook guard that keeps a live implement-plan run going.
#
# Usage:
#   Wired as a Stop hook in plugin/hooks/hooks.json; reads the hook payload on stdin.
#   plugin/scripts/plan-run-guard.sh < payload.json
#   plugin/scripts/plan-run-guard.sh claim <slug>   # this session owns plan/<slug>
#
# What it does:
#   1. Allows the stop unless a plan run is live in the payload's cwd.
#   2. Live means a plan/<slug> branch exists whose own copy of
#      docs/plans/plan-<slug>.md still holds an unticked criterion.
#   3. Reads that copy from the branch, never from the calling checkout — the
#      base-branch copy stays stale by design until the run lands.
#   4. Nudges once per branch tip. A run that stops committing goes quiet, so an
#      abandoned branch can never trap the repo.
#   5. Nudges the session that claimed the run and no other. Sessions share a
#      repo, and a bystander told to continue a peer's run would write its files.
#      A run nobody claimed nudges whoever stops.
#   6. Never nudges while a top-level subagent, a workflow run, or a /tmp task
#      is live — the harness re-invokes on completion, so that stop is safe.
#   7. Opt out per checkout or worktree: touch "$(git rev-parse --git-dir)/plan-run-guard-off".

set -euo pipefail

# Stdout is the hook protocol, so status output would corrupt it. Silence is allow.
allow() { exit 0; }

# The claim lives beside the nudge markers in the common dir, so every worktree
# of the repo reads the same owner.
if [[ "${1:-}" == "claim" ]]; then
  slug="${2:-}"
  sid="${CLAUDE_CODE_SESSION_ID:-}"
  if [[ -z "$slug" || -z "$sid" ]]; then
    echo "usage: CLAUDE_CODE_SESSION_ID=<id> plan-run-guard.sh claim <slug>" >&2
    exit 2
  fi
  common="$(git rev-parse --path-format=absolute --git-common-dir)"
  mkdir -p "$common/plan-run-guard"
  printf '%s\n' "$sid" > "$common/plan-run-guard/owner-${slug//\//__}"
  exit 0
fi

payload="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  allow
fi

# One field per line, so an empty cwd keeps its place.
fields=()
mapfile -t fields < <(printf '%s' "$payload" \
  | jq -r '(.stop_hook_active // false), (.cwd // ""), (.session_id // "nosession")' 2>/dev/null)
[[ "${#fields[@]}" -eq 3 ]] || allow
active="${fields[0]}" cwd="${fields[1]}" session="${fields[2]}"

# A stop this hook already continued is never blocked again; a payload without a
# usable cwd names no repo.
if [[ "$active" == "true" || -z "$cwd" || ! -d "$cwd" ]]; then
  allow
fi

dirs=()
mapfile -t dirs < <(git -C "$cwd" rev-parse --path-format=absolute --git-dir --git-common-dir 2>/dev/null)
[[ "${#dirs[@]}" -eq 2 ]] || allow
gitdir="${dirs[0]}"
# Worktrees share the common dir, so a lead on the base branch and a worker in
# the run worktree see the same nudge markers.
common="${dirs[1]}"
if [[ -e "$gitdir/plan-run-guard-off" ]]; then
  allow
fi

state="$common/plan-run-guard"
branches="$(git -C "$cwd" for-each-ref --format='%(refname:short)' 'refs/heads/plan/*' 2>/dev/null || true)"
# A claim goes with its branch. A landed run deletes the branch and nothing else
# knows the claim existed, so this hook sweeps it.
if [[ -z "$branches" ]]; then
  rm -f "$state"/owner-*
  allow
fi

# A transcript touched inside the window is work still running.
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
IDLE_MIN="${PLAN_RUN_GUARD_IDLE_MIN:-10}"
shopt -s nullglob
recent=(
  "$CONFIG_DIR"/projects/*/"$session"/subagents/agent-*.jsonl
  "$CONFIG_DIR"/projects/*/"$session"/subagents/workflows/*/agent-*.jsonl
  /tmp/"$session"/tasks/*.output
  /tmp/*/"$session"/tasks/*.output
  /tmp/*/*/"$session"/tasks/*.output
)
shopt -u nullglob
if [[ "${#recent[@]}" -gt 0 && -n "$(find "${recent[@]}" -maxdepth 0 \
       -newermt "-$IDLE_MIN minutes" -print -quit 2>/dev/null)" ]]; then
  allow
fi

mkdir -p "$state"
find "$state" -type f ! -name 'owner-*' -mtime +1 -delete 2>/dev/null || true

while IFS= read -r branch; do
  [[ -n "$branch" ]] || continue
  slug="${branch#plan/}"

  owner="$(cat "$state/owner-${slug//\//__}" 2>/dev/null || true)"
  if [[ -n "$owner" && "$owner" != "$session" ]]; then
    continue
  fi

  planbody="$(git -C "$cwd" show "$branch:docs/plans/plan-$slug.md" 2>/dev/null || true)"
  [[ -n "$planbody" ]] || continue

  next="$(printf '%s\n' "$planbody" | grep -m1 '^- \[ \] ' || true)"
  [[ -n "$next" ]] || continue
  next="${next#- \[ \] }"

  tip="$(git -C "$cwd" rev-parse "$branch" 2>/dev/null || echo unknown)"
  marker="$state/$session-$slug-$tip"
  [[ -e "$marker" ]] && continue
  : > "$marker"

  jq -nc --arg s "$slug" --arg n "$next" '{
    decision: "block",
    reason: ("Plan run " + $s + " has an unticked criterion: " + $n
      + ". Continue it. If it is genuinely blocked, commit the ## Run state block first, then stop.")
  }'
  exit 0
done <<< "$branches"

# Sweep the claims whose branch is gone.
for claim in "$state"/owner-*; do
  [[ -e "$claim" ]] || continue
  slug="$(basename "$claim")"; slug="${slug#owner-}"; slug="${slug//__//}"
  git -C "$cwd" show-ref --verify --quiet "refs/heads/plan/$slug" || rm -f "$claim"
done

allow
