#!/usr/bin/env bash
# check-repo.sh – repo self-check for the handbook knowledge base.
#
# Usage:
#   scripts/check-repo.sh [all|links|lint|readme|language|skills|compose|prose|history|contracts]
#
# What it does:
#   1. Runs the named stage, or every stage for `all` (the default)
#   2. Logs each violation and exits non-zero if any stage found one
#
# Every stage except `all` has a same-named Makefile target; `all` is reached as `make check`.
# Idempotent: reads only, never writes.

set -euo pipefail

STAGE="${1:-all}"

# Run from the repo root regardless of the caller's cwd.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FAILED=0

log() {
  printf 'check-repo: %s\n' "$*" >&2
  FAILED=1
}

# Content directories the README indexes as its file index.
INDEX_DIRS=(guides reference templates dotfiles scripts claude)

# Tracked top-level folders the README does not index, as "<dir>|<reason>".
INDEX_EXCLUDE=(
  ".claude|the skills stage indexes skills; rules and agents are harness config"
  "docs|PRDs and plans are work files"
  ".github|the handbook's own CI workflow, not a file a project copies"
)

LANG_ALLOW=(
  ".claude/skills/audiobook/writing.md"
  "claude/CLAUDE.md"
  "guides/neovim.md"
)

# Files exempt from the paragraph cap only — the sentence cap still applies to them.
PARA_ALLOW=(
  ".claude/skills/audiobook/writing.md"
)

# History words check_history flags in prose; the rule is "current state only" in claude/CLAUDE.md.
# A passive "is used to" describes a purpose, not a past, so the lookbehinds skip it.
HISTORY_RE='\b(previously|formerly|deprecated|no longer|(?<!is )(?<!are )(?<!be )(?<!been )(?<!being )used to)\b'

# Accepted history-word hits, as "<file>|<word>|<reason>". Every entry names its reason.
HISTORY_ALLOW=(
  "claude/CLAUDE.md|previously|the current-state rule names the banned word"
  ".claude/skills/distill/SKILL.md|previously|the skill names the word as residue to cut"
  ".claude/skills/verify-docs/SKILL.md|deprecated|upstream deprecations are a claim class to check"
)

# Prose caps enforced by check_prose; stated in AGENTS.md and claude/CLAUDE.md.
PROSE_MAX_WORDS=20
PROSE_MAX_PARA_LINES=3

# Skill description cap enforced by check_skills; stated in .claude/rules/skills.md.
SKILL_MAX_DESC=250

tracked_md() {
  git ls-files '*.md'
}

# prose_md lists the Markdown files subject to the prose caps: tracked_md minus the
# transient plan artifacts under docs/plans/.
prose_md() {
  tracked_md | grep -v '^docs/plans/'
}

# strip_code blanks fenced code blocks and removes inline backtick spans from stdin so
# checks skip code samples. Blank lines keep the line numbers of the input.
strip_code() {
  awk '
    /^[[:space:]]*```/ { fence = !fence; print ""; next }
    fence { print ""; next }
    { gsub(/`[^`]*`/, ""); print }
  '
}

# heading_slugs prints the GitHub heading slug of every ATX heading in a Markdown file,
# one per line. Frontmatter and fenced code do not count; a repeated slug gets the
# first unused suffix -1, -2, as GitHub assigns them.
heading_slugs() {
  perl -CSD -ne '
    if ($. == 1 && /^---\s*$/) { $fm = 1; next }
    if ($fm) { $fm = 0 if /^---\s*$/; next }
    if (/^\s*(```|~~~)/) { $fence = !$fence; next }
    next if $fence;
    next unless /^ {0,3}#{1,6}\s+(.*?)\s*#*\s*$/;
    $h = $1;
    $h =~ s/\[([^\]]*)\]\([^)]*\)/$1/g;
    $h =~ tr/`*//d;
    $h = lc $h;
    $h =~ s/[^\p{L}\p{N}\p{M} _-]//g;
    $h =~ tr/ /-/;
    ($s, $n) = ($h, $seen{$h} || 1);
    $s = "$h-" . $n++ while $used{$s};
    ($seen{$h}, $used{$s}) = ($n, 1);
    print "$s\n";
  ' "$1"
}

check_links() {
  local file dir target path anchor resolved
  local -A slugs=()
  while IFS= read -r file; do
    dir="$(dirname "$file")"
    while IFS= read -r target; do
      [[ -z "$target" ]] && continue
      case "$target" in
        http://*|https://*|mailto:*|tel:*) continue ;;
      esac
      path="${target%%#*}"
      anchor=""
      [[ "$target" == *"#"* ]] && anchor="${target#*#}"
      if [[ -z "$path" ]]; then
        resolved="$file"
      elif [[ "$path" = /* ]]; then
        resolved="$path"
      else
        resolved="$dir/$path"
      fi
      if [[ ! -e "$resolved" ]]; then
        log "dead link in $file -> $target"
        continue
      fi
      [[ -z "$anchor" || "$resolved" != *.md || ! -f "$resolved" ]] && continue
      [[ -v "slugs[$resolved]" ]] || slugs[$resolved]="$(heading_slugs "$resolved")"
      if ! grep -qxF -- "$anchor" <<<"${slugs[$resolved]}"; then
        log "dead anchor in $file -> $target: no heading with slug #$anchor"
      fi
    done < <(strip_code < "$file" | grep -oE '\]\([^)]+\)' | sed -E 's/^\]\(//; s/\)$//')
  done < <(tracked_md)
}

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
                        'dotfiles/.bash_aliases' '.claude/skills/*/*.sh')
}

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
    if ! grep -qxF "$file" <<<"$links"; then
      log "not indexed in README.md: $file"
    fi
  done < <(git ls-files "${index_globs[@]}")

  # Every tracked top-level folder is indexed or excluded with a reason.
  local folder entry covered
  while IFS= read -r folder; do
    covered=false
    for d in "${INDEX_DIRS[@]}"; do [[ "$folder" == "$d" ]] && covered=true; done
    for entry in "${INDEX_EXCLUDE[@]}"; do [[ "$entry" == "$folder|"* ]] && covered=true; done
    [[ "$covered" == true ]] || log "top-level folder neither indexed nor excluded: $folder/"
  done < <(git ls-files | grep / | cut -d/ -f1 | sort -u)

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

# Handbook raw URLs, host and repo written with escaped dots so this file never matches itself.
RAW_URL_RE='raw\.githubusercontent\.com/nicograef/handbook/[^/[:space:]]+/[^[:space:]"'\''`)<>|]+'

# The Claude settings files whose script paths check_contracts resolves.
SETTINGS_FILES=(claude/settings.json .claude/settings.json)

# resolve_home_claude maps a ~/.claude/<rest> path to its repo origin through the install
# table on stdin ("<origin> <dest>" lines): the exact dest, else a directory dest above it.
resolve_home_claude() {
  local dest="$1" origin link_dest
  while read -r origin link_dest; do
    if [[ "$dest" == "$link_dest" ]]; then
      printf '%s\n' "$origin"
      return
    fi
    if [[ "$dest" == "$link_dest/"* ]]; then
      printf '%s\n' "$origin/${dest#"$link_dest"/}"
      return
    fi
  done
}

check_contracts() {
  local hit file path table line settings candidate rest resolved

  # 1. Every handbook raw URL names a tracked path.
  while IFS= read -r hit; do
    file="${hit%%:*}"
    path="${hit#*:}"
    path="${path#*/nicograef/handbook/}"
    path="${path#refs/heads/}"
    path="${path#refs/tags/}"
    path="${path#*/}"
    path="${path%%[.,;:]}"
    if ! git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
      log "raw URL in $file names an untracked path: $path"
    fi
  done < <(git grep -IoE -e "$RAW_URL_RE" || true)

  # 2. The install table's pre-flight passes.
  if ! table="$(scripts/install-dotfiles.sh --check 2>/dev/null)"; then
    table=""
    log "install-dotfiles.sh --check failed; ~/.claude script paths not resolved"
    while IFS= read -r line; do
      log "install-dotfiles.sh --check: $line"
    done < <(scripts/install-dotfiles.sh --check 2>&1 >/dev/null)
  fi

  # 3. Every script path in the settings files exists.
  for settings in "${SETTINGS_FILES[@]}"; do
    while IFS= read -r candidate; do
      [[ -z "$candidate" ]] && continue
      case "$candidate" in
        \~/.claude/*|\$HOME/.claude/*)
          [[ -n "$table" ]] || continue
          rest=".claude/${candidate#*/.claude/}"
          resolved="$(resolve_home_claude "$rest" <<<"$table")"
          if [[ -z "$resolved" ]]; then
            log "script path in $settings is not in the install table: $candidate"
          elif [[ ! -e "$resolved" ]]; then
            log "script path in $settings resolves to a missing file: $candidate -> $resolved"
          fi
          ;;
        \$CLAUDE_PROJECT_DIR/*)
          resolved="${candidate#*/}"
          [[ -e "$resolved" ]] || log "script path in $settings names a missing file: $candidate"
          ;;
      esac
    done < <(settings_candidates "$settings")
  done
}

# settings_candidates prints the script-path candidates of one settings file: every
# token ending in .sh in a hook or statusLine command, quotes stripped, plus the path
# of every Bash(<path>:*) allow entry.
settings_candidates() {
  jq -r '[.hooks[]?[]?.hooks[]?.command, .statusLine.command?] | .[] | select(. != null)' "$1" \
    | sed -E 's/\$\{(HOME|CLAUDE_PROJECT_DIR)\}/$\1/g' | tr -d "\"'" | tr ';|&()' '     ' | tr -s '[:space:]' '\n' | grep -E '\.sh$' || true
  jq -r '.permissions.allow[]?' "$1" | sed -E 's/\$\{(HOME|CLAUDE_PROJECT_DIR)\}/$\1/g' \
    | sed -nE 's/^Bash\((.*):\*\)$/\1/p'
}

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

check_skills() {
  local readme=".claude/skills/README.md" links skill dir
  # Skill directories the index links (form `](name/)`, trailing slash stripped).
  links="$(strip_code < "$readme" \
    | grep -oE '\]\([a-z0-9-]+/\)' \
    | sed -E 's#^\]\(##; s#/\)$##')"

  # Every directory with a SKILL.md must appear in the skills index.
  while IFS= read -r skill; do
    dir="$(basename "$(dirname "$skill")")"
    if ! grep -qxF "$dir" <<<"$links"; then
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

  # Every description stays within the cap in .claude/rules/skills.md.
  local desc len
  while IFS= read -r skill; do
    desc="$(awk 'NR == 1 && /^---/ { fm = 1; next } fm && /^---/ { exit }
      fm && sub(/^description:[ \t]*/, "") { print; exit }' "$skill")"
    desc="${desc#[\"\']}"
    desc="${desc%[\"\']}"
    if [[ -z "$desc" ]]; then
      log "skill has no description: $skill"
      continue
    fi
    len="$(printf '%s' "$desc" | LC_ALL=C.UTF-8 wc -m)"
    if (( len > SKILL_MAX_DESC )); then
      log "skill description of $len characters (cap $SKILL_MAX_DESC): $skill"
    fi
  done < <(git ls-files '.claude/skills/*/SKILL.md')
}

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

check_history() {
  local file hit lineno word entry allowed
  while IFS= read -r file; do
    while IFS= read -r hit; do
      lineno="${hit%%:*}"
      word="${hit#*:}"
      word="${word,,}"
      allowed=false
      for entry in "${HISTORY_ALLOW[@]}"; do
        [[ "$entry" == "$file|$word|"* ]] && allowed=true
      done
      [[ "$allowed" == true ]] || log "history word in $file:$lineno: $word"
    done < <(strip_code < "$file" | grep -noiP "$HISTORY_RE" || true)
  done < <(prose_md)
}

# prose_scan prints one violation per line for a single Markdown file.
#
# It strips YAML frontmatter, fenced code, HTML comments, table rows, inline code spans and
# link URLs, then flags paragraphs over PROSE_MAX_PARA_LINES and sentences over
# PROSE_MAX_WORDS. Sentence splitting keeps `e.g.`, `i.e.`, `etc.`, `vs.` and `cf.` intact.
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
  prose)    check_prose ;;
  history)  check_history ;;
  contracts) check_contracts ;;
  all)      check_links; check_shell; check_readme; check_language; check_skills; check_compose; check_prose; check_history; check_contracts ;;
  *)        printf 'usage: %s [links|lint|readme|language|skills|compose|prose|history|contracts|all]\n' "$0" >&2; exit 2 ;;
esac

if [[ "$FAILED" -ne 0 ]]; then
  exit 2
fi
exit 0
