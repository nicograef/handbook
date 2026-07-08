---
name: systematic-debugging
description: >-
  Investigates a bug, test failure, or unexpected behavior root-cause-first
  before proposing a fix. Use when a test fails, an error shows up in logs or
  CI, or something behaves unexpectedly and the next step would otherwise be
  guessing at a patch.
---

# Systematic Debugging

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

4. **In multi-component systems, add temporary logging at each boundary.**
   For anything crossing a process, service, or layer boundary (API → service
   → database, CI → build → deploy, frontend → backend), log what enters and
   exits each component before guessing which one is at fault:

   ```bash
   # Layer 1: what does the request contain when it hits the handler?
   # Layer 2: what does the service pass to the repository?
   # Layer 3: what does the query actually receive/return?
   ```

   Run once, read the output, and see exactly where good data becomes bad
   data. That tells you which component to investigate — remove the temporary
   logging once you're done.

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
   the bug yet — go back to steps 1-6 instead of trying things.

8. **Test the hypothesis with the smallest possible change.** One variable at
   a time. If it doesn't confirm the hypothesis, form a new one — don't stack
   a second change on top of the first while you're still unsure which one
   did anything.

9. **Write a failing test that reproduces the bug**, then apply the one fix
   that addresses the root cause. No bundled refactoring, no "while I'm here"
   changes.

10. **Verify:** run the failing test (now green) and the full suite
    (`make test`, `go test ./...`, `pnpm test`, `mvn test`) to confirm the fix
    works and nothing else broke.

## Constraints

- **No fix without a stated root cause.** "This might fix it" is not enough
  to act on — know why the bug happened before changing code.
- **After ~3 failed fix attempts, stop trying variations.** That pattern
  (each fix reveals a new problem somewhere else, or needs a bigger and
  bigger change) means the root cause isn't what you think it is, or the
  design itself is the problem. Stop, re-read the evidence, and question the
  approach — including the architecture — before attempting fix #4.
- **One change at a time.** Never apply multiple candidate fixes together —
  you won't know which one worked, and you can't cleanly revert.
- **Don't skip the process because the bug "looks simple."** Simple bugs have
  root causes too, and the process is cheap to run.
- **Remove temporary diagnostics.** Debug logging added to trace a boundary
  or a backward trace comes out again once the root cause is found, unless it
  has lasting value (in which case make it a real log line, not a debug
  print).
- **If it stays unreproducible or environmental after real investigation,**
  say so explicitly, document what was checked, and handle it deliberately
  (retry logic, better error message, monitoring) — don't quietly patch
  around it and call it fixed.

## Quality

- Before presenting results, run the shared [self-review checklist](../quality.md). Surface issues in the chat only if found.
- After task completion, propose a conventional commit message plus a short human-readable summary of what changed, why, and what the reviewer should focus on.
