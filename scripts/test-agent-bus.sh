#!/usr/bin/env bash
# test-agent-bus.sh – fixture test for scripts/agent-bus.sh
#
# Usage:
#   scripts/test-agent-bus.sh        # or: make test-agent-bus
#
# What it does:
#   1. Builds a throwaway git repo with two branches in a temp directory.
#   2. Drives announce, send, inbox, sent and radar as two simulated sessions.
#   3. Exercises every hook body, including its fail-safe paths.
#   4. Removes the temp directory and its stand-in processes on exit.
#
# Touches nothing outside its own temp directory.

set -euo pipefail

BUS_SH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/agent-bus.sh"
TMP="$(mktemp -d)"
FAKE_PID=""
PASS=0
FAIL=0

log() { printf '\033[1;34m▸ %s\033[0m\n' "$*"; }

cleanup() {
  [[ -n "$FAKE_PID" ]] && kill "$FAKE_PID" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT

# ok compares actual against expected and records the result.
ok() {
  local label="$1" want="$2" got="$3"
  if [[ "$got" == *"$want"* ]]; then
    PASS=$((PASS + 1))
    printf '  \033[32mPASS\033[0m %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf '  \033[31mFAIL\033[0m %s\n        want: %s\n        got:  %s\n' \
      "$label" "$want" "${got:0:160}"
  fi
}

# silent asserts a command exits 0 and prints nothing — the contract for a hook
# that has no business acting.
silent() {
  local label="$1"; shift
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [[ "$rc" -eq 0 && -z "$out" ]]; then
    PASS=$((PASS + 1)); printf '  \033[32mPASS\033[0m %s\n' "$label"
  else
    FAIL=$((FAIL + 1)); printf '  \033[31mFAIL\033[0m %s (rc=%s out=%s)\n' \
      "$label" "$rc" "${out:0:120}"
  fi
}

# ── Fixture ─────────────────────────────────────────────────────────────────
# alive() requires a running process whose cmdline contains "claude"; `exec -a`
# supplies one without starting a real session.
bash -c 'exec -a claude-agent-bus-test sleep 600' &
FAKE_PID=$!

REPO="$TMP/repo"
mkdir -p "$REPO"
git init -q "$REPO"
git -C "$REPO" config user.email test@example.com
git -C "$REPO" config user.name Test
printf 'base\n' > "$REPO/shared.md"
printf 'base\n' > "$REPO/mine.md"
git -C "$REPO" add -A
git -C "$REPO" commit -qm base

# A peer branch that edits the same file differently — a guaranteed conflict.
git -C "$REPO" checkout -qb peer
printf 'peer edit\n' > "$REPO/shared.md"
git -C "$REPO" commit -qam peer
git -C "$REPO" checkout -q -
git -C "$REPO" checkout -qb mine
printf 'my edit\n' > "$REPO/shared.md"
git -C "$REPO" commit -qam mine

# The peer gets a real linked worktree, as it would in practice. Both check out
# different branches and share one git-common-dir, hence one bus.
PEER_WT="$TMP/peer-wt"
git -C "$REPO" worktree add -q "$PEER_WT" peer

BUS="$REPO/.git/agent-bus"
A="aaaaaaaa-0000-0000-0000-000000000000"   # this session, in the main checkout
B="bbbbbbbb-0000-0000-0000-000000000000"   # the peer, in the linked worktree

run_a() { (cd "$REPO" && AGENT_BUS_SESSION_ID="$A" CLAUDE_PID="$FAKE_PID" "$BUS_SH" "$@"); }
run_b() { (cd "$PEER_WT" && AGENT_BUS_SESSION_ID="$B" CLAUDE_PID="$FAKE_PID" "$BUS_SH" "$@"); }
hook()  { # hook <session> <event> [cwd]
  local sid="$1" event="$2" cwd="${3:-}"
  [[ -n "$cwd" ]] || { [[ "$sid" == "$B" ]] && cwd="$PEER_WT" || cwd="$REPO"; }
  jq -n --arg s "$sid" --arg c "$cwd" '{session_id:$s,cwd:$c}' \
    | (cd "$REPO" && CLAUDE_PID="$FAKE_PID" "$BUS_SH" hook "$event")
}

# ── Registry ────────────────────────────────────────────────────────────────
log "registry"
run_a announce "phase 6" --paths "shared.md,mine.md" --resources "127.0.0.1:5433" \
  --provides "phase-6" >/dev/null
ok "announce records paths" "shared.md" "$(jq -c '.paths' "$BUS/peers/$A.json")"
run_a announce "phase 6 revised" >/dev/null
ok "task-only re-announce keeps paths" "shared.md" "$(jq -c '.paths' "$BUS/peers/$A.json")"
ok "task-only re-announce updates task" "phase 6 revised" \
  "$(jq -r '.task' "$BUS/peers/$A.json")"

# The peer registers from its own worktree, so it records its own branch.
run_b announce "phase 3" --paths "shared.md" --resources "127.0.0.1:5433" >/dev/null
ok "peer registers its own branch" "peer" "$(jq -r '.branch' "$BUS/peers/$B.json")"
ok "both worktrees share one bus" "$BUS" \
  "$(cd "$PEER_WT" && printf '%s/agent-bus' "$(git rev-parse --path-format=absolute --git-common-dir)")"

# ── Messaging ───────────────────────────────────────────────────────────────
log "messaging"
ok "send resolves a peer by branch" "sent to bbbbbbbb" \
  "$(run_a send peer "0012 not 0013" --kind correction 2>&1)"
ok "unknown peer is rejected" "no peer matches" "$(run_a send nosuch hi 2>&1 || true)"
ok "receipt starts UNREAD" "UNREAD" "$(run_a sent)"
ok "peer sees the message" "0012 not 0013" "$(run_b inbox)"
ok "drain shows the message" "0012 not 0013" "$(run_b inbox --drain)"
ok "receipt flips to read" "read" "$(run_a sent)"
ok "drained message is not redelivered" "Inbox empty." "$(run_b inbox)"

# ── Radar ───────────────────────────────────────────────────────────────────
log "radar"
RADAR="$(run_a radar 2>&1)"
ok "radar predicts the conflict" "CONFLICT" "$RADAR"
ok "radar names the shared file" "shared.md" "$RADAR"
ok "radar reports the resource collision" "RESOURCES: 127.0.0.1:5433" "$RADAR"

# ── Hooks ───────────────────────────────────────────────────────────────────
log "hooks"
silent "stop hook is silent with an empty inbox" hook "$B" stop
run_a send peer "hold your rebase" --kind block >/dev/null
STOP="$(hook "$B" stop)"
ok "stop hook blocks on a queued message" '"decision": "block"' "$STOP"
ok "stop hook carries the text" "hold your rebase" "$STOP"
silent "stop hook is silent once drained (no loop)" hook "$B" stop
ok "wake counter advanced" "1" "$(cat "$BUS/wake/$B")"

ok "session-start injects the peer list" "phase 6 revised" \
  "$(hook "$B" session-start | jq -r '.hookSpecificOutput.additionalContext')"

run_a send peer "read me on prompt" >/dev/null
ok "user-prompt-submit delivers" "read me on prompt" \
  "$(hook "$B" user-prompt-submit | jq -r '.hookSpecificOutput.additionalContext')"
ok "user prompt resets the wake budget" "absent" \
  "$([[ -f "$BUS/wake/$B" ]] && echo present || echo absent)"

printf '25' > "$BUS/wake/$B"
run_a send peer "over the cap" >/dev/null
ok "wake cap holds messages instead of blocking" "systemMessage" \
  "$(hook "$B" stop | jq -r 'keys[]')"

# ── Fail-safe ───────────────────────────────────────────────────────────────
log "fail-safe"
silent "cwd outside a git repo"      hook "$B" stop "$TMP"
silent "cwd that does not exist"     hook "$B" stop "$TMP/gone"
silent "unknown hook event"          hook "$B" nonsense
garbage_out="$(printf 'not json' | (cd "$REPO" && "$BUS_SH" hook stop) 2>&1)" && garbage_rc=0 || garbage_rc=$?
if [[ "$garbage_rc" -eq 0 && -z "$garbage_out" ]]; then
  PASS=$((PASS + 1)); printf '  \033[32mPASS\033[0m garbage stdin\n'
else
  FAIL=$((FAIL + 1)); printf '  \033[31mFAIL\033[0m garbage stdin\n'
fi
printf '{{{' > "$BUS/peers/corrupt.json"
silent "corrupt registry entry"      hook "$B" stop
rm -f "$BUS/peers/corrupt.json"

# ── Sweep ───────────────────────────────────────────────────────────────────
log "sweep"
jq '.pid = 999999' "$BUS/peers/$B.json" > "$TMP/x" && mv "$TMP/x" "$BUS/peers/$B.json"
run_a sweep >/dev/null 2>&1
ok "sweep drops a dead session" "absent" \
  "$([[ -f "$BUS/peers/$B.json" ]] && echo present || echo absent)"
ok "sweep keeps a live session" "present" \
  "$([[ -f "$BUS/peers/$A.json" ]] && echo present || echo absent)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
