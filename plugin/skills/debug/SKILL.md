---
name: debug
description: "Finds and fixes a root cause through a reproducing command and ranked hypotheses. Triggers: hard bug, flaky test, regression, \"why does X fail\"."
argument-hint: "<symptom, failing command or error>"
---

# Debug

Arguments: `$ARGUMENTS`: the symptom, a failing command or a pasted error.

## Gotchas

- No fix before a repro. A fix that was never red proves nothing.
- Two failed fixes mean the model of the bug is wrong. Question the design before a third patch.
- Temporary debug output carries one unique prefix, such as `DBG-<slug>:`. Grep it out before committing.

## Loop

1. Build one fast, deterministic command that shows the exact symptom and can go red. A flaky bug gets a seed, a loop count or a pinned clock until it fails on demand.
2. Shrink the repro: drop input, steps and dependencies while it stays red.
3. Rank 3–5 falsifiable hypotheses by likelihood and cost to test. Each names the observation that would refute it.
4. Test one hypothesis with one change at a time. Revert a change that refuted its hypothesis.
5. Name the root cause, then fix it there, not where the symptom surfaced.
6. The repro becomes the regression test, red before the fix and green after.

## No seam

A bug no test can reach without a running system is an architecture finding. Report it with the repro command and the missing seam.
