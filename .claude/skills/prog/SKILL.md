---
name: prog
description: Summarises this session's state as a table and first rewrites every state file to match the verified status quo. Lists steps done, open and blocked, plus owed decisions. With "compact", also writes a resume prompt for after /compact.
argument-hint: "[compact]"
allowed-tools: Bash(git *), Read, Grep, Glob, Edit, Write
---

# Prog

Arguments: `$ARGUMENTS`. Structured output only: tables and lists, no prose.

1. Establish the status quo from sources, not from recall. Sources: git log, status and worktrees, scheduled jobs, background tasks, live agents and shells, check results.
2. Hold every state file against it. That covers memory and `MEMORY.md`, the scratchpad, plan and programme files, run state, PRDs and lead notes.
3. Rewrite each file to current decisions and verified state. Delete rows that are false, done elsewhere or superseded. A file then reads as if written now; no history.
4. List every step or phase of the current plan, skill run or workflow. Status per row: done, open, or blocked and by what.
5. List every decision or question the user has to answer for the work to continue.
6. List running subagents, workflows, background shells and monitors.
7. List every action the harness or a permission rule blocked. Give each as a `! <command>` line; `sudo` goes in a bash block for a separate terminal. Re-check the targets once the user ran them.

With `compact`, also:

8. Write the state above, the plan file path, worktree paths and open tasks to the scratchpad.
9. Tell the user `/compact` is safe to run. Give them a short prompt to paste afterwards. It names the scratchpad file, the plan and the next step.
