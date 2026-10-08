---
name: prog
description: Critically re-verifies every item, status, blocker and verdict of the session, rewrites all state files to match, prunes stale state, reports, then runs /decide. "close" adds the close sweep and verdict; "compact" a resume prompt.
argument-hint: "[close] [compact] [all] [dry-run]"
allowed-tools: Bash(git *), Bash(gh pr *), Bash(repo-status), Bash(~/.claude/agent-bus.sh *), Read, Grep, Glob, Edit, Write
---

# Prog

Arguments: `$ARGUMENTS`. Every finding is applied without asking; open questions go to `/decide` at the end. Output is tables and lists, no prose.

- Never delete uncommitted work, unpushed commits, stashes or a dirty worktree. Git's own refusals are the guard; never force them.
- Skip every branch and worktree that this session or a live peer holds. `~/.claude/agent-bus.sh peers` lists the peers.
- Under `~/.claude`, delete only memory files the review flagged. Aged harness state belongs to the harness and its retention setting.
- Hard deletion, no trash. `dry-run` lists every deletion and applies none.
- Without `close`, running jobs keep running.

Scope: the current project and repo. `all` adds every project's memory and every repo under `~/r`, one `opus` subagent per project with a repo. Projects without a repo get the memory index checks only.

## 1. Verify

Recall and earlier verdicts are claims, not evidence. Review the whole session, then establish the status quo from sources. Sources: git log, status, branches and worktrees, PRs, scheduled jobs, background tasks, agents, shells, workflows, check and test results.

Check every item at every level: programme, wave, lane, plan, phase, acceptance criterion, workflow, task. Per item:

| Claim | Holds only when |
| --- | --- |
| Done, ticked | Its commit is on the stated branch and its check passes on the current tree |
| Progress | The count matches the items actually done |
| Blocked | The blocker reproduces now; re-run the failing command or re-read the target |
| Depends on | The dependency is real, named and ordered; an open dependency keeps the item blocked |
| Verdict | Review, test, landing or close verdicts re-checked against the current tree; one on an older commit is stale |

A claim that fails becomes the verified state: done without evidence is open, a vanished blocker unblocks.

## 2. Rewrite

Hold every state file against the verified state. That covers the scratchpad, memory and `MEMORY.md`, plan, programme and PRD files, run state and lead notes. Rewrite each to current decisions and verified state, and delete rows that are false, done elsewhere or superseded. A file then reads as if written now; no history.

Open steps and decisions land in the plan file, durable facts in memory. Nothing lives only in the scratchpad. Commit repo files per the repo's conventions.

## 3. Prune

Content, not age. Every finding carries target, cited evidence and its action: delete, or update with the new text.

| Class | Finding |
| --- | --- |
| Memory | Index and files out of sync, duplicates, dead references. Claims the repo contradicts: partly true becomes an update. Events stored as memories, rewritten per the [memory rule of the global CLAUDE.md](../../../claude/CLAUDE.md#models-and-subagents) |
| Rule | Contradicted by the repo, names deleted files or tools, duplicates another surface, pins a stale version. Current repo only; edit per rule |
| Scratchpad | Other sessions' leftover directories. In this session, only files the agent wrote |
| Plan, PRD | Every box ticked, or the PRD shipped. One commit for all |
| Branch | Merged into the default branch, or squash-merged with the merged PR as evidence. Remote copies too |
| Worktree | Clean, and its branch qualifies as a branch finding |

Also sweep what is regenerable or already dead:

- Git: stale worktree entries, remote-tracking refs of deleted remote branches.
- Agent bus: registrations of dead sessions (`agent-bus.sh sweep`).
- This session: loops, monitors, shells, workflows and agents that already finished.

A memory deletion removes the file and its index line together.

## 4. Close

Only with `close`. The scratchpad does not survive it.

- Docker, machine-wide: dangling images, dangling build cache, unused networks.
- Docker review, cited per item: stopped containers with image, compose project and exit age.
- Unused volumes with project and size. Named volumes often hold databases; say so.
- Tagged images that no container uses, with size.
- Durable crons whose work is done.
- Every job of this session. Recall misses ids from before a compaction, and `ListAgents` shows a finished agent as `completed` while the UI still holds it. Enumerate the session's task directory (`/tmp/claude-<uid>/<project>/<session-id>/tasks/`) and `TaskStop` every id, subagents included. "No task found" means it already ended.
- Temp files this session or its agents wrote under `/tmp`, named by the run's prefix.

The session may close when all of these hold:

- No repo in scope holds uncommitted, unpushed or stashed work (`repo-status`), or only work the user chose to keep.
- No job of this session is still running.
- Plan files and memory hold every open step and durable fact.

## 5. Blocked actions

Every action the harness or a permission rule blocked goes to the user, never worked around. Give each as a `! <command>` line; `sudo` goes in a bash block for a separate terminal. Re-check every target once the user ran them, and update the verdict.

## 6. Compact

Only with `compact`. Write the verified state, the plan file path, worktree paths and open tasks to the scratchpad. Tell the user `/compact` is safe to run. Give a short prompt to paste afterwards: scratchpad file, plan and next step.

## Report

1. Corrections: one bullet per claim the verification changed, with file, old claim and verified state.
2. Items: one row per item at every level, with status (done, open, or blocked by what) and evidence.
3. Running: subagents, workflows, background shells and monitors.
4. Prune and sweep: one bullet per finding, marked applied or blocked; space freed per sweep target.
5. Blocked: the `! <command>` lines and the bash block.
6. With `close`: "Safe to close", or "Not yet" with each blocking item.

## Decide

Then invoke the [decide](../decide/SKILL.md) skill on every decision or question the work needs from the user. The report lists none of them; `/decide` asks and records them.
