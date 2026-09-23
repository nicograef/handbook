#!/usr/bin/env bash
# md-to-epub.sh – render listenable Markdown chapters into an ElevenReader EPUB
#
# Usage:
#   scripts/md-to-epub.sh <chapter-dir> [output.epub]
#   WPM=140 STRICT=1 scripts/md-to-epub.sh audiobook/ indexes.epub
#
# Chapters are the NN-slug.md files in <chapter-dir>, in filename order. Other
# Markdown in that directory (PLAN.md, sources.md) is ignored.
#
# What it does:
#   1. Runs each chapter through templates/strip-visuals.lua; every element
#      the filter strips is a finding, prefixed with the chapter name.
#   2. Renders the chapters with pandoc and the same filter.
#   3. Splits one EPUB chapter per H1 and builds a depth-1 table of contents.
#   4. Reports words and estimated listening time, per chapter and total.
#
# See guides/audiobook-pipeline.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Configuration (env-var defaults) ─────────────────────────────────────────
FILTER="${FILTER:-$REPO_ROOT/templates/strip-visuals.lua}"
WPM="${WPM:-150}"          # narration speed used for the time estimate
STRICT="${STRICT:-0}"      # 1 = abort on any finding

log() { printf '\033[1;34m▸ %s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$1" >&2; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$1" >&2; exit 1; }

SRC_DIR="${1:-}"
OUT_FILE="${2:-book.epub}"

# ── Pre-flight ───────────────────────────────────────────────────────────────
[[ -n "$SRC_DIR" ]] || die "usage: $0 <chapter-dir> [output.epub]"
[[ -d "$SRC_DIR" ]] || die "chapter directory not found: $SRC_DIR"
command -v pandoc >/dev/null 2>&1 || die "pandoc is not installed"
[[ -f "$FILTER" ]] || die "lua filter not found: $FILTER (override with FILTER=)"

# --split-level replaced --epub-chapter-level in pandoc 3.0.
PANDOC_MAJOR="$(pandoc --version | head -1 | sed -E 's/^[^0-9]*([0-9]+).*/\1/')"
if ! [[ "$PANDOC_MAJOR" =~ ^[0-9]+$ ]] || [[ "$PANDOC_MAJOR" -lt 3 ]]; then
  die "pandoc 3.0 or newer required, found: $(pandoc --version | head -1)"
fi

CHAPTERS=()
while IFS= read -r file; do
  CHAPTERS+=("$file")
done < <(find "$SRC_DIR" -maxdepth 1 -name '[0-9][0-9]-*.md' | sort)

[[ ${#CHAPTERS[@]} -gt 0 ]] || die "no NN-slug.md chapters in $SRC_DIR"

# ── 1. Findings and word count ───────────────────────────────────────────────
# One pandoc run per chapter: stderr holds the filter's findings, stdout the
# spoken text. The fix belongs in the chapter; the filter strips them anyway.
log "Checking ${#CHAPTERS[@]} chapter(s) for unspeakable elements"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FINDINGS=0
WORDS=()
for file in "${CHAPTERS[@]}"; do
  name="$(basename "$file")"
  if ! STRIP_VISUALS_QUIET=0 pandoc "$file" --from gfm --to plain --lua-filter "$FILTER" \
    >"$TMP_DIR/plain.txt" 2>"$TMP_DIR/stderr.txt"; then
    cat "$TMP_DIR/stderr.txt" >&2
    die "pandoc failed on $name"
  fi
  WORDS+=("$(wc -w <"$TMP_DIR/plain.txt")")
  while IFS= read -r finding; do
    warn "$name: $finding"
    FINDINGS=$((FINDINGS + 1))
  done <"$TMP_DIR/stderr.txt"
done

if [[ "$FINDINGS" -gt 0 ]]; then
  warn "$FINDINGS finding(s); the filter strips them from the EPUB"
  if [[ "$STRICT" == "1" ]]; then
    die "STRICT=1 and the chapters are not clean"
  fi
else
  log "No findings"
fi

# ── 2. Render ────────────────────────────────────────────────────────────────
PANDOC_ARGS=(
  --from gfm
  --to epub3
  --lua-filter "$FILTER"
  --toc
  --toc-depth=1
  --split-level=1
  --output "$OUT_FILE"
)

# Optional metadata: title, creator, lang. Without meta.yml pandoc writes the
# title UNTITLED (readers then show the filename) — it never reads the first
# heading. dc:language falls back to $LANG as a BCP-47 tag (de_DE.UTF-8 →
# de-DE), or en-US when LANG is unset.
if [[ -f "$SRC_DIR/meta.yml" ]]; then
  PANDOC_ARGS+=(--metadata-file "$SRC_DIR/meta.yml")
else
  warn "no $SRC_DIR/meta.yml - title falls back to UNTITLED and language to \$LANG"
fi

# Optional cover: the reader shows it in the library grid.
for cover in "$SRC_DIR/cover.jpg" "$SRC_DIR/cover.png"; do
  if [[ -f "$cover" ]]; then
    PANDOC_ARGS+=(--epub-cover-image "$cover")
    break
  fi
done

# Step 1 already reported the findings; quiet the filter's repeat of them.
log "Rendering $OUT_FILE"
STRIP_VISUALS_QUIET=1 pandoc "${CHAPTERS[@]}" "${PANDOC_ARGS[@]}"

# ── 3. Listening time ────────────────────────────────────────────────────────
# Counted on the filtered plain text from step 1, so it matches what is spoken.
log "Estimated listening time at ${WPM} words per minute"

TOTAL_WORDS=0
for i in "${!CHAPTERS[@]}"; do
  words="${WORDS[$i]}"
  TOTAL_WORDS=$((TOTAL_WORDS + words))
  printf '  %-40s %6d words  %4d min\n' "$(basename "${CHAPTERS[$i]}")" "$words" "$((words / WPM))"
done

printf '  %-40s %6d words  %4d min\n' "TOTAL" "$TOTAL_WORDS" "$((TOTAL_WORDS / WPM))"
log "Wrote $OUT_FILE ($(du -h "$OUT_FILE" | cut -f1))"
