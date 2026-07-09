#!/usr/bin/env bash
# report-health.sh – daily dead-man health ping for an unattended server
#
# Usage (installed as /usr/local/bin/report-health, run by cron):
#   report-health
#   HEALTH_PING_URL=https://hc-ping.com/<uuid> report-health   # ad-hoc override
#
# What it does:
#   1. Reads HEALTH_PING_URL from /etc/default/report-health (env is the fallback).
#   2. Healthy = BOTH: no /var/run/reboot-required AND the latest
#      unattended-upgrades run logged no error.
#   3. Healthy → ping the URL once (curl). Unhealthy → log the reason, ping
#      nothing, exit non-zero. URL unset → run the checks, skip the ping.

set -euo pipefail

# ── Configuration (env-var defaults; production paths are the real ones) ──────
DEFAULTS_FILE="${DEFAULTS_FILE:-/etc/default/report-health}"
REBOOT_REQUIRED_FILE="${REBOOT_REQUIRED_FILE:-/var/run/reboot-required}"
UNATTENDED_UPGRADES_LOG="${UNATTENDED_UPGRADES_LOG:-/var/log/unattended-upgrades/unattended-upgrades.log}"
# ─────────────────────────────────────────────────────────────────────────────

log() { printf '\n\033[1;34m▸ %s\033[0m\n' "$1"; }

# Load HEALTH_PING_URL from the defaults file when present; env is the fallback.
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
# "Starting unattended upgrades script" marker) for an error line.
if [[ -f "$UNATTENDED_UPGRADES_LOG" ]]; then
  last_run="$(awk '
    /Starting unattended upgrades script/ { buf = "" }
    { buf = buf $0 "\n" }
    END { printf "%s", buf }
  ' "$UNATTENDED_UPGRADES_LOG")"
  if printf '%s' "$last_run" | grep -qiE 'error|traceback'; then
    log "UNHEALTHY: last unattended-upgrades run logged an error"
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
