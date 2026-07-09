---
name: create-plan
description: >-
  Creates an implementation plan from a PRD or a task description. Researches
  codebase context, clarifies ambiguities, and outputs a phased plan with
  vertical slices and acceptance criteria. Use when the user wants to plan a
  feature, break down a PRD, create an implementation plan, or mentions
  "tracer bullets".
---

# Create Plan

Create a phased implementation plan from **either** a PRD **or** a task
description. Output is a Markdown file in `docs/plans/`.

## Workflow

### 1. Determine the entry point

- **PRD provided** (file or in conversation context) → read it fully, then
  continue to step 2 to check for ambiguities before planning.
- **Task description only** → continue to step 2.

If a PRD exists but is not yet in context, ask the user to paste it or point
you to the file.

### 2. Clarify ambiguities

**Always run this step** — whether a PRD was provided or not. A PRD may
contain gaps, conflicting requirements, or underspecified decisions that must
be resolved before planning begins.

Resolve unknowns through **1–3 rounds** of structured questions before
planning, following the canonical
[clarification question rules](../clarify/question-rules.md).

### 3. Research the codebase

Read affected files, understand existing patterns, integration layers, and
the current architecture.

### 4. Identify architectural decisions

Before slicing, identify high-level decisions that are unlikely to change
throughout implementation:

- Route structures / URL patterns
- Database schema shape
- Key data models
- Authentication / authorization approach
- Third-party service boundaries

These go in the plan header so every phase can reference them.

### 5. Draft vertical slices

Break the work into **tracer bullet** phases. Each phase is a thin vertical
slice that cuts through ALL integration layers end-to-end.

**Slice rules:**

- Each slice delivers a narrow but COMPLETE path through every layer (schema,
  API, UI, tests).
- A completed slice is demoable or verifiable on its own.
- Prefer many thin slices over few thick ones.
- Do NOT include specific file names, function names, or implementation
  details that are likely to change as later phases are built.
- DO include durable decisions: route paths, schema shapes, data model names.

For small tasks (refactors, config changes, single-module work), a **single
phase** is perfectly valid.

### 6. Validate with the user

Present the proposed breakdown as a numbered list. For each phase show:

- **Title**: short descriptive name
- **User stories covered** (if working from a PRD): which user stories this
  addresses.

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Should any phases be merged or split further?

Iterate until the user approves the breakdown.

### 7. Write the plan file

Derive a slug from the task (e.g. `admin-dashboard`, `order-cancel`).
Create the file `docs/plans/plan-<slug>.md` (create the directory if it
doesn't exist).

### 8. Self-review the plan

Read the written plan with fresh eyes before presenting it.

- **Placeholder scan.** Search for vagueness that would block an implementer:
  "TBD", "TODO", "implement later", "fill in details"; instructions like "add
  appropriate error handling" or "add validation" that don't say how; "similar
  to Phase N" without restating the content; acceptance criteria or phase
  descriptions that reference a file, function, or model not defined anywhere
  else in the plan. Fix inline.
- **Cross-phase consistency check.** Confirm names introduced in
  "Architectural decisions" (route paths, schema/table names, key model or
  function names) are used identically everywhere they recur in later phases.
  Drift — e.g. `Order` in one phase and `PurchaseOrder` in another — is a plan
  bug. Fix inline.

Fix issues directly in the plan file before presenting it to the user. No need
to re-review after fixing.

## Constraints

- **No code changes.** Only create the plan file.
- **Precise references.** In the plan file, anchor references to file path plus
  symbol name (e.g. `backend/api/product/http/handler.go — handleCheckout()`),
  not line numbers — lines drift as later phases land. Use line numbers only for
  in-conversation citations while researching.
- **Readability-first.** Prefer simple, clear, idiomatic solutions.

## Quality

- Once the plan file is written, run the shared
  [self-review checklist](../quality.md) on it. Surface issues in the chat only
  if found.
- Placeholder scan (step 8): no TBD/TODO/vague instructions, and no acceptance
  criteria referencing undefined files, functions, or models.
- Cross-phase consistency check (step 8): names from "Architectural decisions"
  stay identical in every phase that reuses them.

## Plan Template

```markdown
# Plan: <Title>

> Source PRD: <relative path to PRD file, or "n/a" if from task description>

## Goal

<What should be achieved?>

## Architectural decisions

Durable decisions that apply across all phases:

- **Routes**: ...
- **Schema**: ...
- **Key models**: ...
- (add/remove sections as appropriate; omit entirely for small tasks)

## Inventory

<Relevant existing files, patterns, dependencies — each with file path + symbol name>

## Resolved decisions

<Decisions made during the clarification phase — one bullet per decision>

## Open questions / Risks

<If any — otherwise omit>

---

## Phase 1: <Title>

**User stories**: <list from PRD, or omit if from task description>

### Context

- `path/file.go — symbolName()` — <why relevant>

### What to build

A concise description of this vertical slice. Describe the end-to-end
behavior, not layer-by-layer implementation.

### Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

---

## Phase 2: <Title>

**User stories**: <list from PRD>

### Context

- `path/file.go — otherSymbol()` — <why relevant>

### What to build

...

### Acceptance criteria

- [ ] ...

<!-- Repeat for each phase -->
```
