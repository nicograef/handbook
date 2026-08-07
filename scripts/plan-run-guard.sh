#!/usr/bin/env bash
# plan-run-guard.sh – Stop-hook guard that keeps a live implement-plan run going.
#
# Usage:
#   Wired as a Stop hook in claude/settings.json; reads the hook payload on stdin.
#   scripts/plan-run-guard.sh < payload.json
#
# What it does:
#   1. Allows the stop unless a plan run is live in the payload's cwd.
#   2. Live means a plan/<slug> branch exists whose own copy of
#      docs/plans/plan-<slug>.md still holds an unticked criterion.
#   3. Reads that copy from the branch, never from the calling checkout — the
#      base-branch copy stays stale by design until the run lands.
#   4. Nudges once per branch tip. A run that stops committing goes quiet, so an
#      abandoned branch can never trap the repo.
#   5. Never nudges while the session has live background work — the harness
#      re-invokes on completion, so that stop is safe.
#   6. Opt out per repo: touch "$(git rev-parse --git-dir)/plan-run-guard-off".

set -euo pipefail

# Stdout is the hook protocol, so status output would corrupt it. Silence is allow.
allow() { exit 0; }

payload="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  allow
fi

# A stop this hook already continued is never blocked again.
if [[ "$(printf '%s' "$payload" | jq -r '.stop_hook_active // false')" == "true" ]]; then
  allow
fi

cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
if [[ -z "$cwd" || ! -d "$cwd" ]]; then
  allow
fi

session="$(printf '%s' "$payload" | jq -r '.session_id // "nosession"')"

# A stop with live background work is safe: the harness re-invokes on completion.
# A transcript touched inside the window is work still running.
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
IDLE_MIN="${PLAN_RUN_GUARD_IDLE_MIN:-10}"
if [[ -n "$(find "$CONFIG_DIR/projects" -path "*/$session/subagents/agent-*.jsonl" \
             -newermt "-$IDLE_MIN minutes" -print -quit 2>/dev/null)" ]]; then
  allow
fi
if [[ -n "$(find /tmp -maxdepth 5 -path "*/$session/tasks/*.output" \
             -newermt "-$IDLE_MIN minutes" -print -quit 2>/dev/null)" ]]; then
  allow
fi

gitdir=""
gitdir="$(git -C "$cwd" rev-parse --path-format=absolute --git-dir 2>/dev/null)" || allow
if [[ -e "$gitdir/plan-run-guard-off" ]]; then
  allow
fi

# Worktrees share the common dir, so a lead on the base branch and a worker in
# the run worktree see the same nudge markers.
common=""
common="$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || allow
state="$common/plan-run-guard"
mkdir -p "$state"
find "$state" -type f -mtime +1 -delete 2>/dev/null || true

branches="$(git -C "$cwd" for-each-ref --format='%(refname:short)' 'refs/heads/plan/*' 2>/dev/null || true)"

while IFS= read -r branch; do
  [[ -n "$branch" ]] || continue
  slug="${branch#plan/}"

  # The run's own copy of the plan, not the calling checkout's stale one.
  planbody="$(git -C "$cwd" show "$branch:docs/plans/plan-$slug.md" 2>/dev/null || true)"
  [[ -n "$planbody" ]] || continue

  next="$(printf '%s\n' "$planbody" | grep -m1 '^- \[ \] ' || true)"
  [[ -n "$next" ]] || continue
  next="${next#- \[ \] }"

  # One nudge per tip: a run that stops advancing stops being nudged.
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
