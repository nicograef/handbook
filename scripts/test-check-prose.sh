#!/usr/bin/env bash
# test-check-prose.sh – fixture test for plugin/skills/audiobook/check-prose.sh.
#
# Usage:
#   scripts/test-check-prose.sh
#
# What it does:
#   1. Writes chapter dirs under mktemp -d, sized in characters against a small CPM.
#   2. Asserts the exit code and output for budget, chapter cap and pattern hits.

set -euo pipefail

# shellcheck source=scripts/lib/test-harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/test-harness.sh"

CHECK="$REPO_ROOT/plugin/skills/audiobook/check-prose.sh"

# book <dir> <minutes> <chapter text>...: one NN-test.md per text, budget in meta.yml
book() {
  local dir="$FIX/$1" minutes="$2" n=1
  shift 2
  mkdir -p "$dir"
  printf 'title: Test\nminutes: %s\n' "$minutes" >"$dir/meta.yml"
  for text in "$@"; do
    printf '%s\n' "$text" >"$dir/$(printf '%02d' "$n")-test.md"
    n=$((n + 1))
  done
}

# expect <name> <code> <dir> [output-substring], at 100 characters per minute
expect() {
  local code=0 out
  out="$(CPM=100 CHAPTER_MAX=3 bash "$CHECK" "$FIX/$3" 2>&1)" || code=$?
  if [[ "$code" -ne "$2" ]]; then fail "$1: expected exit $2, got $code ($out)"; return; fi
  if [[ -n "${4:-}" && "$out" != *"$4"* ]]; then fail "$1: output lacks '$4': $out"; return; fi
  log "$1 -> exit $code"
}

CLEAN="# Überblick

Der Cache weiß nichts vom Lock. Übrigens schreibt der Job zweihundert Zeilen pro Sekunde."
LONG="$(printf 'Der Job schreibt eine Zeile. %.0s' {1..12})"

book clean 2 "$CLEAN"
expect "clean book in budget" 0 clean "Within budget"

book over 1 "$CLEAN" "$CLEAN"
expect "book over budget" 1 over "budget 1 min"

book quoted "'1'  # Hörzeit" "$CLEAN" "$CLEAN"
expect "quoted budget with comment" 1 quoted "budget 1 min"

book nobudget "" "$CLEAN"
sed -i '/^minutes:/d' "$FIX/nobudget/meta.yml"
expect "missing budget" 1 nobudget "no whole-number 'minutes:'"

book cap 9 "$LONG"
expect "chapter over cap" 1 cap "01-test.md: over the 3-minute chapter cap"

book slop 9 "Abschließend ist das Rückgrat des Systems spannend.
Die Antwort kommt nach 200 ms, z. B. beim Login (meistens). Zudem spielt dabei eine zentrale Rolle der Cache."
expect "closer, frame, mannered and tts hits" 1 slop "8 pattern hit(s)"
expect "hit names chapter, line and category" 1 slop "01-test.md:2: tts: 200 ms"

printf 'frame\t(unclosed\n' >"$FIX/bad.txt"
code=0
PATTERNS="$FIX/bad.txt" bash "$CHECK" "$FIX/clean" >/dev/null 2>&1 || code=$?
if [[ "$code" -eq 2 ]]; then log "invalid pattern -> exit 2"; else fail "invalid pattern: expected exit 2, got $code"; fi

finish
