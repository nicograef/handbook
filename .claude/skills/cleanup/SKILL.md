---
name: cleanup
description: Reviews a diff or area for readability, AI slop, principles, architecture and cross-layer consistency, tags each test Keep/Refactor/Delete/Merge, and checks mobile UX. Applies only picked findings. Triggers: cleanup, deslop, test review, ux review.
argument-hint: "[paths | staged | last-commit | repo | ux]"
---

# Cleanup

Arguments: `$ARGUMENTS`. Report first, change nothing until the user picks. Behaviour stays identical before and after every applied fix.

## Scope

Named files or area, else staged changes, else unstaged, else the last commit, else ask. Before flagging anything, read the full files around a diff and the neighbouring code outside the change. `repo` widens to the codebase, reports without applying, and adds a cross-layer trace over 3–5 representative flows per feature area. `ux` runs the UX pass instead.

## Passes

| Pass | Look for |
| --- | --- |
| Readability | Names that describe implementation instead of the concept, inconsistent names for one concept, clever code, deep nesting where a guard clause would flatten it |
| Prose slop | Docs, comments and commit text that read machine-written: puffery, filler, trailing "ensuring that…" phrases, synonym cycling, collaborative residue ("as requested…"), comments narrating the line below |
| Doc residue | Markdown files that record a session (summary, report, notes, walkthrough), docs restating the code or a commit, docstrings repeating a typed signature. Suggest deletion, not rewording |
| Code slop | Defensive checks on values just constructed, type escape hatches (`as any`, `interface{}`, `@ts-ignore` without reason), single-use wrappers and one-implementation interfaces, config values that restate the tool default, template boilerplate the project does not use |
| Principles | Knowledge duplication (not coincidental similarity), speculative extension points, functions with several reasons to change. Calibrate: 2–3 branches are fine; test setup repetition is fine |
| Architecture | Domain code importing ORM, HTTP or framework types; infrastructure built inside domain functions; repositories returning rows instead of domain objects; external DTOs and SDK enums reaching domain code; modules reaching into another module's tables or internals |
| Cross-layer (`repo` only) | Trace frontend call → API client → handler → service → repository → SQL. Shapes, nullability, validation limits and enum values must agree at every hop; name the layer that is the source of truth |
| UX (`ux` only) | At 375×667 (Playwright if the app runs, else a static review labelled so): components that break, tables without a mobile fallback, touch targets under 44×44 px, primary action below the fold, one concept labelled two ways, inconsistent loading/empty/error states, labels diverging from the repo's glossary, else `docs/UBIQUITOUS_LANGUAGE.md` |

## Tests

Test files get the readability pass and one tag per test. The first matching row wins:

| Signal | Tag |
| --- | --- |
| No meaningful assertion, or asserts only on values the test itself set up | Delete |
| Reaches private methods or fields | Delete; a public-API test replaces it if the behaviour matters |
| Asserts internal call counts, argument order or mock invocations | Delete, or Refactor to assert on output |
| Mocks internal collaborators, or verifies state by bypassing the public interface (raw SQL, file reads) | Refactor |
| Named for how ("calls X", "sets flag") rather than what | Refactor |
| Same behaviour as two or more other tests with trivially different inputs | Merge into one table-driven test |
| Asserts exact error strings | Refactor |
| Otherwise | Keep, unreported |

A Merge finding names its target. A Delete that removes a behaviour's only coverage says so.

## Report

Re-read every flagged location; drop anything that does not anchor to exact lines or does not hold on re-read. Group by file, ordered: boundary and consistency risks, readability wins, principle violations, structural suggestions. One entry per finding:

```
**[What]** (pass → rule)
File: path/to/file.ts:42-58
Why: <one sentence>
Suggestion: <minimal concrete change>
Effort: S | M | L
```

Close with up to five most impactful changes across all files, then ask which to apply. Zero findings is one line.

## Apply

Make the minimal change described per finding. Compile or lint the touched files once, after the last finding. Test findings apply per file: Merge, then Refactor, then Delete. Then the full suite runs; a failure restores the test. Flag a large refactor for the user to schedule instead of doing it. Add no comments, abstractions or error handling; the goal is less noise. Leave patterns that look like slop but are the project's own idiom.
