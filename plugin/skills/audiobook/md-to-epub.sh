#!/usr/bin/env bash
# md-to-epub.sh – render listenable Markdown chapters into an ElevenReader EPUB
#
# Usage:
#   plugin/skills/audiobook/md-to-epub.sh [--strict] <chapter-dir> [output.epub]
#   STRICT=1 plugin/skills/audiobook/md-to-epub.sh audiobook/ indexes.epub
#
# --strict (or STRICT=1) aborts on any finding or check-prose.sh failure.
#
# Chapters are the NN-slug.md files in <chapter-dir>, in filename order. Other
# Markdown in that directory (PLAN.md, sources.md) is ignored.
#
# What it does:
#   1. Runs each chapter through strip-visuals.lua beside this script; every element
#      the filter strips is a finding, prefixed with the chapter name.
#   2. Runs check-prose.sh beside this script: listening budget and AI-tell patterns.
#   3. Renders the chapters with pandoc and the same filter, one EPUB chapter per H1
#      with a depth-1 table of contents.
#
# See plugin/skills/audiobook/SKILL.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Configuration (env-var defaults) ─────────────────────────────────────────
FILTER="${FILTER:-$SCRIPT_DIR/strip-visuals.lua}"
STRICT="${STRICT:-0}"

log() { printf '\033[1;34m▸ %s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$1" >&2; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$1" >&2; exit 1; }

if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
  shift
fi

SRC_DIR="${1:-}"
OUT_FILE="${2:-book.epub}"

# ── Pre-flight ───────────────────────────────────────────────────────────────
[[ -n "$SRC_DIR" ]] || die "usage: $0 [--strict] <chapter-dir> [output.epub]"
[[ -d "$SRC_DIR" ]] || die "chapter directory not found: $SRC_DIR"
command -v pandoc >/dev/null 2>&1 || die "pandoc is not installed"
[[ -f "$FILTER" ]] || die "lua filter not found: $FILTER (override with FILTER=)"

# gfm alerts (> [!WARNING] parsed as a Div) arrived in pandoc 3.1.10.
PANDOC_MIN="3.1.10"
PANDOC_VERSION="$(pandoc --version | head -1 | sed -E 's/^[^0-9]*([0-9][0-9.]*).*/\1/')"
if ! [[ "$PANDOC_VERSION" =~ ^[0-9]+(\.[0-9]+)*$ ]] \
  || ! printf '%s\n' "$PANDOC_MIN" "$PANDOC_VERSION" | sort -V -C; then
  die "pandoc $PANDOC_MIN or newer required, found: $(pandoc --version | head -1)"
fi

CHAPTERS=()
while IFS= read -r file; do
  CHAPTERS+=("$file")
done < <(find "$SRC_DIR" -maxdepth 1 -name '[0-9][0-9]-*.md' | sort)

[[ ${#CHAPTERS[@]} -gt 0 ]] || die "no NN-slug.md chapters in $SRC_DIR"

# ── 1. Findings ──────────────────────────────────────────────────────────────
# One pandoc run per chapter; stderr holds the filter's findings. The fix
# belongs in the chapter; the filter strips them anyway.
log "Checking ${#CHAPTERS[@]} chapter(s) for unspeakable elements"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FINDINGS=0
for file in "${CHAPTERS[@]}"; do
  name="$(basename "$file")"
  if ! STRIP_VISUALS_QUIET=0 pandoc "$file" --from gfm --to plain --lua-filter "$FILTER" \
    >/dev/null 2>"$TMP_DIR/stderr.txt"; then
    cat "$TMP_DIR/stderr.txt" >&2
    die "pandoc failed on $name"
  fi
  while IFS= read -r finding; do
    warn "$name: $finding"
    FINDINGS=$((FINDINGS + 1))
  done <"$TMP_DIR/stderr.txt"
done

if [[ "$FINDINGS" -gt 0 ]]; then
  warn "$FINDINGS finding(s); the filter strips them from the EPUB"
  if [[ "$STRICT" == "1" ]]; then
    die "strict mode and the chapters are not clean"
  fi
else
  log "No findings"
fi

# ── 2. Prose ─────────────────────────────────────────────────────────────────
# Exit 1 is a prose finding; anything higher means the check could not run.
rc=0
"$SCRIPT_DIR/check-prose.sh" "$SRC_DIR" || rc=$?
[[ "$rc" -le 1 ]] || die "check-prose.sh could not run (exit $rc)"
if [[ "$rc" -eq 1 ]]; then
  [[ "$STRICT" == "1" ]] && die "strict mode and check-prose.sh failed"
  warn "check-prose.sh failed; rendering anyway"
fi

# ── 3. Render ────────────────────────────────────────────────────────────────
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

log "Wrote $OUT_FILE ($(du -h "$OUT_FILE" | cut -f1))"
