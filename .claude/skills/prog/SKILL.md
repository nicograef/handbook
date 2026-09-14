---
name: prog
description: Summarises this session's state as a table: steps and phases done, open, blocked, plus every decision or question the user still owes. With "compact", also persists state to the scratchpad and memory and writes a resume prompt for after /compact.
argument-hint: "[compact]"
allowed-tools: Bash, Read, Grep, Glob
---

# Prog

Arguments: `$ARGUMENTS`. Structured output only: tables and lists, no prose.

1. List every step or phase of the current plan, skill run or workflow. Status per row: done, open, or blocked and by what.
2. List every decision or question the user has to answer for the work to continue.
3. List running subagents, workflows, background shells and monitors.

With `compact`, also:

4. Write the state above, the plan file path, worktree paths and open tasks to the scratchpad. Update the plan file and memory where they lag.
5. Tell the user `/compact` is safe to run. Give them a short prompt to paste afterwards. It names the scratchpad file, the plan and the next step.
