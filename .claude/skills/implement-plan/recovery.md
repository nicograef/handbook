# Recovery

How a session picks a run back up, and what it must leave behind when it stops.

- [Start here, every time](#start-here-every-time)
- [The worktree state scan](#the-worktree-state-scan)
- [The log outranks the checkbox](#the-log-outranks-the-checkbox)
- [Half-finished operations](#half-finished-operations)
- [The Run state block](#the-run-state-block)
- [Failure taxonomy](#failure-taxonomy)
- [What does not exist](#what-does-not-exist)

## Start here, every time

```bash
git worktree list --porcelain                                     # 1. find the run's worktrees
# 2. state-scan loop (below)
awk '/^## Phase /{p=$0} /^- \[ \]/{print p" -> "$0; exit}' <plan>  # 3. first unmet criterion
git log --oneline --all --grep='Plan: <slug> phase'               # 4. what was actually committed
```

- Read the plan **inside the run worktree**, including its `## Run state` block.
- The copy on the base branch is stale by design during a run.
- If the run worktree is gone, fall back to `git branch --list 'plan/*'` plus
  the same `git log --grep`.
- Branches, not worktrees, are the durable artifact.

## The worktree state scan

Runs from anywhere:

```bash
git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r w; do
  [ -d "$w" ] || { echo "$w MISSING"; continue; }
  gd=$(git -C "$w" rev-parse --path-format=absolute --git-dir) || continue
  s=""
  [ -d "$gd/rebase-merge" ]     && s="$s rebase"
  [ -d "$gd/rebase-apply" ]     && s="$s rebase-apply"
  [ -f "$gd/MERGE_HEAD" ]       && s="$s merge"
  [ -f "$gd/CHERRY_PICK_HEAD" ] && s="$s cherry-pick"
  [ -f "$gd/index.lock" ]       && s="$s INDEX_LOCK"
  printf '%s\tstate:%s\tdirty:%s\n' "$w" "${s:-clean}" "$(git -C "$w" status --porcelain | wc -l)"
done
```

## The log outranks the checkbox

- A `- [x]` with no matching commit is wrong: untick it.
- A commit with no tick gets its criterion re-verified, then ticked.
- Never trust a tick you did not place this session
  ([quality.md](../quality.md)).

Two limits on this:

- The log is authoritative **only where the trailer is present**.
- A worker that skipped the trailer produces durable but unattributable work.
- The fallback is reading the commit range on that phase's branch.

## Half-finished operations

- Before deciding anything, read `$GD/rebase-merge/head-name`, `onto`,
  `orig-head` (the undo point) and `msgnum`/`end`.
- Mid-rebase the branch name is *not* in HEAD; status reports detached.
- Continue or abort only from the owning worktree.
- Stale or moved worktrees: `git worktree prune --dry-run --verbose` before
  `prune`.
- `git worktree repair <path>` when the directory moved.
- Pruning does not delete the branch.
- For ref or object damage: `git fsck --no-progress`.

## The Run state block

A stop leaves a `## Run state` section in the plan file. Commit it to
`plan/<slug>`; delete it in its own commit before landing.

| Field | Value shape |
| --- | --- |
| `Base` | `<base-branch> <40-hex pinned sha>` |
| `Run branch` | `plan/<slug>` |
| `Worktrees` | one row per member: `<absolute worktree path> -> <branch> -> phase <N>` |
| `Next criterion` | `phase <N> criterion <M>` — the next unticked one |
| `Verify` | the verify command, verbatim |
| `Workflow` | `scriptPath=<absolute path>` and `runId=<id>` |
| `Failure` | the verbatim failure string; omit the field unless the run died |

- No wall-clock call is needed — `git log -1 --format=%cI` gives the time.

## Failure taxonomy

| String | Response |
| --- | --- |
| `You've hit your session limit · resets <time>` / weekly limit | Stop, commit the handoff, name the reset time. Both windows are shared across models — switching model does not help. |
| `You've hit your Opus limit · resets <time>` | The one limit `/model` escapes; a `sonnet`-eligible mechanical phase may continue, an implementation phase may not. |
| `Agent terminated early due to an API error: …` | That `agent()` returned `null`. Its committed work survives on its branch. Re-dispatch it told to continue from its last commit. |
| `API Error: Server is temporarily limiting requests (not your usage limit)` / 529 overloaded | The harness already retried with backoff before you saw this. Check `https://status.claude.com`, stop, hand off. |
| `API Error: Server error mid-response. The response above may be incomplete.` | Never retried by design. Re-run that phase from its last commit. |

- A user action, not skill behaviour: setting `CLAUDE_CODE_RETRY_WATCHDOG=1` in
  the environment before an unattended run.
- It retries capacity 429s and 529s indefinitely.
- It is documented for capacity errors only.
- Whether it waits out a plan usage-limit window is unverified.
- Do not run a plan assuming it does.

## What does not exist

- **No sleep-until-reset.** The reset epoch reaches only a status-line shell
  command, and workflow scripts cannot read a clock at all.
- **Scheduled tasks and `/loop` fire only while the session is running *and*
  idle**, with no catch-up for missed fires.
- **Cross-session workflow resume is not promised by the docs.** A new session
  resumes from git.
- **`StopFailure` fires only after retries are exhausted** and cannot block.
- **`/rewind` checkpoints do not restore subagent or Bash-made edits** — git
  does.
