#!/usr/bin/env bash
# check-agents.sh – last activity of background Claude Code agents, read off their transcripts
#
# Usage:
#   scripts/check-agents.sh <tasks-dir> <id>=<label> [<id>=<label> ...]
#   N=8 scripts/check-agents.sh /tmp/claude-1000/<slug>/<session>/tasks a8a5=w2-two-step
#
# What it does:
#   1. Reads <tasks-dir>/<id>.output, the JSONL transcript of each agent.
#   2. Prints the event count and the last timestamp per agent.
#   3. Prints the last N assistant tool calls and text lines, newest first.
#   Reads only; a missing transcript is reported, never an error.

set -euo pipefail

N="${N:-6}"

log() { printf '%s\n' "$*"; }

if [[ $# -lt 2 ]]; then
  log "usage: $0 <tasks-dir> <id>=<label> [...]"
  exit 2
fi

tasks_dir="$1"
shift

if ! command -v jq >/dev/null 2>&1; then
  log "jq is required"
  exit 2
fi

for pair in "$@"; do
  id="${pair%%=*}"
  label="${pair#*=}"
  path="${tasks_dir}/${id}.output"
  if [[ ! -f "$path" ]]; then
    log "=== ${label} (${id}) no transcript yet"
    continue
  fi
  events="$(wc -l <"$path" | tr -d ' ')"
  last="$(jq -r 'select(.timestamp != null) | .timestamp' "$path" 2>/dev/null | tail -n 1 || true)"
  log "=== ${label} events=${events} last=${last:-?}"
  jq -r --argjson n "$N" '
    select(.message.role == "assistant" and (.message.content | type) == "array")
    | .timestamp[11:19] as $t
    | .message.content[]
    | if .type == "tool_use" then
        "  [\($t)] \(.name): \((.input.command // .input.file_path // .input.prompt // (.input | tojson)) | tostring | .[0:200] | gsub("\n"; " "))"
      elif .type == "text" and (.text | length) > 0 then
        "  [\($t)] text: \(.text | .[0:240] | gsub("\n"; " "))"
      else empty end
  ' "$path" 2>/dev/null | tail -n "$N" | tac || true
done
