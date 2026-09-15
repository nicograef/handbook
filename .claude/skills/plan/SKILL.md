---
name: plan
description: Writes a phased implementation plan (docs/plans/plan-<slug>.md) from a task or PRD, or a PRD (docs/prds/prd-<name>.md) from a problem description. Use to plan a feature, break down a PRD, write a PRD, or when the user mentions tracer bullets.
argument-hint: "[prd] <task, PRD path, or problem description>"
---

# Plan

Arguments: `$ARGUMENTS`. Output is a file, never code. `/plan <task or PRD path>` writes `docs/plans/plan-<slug>.md`; `/plan prd <problem>` writes `docs/prds/prd-<name>.md`.

## Rules the templates depend on

- Every phase carries a `**Depends on**` line. Only phases without one are candidates for implement-plan's concurrency test.
- Reference code as `path — symbol()`, not line numbers; lines drift while phases land.
- Durable decisions (routes, schema shapes, model names, auth approach, third-party boundaries) go in the header. Volatile details (file names, function names) stay out of phase text.
- Phase text holds what to build and how to verify it. No background, no restated PRD, no rationale the header already settled.
- Decide the granularity yourself. The finished file is the review surface; the user merges or splits phases there.

## Workflow

1. Read the input in full: the PRD, or the task and the code it touches.
2. Clarify only what the code, PRD and conventions do not settle, at most three rounds. Zero questions is the normal outcome; say so in one line.
3. Fix the durable decisions.
4. Slice into tracer-bullet phases: each a thin, complete path through every layer (schema, API, UI, tests), demoable on its own. Many thin slices beat few thick ones. A refactor or config change is one phase.
5. Self-review the file for placeholders: TBD, "add appropriate validation", "similar to phase N". Flag names that appear in one phase only. Fix inline.

## PRD mode

1. Split a request that bundles independently shippable features into separate PRDs before anything else.
2. Explore the code to check the user's assertions, then clarify (≤ 3 rounds).
3. Work out two or three approaches with effort, risk and reversibility; pick one and record why.
4. Sketch the modules: deep modules behind small interfaces, dependencies injected, values returned instead of inputs mutated.
5. Write the whole PRD in one pass. Problem Statement and User Stories are prose because their readers are non-technical; the rest follows the usual caps.
6. Domain terms the PRD introduces go into `docs/UBIQUITOUS_LANGUAGE.md`: one table per topic with term, one-sentence definition, aliases to avoid. Pick one word per concept; skip module and class names unless they carry domain meaning.

## Plan template

```markdown
# Plan: <Title>

> Source PRD: <path, or "n/a">

## Goal

## Architectural decisions

- **Routes**: … · **Schema**: … · **Key models**: … (omit for small tasks)

## Inventory

- `path/file.go — symbolName()` — why relevant

## Resolved decisions

## Open questions / Risks

## Phase 1: <Title>

**User stories**: <from the PRD, or omit>
**Depends on**: <phase numbers, or "none">

### Context

- `path/file.go — symbolName()` — why relevant

### What to build

End-to-end behaviour of this slice, not layer-by-layer steps.

### Acceptance criteria

- [ ] …
```

## PRD template

```markdown
# PRD: <Feature>

## Problem Statement      (prose, user's perspective)
## Solution               (prose, user's perspective)
## User Stories           (numbered; one per actor and per capability the Solution names)
1. As an <actor>, I want <feature>, so that <benefit>
## Implementation Decisions   (modules, interfaces, schema, API contracts; no file paths or code)
## Testing Decisions          (external behaviour only; which modules; prior art in the repo)
## Out of Scope
## Further Notes
```
