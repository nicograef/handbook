#!/usr/bin/env bash
# test-report-health.sh – fixture test for scripts/report-health.sh.
#
# Usage:
#   scripts/test-report-health.sh    # or: make test-report-health
#
# What it does:
#   1. Puts journalctl and curl stubs first on PATH: journalctl prints a fixture
#      file, curl logs its arguments and pings nothing.
#   2. Points every path report-health reads at a temp dir through its env overrides.
#   3. Asserts the hourly form's ping, exit code and log, without and with drop-ins.
#   4. Asserts --check-only's lines, its silence on the URL and its exit codes.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/report-health.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC}  $*"; }

FAILED=0
fail() { echo -e "${RED}[FAIL]${NC}  $*" >&2; FAILED=1; }

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/bin"

CALLS="$FIX/curl-calls"
JOURNAL="$FIX/journal"
OUT="$FIX/stdout"
ERR="$FIX/stderr"
URL="https://example.com/heartbeat-secret"

cat > "$FIX/bin/journalctl" <<EOF
#!/usr/bin/env bash
cat "$JOURNAL" 2>/dev/null || true
EOF
cat > "$FIX/bin/curl" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$CALLS"
EOF
chmod +x "$FIX/bin/journalctl" "$FIX/bin/curl"
export PATH="$FIX/bin:$PATH"

unset HEALTH_PING_URL
export DEFAULTS_FILE="$FIX/defaults"
export REBOOT_REQUIRED_FILE="$FIX/reboot-required"
export UNATTENDED_UPGRADES_LOG="$FIX/unattended-upgrades.log"
export CHECKS_DIR="$FIX/checks"
export CHECK_TIMEOUT=1

echo "HEALTH_PING_URL=\"$URL\"" > "$DEFAULTS_FILE"
cat > "$UNATTENDED_UPGRADES_LOG" <<'EOF'
2026-01-01 06:00:00,000 INFO Starting unattended upgrades script
2026-01-01 06:00:01,000 INFO Packages that will be upgraded: libgpg-error0
EOF
: > "$JOURNAL"

run() { # run [args...]; sets rc, stdout in $OUT, stderr in $ERR
  : > "$CALLS"
  rc=0
  bash "$SCRIPT" "$@" > "$OUT" 2> "$ERR" || rc=$?
}

pinged() { grep -qF "$URL" "$CALLS"; }

expect_ping() { # expect_ping <label>
  if [[ "$rc" -eq 0 ]] && pinged; then log "$1 -> exit 0, ping sent"; else fail "$1: rc $rc, curl calls: $(cat "$CALLS")"; fi
}

expect_no_ping() { # expect_no_ping <rc> <label>
  if [[ "$rc" -eq "$1" && ! -s "$CALLS" ]]; then
    log "$2 -> exit $1, no ping"
  else
    fail "$2: expected exit $1 and no curl, got rc $rc, curl calls: $(cat "$CALLS")"
  fi
}

expect_log() { # expect_log <label> <text>
  if grep -qF "$2" "$OUT"; then log "$1 -> logs '$2'"; else fail "$1: no '$2' in: $(cat "$OUT")"; fi
}

dropin() { # dropin <name> <body>; an executable drop-in
  mkdir -p "$CHECKS_DIR"
  printf '#!/usr/bin/env bash\n%s\n' "$2" > "$CHECKS_DIR/$1"
  chmod +x "$CHECKS_DIR/$1"
}

# 1. Without the drop-in directory, the hourly form behaves as before drop-ins existed.
run
expect_ping "healthy, no directory"

touch "$REBOOT_REQUIRED_FILE"
run
expect_no_ping 1 "reboot required"
expect_log "reboot required" "UNHEALTHY: reboot: reboot required"
rm "$REBOOT_REQUIRED_FILE"

echo "2026-01-01 06:00:02,000 ERROR Installing the upgrades failed!" >> "$UNATTENDED_UPGRADES_LOG"
run
expect_no_ping 1 "unattended-upgrades error"
expect_log "unattended-upgrades error" "UNHEALTHY: upgrades:"
echo "2026-01-02 06:00:00,000 INFO Starting unattended upgrades script" >> "$UNATTENDED_UPGRADES_LOG"
run
expect_ping "error in an earlier upgrades run only"

echo "kernel: Out of memory: Killed process 1234 (node)" > "$JOURNAL"
run
expect_no_ping 1 "OOM kill in the journal"
expect_log "OOM kill in the journal" "UNHEALTHY: oom:"
: > "$JOURNAL"

DEFAULTS_FILE="$FIX/absent" run
expect_no_ping 0 "URL unset"

# 2. A passing drop-in lets the ping go.
dropin disk-free 'echo "12% used"'
run
expect_ping "passing drop-in"

# 3. A failing drop-in withholds the ping and logs its name and first stdout line.
dropin queue-depth 'echo "queue at 900"; echo "second line"; exit 1'
run
expect_no_ping 1 "failing drop-in"
expect_log "failing drop-in" "UNHEALTHY: queue-depth: queue at 900"
if grep -qF "second line" "$OUT"; then fail "failing drop-in: reason holds more than the first line"; fi

# 4. A non-executable file and a name outside ^[a-z0-9-]+$ are skipped.
printf '#!/usr/bin/env bash\nexit 1\n' > "$CHECKS_DIR/not-executable"
dropin check.sh 'exit 1'
dropin Upper 'exit 1'
mkdir -p "$CHECKS_DIR/subdir"
rm "$CHECKS_DIR/queue-depth"
run
expect_ping "skipped files"

# 5. --check-only prints one line per check in name order, calls no curl, prints no URL.
dropin queue-depth 'echo "queue at 900"; exit 1'
dropin a-first 'exit 0'
export HEALTH_PING_URL="$URL"
run --check-only
expect_no_ping 1 "--check-only with a failing drop-in"
expected="$(printf '%s\n' \
  "reboot	ok	no reboot required" \
  "upgrades	ok	last unattended-upgrades run logged no error" \
  "oom	ok	the journal records no OOM kill within '65 minutes ago'" \
  "a-first	ok	" \
  "disk-free	ok	12% used" \
  "queue-depth	fail	queue at 900")"
if [[ "$(cat "$OUT")" == "$expected" ]]; then
  log "--check-only -> one tab line per built-in and drop-in"
else
  fail "--check-only: expected:"$'\n'"$expected"$'\n'"got:"$'\n'"$(cat "$OUT")"
fi
if grep -qF "$URL" "$OUT" "$ERR"; then fail "--check-only printed the URL"; else log "--check-only -> no URL"; fi

rm "$CHECKS_DIR/queue-depth"
echo "exit 3" > "$FIX/defaults-exits"
DEFAULTS_FILE="$FIX/defaults-exits" run --check-only
expect_no_ping 0 "--check-only, all pass, defaults file unread"

touch "$REBOOT_REQUIRED_FILE"
run --check-only
expect_no_ping 1 "--check-only, built-in fails"
if grep -q $'^reboot\tfail\t' "$OUT"; then log "--check-only -> reboot fail line"; else fail "--check-only: no reboot fail line: $(cat "$OUT")"; fi
rm "$REBOOT_REQUIRED_FILE"
unset HEALTH_PING_URL

# 6. A hung drop-in fails at the timeout.
dropin hung 'sleep 30'
start=$SECONDS
run --check-only
elapsed=$((SECONDS - start))
if [[ "$rc" -eq 1 && "$elapsed" -lt 10 ]] && grep -qx $'hung\tfail\ttimed out after 1s' "$OUT"; then
  log "hung drop-in -> fails at the timeout"
else
  fail "hung drop-in: rc $rc after ${elapsed}s: $(cat "$OUT")"
fi
run
expect_no_ping 1 "hung drop-in, hourly"
expect_log "hung drop-in, hourly" "UNHEALTHY: hung: timed out after 1s"
rm "$CHECKS_DIR/hung"

# 7. Any other argument exits 2.
for args in "--bogus" "--check-only extra"; do
  # shellcheck disable=SC2086 # split on purpose: each case is an argument list
  run $args
  expect_no_ping 2 "argument '$args'"
done

if [[ "$FAILED" -eq 0 ]]; then
  log "all report-health checks passed"
else
  echo -e "${RED}[FAIL]${NC}  report-health test failed" >&2
  exit 1
fi
