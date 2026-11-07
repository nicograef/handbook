---
name: prog
description: Critically re-verifies every item, status, blocker and verdict of the session, rewrites all state files to match, prunes stale state, reports, then runs /nico:decide. "close" adds the close sweep and verdict; "compact" a resume prompt.
argument-hint: "[close] [compact] [all] [dry-run]"
allowed-tools: Bash(git *), Bash(gh pr *), Bash(repo-status), Bash(~/.claude/agent-bus.sh *), Read, Grep, Glob, Edit, Write
---

# Prog

Arguments: `$ARGUMENTS`. Apply every finding without asking; questions wait for `/nico:decide` at the end.

- Never delete uncommitted work, unpushed commits, stashes or a dirty worktree. Never force past a git refusal.
- Skip branches and worktrees this session or a live peer holds; `~/.claude/agent-bus.sh peers` lists peers.
- Under `~/.claude`, delete only memory files the review flagged. Harness state ages out by its own retention.
- Deletion is hard. `dry-run` lists every deletion and applies none.
- Without `close`, running jobs keep running.
- An action the harness or a permission rule blocks goes to the user, never around it.

Scope is the current project and repo. `all` adds every project's memory and every repo under `~/r`, one `opus` subagent per project with a repo.

## Steps

1. Verify. Recall and earlier verdicts are claims, not evidence. Check every item at every level against git, PRs, jobs, agents and a fresh check run. A failed claim becomes the verified state.
2. Check all shells and workflows. What is slowing the session down? How can we make the release cut and everything else faster and leaner? Anything ready to be cleaned and pruned yet?
3. Critically verify the progress and state of all shells, monitors, agents and workflows. Is any idle, stuck or outdated and to be removed?
4. Rewrite every state file to the verified state: scratchpad, memory and `MEMORY.md`, plan, programme and PRD files, run state, lead notes. Open steps go to the plan file, durable facts to memory.
5. Prune by content, not age: memory, rules, other sessions' scratchpad leftovers, fully ticked plans, shipped PRDs. Also merged or squash-merged branches with their remotes and clean worktrees. A memory deletion removes its index line too.
6. Sweep stale worktree entries, dead remote-tracking refs, dead bus sessions (`agent-bus.sh sweep`) and this session's finished jobs.
7. With `close`: additionally, run the close sweep below.
8. With `compact`: additionally, write verified state, plan path, worktree paths and open tasks to the scratchpad. Say `/compact` is safe and give a short resume prompt.
9. Report corrections, item status with evidence, running jobs, prune results, blocked commands and the close verdict.
10. Invoke the [decide](../decide/SKILL.md) skill on every question the work needs from the user.

## Close

- Docker: prune dangling images, build cache and unused networks. List stopped containers, unused volumes and unused tagged images in the report. Named volumes often hold databases.
- Stop every job of this session, subagents included. Recall misses ids from before a compaction. Enumerate `/tmp/claude-<uid>/<project>/<session-id>/tasks/` and `TaskStop` each id.
  Workflow ids too, completion notice or not. Only "No task found" or a completed status counts as stopped; a paused or refused task is a blocked action, ended by the exit dialog's "stop tasks".
- Delete durable crons whose work is done, and this run's temp files under `/tmp`.
- "Safe to close" needs a clean `repo-status`, no running job, and every open step in plan files or memory.

## Blocked actions

Give each blocked action as a `! <command>` line. `sudo` goes in a bash block for a separate terminal. Re-check each target after the user ran them.
