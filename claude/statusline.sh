#!/usr/bin/env bash
# This script intentionally omits `set -euo pipefail`: a status line should degrade
# gracefully (print what it can) rather than crash the whole line on a missing field
# or a failed subcommand.

input=$(cat)

# Force C numeric locale so printf uses a decimal point (not the German comma)
export LC_NUMERIC=C

# One jq call; the unit separator keeps empty fields in place, unlike tab or space.
IFS=$'\x1f' read -r model cwd effort pct cost added removed five_h seven_d < <(
  echo "$input" | jq -r '[
    (.model.display_name // .model.id // "unknown"),
    (.workspace.current_dir // .cwd // ""),
    (.effort.level // ""),
    (.context_window.used_percentage // ""),
    (.cost.total_cost_usd // ""),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.seven_day.used_percentage // "")
  ] | map(tostring) | join("\u001f")' 2>/dev/null
)
model=${model:-unknown}
dir=$(basename "$cwd")

short_model=$(echo "$model" | grep -oiE 'opus|sonnet' | head -1)
if [[ -z "$short_model" ]]; then
  short_model="$model"
fi

branch=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
fi

CYAN='\033[36m'
DIM='\033[2m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

line1=$(printf "${CYAN}%s${RESET}" "$short_model")
if [[ -n "$effort" ]]; then
  line1="$line1$(printf " ${DIM}%s${RESET}" "$effort")"
fi
line1="$line1$(printf "  ${DIM}%s${RESET}" "$dir")"
if [[ -n "$branch" ]]; then
  line1="$line1$(printf "  %s" "$branch")"
fi
printf "%s" "$line1"

# Line 2: context bar, cost and line counts once the API has reported them
line2=""
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
fi

# Rate limits: present only for subscribers, and each window may be absent
for pair in "5h:$five_h" "7d:$seven_d"; do
  label=${pair%%:*}; used=${pair#*:}
  [[ -z "$used" ]] && continue
  sep=""; [[ -n "$line2" ]] && sep=" ${DIM}·${RESET} "
  line2="$line2$(printf "${sep}${DIM}%s %.0f%%${RESET}" "$label" "$used")"
done

if [[ -n "$line2" ]]; then
  printf "\n%s" "$line2"
fi
