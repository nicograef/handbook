#!/usr/bin/env bash
# plan-run-guard.sh – Stop-hook guard that keeps a live implement-plan run going.
#
# Usage:
#   Registered by the implement-plan skill's frontmatter for the rest of the session;
#   reads the Stop hook payload on stdin.
#   plugin/scripts/plan-run-guard.sh < payload.json
#
# What it does:
#   1. Allows the stop unless a plan run is live in the payload's cwd. The hook outlives
#      the run in its session, so a landed or absent run never blocks.
#   2. Live means a plan/<slug> branch exists whose own copy of
#      docs/plans/plan-<slug>.md still holds an unticked criterion.
#   3. Reads that copy from the branch, never from the calling checkout — the
#      base-branch copy stays stale by design until the run lands.
#   4. Nudges once per branch tip. A run that stops committing goes quiet, so an
#      abandoned branch can never trap the session.
#   5. Never nudges while a top-level subagent, a workflow run, or a /tmp task
#      is live — the harness re-invokes on completion, so that stop is safe.

set -euo pipefail

# Stdout is the hook protocol, so status output would corrupt it. Silence is allow.
allow() { exit 0; }

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

# Worktrees share the common dir, so a lead on the base branch and a worker in
# the run worktree see the same nudge markers.
common="$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || allow

state="$common/plan-run-guard"
branches="$(git -C "$cwd" for-each-ref --format='%(refname:short)' 'refs/heads/plan/*' 2>/dev/null || true)"
[[ -n "$branches" ]] || allow

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
find "$state" -type f -mtime +1 -delete 2>/dev/null || true

while IFS= read -r branch; do
  [[ -n "$branch" ]] || continue
  slug="${branch#plan/}"

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

allow
