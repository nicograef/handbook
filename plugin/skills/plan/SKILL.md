---
name: plan
description: Writes a phased implementation plan (docs/plans/plan-<slug>.md) from a task or PRD, or a PRD (docs/prds/prd-<name>.md) from a problem description. Use to plan a feature, break down a PRD, write a PRD, or when the user mentions tracer bullets.
argument-hint: "[prd] <task, PRD path, or problem description>"
---

# Plan

Arguments: `$ARGUMENTS`. The output is a file, never code. `/nico:plan <task or PRD path>` writes `docs/plans/plan-<slug>.md`; `/nico:plan prd <problem>` writes `docs/prds/prd-<name>.md`.

## What implement-plan relies on

- The plan keeps the [skeleton](#plan-skeleton). implement-plan and the `plan-run-guard.sh` Stop hook parse `## Phase`, `**Depends on**` and `- [ ]` lines.
- Paths go in each phase's Context and What to build. The concurrency test compares them pairwise.
- Phases meant to run in parallel touch disjoint files. Choke files (indexes, lockfiles, migrations) stay in one phase.
- Each criterion is verifiable by one targeted command. The full gate runs once per phase.
- Reference code as `path — symbol()`, not line numbers; lines drift while phases land.

## Plan mode

1. Read the input in full: the PRD, or the task and the code it touches.
2. Ask only what code, PRD and conventions leave open, in at most three rounds. Zero questions is normal.
3. Fix the durable decisions in the header: routes, schema, models, auth, third-party boundaries.
4. Slice into tracer-bullet phases, each a thin path through every layer and demoable alone. Pick the granularity yourself.
5. Self-review: fix placeholders such as TBD or "similar to phase N". Flag names used in one phase only. Propose KISS and YAGNI cuts.
6. Spawn a fresh-context `opus` plan critic on the file. Apply its findings and your cuts; route only forks with no clear winner through the decide skill.

## PRD mode

1. Split a request bundling independently shippable features into separate PRDs.
2. Check the user's assertions against the code, then clarify in at most three rounds.
3. Weigh two or three approaches by effort, risk and reversibility. Record the pick and why.
4. Write the sections of the [PRD skeleton](#prd-skeleton) in one pass.
5. New domain terms go into the repo's glossary, else `docs/UBIQUITOUS_LANGUAGE.md`: term, one-sentence definition, aliases to avoid.
6. Self-review as in plan mode.

## Plan skeleton

```markdown
# Plan: <Title>

> Source PRD: <path, or "n/a">

## Goal
## Architectural decisions
## Inventory                 (`path — symbol()` — why relevant)
## Open questions / Risks

## Phase 1: <Title>

**Depends on**: <phase numbers, or "none">

### Context                  (`path — symbol()` — why relevant)
### What to build            (end-to-end behaviour of the slice)
### Acceptance criteria
- [ ] …
```

## PRD skeleton

```markdown
# PRD: <Feature>

## Problem Statement         (prose, user's perspective)
## Solution                  (prose, user's perspective)
## User Stories              (As an <actor>, I want <feature>, so that <benefit>)
## Implementation Decisions  (modules, interfaces, schema, contracts; no paths or code)
## Testing Decisions         (external behaviour only; prior art in the repo)
## Out of Scope
## Further Notes
```
