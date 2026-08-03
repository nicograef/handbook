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

Find the root cause before touching code. An ungrounded fix is a guess. It may hide the symptom or introduce a new bug.

## Workflow

1. **Read the error completely.**
   - Full stack trace, exact message, line numbers, file paths, exit codes.
   - Don't skim past a warning — it may already tell you the answer.

2. **Reproduce it reliably.**
   - Find the exact steps or command that triggers it every time.
   - Examples: `go test ./... -run TestX`, `pnpm test -- path/to/spec`, `mvn test -Dtest=ClassName`.
   - Won't reproduce? Gather more evidence before guessing fixes.
   - Run with `-v`/`--verbose`, add temporary logging, check whether it's flaky/timing-dependent, or narrow the triggering conditions.

3. **Check what changed recently.**
   - Tools: `git log -p`, `git diff`, `git blame` on the affected lines.
   - Check new or bumped dependencies (`go.mod`, `package.json`, `pom.xml`).
   - Check config/env var changes and infra changes.
   - The bug usually correlates with a recent change, even if the symptom appears elsewhere.

4. **When a value crosses a boundary, log what enters and exits.**
   - Applies to process, service, or layer boundaries: API → service → database, CI → build → deploy, frontend → backend.
   - Add temporary logging at each hop.
   - Run once to see where good data becomes bad data.
   - That pins down which component to investigate.
   - Remove the temporary logging once done.

5. **Trace a bad value backward to its source.**
   - Don't fix where a deep call-stack error surfaces.
   - Ask "what called this with this value?" and walk up: function → caller → caller's caller.
   - Find where the bad value was created or first went wrong.
   - Fix there, not where it finally blew up.

6. **Find a working example in the same codebase and diff against it.**
   - Look for something similar that works: another handler, component, or test.
   - Read it fully; list every difference from the broken code.
   - Differences include configuration, dependencies, assumptions, order of operations.
   - Don't assume a difference "can't matter" without checking.

7. **Form exactly one hypothesis.**
   - State it explicitly: "I think X causes this because Y."
   - Can't state a specific cause? Go back to steps 1-6 instead of trying things.
   - Several independent hypotheses, each needing deep investigation? Dispatch them in parallel with [dispatching-parallel-agents](../dispatching-parallel-agents/SKILL.md).

8. **Test the hypothesis with the smallest possible change.**
   - One variable at a time.
   - Doesn't confirm the hypothesis? Form a new one.
   - Don't stack a second change while unsure which one worked.

9. **Capture the bug as a repeatable check, then fix it.**
   - Expressible as a test? Write a failing test that reproduces it.
   - Otherwise, re-run the original failing command as the check.
   - Apply the one fix that addresses the root cause.
   - No bundled refactoring, no "while I'm here" changes.

10. **Verify.**
    - Run the failing test — confirm it's now green.
    - Run the full suite: `make test`, `go test ./...`, `pnpm test`, `mvn test`.
    - Confirm the fix works and nothing else broke.

## Constraints

- No fix without a stated root cause.
  - "This might fix it" isn't enough — know why the bug happened first.
- After ~3 failed fix attempts, stop trying variations.
  - Pattern: each fix reveals a new problem, or needs a bigger change.
  - That means the root cause is wrong, or the design itself is the problem.
  - Re-read the evidence and question the approach, including the architecture, before fix #4.
- One change at a time.
  - Multiple candidate fixes together hide which one worked.
  - They also block a clean revert.
- Match effort to the bug.
  - Keep the root-cause step even for small ones — it's cheap to run.
  - A "simple" bug still has a cause worth naming.
- Remove temporary diagnostics once the root cause is found.
  - Unless a log line has lasting value — then make it a real log line, not a debug print.
- If it stays unreproducible or environmental after real investigation, say so explicitly.
  - Document what was checked.
  - Handle it deliberately: retry logic, better error message, or monitoring.
  - Don't quietly patch around it and call it fixed.

## Quality

- Before presenting results, run the shared [self-review checklist](../quality.md). Surface issues in the chat only if found.
