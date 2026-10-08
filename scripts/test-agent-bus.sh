#!/usr/bin/env bash
# test-agent-bus.sh – fixture test for scripts/agent-bus.sh
#
# Usage:
#   scripts/test-agent-bus.sh        # or: make test-agent-bus
#
# What it does:
#   1. Builds a throwaway git repo under a temp dir, so no real bus is touched.
#   2. Drives announce, radar and sweep against it.
#   3. Feeds synthetic hook payloads to the session-start hook body.
#   4. Asserts every hook stays silent on malformed input and on events without a body.
#
# Liveness is faked with a background process whose command line contains
# "claude", which is what agent-bus.sh checks. Discovery through
# `claude agents --json` needs a second real session and is not covered here.

set -euo pipefail

# The calling session's id would make every hook case act as that session.
unset CLAUDE_CODE_SESSION_ID AGENT_BUS_SESSION_ID

# shellcheck source=scripts/lib/test-harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/test-harness.sh"

BUS_SCRIPT="$REPO_ROOT/scripts/agent-bus.sh"
FAKE_PID=""
cleanup() {
  [[ -z "$FAKE_PID" ]] || kill "$FAKE_PID" 2>/dev/null || true
}

PASS=0

# ok asserts that output $2 contains substring $3. $1 names the case.
ok() {
  if [[ "$2" == *"$3"* ]]; then
    PASS=$((PASS + 1))
  else
    fail "$1"
    printf '  wanted: %s\n  got:    %s\n' "$3" "$2" >&2
  fi
}

# no asserts that output $2 does NOT contain substring $3.
no() {
  if [[ "$2" != *"$3"* ]]; then PASS=$((PASS + 1)); else fail "$1"; fi
}

# quiet asserts a command produced no output and exited 0.
quiet() {
  local name="$1" out rc=0
  shift
  out="$("$@" 2>&1)" || rc=$?
  if [[ "$rc" -eq 0 && -z "$out" ]]; then
    PASS=$((PASS + 1))
  else
    fail "$name (rc=$rc, out=${out:0:120})"
  fi
}

# ── Fixture ─────────────────────────────────────────────────────────────────

# A process agent-bus.sh will accept as a live session.
mkdir -p "$FIX/bin"
printf '#!/usr/bin/env bash\nsleep 600\n' > "$FIX/bin/claude"
chmod +x "$FIX/bin/claude"
# Detach its stdio: a background child holding the pipe open makes any caller
# that pipes this script's output block until the child exits.
"$FIX/bin/claude" >/dev/null 2>&1 &
FAKE_PID=$!

REPO="$FIX/repo"
mkdir -p "$REPO"
cd "$REPO"
git init -q -b main .
git config user.email t@example.com
git config user.name Test
echo one > shared.txt
git add -A && git commit -q -m base

# branch-b edits the same line as main, so the merge really conflicts.
git checkout -q -b branch-b
echo two > shared.txt
git commit -q -am b-change
git checkout -q main
echo three > shared.txt
git commit -q -am a-change

BUS="$REPO/.git/agent-bus"
A="aaaaaaaa-0000-0000-0000-000000000001"
B="bbbbbbbb-0000-0000-0000-000000000002"

hookjson() { jq -nc --arg s "$1" --arg c "$REPO" '{session_id:$s,cwd:$c}'; }
as_a() { CLAUDE_CODE_SESSION_ID="$A" CLAUDE_PID="$FAKE_PID" "$BUS_SCRIPT" "$@"; }
as_b() { CLAUDE_CODE_SESSION_ID="$B" CLAUDE_PID="$FAKE_PID" "$BUS_SCRIPT" "$@"; }
hook() { hookjson "$1" | CLAUDE_PID="$FAKE_PID" "$BUS_SCRIPT" hook "$2"; }

# ── Registry ────────────────────────────────────────────────────────────────

log "announce records and retains fields"
as_a announce "phase 6" --paths "shared.txt" --resources "127.0.0.1:5433" --provides "p6" 2>/dev/null
ok "task"      "$(jq -r .task "$BUS/peers/$A.json")"      "phase 6"
ok "paths"     "$(jq -c .paths "$BUS/peers/$A.json")"     "shared.txt"
ok "resources" "$(jq -c .resources "$BUS/peers/$A.json")" "127.0.0.1:5433"
ok "provides"  "$(jq -c .provides "$BUS/peers/$A.json")"  "p6"

as_a announce "phase 6 continued" 2>/dev/null
ok "arrays survive a task-only re-announce" "$(jq -c .paths "$BUS/peers/$A.json")" "shared.txt"
ok "task is updated" "$(jq -r .task "$BUS/peers/$A.json")" "phase 6 continued"

log "a second session claims the same file and port"
as_b announce "phase 3" --paths "shared.txt" --resources "127.0.0.1:5433" 2>/dev/null
jq '.branch="branch-b"' "$BUS/peers/$B.json" > "$BUS/peers/$B.tmp"
mv "$BUS/peers/$B.tmp" "$BUS/peers/$B.json"

# The name sorts before B's entry, so a read that aborts on it never reaches B.
log "a corrupt registry entry never hides a live peer"
echo '{{{ not json' > "$BUS/peers/0-corrupt.json"
ok "peer listed past a corrupt entry" "$(hook "$A" session-start)" "branch-b"
rm -f "$BUS/peers/0-corrupt.json"

log "messaging commands are gone"
USAGE_RC=0
USAGE="$("$BUS_SCRIPT" send x y 2>&1)" || USAGE_RC=$?
if [[ "$USAGE_RC" -ne 0 ]]; then PASS=$((PASS + 1)); else fail "send exits 0"; fi
ok "send prints the usage" "$USAGE" "Usage:"

# ── Radar ───────────────────────────────────────────────────────────────────

log "radar reports committed and declared collisions"
RADAR="$(as_a radar main)"
ok "peer branch listed"      "$RADAR" "branch-b"
ok "overlapping file named"  "$RADAR" "shared.txt"
ok "conflict predicted"      "$RADAR" "CONFLICT"
ok "shared resource flagged" "$RADAR" "RESOURCES: 127.0.0.1:5433"

# ── Hooks ───────────────────────────────────────────────────────────────────

log "session-start announces peers"
ok "peer list injected" "$(hook "$B" session-start)" "Concurrent Claude Code sessions"

log "malformed hook input is always silent"
quiet "garbage stdin"  bash -c "printf 'not json' | '$BUS_SCRIPT' hook session-start"
quiet "empty stdin"    bash -c "printf '' | '$BUS_SCRIPT' hook session-start"
quiet "missing cwd"    bash -c "printf '{\"session_id\":\"x\",\"cwd\":\"/no/such/dir\"}' | '$BUS_SCRIPT' hook session-start"
quiet "no session id"  bash -c "printf '{\"cwd\":\"$REPO\"}' | '$BUS_SCRIPT' hook session-start"
quiet "unknown event"  bash -c "printf '{}' | '$BUS_SCRIPT' hook nonsense"
quiet "outside a repo" bash -c "printf '{\"session_id\":\"x\",\"cwd\":\"$FIX\"}' | '$BUS_SCRIPT' hook session-start"

log "events without a body stay silent for a live peer"
quiet "stop event"               bash -c "printf '%s' '$(hookjson "$B")' | '$BUS_SCRIPT' hook stop"
quiet "user-prompt-submit event" bash -c "printf '%s' '$(hookjson "$B")' | '$BUS_SCRIPT' hook user-prompt-submit"

# ── Sweep ───────────────────────────────────────────────────────────────────

log "sweep drops dead sessions and keeps live ones"
DEAD="dddddddd-0000-0000-0000-000000000003"
jq -n --arg s "$DEAD" '{sessionId:$s,pid:2147483000,worktree:"/tmp",branch:"gone",
  task:"",paths:[],resources:[],needs:[],provides:[],updatedAt:0}' > "$BUS/peers/$DEAD.json"
as_a sweep 2>/dev/null
if [[ -f "$BUS/peers/$DEAD.json" ]]; then fail "dead entry survived sweep"; else PASS=$((PASS + 1)); fi
if [[ -f "$BUS/peers/$A.json" ]]; then PASS=$((PASS + 1)); else fail "live entry was swept"; fi

# ── Result ──────────────────────────────────────────────────────────────────

log "$PASS assertions passed"
finish
