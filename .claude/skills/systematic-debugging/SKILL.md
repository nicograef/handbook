---
name: systematic-debugging
description: >-
  Investigates a bug, test failure, or unexpected behavior root-cause-first
  before proposing a fix. Use when a test fails, an error shows up in logs or
  CI, or something behaves unexpectedly and the next step would otherwise be
  guessing at a patch.
---

# Systematic Debugging

_Adapted from the MIT-licensed [superpowers](https://github.com/obra/superpowers) plugin._

## Constraints

- No fix without a stated root cause.
  - "This might fix it" isn't enough — know why the bug happened first.
- Won't reproduce? Gather more evidence before guessing fixes: run with `-v`/`--verbose`, add temporary logging, or narrow the triggering conditions.
- When a value crosses a process, service, or layer boundary, log what enters and exits at that hop.
  - Boundaries include API → service → database, CI → build → deploy, and frontend → backend.
- After ~3 failed fix attempts, stop trying variations.
  - Pattern: each fix reveals a new problem, or needs a bigger change.
  - That means the root cause is wrong, or the design itself is the problem.
  - Re-read the evidence and question the approach, including the architecture, before fix #4.
- One change at a time — multiple candidate fixes together hide which one worked, and block a clean revert.
- Match effort to the bug.
  - Keep the root-cause step even for small ones — it's cheap to run.
  - A "simple" bug still has a cause worth naming.
- Remove temporary diagnostics once the root cause is found.
  - Unless a log line has lasting value — then make it a real log line, not a debug print.
- If it stays unreproducible or environmental after real investigation, say so explicitly.
  - Document what was checked.
  - Handle it deliberately: retry logic, better error message, or monitoring.
  - Don't quietly patch around it and call it fixed.
- Several independent hypotheses, each needing deep investigation? Dispatch them in parallel with [dispatching-parallel-agents](../dispatching-parallel-agents/SKILL.md).

## Quality

- Run the shared [self-review checklist](../quality.md).
