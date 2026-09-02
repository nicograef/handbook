#!/usr/bin/env bash
# check-repo.sh – repo self-check for the handbook knowledge base.
#
# Every stage is documented as a target in the Makefile.
#
# Idempotent: reads only, never writes.

set -euo pipefail

STAGE="${1:-all}"

# Run from the repo root regardless of the caller's cwd.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FAILED=0

# log() prints an error to stderr and marks the run as failed.
log() {
  printf 'check-repo: %s\n' "$*" >&2
  FAILED=1
}

# Content directories the README indexes as its file index.
INDEX_DIRS=(guides cheatsheets templates scripts)

# Files allowed to contain German prose.
LANG_ALLOW=(
  ".claude/skills/cleanup/readability-de.md"
  ".claude/skills/audiobook/german-narration.md"
  "claude/CLAUDE.md"
)

# Files exempt from the paragraph cap only — the sentence cap still applies to them.
# Source of truth: .claude/skills/output-style.md → Named prose exceptions.
PARA_ALLOW=(
  ".claude/skills/tutor/SKILL.md"
  ".claude/skills/understand/SKILL.md"
  ".claude/skills/guided-implementation/SKILL.md"
  ".claude/skills/write-prd/SKILL.md"
  ".claude/skills/cleanup/readability.md"
  ".claude/skills/cleanup/readability-de.md"
)

# Prose caps enforced by check_prose (see .claude/skills/output-style.md).
PROSE_MAX_WORDS=20
PROSE_MAX_PARA_LINES=3

tracked_md() {
  git ls-files '*.md'
}

# prose_md lists the Markdown files subject to the prose caps: tracked_md minus the
# transient plan artifacts under docs/plans/.
prose_md() {
  tracked_md | grep -v '^docs/plans/'
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

# 1. Link check
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

# 2. Shellcheck
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
  done < <(git ls-files 'scripts/*.sh' 'install.sh' 'claude/*.sh' 'templates/*.sh' \
                        '.claude/skills/*/*.sh')
}

# 3. README index diff
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

# 4. Language check
check_language() {
  local file allow
  while IFS= read -r file; do
    for allow in "${LANG_ALLOW[@]}"; do
      [[ "$file" == "$allow" ]] && continue 2
    done
    if LC_ALL=C.UTF-8 grep -qP '[äöüßÄÖÜ]' "$file" 2>/dev/null; then
      log "German prose (umlaut/eszett) outside allow-list: $file"
    fi
  done < <(tracked_md)
}

# 5. Skills index diff
check_skills() {
  local readme=".claude/skills/README.md" links skill dir
  # Skill directories the index links (form `](name/)`, trailing slash stripped).
  links="$(strip_code < "$readme" \
    | grep -oE '\]\([a-z0-9-]+/\)' \
    | sed -E 's#^\]\(##; s#/\)$##')"

  # Every directory with a SKILL.md must appear in the skills index.
  while IFS= read -r skill; do
    dir="$(basename "$(dirname "$skill")")"
    if ! printf '%s\n' "$links" | grep -qxF "$dir"; then
      log "skill not indexed in .claude/skills/README.md: $dir"
    fi
  done < <(git ls-files '.claude/skills/*/SKILL.md')

  # Every skill the index links must have a SKILL.md on disk.
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    if [[ ! -f ".claude/skills/$dir/SKILL.md" ]]; then
      log ".claude/skills/README.md indexes a missing skill: $dir"
    fi
  done <<< "$links"
}

# 6. Compose templates
check_compose() {
  if ! command -v docker >/dev/null 2>&1; then
    log "docker not installed"
    return
  fi
  local file
  while IFS= read -r file; do
    [[ -e "$file" ]] || continue
    if ! docker compose -f "$file" --env-file templates/.env.example config -q >/dev/null 2>&1; then
      log "compose config failed for $file"
      docker compose -f "$file" --env-file templates/.env.example config -q >&2 || true
    fi
  done < <(git ls-files 'templates/docker-compose*.yml')
}

# 7. Plugin manifests
check_plugin() {
  if ! command -v claude >/dev/null 2>&1; then
    log "claude not installed"
    return
  fi
  if ! claude plugin validate . >/dev/null 2>&1; then
    log "plugin validate failed"
    claude plugin validate . >&2 || true
  fi
}

# prose_scan prints one violation per line for a single Markdown file.
#
# It strips YAML frontmatter, fenced code, HTML comments, table rows, inline code spans and
# link URLs, then flags paragraphs over PROSE_MAX_PARA_LINES and sentences over
# PROSE_MAX_WORDS. Sentence splitting keeps `e.g.`, `i.e.`, `etc.`, `vs.`, `cf.` and any
# digit-preceded period intact.
prose_scan() {
  LC_ALL=C awk -v file="$1" -v maxwords="$PROSE_MAX_WORDS" -v maxpara="$PROSE_MAX_PARA_LINES" '
    # clean strips inline code, images, link URLs, autolinks and emphasis markers.
    function clean(s,   pre, mid, post) {
      gsub(/`[^`]*`/, " ", s)
      gsub(/!\[[^]]*\]\([^)]*\)/, " ", s)
      while (match(s, /\[[^]]*\]\([^)]*\)/)) {
        pre = substr(s, 1, RSTART - 1)
        mid = substr(s, RSTART, RLENGTH)
        post = substr(s, RSTART + RLENGTH)
        sub(/\]\([^)]*\)$/, "", mid)
        sub(/^\[/, "", mid)
        s = pre mid post
      }
      gsub(/<[^ <>]*>/, " ", s)
      gsub(/[*_]/, "", s)
      return s
    }

    # words counts whitespace-separated tokens holding at least one alphanumeric character.
    function words(s,   n, i, a, c) {
      n = split(s, a, /[ \t]+/)
      c = 0
      for (i = 1; i <= n; i++)
        if (a[i] ~ /[A-Za-z0-9]/) c++
      return c
    }

    # abbrev reports whether the sentence so far ends in a non-terminal abbreviation.
    function abbrev(s) {
      return (s ~ /(^|[ (])(e\.g|i\.e|etc|vs|cf|approx|resp|Dr|Mr|Ms|No)\.$/)
    }

    # sentences splits a joined block into a[1..n]; returns n.
    #
    # A period only ends a sentence when a space follows it, so version numbers and
    # decimals (`1.26`, `v2.1.197`) never split. That space rule is why no extra
    # digit-before-period guard is needed: such a guard would merge legitimate
    # sentence ends like "on PostgreSQL 17." into the sentence that follows.
    function sentences(s, a,   i, c, cur, n, nxt) {
      n = 0
      cur = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        cur = cur c
        if (c != "." && c != "!" && c != "?") continue
        nxt = substr(s, i + 1, 1)
        if (nxt != "" && nxt != " ") continue
        if (abbrev(cur)) continue
        a[++n] = cur
        cur = ""
      }
      if (cur ~ /[A-Za-z0-9]/) a[++n] = cur
      return n
    }

    # snippet returns the first few words of a sentence, for the violation message.
    function snippet(s,   n, i, a, out) {
      sub(/^[ \t]+/, "", s)
      n = split(s, a, /[ \t]+/)
      out = ""
      for (i = 1; i <= n && i <= 8; i++) out = (out == "") ? a[i] : out " " a[i]
      return (n > 8) ? out " ..." : out
    }

    # flushpara reports a finished run of column-0 paragraph lines.
    function flushpara() {
      if (para > maxpara)
        printf "%s:%d: paragraph of %d lines (cap %d)\n", file, parastart, para, maxpara
      para = 0
    }

    # checkblock reports every over-long sentence in the accumulated block.
    function checkblock(   n, i, a, w) {
      if (block ~ /[A-Za-z]/) {
        n = sentences(block, a)
        for (i = 1; i <= n; i++) {
          w = words(a[i])
          if (w > maxwords)
            printf "%s:%d: sentence of %d words (cap %d): %s\n", file, blockline, w, maxwords, snippet(a[i])
        }
      }
      block = ""
    }

    BEGIN { fm = 0; fence = 0; comment = 0; para = 0; parastart = 0; block = ""; blockline = 0; prevtype = "" }

    { raw = $0 }

    NR == 1 && raw ~ /^---[ \t]*$/ { fm = 1; next }
    fm { if (raw ~ /^---[ \t]*$/) fm = 0; next }

    raw ~ /^[ \t]*(```|~~~)/ { flushpara(); checkblock(); prevtype = ""; fence = !fence; next }
    fence { next }

    # Inline code spans go first: a backticked `<!--` is prose, not a comment opener,
    # and treating it as one would silently mute the rest of the file. The `@` keeps the
    # line non-blank (a code-span-only line still occupies a rendered paragraph line)
    # while contributing no word to any sentence count.
    { gsub(/`[^`]*`/, "@", raw) }

    {
      if (comment) {
        if (raw ~ /-->/) { sub(/^.*-->/, "", raw); comment = 0 }
        else next
      }
      gsub(/<!--.*-->/, " ", raw)
      if (index(raw, "<!--") > 0) {
        raw = substr(raw, 1, index(raw, "<!--") - 1)
        comment = 1
      }
    }

    raw ~ /^[ \t]*$/ { flushpara(); checkblock(); prevtype = ""; next }
    raw ~ /^#{1,6} / { flushpara(); checkblock(); prevtype = ""; next }
    raw ~ /^[ \t]*\|/ { flushpara(); checkblock(); prevtype = ""; next }
    raw ~ /^[ \t]*(-{3,}|\*{3,}|_{3,})[ \t]*$/ { flushpara(); checkblock(); prevtype = ""; next }

    {
      body = raw
      if (raw ~ /^[ \t]*>/) {
        type = "quote"
        sub(/^[ \t]*>[ \t]*/, "", body)
      } else if (raw ~ /^[ \t]*([-*+]|[0-9]+[.)])[ \t]/) {
        type = "bullet"
        sub(/^[ \t]*([-*+]|[0-9]+[.)])[ \t]+/, "", body)
      } else if (raw ~ /^[ \t]/) {
        type = "cont"
      } else {
        type = "para"
      }

      text = clean(body)

      # Paragraph runs count rendered lines, so a line left wordless by stripping still
      # counts. Blockquotes and indented lines continue the block they wrap.
      if (type == "para") {
        if (prevtype != "para") { flushpara(); checkblock(); parastart = NR }
        para++
      } else if (type != "cont" && !(type == "quote" && prevtype == "quote")) {
        flushpara(); checkblock()
      }
      prevtype = type

      if (text !~ /[A-Za-z]/) next
      if (block == "") blockline = NR
      block = (block == "") ? text : block " " text
    }

    END { flushpara(); checkblock() }
  ' "$1"
}

# 8. Prose caps
check_prose() {
  local file allow violation para_exempt
  while IFS= read -r file; do
    para_exempt=false
    for allow in "${PARA_ALLOW[@]}"; do
      [[ "$file" == "$allow" ]] && para_exempt=true
    done
    while IFS= read -r violation; do
      [[ -z "$violation" ]] && continue
      [[ "$para_exempt" == true && "$violation" == *"paragraph of"* ]] && continue
      log "prose: $violation"
    done < <(prose_scan "$file")
  done < <(prose_md)
}

case "$STAGE" in
  links)    check_links ;;
  lint)     check_shell ;;
  readme)   check_readme ;;
  language) check_language ;;
  skills)   check_skills ;;
  compose)  check_compose ;;
  plugin)   check_plugin ;;
  prose)    check_prose ;;
  all)      check_links; check_shell; check_readme; check_language; check_skills; check_compose; check_plugin; check_prose ;;
  *)        printf 'usage: %s [links|lint|readme|language|skills|compose|plugin|prose|all]\n' "$0" >&2; exit 2 ;;
esac

if [[ "$FAILED" -ne 0 ]]; then
  exit 2
fi
exit 0
