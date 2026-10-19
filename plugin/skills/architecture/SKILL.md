---
name: architecture
description: "Reviews and fixes a codebase's architecture through a multi-expert Workflow: boundaries, cross-layer consistency, modularity, SOLID and test design. Triggers: architecture, architecture review, test review."
argument-hint: "[area ...]"
---

# Architecture

Arguments: `$ARGUMENTS`, the areas in scope; none means the whole codebase. Refactors keep behaviour identical. Bugs found along the way get fixed in the same run. Dead and stale code belongs to `/nico:cleanup`; readability and slop to `/simplify`.

## Workflow

- Enable ultracode and use workflows.
- Sweep the codebase and split it into areas or modules that reviewers work on in parallel.
- Run as many `opus` reviewers over as many areas as the codebase warrants. Each reads this file for the criteria.
- Run `sonnet` verifiers and refuters on the findings; only confirmed findings reach a fixer.
- Run `sonnet` fixers and implementers on the confirmed findings.
- Keep the workflows lean and efficient.
  - Bundle reviews, tests and gates on the main branch or a common base branch.
  - One branch or one worktree may hold all of it.
  - Choose the codebase split accordingly.

## Review lenses

- Clean Architecture: the boundary rules below
- Clean Code; readability and understandability
- Modularity, cohesion and coupling
- KISS, YAGNI, overengineering and simplifications
- SOLID principles
- Testability, test isolation, test efficiency and test simplicity: the test tags below

| Rule | Look for |
| --- | --- |
| Boundaries | Domain code importing ORM, HTTP or framework types; infrastructure built inside domain functions; repositories returning rows instead of domain objects; external DTOs and SDK enums reaching domain code; modules reaching into another module's tables or internals |
| Cross-layer | Trace 3–5 representative flows per feature area: frontend call → API client → handler → service → repository → SQL. Shapes, nullability, validation limits and enum values must agree at every hop; name the layer that is the source of truth |

## Test tags

Test files get one tag per test. The first matching row wins:

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

## Findings

Each finding anchors to exact lines, or it is dropped:

```
**[What]** (lens → rule)
File: path/to/file.ts:42-58
Why: <one sentence>
Suggestion: <minimal concrete change>
Effort: S | M | L
```

## Fix

- Make the minimal change the finding describes. Add no comments, abstractions or error handling.
- Leave patterns that look like slop but are the project's own idiom.
- Test findings apply per file: Merge, then Refactor, then Delete. A suite failure restores the test.
- A bug fix starts with a regression test that fails before the fix.
- Compile, lint and run the full suite once per bundle, not per finding.
- Report every L finding left unapplied, with its anchor, for the user to schedule.
