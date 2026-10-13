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

# shellcheck disable=SC2317,SC2329 # stages run by name as check_$STAGE; shellcheck before 0.11 reports that as SC2317
set -euo pipefail

STAGE="${1:-all}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=scripts/lib/skill-hooks.sh
. scripts/lib/skill-hooks.sh

FAILED=0

log() {
  printf 'check-repo: %s\n' "$*" >&2
  FAILED=1
}

# Content directories the README indexes as its file index.
INDEX_DIRS=(guides reference templates dotfiles scripts claude plugin)

# Subtrees of INDEX_DIRS the README links as one folder. Plugin skills describe themselves
# in their frontmatter.
INDEX_FOLDERS=(plugin/skills)

# Tracked top-level folders the README does not index, as "<dir>|<reason>".
INDEX_EXCLUDE=(
  ".claude|the repo's own rules and Stop hook are harness config"
  "docs|PRDs and plans are work files"
  ".github|the handbook's own CI workflow, not a file a project copies"
)

LANG_ALLOW=(
  "plugin/skills/audiobook/writing.md"
  "claude/global.md"
  "guides/neovim.md"
)

# History words check_history flags in prose; the rule is "current state only" in claude/global.md.
# A passive "is used to" describes a purpose, not a past, so the lookbehinds skip it.
HISTORY_RE='\b(previously|formerly|deprecated|no longer|(?<!is )(?<!are )(?<!be )(?<!been )(?<!being )used to)\b'

# Accepted history-word hits, as "<file>|<word>|<reason>". Every entry names its reason.
HISTORY_ALLOW=(
  "claude/global.md|previously|the current-state rule names the banned word"
  "plugin/skills/distill/SKILL.md|previously|the skill names the word as residue to cut"
  "plugin/skills/distill/verify.md|deprecated|upstream deprecations are a claim class to check"
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
                    'dotfiles/.bash_aliases' 'plugin/scripts/*.sh' 'plugin/skills/*/*.sh')
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

  # Every tracked file in an index dir must appear in the README, or its folder for INDEX_FOLDERS.
  local index_globs=()
  for d in "${INDEX_DIRS[@]}"; do index_globs+=("$d/*"); done
  while IFS= read -r file; do
    for d in "${INDEX_FOLDERS[@]}"; do
      [[ "$file" == "$d/"* ]] && continue 2
    done
    [[ -v "linked[$file]" ]] || log "not indexed in README.md: $file"
  done < <(tracked "${index_globs[@]}")
  for d in "${INDEX_FOLDERS[@]}"; do
    [[ -v "linked[$d/]" ]] || log "not indexed in README.md: $d/"
  done

  # Every tracked top-level folder is indexed or excluded with a reason.
  local -A folders=()
  for file in "${TRACKED_LIST[@]}"; do
    [[ "$file" == */* ]] && folders[${file%%/*}]=1
  done
  while IFS= read -r folder; do
    covered=false
    for d in "${INDEX_DIRS[@]}"; do [[ "$d" == "$folder" || "$d" == "$folder/"* ]] && covered=true; done
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

# Files whose hook commands and Bash allow rules name scripts; plugin skills add their frontmatter hooks.
HOOK_FILES=(claude/settings.json .claude/settings.json plugin/hooks/hooks.json)

PLUGIN_MANIFEST=plugin/.claude-plugin/plugin.json
PLUGIN_MARKETPLACE=plugin/.claude-plugin/marketplace.json

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

# audit_fact prints capture group 1 of the first line of host-audit.sh that matches Perl regex $1.
audit_fact() {
  perl -ne 'BEGIN { $re = shift } if (/$re/) { print $1; exit }' "$1" scripts/host-audit.sh
}

# heredoc_body prints the lines of setup-server.sh between the heredoc opener matching Perl
# regex $1 and its EOF.
heredoc_body() {
  perl -ne 'BEGIN { $re = shift } if (/$re/) { $on = 1; next } exit if $on && /^EOF$/; print if $on' \
    "$1" scripts/setup-server.sh
}

# server_audit_contract keeps host-audit.sh's expectations equal to what setup-server.sh
# configures; both are fetched standalone, so they cannot source one shared file.
# shellcheck disable=SC2016 # the patterns match a literal $VAR in the scripts' source
server_audit_contract() {
  local s=scripts/setup-server.sh line var want got keys key log_keys probe kind body rot v6
  local rot_filter rot_want v6_filter v6_want v6_seen=0
  local -A setup_defaults=() jail=()

  # Configuration defaults host-audit.sh shares with setup-server.sh are identical.
  while IFS= read -r line; do
    setup_defaults[${line%%=*}]="$line"
  done < <(sed -nE 's/^([A-Z_]+="\$\{[A-Z_]+:?-[^}]*\}").*/\1/p' "$s")
  got=0
  while IFS= read -r line; do
    got=1
    var="${line%%=*}"
    if [[ ! -v "setup_defaults[$var]" ]]; then
      log "host-audit.sh defaults $var, which setup-server.sh does not configure"
    elif [[ "${setup_defaults[$var]}" != "$line" ]]; then
      log "host-audit.sh has $line; setup-server.sh has ${setup_defaults[$var]}"
    fi
  done < <(sed -nE 's/^([A-Z_]+="\$\{[A-Z_]+:?-[^}]*\}").*/\1/p' scripts/host-audit.sh)
  (( got )) || log "host-audit.sh: no VAR=\"\${VAR:-default}\" Configuration line read"

  # Both read the recorded configuration with the same copied parser.
  want="$(sed -n '/^declare -A HOST_CONFIG_PATTERN=/,/^}/p' "$s")"
  got="$(sed -n '/^declare -A HOST_CONFIG_PATTERN=/,/^}/p' scripts/host-audit.sh)"
  [[ -n "$want" && "$want" == "$got" ]] || log "host-audit.sh's HOST_CONFIG_PATTERN and read_host_config differ from setup-server.sh's"

  # sshd: the audited key:value pairs are the drop-in's lines.
  want="$(audit_fact '^\s*for pair in ([^;]*); do' | words)"
  got="$(heredoc_body '^write_file "\$SSHD_DROPIN" <<' | awk 'NF { print tolower($1) ":" $2 }' | words)"
  [[ -n "$want" && "$want" == "$got" ]] || log "host-audit.sh audits sshd '$want'; setup-server.sh's drop-in sets '$got'"

  # fail2ban: the audited journalmatch tokens and limits are the jail's values.
  while IFS='=' read -r key line; do
    key="${key//[[:space:]]/}"
    if [[ -n "$key" ]]; then jail[$key]="$(xargs <<<"$line")"; fi
  done < <(heredoc_body '^write_file /etc/fail2ban/jail\.local <<')
  want="$(audit_fact '^\s*for token in ([^;]*); do' | words)"
  line="${jail[journalmatch]:-}"
  got="$(words <<<"${line// + / }")"
  [[ -n "$want" && "$want" == "$got" ]] || log "host-audit.sh audits sshd journalmatch '$want'; setup-server.sh sets '$got'"
  keys="$(grep -m1 '^ *limits=' scripts/host-audit.sh | grep -oP 'get sshd \K\w+' | paste -sd ' ' || true)"
  want="$(audit_fact '\[\[ "\$limits" == "([^"]*)" \]\]')"
  got=""
  for key in $keys; do got+="${got:+ }${jail[$key]:-unset}"; done
  [[ -n "$keys" && -n "$want" && "$want" == "$got" ]] \
    || log "host-audit.sh expects sshd '${keys:-?}' as '$want'; setup-server.sh's jail sets '$got'"

  # Docker: host-audit.sh's own jq filters, run on each daemon.json setup-server.sh writes.
  rot_filter="$(audit_fact "^\\s*rot=\"\\\$\\(jq -r '([^']*)'")"
  rot_want="$(audit_fact '^\s*"([^"]*)"\)\s*verdict ok "docker log rotation"')"
  v6_filter="$(audit_fact "^\\s*v6=\"\\\$\\(jq -r '([^']*)'")"
  v6_want="$(audit_fact '\[\[ "\$v6" == "([^"]*)" \]\]')"
  probe="$(audit_fact '^\s*if ! (ip -4 route get \S+)')"
  log_keys="$(sed -n "/^ *LOG_KEYS='/,/'\$/p" "$s" | sed "1s/^ *LOG_KEYS='//; \$s/'\$//")"
  if [[ -z "$rot_filter" || -z "$rot_want" || -z "$v6_filter" || -z "$v6_want" || -z "$probe" || -z "$log_keys" ]]; then
    log "host-audit.sh docker checks or setup-server.sh LOG_KEYS not read; contract unchecked"
  else
    while IFS=$'\t' read -r kind body; do
      body="${body//\$LOG_KEYS/$log_keys}"
      rot="$(jq -r "$rot_filter" <<<"$body" 2>&1 || true)"
      [[ "$rot" == "$rot_want" ]] || log "setup-server.sh writes a daemon.json host-audit.sh reads as '$rot', not '$rot_want'"
      [[ "$kind" == v6 ]] || continue
      v6_seen=1
      v6="$(jq -r "$v6_filter" <<<"$body" 2>&1 || true)"
      [[ "$v6" == "$v6_want" ]] || log "setup-server.sh's IPv6-only daemon.json reads as '$v6' to host-audit.sh, not '$v6_want'"
    done < <(awk -v probe="! $probe" '
      /^ *(if |elif |else$)/ { kind = index($0, probe) ? "v6" : "v4" }
      /^ *write_file \/etc\/docker\/daemon\.json <</ { on = 1; body = ""; next }
      on && /^EOF$/ { print kind "\t" body; on = 0; next }
      on { body = body " " $0 }' "$s")
    (( v6_seen )) || log "setup-server.sh writes no daemon.json under host-audit.sh's IPv6-only probe '$probe'"
  fi

  # The audited cron line is the one setup-server.sh installs.
  want="$(audit_fact '^\s*cron_line="([^"]*)"')"
  if [[ -z "$want" ]] || ! grep -qxF -- "$want" "$s"; then
    log "setup-server.sh installs no cron line '$want' that host-audit.sh expects"
  fi

  # host-audit.sh expects lingering exactly when setup-server.sh enables it.
  want=no got=no
  grep -qF '/var/lib/systemd/linger/$USERNAME' scripts/host-audit.sh && want=yes
  grep -qx 'run loginctl enable-linger "$USERNAME"' "$s" && got=yes
  [[ "$want" == "$got" ]] || log "host-audit.sh audits lingering: $want; setup-server.sh enables it: $got"
}

## contracts: verify handbook raw URLs name tracked paths, setup-server.sh pins report-health.sh's digest and applies what host-audit.sh expects, install-dotfiles.sh --check passes, the settings enable the plugin and its theme, plugin paths name the marketplace, every hook script path exists, and neovim.md installs setup-dev-machine.sh's tool lists
check_contracts() {
  local hit file path table line pinned actual name market entry mpath default theme slug
  local candidate resolved want got
  local -a files=("${HOOK_FILES[@]}")
  mapfile -t -O "${#files[@]}" files < <(tracked 'plugin/skills/*/SKILL.md')

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

  # 3. host-audit.sh expects the defaults and values setup-server.sh applies.
  server_audit_contract

  # 4. The install table's pre-flight passes.
  if ! table="$(scripts/install-dotfiles.sh --check 2>/dev/null)"; then
    table=""
    log "install-dotfiles.sh --check failed; ~/.claude script paths not resolved"
    while IFS= read -r line; do
      log "install-dotfiles.sh --check: $line"
    done < <(scripts/install-dotfiles.sh --check 2>&1 >/dev/null)
  fi

  # 5. The marketplace lists the plugin at its own root, and the global settings register
  #    that marketplace by directory and enable the plugin from it.
  name="$(jq -r '.name // ""' "$PLUGIN_MANIFEST")"
  market="$(jq -r '.name // ""' "$PLUGIN_MARKETPLACE")"
  entry="$(jq -c --arg n "$name" '[.plugins[]? | select(.name == $n)] | length' "$PLUGIN_MARKETPLACE")"
  [[ "$entry" == 1 ]] || log "$PLUGIN_MARKETPLACE lists plugin '$name' $entry times; want once"
  if ! jq -e --arg n "$name" '.plugins[] | select(.name == $n) | .source | IN("./", ".")' \
       "$PLUGIN_MARKETPLACE" >/dev/null; then
    log "$PLUGIN_MARKETPLACE: plugin '$name' must have the marketplace root as source"
  fi
  if ! jq -e --arg id "$name@$market" '.enabledPlugins[$id] == true' claude/settings.json >/dev/null; then
    log "claude/settings.json does not enable $name@$market"
  fi
  # A plugin theme id is custom:<plugin>:<slug>, the slug being its file name under plugin/themes/.
  theme="$(jq -r '.theme // ""' claude/settings.json)"
  if [[ "$theme" == custom:*:* ]]; then
    slug="${theme#"custom:$name:"}"
    if [[ "$slug" == "$theme" || ! -f "plugin/themes/$slug.json" ]]; then
      log "claude/settings.json theme $theme names no plugin/themes/<slug>.json of plugin $name"
    fi
  fi
  mpath="$(jq -r --arg m "$market" \
    '.extraKnownMarketplaces[$m].source | select(.source == "directory") | .path // ""' claude/settings.json)"
  [[ "$mpath" == /*/plugin ]] \
    || log "claude/settings.json: marketplace '$market' needs a directory source whose path ends in /plugin, got '$mpath'"

  # 6. A CLAUDE_PLUGIN_ROOT default and every absolute plugin path in a Bash allow rule name
  #    the marketplace path.
  while IFS= read -r hit; do
    default="${hit#*:-}"
    [[ "$default" == "$mpath" ]] || log "CLAUDE_PLUGIN_ROOT default in ${hit%%:*} is $default; the marketplace path is $mpath"
  done < <(git grep -oE 'CLAUDE_PLUGIN_ROOT:-[^}]*' -- plugin claude || true)
  for file in "${HOOK_FILES[@]}"; do
    while IFS= read -r path; do
      [[ "$path" == "$mpath"/* ]] || log "Bash allow rule in $file names $path outside the marketplace path $mpath"
    done < <(jq -r '.permissions.allow[]? | capture("^Bash\\((?<p>/[^:)]*/plugin/[^:)]*)").p' "$file")
  done

  # 7. Every script a hook command or a Bash allow rule names exists.
  for file in "${files[@]}"; do
    while IFS= read -r candidate; do
      [[ -z "$candidate" ]] && continue
      case "$candidate" in
        \~/.claude/*|\$HOME/.claude/*)
          [[ -n "$table" ]] || continue
          resolved="$(resolve_home_claude ".claude/${candidate#*/.claude/}" <<<"$table")"
          if [[ -z "$resolved" ]]; then
            log "script path in $file is not in the install table: $candidate"
            continue
          fi
          ;;
        \$CLAUDE_PROJECT_DIR/*) resolved="${candidate#*/}" ;;
        \$CLAUDE_PLUGIN_ROOT/*) resolved="plugin/${candidate#*/}" ;;
        "$mpath"/*) resolved="plugin/${candidate#"$mpath"/}" ;;
        *) continue ;;
      esac
      [[ -e "$resolved" ]] || log "script path in $file names a missing file: $candidate -> $resolved"
    done < <(script_candidates "$file")
  done
  # 8. guides/neovim.md installs the servers and uv tools that setup-dev-machine.sh installs.
  want="$(sed -n 's/^\(NPM_SERVERS\|UV_TOOLS\)=(\(.*\))$/\2/p' scripts/setup-dev-machine.sh | words)"
  got="$(awk '/npm install -g|uv tool install/ {on = 1} on {cont = sub(/\\$/, ""); print; if (!cont) on = 0}' guides/neovim.md \
    | sed -E 's/npm install -g|uv tool install|&&|--[a-z-]+=[^ ]*//g' | words)"
  [[ "$want" == "$got" ]] || log "guides/neovim.md installs '$got'; setup-dev-machine.sh installs '$want'"
}

# words prints its input's words sorted, one line, space-separated.
words() { tr -s '[:space:]' '\n' | sed '/^$/d' | sort | tr '\n' ' '; }

# script_candidates prints the script paths one file names: every token ending in .sh in a
# hook or statusLine command, quotes and variable assignments stripped, plus the path of every
# Bash(<path>:*) allow entry. A SKILL.md contributes its frontmatter hook commands.
script_candidates() {
  {
    if [[ "$1" == *.md ]]; then
      skill_hook_commands "$1"
    else
      jq -r '[.hooks[]?[]?.hooks[]?.command, .statusLine.command?] | .[] | select(. != null)' "$1"
    fi
  } | sed -E 's/\$\{([A-Z_]+)(:-[^}]*)?\}/$\1/g' | tr -d "\"'" | tr ';|&(){}' '       ' \
    | tr -s '[:space:]' '\n' | sed -E 's/^[A-Za-z_][A-Za-z0-9_]*=//' | grep -E '\.sh$' || true
  [[ "$1" == *.json ]] || return 0
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
  mapfile -t skills < <(tracked 'plugin/skills/*/SKILL.md')

  for skill in "${skills[@]}"; do
    [[ "$skill" == plugin/skills/audiobook/SKILL.md ]] && continue
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

    # flushpara reports a finished paragraph run; run is "para", "quote", or "item" or "qlist"
    # (a list item, outside or inside a blockquote, never counted).
    function flushpara() {
      if (para > maxpara)
        printf "%s:%d: paragraph of %d lines (cap %d)\n", file, parastart, para, maxpara
      para = 0
      run = ""
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

    BEGIN { fm = 0; fence = 0; comment = 0; para = 0; run = ""; parastart = 0; block = ""; blockline = 0 }

    { raw = $0 }

    NR == 1 && raw ~ /^---[ \t]*$/ { fm = 1; next }
    fm { if (raw ~ /^---[ \t]*$/) fm = 0; next }

    raw ~ /^[ \t]*(```|~~~)/ { flushpara(); checkblock(); fence = !fence; next }
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

    raw ~ /^[ \t]*$/ { flushpara(); checkblock(); next }
    raw ~ /^#{1,6} / { flushpara(); checkblock(); next }
    raw ~ /^[ \t]*\|/ { flushpara(); checkblock(); next }
    raw ~ /^[ \t]*(-{3,}|\*{3,}|_{3,})[ \t]*$/ { flushpara(); checkblock(); next }

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
      # counts. Indented and lazy lines continue the paragraph or list item they follow.
      inrun = (run == "para" || run == "quote")
      inlist = (run == "item" || run == "qlist")
      qlist = (type == "quote" && body ~ /^([-*+]|[0-9]+[.)])[ \t]/)
      if (qlist || type == "quote" && (body == "" || body ~ /^#{1,6} / || body ~ /^\|/)) {
        flushpara(); checkblock()
        if (qlist) run = "qlist"
      } else if (type == "bullet") {
        flushpara(); checkblock(); run = "item"
      } else if (type == "cont" || type == "para" && (inrun || inlist) || type == "quote" && (run == "quote" || run == "qlist")) {
        if (inrun) para++
      } else {
        flushpara(); checkblock(); run = type; parastart = NR; para = 1
      }

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
