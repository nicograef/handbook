#!/usr/bin/env bash
# agent-bus.sh – coordination bus for concurrent Claude Code sessions in one repo.
#
# Usage:
#   agent-bus.sh peers                       list live sessions sharing this repo
#   agent-bus.sh announce <task> [flags]     publish what this session is doing
#   agent-bus.sh send <peer> <text> [flags]  queue a message for a peer
#   agent-bus.sh inbox [--drain]             show or drain this session's messages
#   agent-bus.sh sent                        delivery receipts for messages sent
#   agent-bus.sh radar [base-ref]            conflicts and collisions against peers
#   agent-bus.sh sweep                       drop registry entries of dead sessions
#   agent-bus.sh hook <event>                hook body; reads hook JSON on stdin
#
# What it does:
#   1. Finds sessions whose working directory shares this repo's git-common-dir.
#   2. Keeps a registry of each session's branch, task, paths, resources and deps.
#   3. Predicts merge conflicts, path overlap and resource collisions.
#   4. Moves messages between sessions through a directory queue in the git dir.
#   5. Delivers queued messages into a running session from its Stop hook.
#
# The channel is derived, never negotiated: every worktree of a repo resolves
# `git rev-parse --git-common-dir` to the same directory, so both sides compute the
# same bus path without agreeing on one. Two sessions that negotiate a channel can
# deadlock by each adopting the other's; a derived path cannot.

set -euo pipefail

# Cap on consecutive Stop-hook deliveries, so two chatty sessions cannot ping-pong
# forever. Reset whenever the user submits a prompt.
MAX_WAKES="${AGENT_BUS_MAX_WAKES:-25}"

log() { printf '\033[1;34m▸ %s\033[0m\n' "$*" >&2; }
die() { printf '\033[1;31magent-bus: %s\033[0m\n' "$*" >&2; exit 1; }

need_jq() { command -v jq >/dev/null 2>&1 || die "jq is required"; }

# ── Identity and location ───────────────────────────────────────────────────

# session_id prefers an explicit override; hooks set it from their stdin payload.
session_id() { printf '%s' "${AGENT_BUS_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}"; }

# bus_root prints the bus directory for the repo containing $PWD, creating it.
bus_root() {
  local common
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
    || die "not inside a git repository"
  mkdir -p "$common/agent-bus"/{peers,inbox,outbox,acks,wake}
  printf '%s' "$common/agent-bus"
}

# bus_root_quiet prints the bus directory without creating it; empty outside a repo.
bus_root_quiet() {
  local common
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 0
  printf '%s' "$common/agent-bus"
}

current_branch() { git symbolic-ref --quiet --short HEAD 2>/dev/null || true; }
worktree_root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }
now_ms() { date +%s%3N; }

# default_base prints the branch this work is expected to land on.
default_base() {
  local ref b
  ref="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$ref" ]]; then printf '%s' "${ref#origin/}"; return; fi
  for b in main master; do
    if git show-ref --verify --quiet "refs/heads/$b"; then printf '%s' "$b"; return; fi
  done
  printf 'HEAD'
}

# alive reports whether a pid is a running claude process.
alive() {
  local pid="${1:-}"
  [[ -n "$pid" && "$pid" != "null" ]] || return 1
  [[ -r "/proc/$pid/cmdline" ]] || return 1
  tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -qi claude
}

# write_json atomically replaces a file with stdin, but only if stdin was valid JSON.
# Without the check a failed producer installs an empty file that every later read
# then has to treat as corrupt.
write_json() {
  local dest="$1" tmp="$1.tmp"
  cat > "$tmp"
  if jq -e . "$tmp" >/dev/null 2>&1; then
    mv -f "$tmp" "$dest"
  else
    rm -f "$tmp"
    return 1
  fi
}

# csv_to_json turns "a,b" into a JSON array, dropping empties.
# The trailing newline matters: on empty input `jq -R` reads no line and prints
# nothing, which --argjson then rejects as invalid JSON.
csv_to_json() {
  printf '%s\n' "${1:-}" | jq -R 'split(",") | map(select(length > 0))'
}

# ── Registry ────────────────────────────────────────────────────────────────

# register writes or refreshes this session's entry. An empty argument keeps the
# previous value, so SessionStart can register without erasing an earlier announce.
# Usage: register <task> <paths-csv> <resources-csv> <needs-csv> <provides-csv>
register() {
  local bus sid file prev
  sid="$(session_id)"
  [[ -n "$sid" ]] || return 0
  bus="$(bus_root)"
  file="$bus/peers/$sid.json"
  mkdir -p "$bus/inbox/$sid/read" "$bus/outbox/$sid"
  prev='{}'
  if [[ -f "$file" ]]; then
    prev="$(jq -c . "$file" 2>/dev/null || true)"
    [[ -n "$prev" ]] || prev='{}'
  fi

  jq -n \
    --argjson prev "$prev" \
    --arg sid "$sid" \
    --arg pid "${CLAUDE_PID:-$$}" \
    --arg wt "$(worktree_root)" \
    --arg branch "$(current_branch)" \
    --arg task "${1:-}" \
    --argjson paths "$(csv_to_json "${2:-}")" \
    --argjson resources "$(csv_to_json "${3:-}")" \
    --argjson needs "$(csv_to_json "${4:-}")" \
    --argjson provides "$(csv_to_json "${5:-}")" \
    --arg at "$(now_ms)" \
    '
    def keep(new; old): if (new | length) == 0 then (old // null) else new end;
    {
      sessionId: $sid,
      pid: ($pid | tonumber),
      worktree: $wt,
      branch: $branch,
      task:      (keep($task;      $prev.task)      // ""),
      paths:     (keep($paths;     $prev.paths)     // []),
      resources: (keep($resources; $prev.resources) // []),
      needs:     (keep($needs;     $prev.needs)     // []),
      provides:  (keep($provides;  $prev.provides)  // []),
      updatedAt: ($at | tonumber)
    }' | write_json "$file"
}

# registry_rows emits one TSV row per registry entry: sid, pid, branch, worktree, task.
registry_rows() {
  local bus file
  bus="$(bus_root_quiet)"
  [[ -n "$bus" && -d "$bus/peers" ]] || return 0
  for file in "$bus"/peers/*.json; do
    [[ -e "$file" ]] || continue
    jq -r '[.sessionId // "", (.pid // 0 | tostring), .branch // "",
            .worktree // "", .task // ""] | @tsv' "$file" 2>/dev/null || true
  done
}

# peer_file prints the registry path for a session id.
peer_file() { printf '%s/peers/%s.json' "$1" "$2"; }

# queued_count prints how many messages are waiting for a session.
# A glob, not `find`: on a missing directory `find` exits 1, and under pipefail
# that kills the caller through errexit.
queued_count() {
  local f n=0
  for f in "$1/inbox/$2"/*.json; do
    [[ -e "$f" ]] && n=$((n + 1))
  done
  printf '%s' "$n"
}

# live_sessions emits TSV rows for every live session whose cwd shares this repo:
# sessionId, pid, cwd, name, status. Source is `claude agents --json`, which sees
# sessions that have not registered themselves yet.
live_sessions() {
  local mine agents p_sid p_pid p_cwd p_name p_status common
  command -v claude >/dev/null 2>&1 || return 0
  mine="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 0
  agents="$(claude agents --json 2>/dev/null || true)"
  [[ -n "$agents" ]] || return 0
  while IFS=$'\t' read -r p_sid p_pid p_cwd p_name p_status; do
    [[ -n "$p_sid" && -d "$p_cwd" ]] || continue
    common="$(git -C "$p_cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    [[ "$common" == "$mine" ]] || continue
    printf '%s\t%s\t%s\t%s\t%s\n' "$p_sid" "$p_pid" "$p_cwd" "$p_name" "$p_status"
  done < <(jq -r '.[] | [.sessionId // "", (.pid // "" | tostring), .cwd // "",
                         .name // "", (.status // .state // .kind // "")] | @tsv' <<<"$agents")
}

# ── Commands ────────────────────────────────────────────────────────────────

cmd_peers() {
  need_jq
  local bus sid rows='' p_sid p_pid p_cwd p_name p_status claim branch task queued
  bus="$(bus_root)"
  sid="$(session_id)"

  while IFS=$'\t' read -r p_sid p_pid p_cwd p_name p_status; do
    [[ -n "$p_sid" && "$p_sid" != "$sid" ]] || continue
    claim="$(peer_file "$bus" "$p_sid")"
    branch='?'; task='(not announced)'
    if [[ -f "$claim" ]]; then
      branch="$(jq -r '.branch // "?"' "$claim" 2>/dev/null || echo '?')"
      task="$(jq -r 'if (.task // "") == "" then "(not announced)" else .task end' \
        "$claim" 2>/dev/null || echo '?')"
    fi
    queued="$(queued_count "$bus" "$p_sid")"
    rows+="$(printf '%-24s %-8s %-20s %-6s %s' \
      "${p_name:-${p_sid:0:8}}" "${p_status:-?}" "$branch" "$queued" "${task:0:60}")"$'\n'
  done < <(live_sessions)

  if [[ -z "$rows" ]]; then
    echo "No other live session is working in this repo."
    return 0
  fi
  printf '%-24s %-8s %-20s %-6s %s\n' SESSION STATUS BRANCH QUEUED TASK
  printf '%s' "$rows"
}

cmd_announce() {
  need_jq
  local task paths='' resources='' needs='' provides=''
  [[ $# -gt 0 ]] || die "announce needs a task description"
  task="$1"; shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --paths)     paths="${2:-}"; shift 2 ;;
      --resources) resources="${2:-}"; shift 2 ;;
      --needs)     needs="${2:-}"; shift 2 ;;
      --provides)  provides="${2:-}"; shift 2 ;;
      *) die "unknown flag: $1" ;;
    esac
  done
  [[ -n "$(session_id)" ]] || die "no session id (CLAUDE_CODE_SESSION_ID unset)"
  register "$task" "$paths" "$resources" "$needs" "$provides"
  log "announced on $(current_branch): $task"
}

# resolve_peer prints one session id for an identifier, or an error token.
# Matches a full session id, an 8-char prefix, a branch, or a worktree basename.
resolve_peer() {
  local bus="$1" want="$2" me="$3" file sid branch base hits=()
  for file in "$bus"/peers/*.json; do
    [[ -e "$file" ]] || continue
    sid="$(jq -r '.sessionId // ""' "$file" 2>/dev/null || true)"
    [[ -n "$sid" && "$sid" != "$me" ]] || continue
    branch="$(jq -r '.branch // ""' "$file" 2>/dev/null || true)"
    base="$(basename "$(jq -r '.worktree // ""' "$file" 2>/dev/null || true)")"
    if [[ "$want" == "$sid" || "$want" == "${sid:0:8}" || \
          ( -n "$branch" && "$want" == "$branch" ) || \
          ( -n "$base" && "$want" == "$base" ) ]]; then
      hits+=("$sid")
    fi
  done

  # A session that has not announced yet has no registry entry, but it is still
  # live and still addressable. Fall back to the process list.
  if [[ "${#hits[@]}" -eq 0 ]]; then
    local l_sid _l_pid l_cwd l_name _l_status
    while IFS=$'\t' read -r l_sid _l_pid l_cwd l_name _l_status; do
      [[ -n "$l_sid" && "$l_sid" != "$me" ]] || continue
      if [[ "$want" == "$l_sid" || "$want" == "${l_sid:0:8}" || \
            ( -n "$l_name" && "$want" == "$l_name" ) || \
            "$want" == "$(basename "$l_cwd")" ]]; then
        hits+=("$l_sid")
      fi
    done < <(live_sessions)
  fi

  case "${#hits[@]}" in
    0) printf 'NONE' ;;
    1) printf '%s' "${hits[0]}" ;;
    *) printf 'AMBIGUOUS %s' "${hits[*]}" ;;
  esac
}

cmd_send() {
  need_jq
  local target text kind='note'
  [[ $# -ge 2 ]] || die "send needs a peer and a message"
  target="$1"; text="$2"; shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --kind) kind="${2:-note}"; shift 2 ;;
      *) die "unknown flag: $1" ;;
    esac
  done

  local bus sid to id stamp
  bus="$(bus_root)"
  sid="$(session_id)"
  [[ -n "$sid" ]] || die "no session id (CLAUDE_CODE_SESSION_ID unset)"

  to="$(resolve_peer "$bus" "$target" "$sid")"
  case "$to" in
    NONE)          die "no peer matches '$target' — run: agent-bus.sh peers" ;;
    'AMBIGUOUS '*) die "'$target' matches several peers: ${to#AMBIGUOUS }" ;;
  esac

  stamp="$(now_ms)"
  id="$stamp-${sid:0:8}-$$"
  mkdir -p "$bus/inbox/$to/read" "$bus/outbox/$sid"
  jq -n --arg id "$id" --arg from "$sid" --arg branch "$(current_branch)" \
        --arg kind "$kind" --arg text "$text" --arg to "$to" --arg at "$stamp" \
    '{id: $id, from: $from, fromBranch: $branch, to: $to, kind: $kind,
      at: ($at | tonumber), text: $text}' \
    | tee "$bus/outbox/$sid/$id.json" > "$bus/inbox/$to/$id.json.tmp"
  mv -f "$bus/inbox/$to/$id.json.tmp" "$bus/inbox/$to/$id.json"
  log "sent to ${to:0:8} (kind: $kind, id: $id)"
}

# render_inbox prints queued messages; drain=1 moves them to read/ and writes an ack.
render_inbox() {
  local bus="$1" sid="$2" drain="$3" file id from label out=''
  [[ -d "$bus/inbox/$sid" ]] || return 0
  for file in "$bus/inbox/$sid"/*.json; do
    [[ -e "$file" ]] || continue
    id="$(jq -r '.id // ""' "$file" 2>/dev/null || true)"
    from="$(jq -r '.from // ""' "$file" 2>/dev/null || true)"
    label="$(jq -r '.branch // ""' "$(peer_file "$bus" "$from")" 2>/dev/null || true)"
    [[ -n "$label" ]] || label="${from:0:8}"
    out+="$(jq -r --arg label "$label" \
      '"[" + (.at / 1000 | strflocaltime("%H:%M:%S")) + "] from " + $label
       + " (" + (.kind // "note") + "): " + (.text // "")' "$file" 2>/dev/null || true)"$'\n'
    if [[ "$drain" == "1" ]]; then
      mkdir -p "$bus/inbox/$sid/read" "$bus/acks"
      # The ack is a receipt, not a message: it never wakes the sender.
      # Only the read time is stored. The id is the filename, and the reader is
      # always the inbox owner, so recording either would duplicate a known fact.
      jq -n --arg at "$(now_ms)" '{ackAt: ($at | tonumber)}' > "$bus/acks/$id.json"
      mv -f "$file" "$bus/inbox/$sid/read/"
    fi
  done
  printf '%s' "$out"
}

cmd_inbox() {
  need_jq
  local bus sid drain=0 out
  [[ "${1:-}" == "--drain" ]] && drain=1
  bus="$(bus_root)"
  sid="$(session_id)"
  [[ -n "$sid" ]] || die "no session id (CLAUDE_CODE_SESSION_ID unset)"
  mkdir -p "$bus/inbox/$sid/read"
  out="$(render_inbox "$bus" "$sid" "$drain")"
  if [[ -z "${out//[$'\n'[:space:]]/}" ]]; then echo "Inbox empty."; else printf '%s' "$out"; fi
}

cmd_sent() {
  need_jq
  local bus sid file id state read_at any=0
  bus="$(bus_root)"
  sid="$(session_id)"
  [[ -d "$bus/outbox/$sid" ]] || { echo "Nothing sent from this session."; return 0; }
  printf '%-8s %-10s %-10s %s\n' STATE TO READ TEXT
  for file in "$bus/outbox/$sid"/*.json; do
    [[ -e "$file" ]] || continue
    any=1
    id="$(jq -r '.id // ""' "$file")"
    state='UNREAD'
    read_at='-'
    if [[ -f "$bus/acks/$id.json" ]]; then
      state='read'
      read_at="$(jq -r 'if .ackAt then (.ackAt / 1000 | strflocaltime("%H:%M:%S")) else "-" end' \
        "$bus/acks/$id.json" 2>/dev/null || true)"
      [[ -n "$read_at" ]] || read_at='-'
    fi
    jq -r --arg state "$state" --arg read "$read_at" \
      '[$state, (.to[0:8]), $read, (.text | gsub("\n"; " ") | .[0:52])] | @tsv' "$file" \
      | while IFS=$'\t' read -r a b c d; do printf '%-8s %-10s %-10s %s\n' "$a" "$b" "$c" "$d"; done
  done
  [[ "$any" -eq 1 ]] || echo "Nothing sent from this session."
}

cmd_radar() {
  need_jq
  local bus base mine sid found=0
  bus="$(bus_root)"
  base="${1:-$(default_base)}"
  mine="$(current_branch)"
  sid="$(session_id)"
  [[ -n "$mine" ]] || die "detached HEAD — check out a branch first"

  printf 'base %s · this session on %s\n\n' "$base" "$mine"
  printf '%-24s %-8s %-10s %s\n' 'PEER BRANCH' OVERLAP MERGE 'SHARED PATHS'

  local p_sid p_pid p_branch _wt _task mb overlap count state
  while IFS=$'\t' read -r p_sid p_pid p_branch _wt _task; do
    [[ -n "$p_branch" && "$p_sid" != "$sid" ]] || continue
    alive "$p_pid" || continue
    git show-ref --verify --quiet "refs/heads/$p_branch" || continue
    found=1

    mb="$(git merge-base "$mine" "$p_branch" 2>/dev/null || true)"
    if [[ -z "$mb" ]]; then
      printf '%-24s %-8s %-10s %s\n' "$p_branch" '-' 'no-base' 'unrelated histories'
      continue
    fi
    overlap="$(comm -12 \
      <(git diff --name-only "$mb" "$mine" 2>/dev/null | sort) \
      <(git diff --name-only "$mb" "$p_branch" 2>/dev/null | sort) || true)"
    count="$(grep -c . <<<"$overlap" || true)"

    # merge-tree is pure prediction: it writes an object, never a ref or a file.
    if git merge-tree --write-tree --messages "$mine" "$p_branch" >/dev/null 2>&1; then
      state='clean'
    else
      state='CONFLICT'
    fi
    printf '%-24s %-8s %-10s %s\n' "$p_branch" "$count" "$state" \
      "$(tr '\n' ' ' <<<"$overlap" | cut -c1-52)"
  done < <(registry_rows)

  [[ "$found" -eq 1 ]] || printf '%s\n' '(no live peer branch to compare against)'

  # Claims cover work not yet committed, and resources git cannot see at all:
  # ports, database clusters, containers. A shared cluster is a real collision.
  local myfile shared_paths shared_res
  myfile="$(peer_file "$bus" "$sid")"
  [[ -f "$myfile" ]] || return 0
  printf '\nDeclared collisions (announced claims, not commits)\n'
  local hit=0
  while IFS=$'\t' read -r p_sid p_pid p_branch _wt _task; do
    [[ -n "$p_sid" && "$p_sid" != "$sid" ]] || continue
    alive "$p_pid" || continue
    shared_paths="$(jq -r -s '(.[0].paths // []) - ((.[0].paths // []) - (.[1].paths // [])) | join(" ")' \
      "$myfile" "$(peer_file "$bus" "$p_sid")" 2>/dev/null || true)"
    shared_res="$(jq -r -s '(.[0].resources // []) - ((.[0].resources // []) - (.[1].resources // [])) | join(" ")' \
      "$myfile" "$(peer_file "$bus" "$p_sid")" 2>/dev/null || true)"
    [[ -n "$shared_paths" ]] && { printf '  %-22s paths: %s\n' "${p_branch:-${p_sid:0:8}}" "$shared_paths"; hit=1; }
    [[ -n "$shared_res" ]] && { printf '  %-22s RESOURCES: %s\n' "${p_branch:-${p_sid:0:8}}" "$shared_res"; hit=1; }
  done < <(registry_rows)
  [[ "$hit" -eq 1 ]] || printf '  none\n'
}

cmd_sweep() {
  need_jq
  local bus file sid pid removed=0
  bus="$(bus_root)"
  for file in "$bus"/peers/*.json; do
    [[ -e "$file" ]] || continue
    sid="$(basename "$file" .json)"
    pid="$(jq -r '.pid // ""' "$file" 2>/dev/null || true)"
    if ! alive "$pid"; then
      rm -f "$file"
      rm -rf "${bus:?}/inbox/$sid" "${bus:?}/outbox/$sid" "${bus:?}/wake/$sid"
      removed=$((removed + 1))
    fi
  done
  log "swept $removed dead session(s)"
}

# ── Hook bodies ─────────────────────────────────────────────────────────────
#
# Hooks must never break a session. Every body runs in a subshell whose failure is
# swallowed, and each exits 0 with no output when this repo has no live peer.

# peer_summary prints one line per live peer, or nothing when alone.
peer_summary() {
  local bus sid p_sid p_pid p_branch _wt task out=''
  bus="$(bus_root_quiet)"
  [[ -n "$bus" && -d "$bus/peers" ]] || return 0
  sid="$(session_id)"
  while IFS=$'\t' read -r p_sid p_pid p_branch _wt task; do
    [[ -n "$p_sid" && "$p_sid" != "$sid" ]] || continue
    alive "$p_pid" || continue
    out+="- ${p_branch:-?} (session ${p_sid:0:8}) — ${task:-not announced}"$'\n'
  done < <(registry_rows)
  printf '%s' "$out"
}

# emit_context prints the hook JSON that injects text into the session.
emit_context() {
  jq -n --arg event "$1" --arg ctx "$2" \
    '{hookSpecificOutput: {hookEventName: $event, additionalContext: $ctx}}'
}

hook_session_start() {
  local peers msgs bus sid ctx=''
  register '' '' '' '' ''
  peers="$(peer_summary)"
  bus="$(bus_root_quiet)"; sid="$(session_id)"
  msgs=''
  [[ -n "$bus" && -n "$sid" ]] && msgs="$(render_inbox "$bus" "$sid" 1)"

  [[ -n "$peers" || -n "${msgs//[$'\n'[:space:]]/}" ]] || return 0
  if [[ -n "$peers" ]]; then
    # Command substitution stripped peer_summary's trailing newline; restore it.
    ctx+="Concurrent Claude Code sessions are working in this repository:"$'\n'"$peers"$'\n'
    ctx+="Coordinate before you rebase, fold or land. Read the parallel-sessions "
    ctx+="skill, then run \`agent-bus.sh radar\` and \`agent-bus.sh announce\`."$'\n'
  fi
  [[ -n "${msgs//[$'\n'[:space:]]/}" ]] && ctx+=$'\n'"Messages waiting for you:"$'\n'"$msgs"
  emit_context SessionStart "$ctx"
}

hook_user_prompt_submit() {
  local bus sid msgs
  bus="$(bus_root_quiet)"; sid="$(session_id)"
  [[ -n "$bus" && -n "$sid" ]] || return 0
  # A user prompt starts a fresh turn, so the ping-pong budget starts over.
  rm -f "$bus/wake/$sid"
  msgs="$(render_inbox "$bus" "$sid" 1)"
  [[ -n "${msgs//[$'\n'[:space:]]/}" ]] || return 0
  emit_context UserPromptSubmit \
    "Messages from concurrent sessions in this repo:"$'\n'"$msgs"
}

hook_stop() {
  local bus sid wakes msgs
  bus="$(bus_root_quiet)"; sid="$(session_id)"
  [[ -n "$bus" && -n "$sid" && -d "$bus/inbox/$sid" ]] || return 0

  wakes=0
  [[ -f "$bus/wake/$sid" ]] && wakes="$(cat "$bus/wake/$sid" 2>/dev/null || echo 0)"

  # Drain before deciding: messages are marked read even when the turn continues,
  # so the next Stop finds an empty inbox and the session can actually stop.
  msgs="$(render_inbox "$bus" "$sid" 1)"
  [[ -n "${msgs//[$'\n'[:space:]]/}" ]] || return 0

  if [[ "$wakes" -ge "$MAX_WAKES" ]]; then
    jq -n --arg m "$msgs" \
      '{systemMessage: ("agent-bus: wake budget spent; peer messages held:\n" + $m)}'
    return 0
  fi
  mkdir -p "$bus/wake"
  printf '%s' "$((wakes + 1))" > "$bus/wake/$sid"
  jq -n --arg m "$msgs" \
    '{decision: "block",
      reason: ("Messages from concurrent sessions working in this repository:\n" + $m
        + "\nAnswer each with `agent-bus.sh send <peer> <text>` before you finish. "
        + "If a message needs no answer, say so and stop.")}'
}

cmd_hook() {
  local event="${1:-}" payload sid cwd out=''
  command -v jq >/dev/null 2>&1 || return 0
  payload="$(cat)"
  # The payload carries session_id and cwd; the hook environment may not.
  sid="$(jq -r '.session_id // ""' <<<"$payload" 2>/dev/null || true)"
  cwd="$(jq -r '.cwd // ""' <<<"$payload" 2>/dev/null || true)"
  [[ -n "$sid" ]] && export AGENT_BUS_SESSION_ID="$sid"
  # A payload cwd that no longer exists must not make the hook act on whatever
  # directory it happens to have inherited.
  if [[ -n "$cwd" ]]; then
    [[ -d "$cwd" ]] || return 0
    cd "$cwd" || return 0
  fi

  case "$event" in
    session-start)      out="$(hook_session_start 2>/dev/null)" || out='' ;;
    user-prompt-submit) out="$(hook_user_prompt_submit 2>/dev/null)" || out='' ;;
    stop)               out="$(hook_stop 2>/dev/null)" || out='' ;;
    *) return 0 ;;
  esac
  [[ -n "$out" ]] && printf '%s\n' "$out"
  return 0
}

# ── Dispatch ────────────────────────────────────────────────────────────────

case "${1:-}" in
  peers)    shift; cmd_peers "$@" ;;
  announce) shift; cmd_announce "$@" ;;
  send)     shift; cmd_send "$@" ;;
  inbox)    shift; cmd_inbox "$@" ;;
  sent)     shift; cmd_sent "$@" ;;
  radar)    shift; cmd_radar "$@" ;;
  sweep)    shift; cmd_sweep "$@" ;;
  hook)     shift; cmd_hook "$@" ;;
  *)        awk '/^# Usage:/{f=1} f && /^#$/{exit} f' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
