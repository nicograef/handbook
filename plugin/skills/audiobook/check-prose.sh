#!/usr/bin/env bash
# check-prose.sh – gate audiobook chapters on the listening budget and on AI-tell patterns
#
# Usage:
#   plugin/skills/audiobook/check-prose.sh <chapter-dir>
#   CPM=900 plugin/skills/audiobook/check-prose.sh audiobook/
#
# What it does:
#   1. Converts the characters of each NN-slug.md chapter into narrated minutes at CPM.
#   2. Fails when a chapter runs over CHAPTER_MAX minutes, when <chapter-dir>/meta.yml
#      lacks `minutes`, or when the book runs over it by more than TOLERANCE percent.
#   3. Fails on every match of a pattern in slop-de.txt beside this script.
#
# See plugin/skills/audiobook/SKILL.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Configuration (env-var defaults) ─────────────────────────────────────────
PATTERNS="${PATTERNS:-$SCRIPT_DIR/slop-de.txt}"
CPM="${CPM:-1000}"              # characters with spaces per narrated minute of German
CHAPTER_MAX="${CHAPTER_MAX:-15}" # minutes
TOLERANCE="${TOLERANCE:-10}"    # percent over the book budget still accepted

# wc -m and grep -P count and match umlauts as letters only in a UTF-8 locale.
export LC_ALL=C.UTF-8

log() { printf '\033[1;34m▸ %s\033[0m\n' "$1"; }
fail() { printf '\033[1;31m✗ %s\033[0m\n' "$1" >&2; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$1" >&2; exit 2; }

SRC_DIR="${1:-}"
[[ -n "$SRC_DIR" ]] || die "usage: $0 <chapter-dir>"
[[ -d "$SRC_DIR" ]] || die "chapter directory not found: $SRC_DIR"
[[ -f "$PATTERNS" ]] || die "pattern file not found: $PATTERNS (override with PATTERNS=)"

CHAPTERS=()
while IFS= read -r file; do
  CHAPTERS+=("$file")
done < <(find "$SRC_DIR" -maxdepth 1 -name '[0-9][0-9]-*.md' | sort)

[[ ${#CHAPTERS[@]} -gt 0 ]] || die "no NN-slug.md chapters in $SRC_DIR"

ERRORS=0

# ── 1. Listening time ────────────────────────────────────────────────────────
log "Listening time at $CPM characters per minute"

TOTAL=0
for file in "${CHAPTERS[@]}"; do
  chars="$(wc -m <"$file")"
  TOTAL=$((TOTAL + chars))
  printf '  %-40s %7d chars  %4d min\n' "$(basename "$file")" "$chars" "$(((chars + CPM / 2) / CPM))"
  if [[ "$chars" -gt $((CHAPTER_MAX * CPM)) ]]; then
    fail "$(basename "$file"): over the $CHAPTER_MAX-minute chapter cap"
    ERRORS=$((ERRORS + 1))
  fi
done
printf '  %-40s %7d chars  %4d min\n' "TOTAL" "$TOTAL" "$(((TOTAL + CPM / 2) / CPM))"

BUDGET=""
if [[ -f "$SRC_DIR/meta.yml" ]]; then
  BUDGET="$(sed -nE "s/^[[:space:]]*minutes:[[:space:]]*[\"']?([0-9]+)[\"']?[[:space:]]*(#.*)?\$/\1/p" "$SRC_DIR/meta.yml" | head -1)"
fi
if [[ -z "$BUDGET" ]]; then
  fail "no whole-number 'minutes:' in $SRC_DIR/meta.yml"
  ERRORS=$((ERRORS + 1))
elif [[ "$TOTAL" -gt $((BUDGET * CPM * (100 + TOLERANCE) / 100)) ]]; then
  fail "book runs $(((TOTAL + CPM / 2) / CPM)) min, budget $BUDGET min (+$TOLERANCE%)"
  ERRORS=$((ERRORS + 1))
fi

# ── 2. Patterns ──────────────────────────────────────────────────────────────
log "Scanning for the patterns in $(basename "$PATTERNS")"

HITS=0
while IFS=$'\t' read -r category regex; do
  [[ -z "${category// /}" || "$category" == \#* ]] && continue
  [[ -n "$regex" ]] || die "pattern line without a tab-separated regex: $category"
  rc=0
  grep -qP -- "$regex" </dev/null || rc=$?
  [[ "$rc" -le 1 ]] || die "invalid pattern in $PATTERNS: $regex"
  for file in "${CHAPTERS[@]}"; do
    while IFS=: read -r line match; do
      fail "$(basename "$file"):$line: $category: $match"
      HITS=$((HITS + 1))
    done < <(grep -inoP -- "$regex" "$file" || true)
  done
done <"$PATTERNS"

if [[ "$ERRORS" -gt 0 || "$HITS" -gt 0 ]]; then
  fail "$ERRORS length error(s), $HITS pattern hit(s)"
  exit 1
fi

log "Within budget, no pattern hits"
