#!/usr/bin/env bash
# report-health.sh – hourly dead-man health ping for an unattended server
#
# Usage (installed as /usr/local/bin/report-health, run by cron):
#   report-health
#   report-health --check-only                                             # one line per check, no ping
#   DEFAULTS_FILE=/dev/null HEALTH_PING_URL=<heartbeat-url> report-health   # ad-hoc override
#
# What it does:
#   1. Reads HEALTH_PING_URL from /etc/default/report-health (env is the fallback).
#   2. Runs the built-in checks: reboot (no /var/run/reboot-required), upgrades
#      (the latest unattended-upgrades run logged no error) and oom (the journal
#      records no OOM kill within OOM_WINDOW).
#   3. Runs the drop-ins in /etc/report-health.d/: each executable regular file
#      named ^[a-z0-9-]+$, in name order, under `timeout 30`. A non-zero exit or
#      a timeout fails it; its first stdout line is the reason. No directory, no drop-ins.
#   4. All pass → ping the URL once (curl). A failure → log
#      "UNHEALTHY: <name>: <reason>", ping nothing, exit 1. URL unset → run the
#      checks, skip the ping.
#
# --check-only runs every check and prints "<name>\t<ok|fail>\t<reason>" per check.
# It exits 0 when all pass and 1 otherwise, reads no defaults file and pings nothing.
# Any other argument exits 2.

set -euo pipefail

# ── Configuration (env-var defaults; production paths are the real ones) ──────
DEFAULTS_FILE="${DEFAULTS_FILE:-/etc/default/report-health}"
REBOOT_REQUIRED_FILE="${REBOOT_REQUIRED_FILE:-/var/run/reboot-required}"
UNATTENDED_UPGRADES_LOG="${UNATTENDED_UPGRADES_LOG:-/var/log/unattended-upgrades/unattended-upgrades.log}"
OOM_WINDOW="${OOM_WINDOW:-65 minutes ago}"  # slightly over the hourly cron interval, so no kill falls between runs
CHECKS_DIR="${CHECKS_DIR:-/etc/report-health.d}"
CHECK_TIMEOUT="${CHECK_TIMEOUT:-30}"  # seconds per drop-in
# ─────────────────────────────────────────────────────────────────────────────

log() { printf '\n\033[1;34m▸ %s\033[0m\n' "$1"; }

mode=hourly
if [[ $# -eq 1 && "$1" == --check-only ]]; then
  mode=check
elif [[ $# -gt 0 ]]; then
  echo "usage: report-health [--check-only]" >&2
  exit 2
fi

HEALTH_PING_URL="${HEALTH_PING_URL:-}"
if [[ "$mode" == hourly && -f "$DEFAULTS_FILE" ]]; then
  # shellcheck source=/dev/null
  . "$DEFAULTS_FILE"
fi

# ── Health checks ─────────────────────────────────────────────────────────────
# Each check sets $reason and returns 0 when it passes.
reason=""

# A pending reboot means kernel/library updates are not yet live — not healthy.
check_reboot() {
  if [[ -e "$REBOOT_REQUIRED_FILE" ]]; then
    reason="reboot required ($REBOOT_REQUIRED_FILE present)"
    return 1
  fi
  reason="no reboot required"
}

# Inspect only the most recent unattended-upgrades run (the block after the last
# "Starting unattended upgrades script" marker) for an error line. Match the
# log's severity field (" ERROR ") and Python tracebacks case-sensitively —
# a substring match would false-alarm on package names like libgpg-error0.
check_upgrades() {
  if [[ ! -f "$UNATTENDED_UPGRADES_LOG" ]]; then
    reason="no unattended-upgrades log"
    return 0
  fi
  local last_run
  if ! last_run="$(awk '
    /Starting unattended upgrades script/ { buf = "" }
    { buf = buf $0 "\n" }
    END { printf "%s", buf }
  ' "$UNATTENDED_UPGRADES_LOG")"; then
    reason="cannot read $UNATTENDED_UPGRADES_LOG"
    return 1
  fi
  if printf '%s' "$last_run" | grep -qE ' ERROR |^Traceback'; then
    reason="last unattended-upgrades run logged an error"
    return 1
  fi
  reason="last unattended-upgrades run logged no error"
}

# An OOM kill leaves no failed unit, yet may have taken every session: guides/maintenance.md#after-an-oom-kill.
# The cgroup counters carry no timestamps, so a bounded journal window is the only reading that dates a kill.
# Counted, not `grep -q`: a quiet grep exits early, journalctl dies of SIGPIPE and pipefail hides every hit.
# `|| true` absorbs grep -c's exit 1 on zero matches.
check_oom() {
  if ! command -v journalctl >/dev/null 2>&1; then
    reason="no journalctl"
    return 0
  fi
  local oom_hits
  oom_hits="$(journalctl --since "$OOM_WINDOW" --no-pager --quiet 2>/dev/null \
    | grep -cE 'killed by the OOM killer|Out of memory: Killed process|oom-kill:' || true)"
  if [[ "${oom_hits:-0}" -gt 0 ]]; then
    reason="the journal records $oom_hits OOM-kill line(s) within '$OOM_WINDOW'"
    return 1
  fi
  reason="the journal records no OOM kill within '$OOM_WINDOW'"
}

failed=0
report() { # report <name> <ok|fail> <reason>
  local why="${3//$'\t'/ }"
  if [[ "$mode" == check ]]; then
    printf '%s\t%s\t%s\n' "$1" "$2" "$why"
  elif [[ "$2" == fail ]]; then
    log "UNHEALTHY: $1: $why"
  fi
  [[ "$2" == ok ]] || failed=1
}

for name in reboot upgrades oom; do
  if "check_$name"; then report "$name" ok "$reason"; else report "$name" fail "$reason"; fi
done

# Name order is byte order, whatever the caller's locale.
list_dropins() {
  local LC_ALL=C
  dropins=()
  if [[ -d "$CHECKS_DIR" ]]; then dropins=("$CHECKS_DIR"/*); fi
}
list_dropins

for file in "${dropins[@]}"; do
  name="${file##*/}"
  [[ -f "$file" && -x "$file" && "$name" =~ ^[a-z0-9-]+$ ]] || continue
  rc=0
  # KILL follows 5 s after TERM, so a drop-in that ignores TERM cannot stall the run.
  out="$(timeout -k 5 "$CHECK_TIMEOUT" "$file" </dev/null)" || rc=$?
  first="${out%%$'\n'*}"
  if [[ "$rc" -eq 0 ]]; then
    report "$name" ok "$first"
  elif [[ "$rc" -eq 124 ]]; then
    report "$name" fail "timed out after ${CHECK_TIMEOUT}s"
  else
    report "$name" fail "${first:-exit $rc}"
  fi
done

if [[ "$mode" == check ]]; then
  exit "$failed"
fi

# ── Ping ──────────────────────────────────────────────────────────────────────
if [[ "$failed" -ne 0 ]]; then
  log "Unhealthy — sending no ping."
  exit 1
fi

if [[ -z "$HEALTH_PING_URL" ]]; then
  log "Healthy, but HEALTH_PING_URL is unset — no ping attempted."
  exit 0
fi

log "Healthy — pinging the heartbeat URL"
curl -fsS --max-time 10 --retry 3 "$HEALTH_PING_URL" >/dev/null
