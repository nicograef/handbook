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
#   1. Lints every chapter for elements a narrator cannot speak (file:line).
#   2. Renders the chapters with pandoc and templates/strip-visuals.lua.
#   3. Splits one EPUB chapter per H1 and builds a depth-1 table of contents.
#   4. Reports words and estimated listening time, per chapter and total.
#
# See guides/audiobook-pipeline.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Configuration (env-var defaults) ─────────────────────────────────────────
FILTER="${FILTER:-$REPO_ROOT/templates/strip-visuals.lua}"
WPM="${WPM:-150}"          # narration speed used for the time estimate
STRICT="${STRICT:-0}"      # 1 = abort on any lint finding
# ─────────────────────────────────────────────────────────────────────────────

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

# Chapters are NN-slug.md. The prefix fixes reading order and keeps planning
# artifacts (PLAN.md, sources.md) in the same directory out of the book.
CHAPTERS=()
while IFS= read -r file; do
  CHAPTERS+=("$file")
done < <(find "$SRC_DIR" -maxdepth 1 -name '[0-9][0-9]-*.md' | sort)

[[ ${#CHAPTERS[@]} -gt 0 ]] || die "no NN-slug.md chapters in $SRC_DIR"

# ── 1. Lint ──────────────────────────────────────────────────────────────────
# Reports the source line, not the rendered output: the fix belongs in the
# chapter. The filter still strips these at render time.
log "Linting ${#CHAPTERS[@]} chapter(s) for unspeakable elements"

FINDINGS=0
for file in "${CHAPTERS[@]}"; do
  while IFS= read -r finding; do
    [[ -z "$finding" ]] && continue
    warn "$finding"
    FINDINGS=$((FINDINGS + 1))
  done < <(awk -v f="$file" '
    /^[[:space:]]*(```|~~~)/ {
      fence = !fence
      if (fence) printf "%s:%d: code block - say what it does instead\n", f, NR
      next
    }
    fence { next }
    /^[[:space:]]*\|/ {
      if (!intable) printf "%s:%d: table - linearise it in prose\n", f, NR
      intable = 1
      next
    }
    { intable = 0 }
    /!\[[^]]+\]/ { printf "%s:%d: image alt text - describe the mechanism in prose\n", f, NR }
    /\[\^/ { printf "%s:%d: footnote - fold it into the sentence\n", f, NR }
    /\$\$/ { printf "%s:%d: math block - write the formula in words\n", f, NR }
    /(^|[[:space:]])https?:\/\// { printf "%s:%d: bare URL - drop it or name the source\n", f, NR }
  ' "$file")
done

if [[ "$FINDINGS" -gt 0 ]]; then
  warn "$FINDINGS lint finding(s); the filter strips them from the EPUB"
  if [[ "$STRICT" == "1" ]]; then
    die "STRICT=1 and the lint is not clean"
  fi
else
  log "Lint clean"
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

# Optional metadata: title, creator, lang. Without it pandoc guesses the title
# from the first heading and leaves the language unset.
if [[ -f "$SRC_DIR/meta.yml" ]]; then
  PANDOC_ARGS+=(--metadata-file "$SRC_DIR/meta.yml")
else
  warn "no $SRC_DIR/meta.yml - title and language will be unset"
fi

# Optional cover: the reader shows it in the library grid.
for cover in "$SRC_DIR/cover.jpg" "$SRC_DIR/cover.png"; do
  if [[ -f "$cover" ]]; then
    PANDOC_ARGS+=(--epub-cover-image "$cover")
    break
  fi
done

log "Rendering $OUT_FILE"
pandoc "${CHAPTERS[@]}" "${PANDOC_ARGS[@]}"

# ── 3. Listening time ────────────────────────────────────────────────────────
# Counted on the filtered plain text, so the estimate matches what is spoken.
log "Estimated listening time at ${WPM} words per minute"

TOTAL_WORDS=0
for file in "${CHAPTERS[@]}"; do
  words=$(pandoc "$file" --from gfm --to plain --lua-filter "$FILTER" | wc -w)
  TOTAL_WORDS=$((TOTAL_WORDS + words))
  printf '  %-40s %6d words  %4d min\n' "$(basename "$file")" "$words" "$((words / WPM))"
done

printf '  %-40s %6d words  %4d min\n' "TOTAL" "$TOTAL_WORDS" "$((TOTAL_WORDS / WPM))"
log "Wrote $OUT_FILE ($(du -h "$OUT_FILE" | cut -f1))"
