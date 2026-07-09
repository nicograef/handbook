#!/usr/bin/env bash
# check-repo.sh – repo self-check for the handbook knowledge base.
#
# Usage:
#   scripts/check-repo.sh            # run every stage
#   make check                       # same, via the Makefile
#   make links | make lint | make readme   # a single stage (see Makefile)
#
# What it does (silent on success, exit 0; focused errors + exit 2 on failure):
#   1. Link check    — every relative Markdown link resolves to a file on disk.
#   2. Shellcheck    — scripts/*.sh and install.sh pass shellcheck.
#   3. README index  — every content-dir file is indexed in README.md and vice-versa.
#   4. Language      — no German prose (umlauts / eszett) outside the allow-listed files.
#
# Idempotent: reads only, never writes. Run any subset via the STAGE argument:
#   scripts/check-repo.sh links | lint | readme | language | all   (default: all)

set -euo pipefail

STAGE="${1:-all}"

# Run from the repo root regardless of the caller's cwd.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FAILED=0

# log() prints a focused error to stderr and marks the run as failed.
log() {
  printf 'check-repo: %s\n' "$*" >&2
  FAILED=1
}

# Content directories the README indexes as its file index.
INDEX_DIRS=(guides cheatsheets theory research templates scripts)

# Files allowed to contain German prose (besides theory/, which is German by design).
LANG_ALLOW=(
  ".claude/skills/cleanup/readability-de.md"
  "claude/CLAUDE.md"
)

# tracked_md lists tracked Markdown files, excluding the transient overhaul plan.
tracked_md() {
  git ls-files '*.md' | grep -vxF 'plan.md'
}

# strip_code removes fenced code blocks and inline backtick spans from stdin so the
# link check does not match example links inside code samples.
strip_code() {
  awk '
    /^[[:space:]]*```/ { fence = !fence; next }
    fence { next }
    { gsub(/`[^`]*`/, ""); print }
  '
}

# ---------------------------------------------------------------------------
# 1. Link check
# ---------------------------------------------------------------------------
check_links() {
  local file dir target path resolved
  while IFS= read -r file; do
    dir="$(dirname "$file")"
    while IFS= read -r target; do
      [[ -z "$target" ]] && continue
      case "$target" in
        http://*|https://*|mailto:*|tel:*|\#*) continue ;;
      esac
      path="${target%%#*}"
      [[ -z "$path" ]] && continue
      if [[ "$path" = /* ]]; then
        resolved="$path"
      else
        resolved="$dir/$path"
      fi
      if [[ ! -e "$resolved" ]]; then
        log "dead link in $file -> $target"
      fi
    done < <(strip_code < "$file" | grep -oE '\]\([^)]+\)' | sed -E 's/^\]\(//; s/\)$//')
  done < <(tracked_md)
}

# ---------------------------------------------------------------------------
# 2. Shellcheck
# ---------------------------------------------------------------------------
check_shell() {
  if ! command -v shellcheck >/dev/null 2>&1; then
    log "shellcheck not installed"
    return
  fi
  local script
  while IFS= read -r script; do
    [[ -e "$script" ]] || continue
    if ! shellcheck "$script" >/dev/null 2>&1; then
      log "shellcheck failed for $script"
      shellcheck "$script" >&2 || true
    fi
  done < <(git ls-files 'scripts/*.sh' 'install.sh')
}

# ---------------------------------------------------------------------------
# 3. README index diff
# ---------------------------------------------------------------------------
check_readme() {
  local readme="README.md" links file target path
  # All relative links the README points at (anchors stripped).
  links="$(strip_code < "$readme" \
    | grep -oE '\]\([^)]+\)' \
    | sed -E 's/^\]\(//; s/\)$//; s/#.*$//')"

  # Every tracked file in an index dir must appear in the README.
  local index_globs=()
  for d in "${INDEX_DIRS[@]}"; do index_globs+=("$d/*"); done
  while IFS= read -r file; do
    if ! printf '%s\n' "$links" | grep -qxF "$file"; then
      log "not indexed in README.md: $file"
    fi
  done < <(git ls-files "${index_globs[@]}")

  # Every README link into an index dir must point at an existing tracked file.
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    case "$target" in
      http://*|https://*|mailto:*|\#*) continue ;;
    esac
    path="${target%%#*}"
    for d in "${INDEX_DIRS[@]}"; do
      if [[ "$path" == "$d/"* ]]; then
        if ! git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
          log "README.md indexes a missing file: $path"
        fi
      fi
    done
  done <<< "$links"
}

# ---------------------------------------------------------------------------
# 4. Language check
# ---------------------------------------------------------------------------
check_language() {
  local file allow
  while IFS= read -r file; do
    case "$file" in theory/*) continue ;; esac
    for allow in "${LANG_ALLOW[@]}"; do
      [[ "$file" == "$allow" ]] && continue 2
    done
    if LC_ALL=C.UTF-8 grep -qP '[äöüßÄÖÜ]' "$file" 2>/dev/null; then
      log "German prose (umlaut/eszett) outside allow-list: $file"
    fi
  done < <(tracked_md)
}

case "$STAGE" in
  links)    check_links ;;
  lint)     check_shell ;;
  readme)   check_readme ;;
  language) check_language ;;
  all)      check_links; check_shell; check_readme; check_language ;;
  *)        printf 'usage: %s [links|lint|readme|language|all]\n' "$0" >&2; exit 2 ;;
esac

if [[ "$FAILED" -ne 0 ]]; then
  exit 2
fi
exit 0
