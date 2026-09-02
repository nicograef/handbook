#!/usr/bin/env bash
# report-health.sh – daily dead-man health ping for an unattended server
#
# Usage (installed as /usr/local/bin/report-health, run by cron):
#   report-health
#   DEFAULTS_FILE=/dev/null HEALTH_PING_URL=https://hc-ping.com/<uuid> report-health   # ad-hoc override; the env value only applies when the defaults file is absent or leaves HEALTH_PING_URL unset
#
# What it does:
#   1. Reads HEALTH_PING_URL from /etc/default/report-health (env is the fallback).
#   2. Healthy = ALL THREE: no /var/run/reboot-required, the latest
#      unattended-upgrades run logged no error, and the journal records no OOM
#      kill within OOM_WINDOW.
#   3. Healthy → ping the URL once (curl). Unhealthy → log the reason, ping
#      nothing, exit non-zero. URL unset → run the checks, skip the ping.

set -euo pipefail

# ── Configuration (env-var defaults; production paths are the real ones) ──────
DEFAULTS_FILE="${DEFAULTS_FILE:-/etc/default/report-health}"
REBOOT_REQUIRED_FILE="${REBOOT_REQUIRED_FILE:-/var/run/reboot-required}"
UNATTENDED_UPGRADES_LOG="${UNATTENDED_UPGRADES_LOG:-/var/log/unattended-upgrades/unattended-upgrades.log}"
OOM_WINDOW="${OOM_WINDOW:-25 hours ago}"  # slightly over the daily cron interval, so no kill falls between runs
# ─────────────────────────────────────────────────────────────────────────────

log() { printf '\n\033[1;34m▸ %s\033[0m\n' "$1"; }

HEALTH_PING_URL="${HEALTH_PING_URL:-}"
if [[ -f "$DEFAULTS_FILE" ]]; then
  # shellcheck source=/dev/null
  . "$DEFAULTS_FILE"
fi

# ── Health checks ─────────────────────────────────────────────────────────────
healthy=true

# A pending reboot means kernel/library updates are not yet live — not healthy.
if [[ -e "$REBOOT_REQUIRED_FILE" ]]; then
  log "UNHEALTHY: reboot required ($REBOOT_REQUIRED_FILE present)"
  healthy=false
fi

# Inspect only the most recent unattended-upgrades run (the block after the last
# "Starting unattended upgrades script" marker) for an error line. Match the
# log's severity field (" ERROR ") and Python tracebacks case-sensitively —
# a substring match would false-alarm on package names like libgpg-error0.
if [[ -f "$UNATTENDED_UPGRADES_LOG" ]]; then
  last_run="$(awk '
    /Starting unattended upgrades script/ { buf = "" }
    { buf = buf $0 "\n" }
    END { printf "%s", buf }
  ' "$UNATTENDED_UPGRADES_LOG")"
  if printf '%s' "$last_run" | grep -qE ' ERROR |^Traceback'; then
    log "UNHEALTHY: last unattended-upgrades run logged an error"
    healthy=false
  fi
fi

# An OOM kill is exactly what this ping exists to catch: nothing fails, no unit
# stays down, and the box looks fine afterwards — while the kill may have taken
# every session on it, because systemd stops user@.service when the kill lands on
# the user manager. The cgroup counters under /sys/fs/cgroup are cumulative since
# boot and carry no timestamps, so a bounded journal window is the only reading
# that distinguishes "killed something last night" from "killed something in May".
# Three patterns are matched: two kernel spellings (Out of memory: Killed
# process, oom-kill:) and systemd's unit-level "killed by the OOM killer".
# Counted, not `grep -q`: under `set -o pipefail` a quiet grep exits at the first
# match, journalctl dies of SIGPIPE, and the non-zero pipeline makes the condition
# false — the check would silently never fire. `grep -c` drains the stream instead,
# and `|| true` absorbs its exit 1 on zero matches.
if command -v journalctl >/dev/null 2>&1; then
  oom_hits="$(journalctl --since "$OOM_WINDOW" --no-pager --quiet 2>/dev/null \
    | grep -cE 'killed by the OOM killer|Out of memory: Killed process|oom-kill:' || true)"
  if [[ "${oom_hits:-0}" -gt 0 ]]; then
    log "UNHEALTHY: the journal records $oom_hits OOM-kill line(s) within '$OOM_WINDOW'"
    healthy=false
  fi
fi

# ── Ping ──────────────────────────────────────────────────────────────────────
if [[ "$healthy" != "true" ]]; then
  log "Unhealthy — sending no ping."
  exit 1
fi

if [[ -z "$HEALTH_PING_URL" ]]; then
  log "Healthy, but HEALTH_PING_URL is unset — no ping attempted."
  exit 0
fi

log "Healthy — pinging $HEALTH_PING_URL"
curl -fsS --max-time 10 --retry 3 "$HEALTH_PING_URL" >/dev/null
