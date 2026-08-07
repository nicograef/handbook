#!/usr/bin/env bash
# plan-run-guard.sh – Stop-hook guard that keeps a live implement-plan run going.
#
# Usage:
#   Wired as a Stop hook in claude/settings.json; reads the hook payload on stdin.
#   scripts/plan-run-guard.sh < payload.json
#
# What it does:
#   1. Allows the stop unless a plan run is live in the payload's cwd.
#   2. Live means a plan/<slug> branch exists and docs/plans/plan-<slug>.md
#      still holds an unticked criterion.
#   3. Blocks once, naming the next criterion. stop_hook_active lets the very
#      next stop through, so a session can always end on the second attempt.
#   4. Opt out per repo: touch "$(git rev-parse --git-dir)/plan-run-guard-off".

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

gitdir=""
gitdir="$(git -C "$cwd" rev-parse --path-format=absolute --git-dir 2>/dev/null)" || allow
if [[ -e "$gitdir/plan-run-guard-off" ]]; then
  allow
fi

root=""
root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || allow

branches="$(git -C "$cwd" for-each-ref --format='%(refname:short)' 'refs/heads/plan/*' 2>/dev/null || true)"

while IFS= read -r branch; do
  [[ -n "$branch" ]] || continue
  slug="${branch#plan/}"
  plan="$root/docs/plans/plan-$slug.md"
  [[ -f "$plan" ]] || continue
  next="$(grep -m1 '^- \[ \] ' "$plan" 2>/dev/null || true)"
  [[ -n "$next" ]] || continue
  next="${next#- [ ] }"
  jq -nc --arg s "$slug" --arg n "$next" '{
    decision: "block",
    reason: ("Plan run " + $s + " has an unticked criterion: " + $n
      + ". Continue it. If it is genuinely blocked, commit the ## Run state block first, then stop.")
  }'
  exit 0
done <<< "$branches"

allow
