#!/usr/bin/env bash
# test-plan-run-guard.sh – fixture test for scripts/plan-run-guard.sh.
#
# Usage:
#   scripts/test-plan-run-guard.sh    # or: make test-plan-run-guard
#
# What it does:
#   1. Builds a throwaway git repo under mktemp -d with a docs/plans/ tree.
#   2. Gives the run branch and the base branch different copies of the plan,
#      so a guard reading the wrong one fails the assertion.
#   3. Feeds synthetic Stop payloads and asserts block vs allow.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$REPO_ROOT/scripts/plan-run-guard.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC}  $*"; }

FAILED=0
fail() { echo -e "${RED}[FAIL]${NC}  $*" >&2; FAILED=1; }

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

REPO="$FIX/repo"
mkdir -p "$REPO/docs/plans"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.email test@example.com
git -C "$REPO" config user.name Test
echo seed > "$REPO/README.md"
git -C "$REPO" add -A
git -C "$REPO" commit -q -m seed

run() { # run [stop_hook_active] [session_id]
  printf '{"cwd":"%s","stop_hook_active":%s,"session_id":"%s","hook_event_name":"Stop"}' \
    "$REPO" "${1:-false}" "${2:-sessA}" | bash "$GUARD"
}

# 1. No plan branch at all — the guard must stay out of the way.
out="$(run)"
if [[ -n "$out" ]]; then fail "no plan branch: expected allow, got: $out"; else log "no plan branch -> allow"; fi

# 2. A plan file with unticked criteria but no branch is an unstarted plan.
cat > "$REPO/docs/plans/plan-unstarted.md" <<'EOF'
# Plan: unstarted
- [ ] Criterion that no run owns
EOF
git -C "$REPO" add -A && git -C "$REPO" commit -q -m unstarted
out="$(run)"
if [[ -n "$out" ]]; then fail "unstarted plan: expected allow, got: $out"; else log "unstarted plan -> allow"; fi

# The base-branch copy stays stale for the whole run: nothing is ticked here.
cat > "$REPO/docs/plans/plan-live.md" <<'EOF'
# Plan: live
- [ ] STALE base-branch criterion
- [ ] Later one
EOF
git -C "$REPO" add -A && git -C "$REPO" commit -q -m "base copy of the plan"

# The run branch ticks as it goes — this is the copy the guard must read.
git -C "$REPO" checkout -q -b plan/live
cat > "$REPO/docs/plans/plan-live.md" <<'EOF'
# Plan: live
- [x] STALE base-branch criterion
- [ ] Wire the resolver
EOF
git -C "$REPO" add -A && git -C "$REPO" commit -q -m "phase 1 ticked"
git -C "$REPO" checkout -q main

# 3. The reported criterion must come from the branch, not the checkout.
out="$(run)"
if [[ "$(jq -r '.decision' <<< "$out" 2>/dev/null)" != "block" ]]; then
  fail "live run: expected block, got: $out"
else
  reason="$(jq -r '.reason' <<< "$out")"
  case "$reason" in
    *STALE*)               fail "live run: read the base-branch copy: $reason" ;;
    *"- [ ]"*)             fail "live run: checkbox prefix not stripped: $reason" ;;
    *"Wire the resolver"*) log "live run -> block, reads the branch copy" ;;
    *)                     fail "live run: unexpected reason: $reason" ;;
  esac
fi

# 4. Same tip, same session — nudge once, then go quiet.
out="$(run false sessA)"
if [[ -n "$out" ]]; then fail "repeat tip: expected allow, got: $out"; else log "same tip again -> allow"; fi

# 5. The run commits again, so the guard may nudge once more.
git -C "$REPO" checkout -q plan/live
echo progress >> "$REPO/docs/plans/plan-live.md"
git -C "$REPO" add -A && git -C "$REPO" commit -q -m "phase 2 progress"
git -C "$REPO" checkout -q main
out="$(run false sessA)"
if [[ "$(jq -r '.decision' <<< "$out" 2>/dev/null)" != "block" ]]; then
  fail "advanced tip: expected block, got: $out"
else
  log "branch advanced -> block again"
fi

# 6. stop_hook_active must always let the session end.
out="$(run true sessB)"
if [[ -n "$out" ]]; then fail "stop_hook_active: expected allow, got: $out"; else log "stop_hook_active -> allow"; fi

# 7. The opt-out file disarms the guard.
touch "$REPO/.git/plan-run-guard-off"
out="$(run false sessC)"
if [[ -n "$out" ]]; then fail "opt-out: expected allow, got: $out"; else log "opt-out file -> allow"; fi
rm "$REPO/.git/plan-run-guard-off"

# 8. Every criterion ticked on the branch means the run is done.
git -C "$REPO" checkout -q plan/live
cat > "$REPO/docs/plans/plan-live.md" <<'EOF'
# Plan: live
- [x] STALE base-branch criterion
- [x] Wire the resolver
EOF
git -C "$REPO" add -A && git -C "$REPO" commit -q -m "all ticked"
git -C "$REPO" checkout -q main
out="$(run false sessD)"
if [[ -n "$out" ]]; then fail "all ticked: expected allow, got: $out"; else log "all criteria ticked -> allow"; fi

# 9. Live background work makes the stop safe — the harness re-invokes on it.
git -C "$REPO" checkout -q plan/live
cat > "$REPO/docs/plans/plan-live.md" <<'EOF'
# Plan: live
- [x] STALE base-branch criterion
- [ ] Still going
EOF
git -C "$REPO" add -A && git -C "$REPO" commit -q -m "unticked again"
git -C "$REPO" checkout -q main

AGENTS="$FIX/config/projects/proj/sessLIVE/subagents"
mkdir -p "$AGENTS"
echo '{}' > "$AGENTS/agent-running.jsonl"
out="$(CLAUDE_CONFIG_DIR="$FIX/config" run false sessLIVE)"
if [[ -n "$out" ]]; then fail "live agent: expected allow, got: $out"; else log "live background agent -> allow"; fi

# A silent agent is a stuck one, so the nudge comes back.
touch -d '2 hours ago' "$AGENTS/agent-running.jsonl"
out="$(CLAUDE_CONFIG_DIR="$FIX/config" run false sessLIVE)"
if [[ "$(jq -r '.decision' <<< "$out" 2>/dev/null)" != "block" ]]; then
  fail "stale agent: expected block, got: $out"
else
  log "agent silent past the window -> block"
fi

# 10. A branch carrying no plan file must not block.
git -C "$REPO" checkout -q plan/live
cat > "$REPO/docs/plans/plan-live.md" <<'EOF'
# Plan: live
- [x] STALE base-branch criterion
- [x] Still going
EOF
git -C "$REPO" add -A && git -C "$REPO" commit -q -m "live run finished"
git -C "$REPO" checkout -q main
git -C "$REPO" branch plan/orphan
out="$(run false sessE)"
if [[ -n "$out" ]]; then fail "orphan branch: expected allow, got: $out"; else log "branch without a plan file -> allow"; fi

if [[ "$FAILED" -eq 0 ]]; then
  log "all plan-run-guard checks passed"
else
  echo -e "${RED}[FAIL]${NC}  plan-run-guard test failed" >&2
  exit 1
fi
