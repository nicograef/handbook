#!/usr/bin/env bash
# check-repo.sh – repo self-check for the handbook knowledge base.
#
# Usage:
#   scripts/check-repo.sh [all|<stage>]    # `make help` lists the stages
#
# What it does:
#   1. Runs the named stage, or every stage for `all` (the default). A stage is a
#      check_<stage> function; the "## <stage>:" line above it feeds `make help`.
#   2. Logs each violation to stderr and exits 1 if any stage found one
#
# Idempotent: reads only, never writes.

# shellcheck disable=SC2329 # stages run by name as check_$STAGE, so no call site names them
set -euo pipefail

STAGE="${1:-all}"

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
  ".claude|skills, rules and agents are harness config; each skill describes itself in its frontmatter"
  "docs|PRDs and plans are work files"
  ".github|the handbook's own CI workflow, not a file a project copies"
)

LANG_ALLOW=(
  ".claude/skills/audiobook/writing.md"
  "claude/global.md"
  "guides/neovim.md"
)

# History words check_history flags in prose; the rule is "current state only" in claude/global.md.
# A passive "is used to" describes a purpose, not a past, so the lookbehinds skip it.
HISTORY_RE='\b(previously|formerly|deprecated|no longer|(?<!is )(?<!are )(?<!be )(?<!been )(?<!being )used to)\b'

# Accepted history-word hits, as "<file>|<word>|<reason>". Every entry names its reason.
HISTORY_ALLOW=(
  "claude/global.md|previously|the current-state rule names the banned word"
  ".claude/skills/distill/SKILL.md|previously|the skill names the word as residue to cut"
  ".claude/skills/distill/verify.md|deprecated|upstream deprecations are a claim class to check"
)

# Prose caps enforced by check_prose; stated in AGENTS.md and claude/global.md.
PROSE_MAX_WORDS=20
PROSE_MAX_PARA_LINES=3

# Skill description cap enforced by check_skills; stated in .claude/rules/skills.md.
SKILL_MAX_DESC=250

# Every tracked path, listed once: TRACKED_LIST keeps git's order, TRACKED is the membership set.
TRACKED_LIST=()
declare -A TRACKED=()
while IFS= read -r -d '' path; do
  TRACKED_LIST+=("$path")
  TRACKED[$path]=1
done < <(git ls-files -z)

# tracked prints every tracked path matching one of the globs $@, where * also matches /.
tracked() {
  local path glob
  for path in "${TRACKED_LIST[@]}"; do
    for glob; do
      # shellcheck disable=SC2053 # the right side is a glob on purpose
      if [[ "$path" == $glob ]]; then printf '%s\n' "$path"; break; fi
    done
  done
}

tracked_md() {
  tracked '*.md'
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

# md_links prints the target of every inline Markdown link in file $1, code skipped.
md_links() {
  strip_code < "$1" | grep -oE '\]\([^)]+\)' | sed -E 's/^\]\(//; s/\)$//' || true
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

## links: verify every relative Markdown link resolves on disk, #anchors included (GitHub heading slugs)
check_links() {
  local file dir target path anchor resolved slug
  local -A slugged=() anchors=()
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
      if [[ ! -v "slugged[$resolved]" ]]; then
        slugged[$resolved]=1
        while IFS= read -r slug; do anchors["$resolved#$slug"]=1; done < <(heading_slugs "$resolved")
      fi
      if [[ ! -v "anchors[$resolved#$anchor]" ]]; then
        log "dead anchor in $file -> $target: no heading with slug #$anchor"
      fi
    done < <(md_links "$file")
  done < <(tracked_md)
}

## lint: run shellcheck on every tracked shell script
check_lint() {
  if ! command -v shellcheck >/dev/null 2>&1; then
    log "shellcheck not installed"
    return
  fi
  local script out scripts=()
  while IFS= read -r script; do
    [[ -e "$script" ]] && scripts+=("$script")
  done < <(tracked 'scripts/*.sh' 'install.sh' 'claude/*.sh' 'templates/*.sh' \
                    'dotfiles/.bash_aliases' '.claude/skills/*/*.sh')
  # One file per process, so each report reaches the pipe in one write; -x follows scripts/lib.
  if ! out="$(printf '%s\0' "${scripts[@]}" | xargs -0 -n1 -P"$(nproc)" shellcheck -x 2>&1)"; then
    log "shellcheck failed"
    printf '%s\n' "$out" >&2
  fi
}

## readme: verify README.md indexes every content file and vice-versa, and every top-level folder is indexed or excluded
check_readme() {
  local readme="README.md" target file folder entry covered d
  local -a links=()
  local -A linked=()
  # All relative links the README points at (anchors stripped).
  while IFS= read -r target; do
    target="${target%%#*}"
    [[ -n "$target" ]] || continue
    links+=("$target")
    linked[$target]=1
  done < <(md_links "$readme")

  # Every tracked file in an index dir must appear in the README.
  local index_globs=()
  for d in "${INDEX_DIRS[@]}"; do index_globs+=("$d/*"); done
  while IFS= read -r file; do
    [[ -v "linked[$file]" ]] || log "not indexed in README.md: $file"
  done < <(tracked "${index_globs[@]}")

  # Every tracked top-level folder is indexed or excluded with a reason.
  local -A folders=()
  for file in "${TRACKED_LIST[@]}"; do
    [[ "$file" == */* ]] && folders[${file%%/*}]=1
  done
  while IFS= read -r folder; do
    covered=false
    for d in "${INDEX_DIRS[@]}"; do [[ "$folder" == "$d" ]] && covered=true; done
    for entry in "${INDEX_EXCLUDE[@]}"; do [[ "$entry" == "$folder|"* ]] && covered=true; done
    [[ "$covered" == true ]] || log "top-level folder neither indexed nor excluded: $folder/"
  done < <(printf '%s\n' "${!folders[@]}" | sort)

  # A README link to a file on disk must name a tracked file; check_links reports dead ones.
  for target in "${links[@]}"; do
    if [[ -f "$target" && ! -v "TRACKED[$target]" ]]; then
      log "README.md indexes an untracked file: $target"
    fi
  done
}

# Handbook raw URLs, host and repo written with escaped dots so this file never matches itself.
RAW_URL_RE='raw\.githubusercontent\.com/nicograef/handbook/[^/[:space:]]+/[^[:space:]"'\''`)<>|]+'

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

## contracts: verify handbook raw URLs name tracked paths, setup-server.sh pins report-health.sh's digest, install-dotfiles.sh --check passes, and settings script paths exist
check_contracts() {
  local hit file path table line settings candidate rest resolved pinned actual

  # 1. Every handbook raw URL names a tracked path.
  while IFS= read -r hit; do
    file="${hit%%:*}"
    path="${hit#*:}"
    path="${path#*/nicograef/handbook/}"
    path="${path#refs/heads/}"
    path="${path#refs/tags/}"
    path="${path#*/}"
    path="${path%%[.,;:]}"
    if [[ -z "$path" || ! -v "TRACKED[$path]" ]]; then
      log "raw URL in $file names an untracked path: $path"
    fi
  done < <(git grep -IoE -e "$RAW_URL_RE" || true)

  # 2. setup-server.sh installs report-health.sh only if it matches this digest.
  pinned="$(sed -n 's/^REPORT_HEALTH_SHA256="\([0-9a-f]*\)"$/\1/p' scripts/setup-server.sh)"
  actual="$(sha256sum scripts/report-health.sh | cut -d' ' -f1)"
  if [[ "$pinned" != "$actual" ]]; then
    log "REPORT_HEALTH_SHA256 in scripts/setup-server.sh is '$pinned'; scripts/report-health.sh hashes to $actual"
  fi

  # 3. The install table's pre-flight passes.
  if ! table="$(scripts/install-dotfiles.sh --check 2>/dev/null)"; then
    table=""
    log "install-dotfiles.sh --check failed; ~/.claude script paths not resolved"
    while IFS= read -r line; do
      log "install-dotfiles.sh --check: $line"
    done < <(scripts/install-dotfiles.sh --check 2>&1 >/dev/null)
  fi

  # 4. Every script path in the settings files exists.
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

## language: verify no German prose outside the allow-listed files
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

## skills: verify every skill but audiobook stays model-invocable and its description within the cap
check_skills() {
  local -a skills=()
  local skill
  mapfile -t skills < <(tracked '.claude/skills/*/SKILL.md')

  for skill in "${skills[@]}"; do
    [[ "$skill" == .claude/skills/audiobook/SKILL.md ]] && continue
    if grep -q '^disable-model-invocation:' "$skill"; then
      log "skill blocks model invocation: $skill"
    fi
  done

  # Every description stays within the cap in .claude/rules/skills.md.
  local desc len
  for skill in "${skills[@]}"; do
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
  done
}

## compose: verify every templates/docker-compose*.yml passes `docker compose config -q`
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
  done < <(tracked 'templates/docker-compose*.yml')
}

## history: verify Markdown prose holds no history words (previously, formerly, deprecated, no longer, used to)
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

# prose_scan prints one violation per line for a single Markdown file. Frontmatter, fenced
# code, HTML comments, table rows, inline code and link URLs are not prose.
prose_scan() {
  LC_ALL=C awk -v file="$1" -v maxwords="$PROSE_MAX_WORDS" -v maxpara="$PROSE_MAX_PARA_LINES" '
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

    # sentences splits a joined block into a[1..n]; returns n. A period ends a sentence only
    # before a space, so `1.26` and `v2.1.197` never split; a digit-before-period guard would
    # merge a sentence end like "on PostgreSQL 17." into the next sentence.
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

    # Inline code spans go first: a backticked `<!--` read as a comment opener would mute the
    # rest of the file. The `@` keeps a code-span-only line non-blank, as it renders, and adds
    # no word to any sentence count.
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

## prose: verify Markdown meets the prose caps (sentence ≤ 20 words, paragraph ≤ 3 lines)
check_prose() {
  local file violation
  while IFS= read -r file; do
    while IFS= read -r violation; do
      [[ -z "$violation" ]] && continue
      log "prose: $violation"
    done < <(prose_scan "$file")
  done < <(prose_md)
}

mapfile -t STAGES < <(declare -F | sed -n 's/^declare -f check_//p')

if [[ "$STAGE" == all ]]; then
  for stage in "${STAGES[@]}"; do "check_$stage"; done
elif [[ " ${STAGES[*]} " == *" $STAGE "* ]]; then
  "check_$STAGE"
else
  printf 'usage: %s [all|%s]\n' "$0" "$(IFS='|'; printf '%s' "${STAGES[*]}")" >&2
  exit 2
fi

exit "$FAILED"
