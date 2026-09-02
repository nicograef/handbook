#!/usr/bin/env bash
# check-terms.sh – verify no audiobook term is used before it is explained
#
# Usage:
#   scripts/check-terms.sh <chapter-dir>
#
# What it does:
#   1. Reads <chapter-dir>/terms.yml — one `term: chapter-file.md` per line.
#   2. Walks the NN-slug.md chapters in filename order, finds each first use.
#   3. Fails when a term appears before the chapter that explains it.
#   4. Fails when the declaring chapter does not contain the term at all.
#
# Matching is case-insensitive and substring-based: "index" matches "Indexes".
# See guides/audiobook-pipeline.md and .claude/skills/audiobook/review-rounds.md.

set -euo pipefail

log() { printf '\033[1;34m▸ %s\033[0m\n' "$1"; }
fail() { printf '\033[1;31m✗ %s\033[0m\n' "$1" >&2; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$1" >&2; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$1" >&2; exit 2; }

SRC_DIR="${1:-}"
[[ -n "$SRC_DIR" ]] || die "usage: $0 <chapter-dir>"
[[ -d "$SRC_DIR" ]] || die "chapter directory not found: $SRC_DIR"

TERMS_FILE="$SRC_DIR/terms.yml"
[[ -f "$TERMS_FILE" ]] || die "no $TERMS_FILE — the skill writes it in step 6"

# Chapters in reading order; the array index is the reading position.
CHAPTERS=()
while IFS= read -r file; do
  CHAPTERS+=("$(basename "$file")")
done < <(find "$SRC_DIR" -maxdepth 1 -name '[0-9][0-9]-*.md' | sort)

[[ ${#CHAPTERS[@]} -gt 0 ]] || die "no NN-slug.md chapters in $SRC_DIR"

# position <chapter-file> → 1-based reading position, 0 when unknown.
position() {
  local want="$1" i=1 chapter
  for chapter in "${CHAPTERS[@]}"; do
    if [[ "$chapter" == "$want" ]]; then
      printf '%s' "$i"
      return
    fi
    i=$((i + 1))
  done
  printf '0'
}

log "Checking terms from $TERMS_FILE against ${#CHAPTERS[@]} chapter(s)"

ERRORS=0
WARNINGS=0
CHECKED=0

while IFS= read -r line; do
  [[ -z "${line// /}" ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^[[:space:]]*---[[:space:]]*$ ]] && continue
  [[ "$line" == *:* ]] || continue

  term="${line%%:*}"
  declared="${line#*:}"
  term="$(printf '%s' "$term" | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
  declared="$(printf '%s' "$declared" | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
  [[ -n "$term" && -n "$declared" ]] || continue
  CHECKED=$((CHECKED + 1))

  declared_pos="$(position "$declared")"
  if [[ "$declared_pos" == "0" ]]; then
    fail "$term: terms.yml points at a missing chapter: $declared"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # First chapter that mentions the term at all.
  first_pos=0
  first_file=""
  i=1
  for chapter in "${CHAPTERS[@]}"; do
    if grep -qiF -- "$term" "$SRC_DIR/$chapter"; then
      first_pos="$i"
      first_file="$chapter"
      break
    fi
    i=$((i + 1))
  done

  if [[ "$first_pos" == "0" ]]; then
    warn "$term: never used in any chapter — stale entry in terms.yml?"
    WARNINGS=$((WARNINGS + 1))
  elif [[ "$first_pos" -lt "$declared_pos" ]]; then
    fail "$term: used in $first_file but explained in $declared"
    ERRORS=$((ERRORS + 1))
  elif [[ "$first_pos" -gt "$declared_pos" ]]; then
    fail "$term: $declared claims the explanation but never mentions the term"
    ERRORS=$((ERRORS + 1))
  fi
done < "$TERMS_FILE"

[[ "$CHECKED" -gt 0 ]] || die "no 'term: chapter.md' entries parsed from $TERMS_FILE"

if [[ "$ERRORS" -gt 0 ]]; then
  fail "$CHECKED term(s) checked, $ERRORS ordering error(s), $WARNINGS warning(s)"
  exit 1
fi

log "$CHECKED term(s) checked, no term used before it is explained ($WARNINGS warning(s))"
