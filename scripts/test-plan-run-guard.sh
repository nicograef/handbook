#!/usr/bin/env bash
# test-plan-run-guard.sh – fixture test for scripts/plan-run-guard.sh.
#
# Usage:
#   scripts/test-plan-run-guard.sh    # or: make test-plan-run-guard
#
# What it does:
#   1. Builds a throwaway git repo under mktemp -d with a docs/plans/ tree.
#   2. Feeds the guard synthetic Stop payloads and asserts block vs allow.
#   3. Never touches a real repo — every path lives inside the fixture.

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

payload() { printf '{"cwd":"%s","stop_hook_active":%s,"hook_event_name":"Stop"}' "$REPO" "${1:-false}"; }
run() { payload "${1:-false}" | bash "$GUARD"; }

# 1. No plan branch at all — the guard must stay out of the way.
out="$(run)"
if [[ -n "$out" ]]; then fail "no plan branch: expected allow, got: $out"; else log "no plan branch -> allow"; fi

# 2. A plan file with unticked criteria but no branch is an unstarted plan.
cat > "$REPO/docs/plans/plan-unstarted.md" <<'EOF'
# Plan: unstarted
- [ ] Criterion that no run owns
EOF
out="$(run)"
if [[ -n "$out" ]]; then fail "unstarted plan: expected allow, got: $out"; else log "unstarted plan -> allow"; fi

# 3. A live run: plan/<slug> branch plus an unticked criterion.
git -C "$REPO" branch plan/live
cat > "$REPO/docs/plans/plan-live.md" <<'EOF'
# Plan: live
- [x] Already done
- [ ] Wire the resolver
- [ ] Later one
EOF
out="$(run)"
if [[ "$(jq -r '.decision' <<< "$out" 2>/dev/null)" != "block" ]]; then
  fail "live run: expected block, got: $out"
else
  reason="$(jq -r '.reason' <<< "$out")"
  case "$reason" in
    *"Wire the resolver"*) log "live run -> block, names the next criterion" ;;
    *) fail "live run: reason lost the criterion: $reason" ;;
  esac
fi

# 4. stop_hook_active must always let the session end.
out="$(run true)"
if [[ -n "$out" ]]; then fail "stop_hook_active: expected allow, got: $out"; else log "stop_hook_active -> allow"; fi

# 5. The opt-out file disarms the guard.
touch "$REPO/.git/plan-run-guard-off"
out="$(run)"
if [[ -n "$out" ]]; then fail "opt-out: expected allow, got: $out"; else log "opt-out file -> allow"; fi
rm "$REPO/.git/plan-run-guard-off"

# 6. Every criterion ticked means the run is done.
cat > "$REPO/docs/plans/plan-live.md" <<'EOF'
# Plan: live
- [x] Already done
- [x] Wire the resolver
EOF
out="$(run)"
if [[ -n "$out" ]]; then fail "all ticked: expected allow, got: $out"; else log "all criteria ticked -> allow"; fi

# 7. A branch with no matching plan file must not block.
git -C "$REPO" branch plan/orphan
out="$(run)"
if [[ -n "$out" ]]; then fail "orphan branch: expected allow, got: $out"; else log "branch without a plan file -> allow"; fi

if [[ "$FAILED" -eq 0 ]]; then
  log "all plan-run-guard checks passed"
else
  echo -e "${RED}[FAIL]${NC}  plan-run-guard test failed" >&2
  exit 1
fi
