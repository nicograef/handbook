#!/usr/bin/env bash
# Claude Code status line for Nico
#
# This script intentionally omits `set -euo pipefail`: a status line should degrade
# gracefully (print what it can) rather than crash the whole line on a missing field
# or a failed subcommand.

input=$(cat)

# Force C numeric locale so printf uses a decimal point (not the German comma)
export LC_NUMERIC=C

model=$(echo "$input" | jq -r '.model.display_name // .model.id // "unknown"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
dir=$(basename "$cwd")

short_model=$(echo "$model" | grep -oiE 'opus|sonnet|haiku' | head -1)
if [[ -z "$short_model" ]]; then
  short_model="$model"
fi

branch=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
fi

pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Colors: cyan for the model, dim for directory, percentage and cost,
# green/yellow/red for the context bar, green/red for the +/- counts;
# the branch alone is uncoloured.
CYAN='\033[36m'
DIM='\033[2m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

# Line 1
if [[ -n "$branch" ]]; then
  printf "${CYAN}%s${RESET}  ${DIM}%s${RESET}  %s" "$short_model" "$dir" "$branch"
else
  printf "${CYAN}%s${RESET}  ${DIM}%s${RESET}" "$short_model" "$dir"
fi

# Line 2 — only if the API has reported context/cost data yet
if [[ -n "$pct" ]] || [[ -n "$cost" ]]; then
  ip=${pct%.*}; [[ -z "$ip" ]] && ip=0
  filled=$(( ip / 10 )); [[ "$filled" -gt 10 ]] && filled=10; [[ "$filled" -lt 0 ]] && filled=0
  bar=""; i=0
  while [[ "$i" -lt 10 ]]; do
    if [[ "$i" -lt "$filled" ]]; then bar="${bar}█"; else bar="${bar}░"; fi
    i=$((i + 1))
  done
  if [[ "$ip" -ge 80 ]]; then c=$RED; elif [[ "$ip" -ge 50 ]]; then c=$YELLOW; else c=$GREEN; fi

  line2=$(printf "${c}%s${RESET} ${DIM}%s%% ctx${RESET}" "$bar" "$ip")
  if [[ -n "$cost" ]]; then
    line2="$line2$(printf " ${DIM}·${RESET} ${DIM}\$%.2f${RESET}" "$cost")"
  fi
  if [[ "$added" != "0" ]] || [[ "$removed" != "0" ]]; then
    line2="$line2$(printf " ${DIM}·${RESET} ${GREEN}+%s${RESET} ${RED}-%s${RESET}" "$added" "$removed")"
  fi
  printf "\n%s" "$line2"
fi
