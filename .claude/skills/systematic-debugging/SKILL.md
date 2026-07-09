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

Find the root cause before touching code. A fix that isn't grounded in an
understood cause is a guess — it may hide the symptom while leaving the bug in
place, or introduce a new one.

## Workflow

1. **Read the error completely.** Full stack trace, exact message, line
   numbers, file paths, exit codes. Don't skim past a warning that's actually
   telling you the answer.

2. **Reproduce it reliably.** Find the exact steps or command that triggers
   it every time (`go test ./... -run TestX`, `pnpm test -- path/to/spec`,
   `mvn test -Dtest=ClassName`). If it won't reproduce, don't start guessing
   fixes — gather more evidence first: run with `-v`/`--verbose`, add
   temporary logging, check whether it's flaky/timing-dependent, or try to
   narrow the triggering conditions.

3. **Check what changed recently.** `git log -p`, `git diff`, `git blame` on
   the affected lines. New or bumped dependencies (`go.mod`, `package.json`,
   `pom.xml`), config/env var changes, infra changes. The bug usually
   correlates with a recent change even if the symptom appears elsewhere.

4. **When a value crosses a boundary, log what enters and exits.** For a bug
   spanning a process, service, or layer boundary (API → service → database,
   CI → build → deploy, frontend → backend), add temporary logging at each hop
   and run once to see where good data becomes bad data. That pins down which
   component to investigate. Remove the temporary logging once you're done.

5. **Trace a bad value backward to its source.** When the error surfaces deep
   in a call stack, don't fix where it surfaces. Ask "what called this with
   this value?" and keep walking up (function → caller → caller's caller)
   until you find where the bad value was created or first went wrong. Fix
   there, not at the point where it finally blew up.

6. **Find a working example in the same codebase and diff against it.** If
   something similar works elsewhere (another handler, another component,
   another test), read it fully and list every difference between it and the
   broken code — configuration, dependencies, assumptions, order of
   operations. Don't assume a difference "can't matter" without checking.

7. **Form exactly one hypothesis.** State it explicitly: "I think X causes
   this because Y." If you can't state a specific cause, you don't understand
   the bug yet — go back to steps 1-6 instead of trying things. If several
   genuinely independent hypotheses survive and each needs its own deep
   investigation, dispatch them in parallel with
   [dispatching-parallel-agents](../dispatching-parallel-agents/SKILL.md)
   rather than testing them serially.

8. **Test the hypothesis with the smallest possible change.** One variable at
   a time. If it doesn't confirm the hypothesis, form a new one — don't stack
   a second change on top of the first while you're still unsure which one
   did anything.

9. **Capture the bug as a repeatable check, then fix it.** Where the bug is
   expressible as a test, write a failing test that reproduces it; otherwise
   re-run the original failing command as the check. Then apply the one fix
   that addresses the root cause. No bundled refactoring, no "while I'm here"
   changes.

10. **Verify:** run the failing test (now green) and the full suite
    (`make test`, `go test ./...`, `pnpm test`, `mvn test`) to confirm the fix
    works and nothing else broke.

## Constraints

- No fix without a stated root cause. "This might fix it" is not enough to act
  on — know why the bug happened before changing code.
- After ~3 failed fix attempts, stop trying variations. That pattern (each fix
  reveals a new problem somewhere else, or needs a bigger and bigger change)
  means the root cause isn't what you think it is, or the design itself is the
  problem. Re-read the evidence and question the approach — including the
  architecture — before attempting fix #4.
- One change at a time. Applying multiple candidate fixes together hides which
  one worked and blocks a clean revert.
- Match the effort to the bug, but keep the root-cause step even for a small
  one — it's cheap to run and a "simple" bug still has a cause worth naming.
- Remove temporary diagnostics once the root cause is found, unless a log line
  has lasting value (in which case make it a real log line, not a debug print).
- If it stays unreproducible or environmental after real investigation, say so
  explicitly, document what was checked, and handle it deliberately (retry
  logic, better error message, monitoring) rather than quietly patching around
  it and calling it fixed.

## Quality

- Before presenting results, run the shared [self-review checklist](../quality.md). Surface issues in the chat only if found.
