#!/usr/bin/env bash
# prune-state.sh – delete agent session state older than a threshold, allowlist-only.
#
# Usage:
#   bash prune-state.sh --days <N> --scope <slug>|all [--exclude-session <id>] [--delete]
#
#   PRUNE_CLAUDE_DIR   harness state root    (default: ~/.claude)
#   PRUNE_SCRATCH_DIR  scratchpad root       (default: /tmp/claude-<uid>)
#
# What it does:
#   1. Walks an explicit allowlist of known state locations (see state-map.md) and
#      collects entries whose mtime is strictly older than --days days. A project
#      slug as scope covers only that project's transcripts and scratchpads; "all"
#      covers every slug plus the six global classes.
#   2. Always excludes: the live session (--exclude-session id, plus the
#      newest-mtime transcript per project directory as the no-id fallback), every
#      memory/ directory, symlinks, and anything outside the allowlist. Session
#      entries are recognized by UUID shape only. Absent locations are skipped
#      silently.
#   3. Dry-run by default: reports what would be deleted. Only with --delete does
#      it remove the collected set (hard deletion, no trash).
#   4. Output: one "MODE <dry-run|delete>" line, one "<class> <files> <bytes>"
#      line per class in scope, then one "total <files> <bytes>" line.

set -euo pipefail
shopt -s nullglob

PRUNE_CLAUDE_DIR="${PRUNE_CLAUDE_DIR:-$HOME/.claude}"
PRUNE_SCRATCH_DIR="${PRUNE_SCRATCH_DIR:-/tmp/claude-$(id -u)}"

RED='\033[0;31m'
NC='\033[0m'

error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

usage() {
  echo "usage: prune-state.sh --days <N> --scope <slug>|all [--exclude-session <id>] [--delete]" >&2
}

DAYS=""
SCOPE=""
EXCLUDE=""
DELETE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --days)
      [[ $# -ge 2 ]] || { usage; error "--days needs a value"; }
      DAYS="$2"; shift 2 ;;
    --scope)
      [[ $# -ge 2 ]] || { usage; error "--scope needs a value"; }
      SCOPE="$2"; shift 2 ;;
    --exclude-session)
      [[ $# -ge 2 ]] || { usage; error "--exclude-session needs a value"; }
      EXCLUDE="$2"; shift 2 ;;
    --delete)
      DELETE=1; shift ;;
    *)
      usage; error "unknown argument: $1" ;;
  esac
done

if [[ -z "$DAYS" || -z "$SCOPE" ]]; then
  usage
  error "--days and --scope are required"
fi
if [[ ! "$DAYS" =~ ^[0-9]+$ ]] || [[ "$DAYS" -lt 1 ]]; then
  error "--days must be a whole number of at least 1, got: $DAYS"
fi
if [[ "$SCOPE" == */* ]]; then
  error "--scope must be a project slug or 'all', got: $SCOPE"
fi

CUTOFF=$(( $(date +%s) - DAYS * 86400 ))

mtime() { stat -c %Y -- "$1"; }

# is_session_id <name> – true when <name> has the UUID shape session ids use.
is_session_id() {
  [[ "$1" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
}

# measure <path> – print "<files> <bytes>" for the regular files at/under <path>.
measure() {
  find "$1" -type f -printf '%s\n' \
    | awk '{ files++; bytes += $1 } END { printf "%d %d", files, bytes }'
}

declare -A CLASS_FILES CLASS_BYTES
DELETE_PATHS=()

# add_candidate <class> <path...> – record one deletion unit and its stats.
add_candidate() {
  local class="$1" path files bytes
  shift
  for path in "$@"; do
    read -r files bytes <<<"$(measure "$path")"
    CLASS_FILES[$class]=$(( CLASS_FILES[$class] + files ))
    CLASS_BYTES[$class]=$(( CLASS_BYTES[$class] + bytes ))
    DELETE_PATHS+=("$path")
  done
}

# prune_project_transcripts <project-dir> – transcript+session-dir units plus
# orphaned session directories under one ~/.claude/projects/<slug>/ directory.
prune_project_transcripts() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0

  local f id m newest_id="" newest_m=-1
  for f in "$dir"/*.jsonl; do
    [[ -f "$f" && ! -L "$f" ]] || continue
    id="$(basename "$f" .jsonl)"
    is_session_id "$id" || continue
    m="$(mtime "$f")"
    if (( m > newest_m )); then
      newest_m="$m"
      newest_id="$id"
    fi
  done

  local d dm unit
  for f in "$dir"/*.jsonl; do
    [[ -f "$f" && ! -L "$f" ]] || continue
    id="$(basename "$f" .jsonl)"
    is_session_id "$id" || continue
    [[ "$id" != "$EXCLUDE" ]] || continue
    [[ "$id" != "$newest_id" ]] || continue
    m="$(mtime "$f")"
    unit=("$f")
    d="$dir/$id"
    if [[ -d "$d" && ! -L "$d" ]]; then
      unit+=("$d")
      dm="$(mtime "$d")"
      if (( dm > m )); then m="$dm"; fi
    fi
    if (( m < CUTOFF )); then add_candidate transcripts "${unit[@]}"; fi
  done

  local name
  for d in "$dir"/*/; do
    d="${d%/}"
    [[ ! -L "$d" ]] || continue
    name="$(basename "$d")"
    [[ "$name" != memory ]] || continue
    is_session_id "$name" || continue
    [[ ! -f "$dir/$name.jsonl" ]] || continue
    [[ "$name" != "$EXCLUDE" ]] || continue
    m="$(mtime "$d")"
    if (( m < CUTOFF )); then add_candidate transcripts "$d"; fi
  done
  return 0
}

# prune_session_dirs <class> <root> – session-id-named subdirectories by age.
prune_session_dirs() {
  local class="$1" root="$2"
  [[ -d "$root" ]] || return 0
  local d name m
  for d in "$root"/*/; do
    d="${d%/}"
    [[ ! -L "$d" ]] || continue
    name="$(basename "$d")"
    is_session_id "$name" || continue
    [[ "$name" != "$EXCLUDE" ]] || continue
    m="$(mtime "$d")"
    if (( m < CUTOFF )); then add_candidate "$class" "$d"; fi
  done
  return 0
}

# prune_files <class> <file...> – plain files by age; symlinks never qualify.
prune_files() {
  local class="$1" f m
  shift
  for f in "$@"; do
    [[ -f "$f" && ! -L "$f" ]] || continue
    if [[ "$class" == debug-logs && -n "$EXCLUDE" ]]; then
      [[ "$(basename "$f")" != "$EXCLUDE.txt" ]] || continue
    fi
    m="$(mtime "$f")"
    if (( m < CUTOFF )); then add_candidate "$class" "$f"; fi
  done
  return 0
}

if [[ "$SCOPE" == all ]]; then
  ACTIVE_CLASSES=(transcripts file-history session-env tasks shell-snapshots paste-cache debug-logs scratchpads)
else
  ACTIVE_CLASSES=(transcripts scratchpads)
fi
for class in "${ACTIVE_CLASSES[@]}"; do
  CLASS_FILES[$class]=0
  CLASS_BYTES[$class]=0
done

if [[ "$SCOPE" == all ]]; then
  for slug_dir in "$PRUNE_CLAUDE_DIR/projects"/*/; do
    slug_dir="${slug_dir%/}"
    [[ ! -L "$slug_dir" ]] || continue
    prune_project_transcripts "$slug_dir"
  done
  prune_session_dirs file-history "$PRUNE_CLAUDE_DIR/file-history"
  prune_session_dirs session-env "$PRUNE_CLAUDE_DIR/session-env"
  prune_session_dirs tasks "$PRUNE_CLAUDE_DIR/tasks"
  prune_files shell-snapshots "$PRUNE_CLAUDE_DIR/shell-snapshots"/snapshot-*.sh
  prune_files paste-cache "$PRUNE_CLAUDE_DIR/paste-cache"/*.txt
  prune_files debug-logs "$PRUNE_CLAUDE_DIR/debug"/*.txt
  for slug_dir in "$PRUNE_SCRATCH_DIR"/*/; do
    slug_dir="${slug_dir%/}"
    [[ ! -L "$slug_dir" ]] || continue
    prune_session_dirs scratchpads "$slug_dir"
  done
else
  prune_project_transcripts "$PRUNE_CLAUDE_DIR/projects/$SCOPE"
  prune_session_dirs scratchpads "$PRUNE_SCRATCH_DIR/$SCOPE"
fi

MODE=dry-run
if (( DELETE )); then
  MODE=delete
  for path in "${DELETE_PATHS[@]}"; do
    rm -rf -- "$path"
  done
fi

echo "MODE $MODE"
TOTAL_FILES=0
TOTAL_BYTES=0
for class in "${ACTIVE_CLASSES[@]}"; do
  echo "$class ${CLASS_FILES[$class]} ${CLASS_BYTES[$class]}"
  TOTAL_FILES=$(( TOTAL_FILES + CLASS_FILES[$class] ))
  TOTAL_BYTES=$(( TOTAL_BYTES + CLASS_BYTES[$class] ))
done
echo "total $TOTAL_FILES $TOTAL_BYTES"
