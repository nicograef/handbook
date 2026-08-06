#!/usr/bin/env bash
# test-agent-bus.sh – fixture test for scripts/agent-bus.sh
#
# Usage:
#   scripts/test-agent-bus.sh        # or: make test-agent-bus
#
# What it does:
#   1. Builds a throwaway git repo under a temp dir, so no real bus is touched.
#   2. Drives announce, send, inbox, sent, radar and sweep against it.
#   3. Feeds synthetic hook payloads to the three hook bodies.
#   4. Asserts every hook stays silent on malformed input.
#
# Liveness is faked with a background process whose command line contains
# "claude", which is what agent-bus.sh checks. Discovery through
# `claude agents --json` needs a second real session and is not covered here.

set -euo pipefail

BUS_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/agent-bus.sh"
TMP="$(mktemp -d)"
FAKE_PID=""
cleanup() {
  [[ -n "$FAKE_PID" ]] && kill "$FAKE_PID" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT

PASS=0
FAILED=0

log() { printf '\033[1;34m▸ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31mFAIL: %s\033[0m\n' "$*" >&2; FAILED=1; }

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
mkdir -p "$TMP/bin"
printf '#!/usr/bin/env bash\nsleep 600\n' > "$TMP/bin/claude"
chmod +x "$TMP/bin/claude"
# Detach its stdio: a background child holding the pipe open makes any caller
# that pipes this script's output block until the child exits.
"$TMP/bin/claude" >/dev/null 2>&1 &
FAKE_PID=$!

REPO="$TMP/repo"
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

log "a corrupt registry entry never crashes a read"
echo '{{{ not json' > "$BUS/peers/corrupt.json"
quiet "corrupt entry ignored by the stop hook" \
  bash -c "printf '%s' '$(hookjson "$A")' | '$BUS_SCRIPT' hook stop"
rm -f "$BUS/peers/corrupt.json"

# ── Messaging ───────────────────────────────────────────────────────────────

log "send, deliver, acknowledge"
as_b announce "phase 3" --paths "shared.txt" --resources "127.0.0.1:5433" 2>/dev/null
jq '.branch="branch-b"' "$BUS/peers/$B.json" > "$BUS/peers/$B.tmp"
mv "$BUS/peers/$B.tmp" "$BUS/peers/$B.json"

as_a send branch-b "0012 not 0013" --kind correction 2>/dev/null
ok "receipt starts unread"  "$(as_a sent)"          "UNREAD"
ok "peer receives it"       "$(as_b inbox --drain)" "0012 not 0013"
ok "kind is carried"        "$(as_b sent)"          "STATE"
ok "receipt flips to read"  "$(as_a sent)"          "read"
no "receipt no longer unread" "$(as_a sent)"        "UNREAD"
ok "no redelivery"          "$(as_b inbox)"         "Inbox empty."

log "addressing"
ok "unknown peer rejected" "$(as_a send nosuchpeer hi 2>&1 || true)" "no peer matches"
as_a send "${B:0:8}" "addressed by id prefix" 2>/dev/null
ok "id prefix resolves" "$(as_b inbox --drain)" "addressed by id prefix"

# ── Radar ───────────────────────────────────────────────────────────────────

log "radar reports committed and declared collisions"
RADAR="$(as_a radar main)"
ok "peer branch listed"      "$RADAR" "branch-b"
ok "overlapping file named"  "$RADAR" "shared.txt"
ok "conflict predicted"      "$RADAR" "CONFLICT"
ok "shared resource flagged" "$RADAR" "RESOURCES: 127.0.0.1:5433"

# ── Hooks ───────────────────────────────────────────────────────────────────

log "stop hook delivers exactly once"
as_a send branch-b "hold your rebase" --kind block 2>/dev/null
STOP="$(hook "$B" stop)"
ok "stop blocks"            "$STOP" '"decision": "block"'
ok "stop carries the text"  "$STOP" "hold your rebase"
quiet "stop is silent once drained" bash -c "printf '%s' '$(hookjson "$B")' | '$BUS_SCRIPT' hook stop"

log "wake budget holds messages instead of blocking"
printf '25' > "$BUS/wake/$B"
as_a send branch-b "over budget" 2>/dev/null
ok "budget spent" "$(hook "$B" stop)" "systemMessage"
rm -f "$BUS/wake/$B"

log "user-prompt-submit delivers and resets the budget"
printf '9' > "$BUS/wake/$B"
as_a send branch-b "resumed" 2>/dev/null
ok "prompt hook injects" "$(hook "$B" user-prompt-submit)" "resumed"
if [[ -f "$BUS/wake/$B" ]]; then fail "wake budget not reset"; else PASS=$((PASS + 1)); fi

log "session-start announces peers"
ok "peer list injected" "$(hook "$B" session-start)" "Concurrent Claude Code sessions"

log "malformed hook input is always silent"
quiet "garbage stdin"  bash -c "printf 'not json' | '$BUS_SCRIPT' hook stop"
quiet "empty stdin"    bash -c "printf '' | '$BUS_SCRIPT' hook stop"
quiet "missing cwd"    bash -c "printf '{\"session_id\":\"x\",\"cwd\":\"/no/such/dir\"}' | '$BUS_SCRIPT' hook session-start"
quiet "no session id"  bash -c "printf '{\"cwd\":\"$REPO\"}' | '$BUS_SCRIPT' hook stop"
quiet "unknown event"  bash -c "printf '{}' | '$BUS_SCRIPT' hook nonsense"
quiet "outside a repo" bash -c "printf '{\"session_id\":\"x\",\"cwd\":\"$TMP\"}' | '$BUS_SCRIPT' hook stop"

# ── Sweep ───────────────────────────────────────────────────────────────────

log "sweep drops dead sessions and keeps live ones"
DEAD="dddddddd-0000-0000-0000-000000000003"
jq -n --arg s "$DEAD" '{sessionId:$s,pid:2147483000,worktree:"/tmp",branch:"gone",
  task:"",paths:[],resources:[],needs:[],provides:[],updatedAt:0}' > "$BUS/peers/$DEAD.json"
as_a sweep 2>/dev/null
if [[ -f "$BUS/peers/$DEAD.json" ]]; then fail "dead entry survived sweep"; else PASS=$((PASS + 1)); fi
if [[ -f "$BUS/peers/$A.json" ]]; then PASS=$((PASS + 1)); else fail "live entry was swept"; fi

# ── Result ──────────────────────────────────────────────────────────────────

if [[ "$FAILED" -ne 0 ]]; then
  printf '\033[1;31mtest-agent-bus: FAILED (%d assertions passed)\033[0m\n' "$PASS" >&2
  exit 1
fi
printf '\033[1;32mtest-agent-bus: %d assertions passed\033[0m\n' "$PASS"
