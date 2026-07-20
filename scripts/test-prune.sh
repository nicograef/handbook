#!/usr/bin/env bash
# test-prune.sh – fixture test for the prune skill's bundled prune-state.sh.
#
# Usage:
#   scripts/test-prune.sh        # or: make test-prune
#
# What it does:
#   1. Builds a throwaway state tree under mktemp -d: fake project slugs with
#      back-dated transcripts and session dirs, a live session, a memory/
#      directory, session-keyed global state, scratchpads, symlinks, and
#      non-allowlisted files.
#   2. Points prune-state.sh at it via PRUNE_CLAUDE_DIR / PRUNE_SCRATCH_DIR —
#      real ~/.claude state is never touched.
#   3. Asserts: --days 0 is refused; dry-run reports the expected set exactly
#      and deletes nothing; --delete removes exactly the reported set; the live
#      session (by id and by newest-mtime fallback), memory/, symlink targets,
#      and non-allowlisted paths survive; project scope leaves other slugs and
#      the global classes untouched.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRUNE="$REPO_ROOT/.claude/skills/prune/prune-state.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC}  $*"; }

FAILED=0
fail() { echo -e "${RED}[FAIL]${NC}  $*" >&2; FAILED=1; }

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

CLAUDE_DIR="$FIX/claude"
SCRATCH_DIR="$FIX/scratch"

LIVE="11111111-1111-1111-1111-111111111111"
OLD_A="22222222-2222-2222-2222-222222222222"
OLD_B="33333333-3333-3333-3333-333333333333"
OLD_C="44444444-4444-4444-4444-444444444444"
KEPT_NEWEST="55555555-5555-5555-5555-555555555555"
ORPHAN="66666666-6666-6666-6666-666666666666"
PAIRED="77777777-7777-7777-7777-777777777777"
FRESH="88888888-8888-8888-8888-888888888888"
LINKED="99999999-9999-9999-9999-999999999999"
SLUG1="-home-test-r-alpha"
SLUG2="-home-test-r-beta"
P1="$CLAUDE_DIR/projects/$SLUG1"
P2="$CLAUDE_DIR/projects/$SLUG2"

run_prune() {
  PRUNE_CLAUDE_DIR="$CLAUDE_DIR" PRUNE_SCRATCH_DIR="$SCRATCH_DIR" bash "$PRUNE" "$@"
}

# measure_paths <path...> – "<files> <bytes>", same measurement the script uses.
measure_paths() {
  find "$@" -type f -printf '%s\n' \
    | awk '{ f++; b += $1 } END { printf "%d %d", f, b }'
}

assert_exists() {
  local p
  for p in "$@"; do
    [[ -e "$p" || -L "$p" ]] || fail "missing (should survive): $p"
  done
}

assert_gone() {
  local p
  for p in "$@"; do
    [[ ! -e "$p" && ! -L "$p" ]] || fail "still present (should be deleted): $p"
  done
}

build_fixture() {
  rm -rf "$CLAUDE_DIR" "$SCRATCH_DIR" "$FIX/outside"

  # slug1 transcripts: a back-dated live session (survives only via id
  # exclusion), a fresh newest one, two old prunable ones, an old orphaned
  # session dir, and an old transcript kept alive by its fresh session dir.
  mkdir -p "$P1/$LIVE" "$P1/$OLD_A" "$P1/$PAIRED" "$P1/$ORPHAN" "$P1/memory"
  echo "live transcript"   > "$P1/$LIVE.jsonl"
  echo "live state"        > "$P1/$LIVE/state.json"
  echo "fresh transcript"  > "$P1/$FRESH.jsonl"
  echo "old transcript A"  > "$P1/$OLD_A.jsonl"
  echo "old state A"       > "$P1/$OLD_A/state.json"
  echo "old transcript B"  > "$P1/$OLD_B.jsonl"
  echo "paired transcript" > "$P1/$PAIRED.jsonl"
  echo "orphan state"      > "$P1/$ORPHAN/state.json"
  echo "# memory index"    > "$P1/memory/MEMORY.md"
  echo "a memory fact"     > "$P1/memory/fact.md"
  echo "not allowlisted"   > "$P1/notes.txt"

  # A transcript-shaped symlink: must be skipped, its target must survive.
  mkdir -p "$FIX/outside"
  echo "symlink target" > "$FIX/outside/target.jsonl"
  ln -s "$FIX/outside/target.jsonl" "$P1/$LINKED.jsonl"

  # slug2 has only old transcripts — the newest survives via the fallback.
  mkdir -p "$P2"
  echo "old transcript C" > "$P2/$OLD_C.jsonl"
  echo "newest of slug2"  > "$P2/$KEPT_NEWEST.jsonl"

  # Session-keyed global state. The live session's entries are back-dated too,
  # so their survival proves the id exclusion, not the age rule.
  mkdir -p "$CLAUDE_DIR/file-history/$OLD_A" "$CLAUDE_DIR/file-history/$LIVE" \
           "$CLAUDE_DIR/session-env/$OLD_A" "$CLAUDE_DIR/tasks/$OLD_A" \
           "$CLAUDE_DIR/shell-snapshots" "$CLAUDE_DIR/paste-cache" \
           "$CLAUDE_DIR/debug" "$CLAUDE_DIR/backups"
  echo "old file history"  > "$CLAUDE_DIR/file-history/$OLD_A/v1.txt"
  echo "live file history" > "$CLAUDE_DIR/file-history/$LIVE/v1.txt"
  echo "old session env"   > "$CLAUDE_DIR/session-env/$OLD_A/env.json"
  echo "old tasks"         > "$CLAUDE_DIR/tasks/$OLD_A/tasks.json"
  echo "old snapshot"      > "$CLAUDE_DIR/shell-snapshots/snapshot-bash-1-old.sh"
  echo "fresh snapshot"    > "$CLAUDE_DIR/shell-snapshots/snapshot-bash-2-new.sh"
  echo "old paste"         > "$CLAUDE_DIR/paste-cache/deadbeefdeadbeef.txt"
  echo "old debug"         > "$CLAUDE_DIR/debug/$OLD_A.txt"
  echo "live debug"        > "$CLAUDE_DIR/debug/$LIVE.txt"
  ln -s "$CLAUDE_DIR/debug/$LIVE.txt" "$CLAUDE_DIR/debug/latest"

  # Non-allowlisted global files — must never be touched.
  echo "config"  > "$CLAUDE_DIR/settings.json"
  echo "history" > "$CLAUDE_DIR/history.jsonl"
  echo "backup"  > "$CLAUDE_DIR/backups/backup.tar"

  # Scratchpads (live one back-dated: survives via id exclusion only).
  mkdir -p "$SCRATCH_DIR/$SLUG1/$OLD_A/scratchpad" \
           "$SCRATCH_DIR/$SLUG1/$LIVE/scratchpad" \
           "$SCRATCH_DIR/$SLUG2/$OLD_C/scratchpad"
  echo "old scratch 1" > "$SCRATCH_DIR/$SLUG1/$OLD_A/scratchpad/tmp.txt"
  echo "live scratch"  > "$SCRATCH_DIR/$SLUG1/$LIVE/scratchpad/tmp.txt"
  echo "old scratch 2" > "$SCRATCH_DIR/$SLUG2/$OLD_C/scratchpad/tmp.txt"

  # Back-date everything except the deliberately fresh entries — files first,
  # then directories (writing into a directory refreshes its mtime).
  local old="30 days ago"
  touch -d "$old" \
    "$P1/$LIVE.jsonl" "$P1/$LIVE/state.json" \
    "$P1/$OLD_A.jsonl" "$P1/$OLD_A/state.json" "$P1/$OLD_B.jsonl" \
    "$P1/$PAIRED.jsonl" "$P1/$ORPHAN/state.json" \
    "$P1/memory/MEMORY.md" "$P1/memory/fact.md" "$P1/notes.txt" \
    "$FIX/outside/target.jsonl" \
    "$P2/$OLD_C.jsonl" \
    "$CLAUDE_DIR/file-history/$OLD_A/v1.txt" "$CLAUDE_DIR/file-history/$LIVE/v1.txt" \
    "$CLAUDE_DIR/session-env/$OLD_A/env.json" "$CLAUDE_DIR/tasks/$OLD_A/tasks.json" \
    "$CLAUDE_DIR/shell-snapshots/snapshot-bash-1-old.sh" \
    "$CLAUDE_DIR/paste-cache/deadbeefdeadbeef.txt" \
    "$CLAUDE_DIR/debug/$OLD_A.txt" "$CLAUDE_DIR/debug/$LIVE.txt" \
    "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/history.jsonl" "$CLAUDE_DIR/backups/backup.tar" \
    "$SCRATCH_DIR/$SLUG1/$OLD_A/scratchpad/tmp.txt" \
    "$SCRATCH_DIR/$SLUG1/$LIVE/scratchpad/tmp.txt" \
    "$SCRATCH_DIR/$SLUG2/$OLD_C/scratchpad/tmp.txt"
  touch -d "10 days ago" "$P2/$KEPT_NEWEST.jsonl"
  touch -d "$old" \
    "$P1/$LIVE" "$P1/$OLD_A" "$P1/$ORPHAN" "$P1/memory" \
    "$CLAUDE_DIR/file-history/$OLD_A" "$CLAUDE_DIR/file-history/$LIVE" \
    "$CLAUDE_DIR/session-env/$OLD_A" "$CLAUDE_DIR/tasks/$OLD_A" \
    "$SCRATCH_DIR/$SLUG1/$OLD_A/scratchpad" "$SCRATCH_DIR/$SLUG1/$OLD_A" \
    "$SCRATCH_DIR/$SLUG1/$LIVE/scratchpad" "$SCRATCH_DIR/$SLUG1/$LIVE" \
    "$SCRATCH_DIR/$SLUG2/$OLD_C/scratchpad" "$SCRATCH_DIR/$SLUG2/$OLD_C"
  # $P1/$PAIRED (the dir) stays fresh: its old transcript survives via unit mtime.
}

# survivors_intact – everything outside the expected-deleted set, in any scope.
survivors_intact() {
  assert_exists \
    "$P1/$LIVE.jsonl" "$P1/$LIVE/state.json" \
    "$P1/$FRESH.jsonl" \
    "$P1/$PAIRED.jsonl" "$P1/$PAIRED" \
    "$P1/memory/MEMORY.md" "$P1/memory/fact.md" \
    "$P1/notes.txt" \
    "$P1/$LINKED.jsonl" "$FIX/outside/target.jsonl" \
    "$P2/$KEPT_NEWEST.jsonl" \
    "$CLAUDE_DIR/file-history/$LIVE/v1.txt" \
    "$CLAUDE_DIR/shell-snapshots/snapshot-bash-2-new.sh" \
    "$CLAUDE_DIR/debug/$LIVE.txt" "$CLAUDE_DIR/debug/latest" \
    "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/history.jsonl" "$CLAUDE_DIR/backups/backup.tar" \
    "$SCRATCH_DIR/$SLUG1/$LIVE/scratchpad/tmp.txt"
}

# ---------------------------------------------------------------------------
# 1. Threshold under 1 day is refused
# ---------------------------------------------------------------------------
log "test: --days 0 is refused"
build_fixture
if out="$(run_prune --days 0 --scope "$SLUG1" 2>&1)"; then
  fail "--days 0 was accepted (exit 0)"
else
  [[ -n "$out" ]] || fail "--days 0 refused without an error message"
fi

# ---------------------------------------------------------------------------
# 2. Project scope: dry-run reports the expected set and deletes nothing
# ---------------------------------------------------------------------------
log "test: project-scope dry-run"
read -r TF TB <<<"$(measure_paths "$P1/$OLD_A.jsonl" "$P1/$OLD_A" "$P1/$OLD_B.jsonl" "$P1/$ORPHAN")"
read -r SF SB <<<"$(measure_paths "$SCRATCH_DIR/$SLUG1/$OLD_A")"
expected_project="MODE dry-run
transcripts $TF $TB
scratchpads $SF $SB
total $(( TF + SF )) $(( TB + SB ))"

before="$(find "$FIX" | sort)"
report="$(run_prune --days 7 --scope "$SLUG1" --exclude-session "$LIVE")"
if [[ "$report" != "$expected_project" ]]; then
  fail "project-scope dry-run report mismatch
--- expected ---
$expected_project
--- actual ---
$report"
fi
after="$(find "$FIX" | sort)"
[[ "$after" == "$before" ]] || fail "dry-run modified the fixture tree"

# ---------------------------------------------------------------------------
# 3. Project scope: --delete removes exactly the reported set
# ---------------------------------------------------------------------------
log "test: project-scope delete"
pre_files="$(find "$FIX" -type f | wc -l)"
report="$(run_prune --days 7 --scope "$SLUG1" --exclude-session "$LIVE" --delete)"
post_files="$(find "$FIX" -type f | wc -l)"
expected_delete="${expected_project/MODE dry-run/MODE delete}"
[[ "$report" == "$expected_delete" ]] || fail "project-scope delete report mismatch: $report"
[[ $(( pre_files - post_files )) -eq $(( TF + SF )) ]] \
  || fail "delete removed $(( pre_files - post_files )) files, reported $(( TF + SF ))"

assert_gone "$P1/$OLD_A.jsonl" "$P1/$OLD_A" "$P1/$OLD_B.jsonl" "$P1/$ORPHAN" \
            "$SCRATCH_DIR/$SLUG1/$OLD_A"
survivors_intact
# Other slugs and global classes are untouched in project scope.
assert_exists "$P2/$OLD_C.jsonl" \
  "$CLAUDE_DIR/file-history/$OLD_A/v1.txt" \
  "$CLAUDE_DIR/session-env/$OLD_A/env.json" \
  "$CLAUDE_DIR/tasks/$OLD_A/tasks.json" \
  "$CLAUDE_DIR/shell-snapshots/snapshot-bash-1-old.sh" \
  "$CLAUDE_DIR/paste-cache/deadbeefdeadbeef.txt" \
  "$CLAUDE_DIR/debug/$OLD_A.txt" \
  "$SCRATCH_DIR/$SLUG2/$OLD_C/scratchpad/tmp.txt"

# ---------------------------------------------------------------------------
# 4. All scope: dry-run reports every class and deletes nothing
# ---------------------------------------------------------------------------
log "test: all-scope dry-run"
build_fixture
read -r TF TB <<<"$(measure_paths "$P1/$OLD_A.jsonl" "$P1/$OLD_A" "$P1/$OLD_B.jsonl" \
                                  "$P1/$ORPHAN" "$P2/$OLD_C.jsonl")"
read -r FF FB <<<"$(measure_paths "$CLAUDE_DIR/file-history/$OLD_A")"
read -r EF EB <<<"$(measure_paths "$CLAUDE_DIR/session-env/$OLD_A")"
read -r KF KB <<<"$(measure_paths "$CLAUDE_DIR/tasks/$OLD_A")"
read -r NF NB <<<"$(measure_paths "$CLAUDE_DIR/shell-snapshots/snapshot-bash-1-old.sh")"
read -r CF CB <<<"$(measure_paths "$CLAUDE_DIR/paste-cache/deadbeefdeadbeef.txt")"
read -r DF DB <<<"$(measure_paths "$CLAUDE_DIR/debug/$OLD_A.txt")"
read -r SF SB <<<"$(measure_paths "$SCRATCH_DIR/$SLUG1/$OLD_A" "$SCRATCH_DIR/$SLUG2/$OLD_C")"
total_f=$(( TF + FF + EF + KF + NF + CF + DF + SF ))
total_b=$(( TB + FB + EB + KB + NB + CB + DB + SB ))
expected_all="MODE dry-run
transcripts $TF $TB
file-history $FF $FB
session-env $EF $EB
tasks $KF $KB
shell-snapshots $NF $NB
paste-cache $CF $CB
debug-logs $DF $DB
scratchpads $SF $SB
total $total_f $total_b"

before="$(find "$FIX" | sort)"
report="$(run_prune --days 7 --scope all --exclude-session "$LIVE")"
if [[ "$report" != "$expected_all" ]]; then
  fail "all-scope dry-run report mismatch
--- expected ---
$expected_all
--- actual ---
$report"
fi
after="$(find "$FIX" | sort)"
[[ "$after" == "$before" ]] || fail "all-scope dry-run modified the fixture tree"

# ---------------------------------------------------------------------------
# 5. All scope: --delete removes exactly the reported set, survivors intact
# ---------------------------------------------------------------------------
log "test: all-scope delete"
pre_files="$(find "$FIX" -type f | wc -l)"
report="$(run_prune --days 7 --scope all --exclude-session "$LIVE" --delete)"
post_files="$(find "$FIX" -type f | wc -l)"
expected_delete="${expected_all/MODE dry-run/MODE delete}"
[[ "$report" == "$expected_delete" ]] || fail "all-scope delete report mismatch: $report"
[[ $(( pre_files - post_files )) -eq "$total_f" ]] \
  || fail "delete removed $(( pre_files - post_files )) files, reported $total_f"

assert_gone "$P1/$OLD_A.jsonl" "$P1/$OLD_A" "$P1/$OLD_B.jsonl" "$P1/$ORPHAN" \
            "$P2/$OLD_C.jsonl" \
            "$CLAUDE_DIR/file-history/$OLD_A" \
            "$CLAUDE_DIR/session-env/$OLD_A" \
            "$CLAUDE_DIR/tasks/$OLD_A" \
            "$CLAUDE_DIR/shell-snapshots/snapshot-bash-1-old.sh" \
            "$CLAUDE_DIR/paste-cache/deadbeefdeadbeef.txt" \
            "$CLAUDE_DIR/debug/$OLD_A.txt" \
            "$SCRATCH_DIR/$SLUG1/$OLD_A" "$SCRATCH_DIR/$SLUG2/$OLD_C"
survivors_intact

# ---------------------------------------------------------------------------
if [[ "$FAILED" -ne 0 ]]; then
  fail "prune fixture tests failed"
  exit 2
fi
log "all prune fixture tests passed"
