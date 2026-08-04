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

- **PRD provided** (file or in conversation context) → read it fully.
- Then continue to step 2, checking for ambiguities before planning.
- **Task description only** → continue to step 2.
- PRD exists but is not yet in context → ask the user to paste it or point you
  to the file.

### 2. Clarify ambiguities

- **Always run this step** — whether a PRD was provided or not.
- A PRD may contain gaps, conflicting requirements, or underspecified decisions.
- Resolve those before planning begins.
- Resolve unknowns through **1–3 rounds** of structured questions before planning.
- Follow the canonical [clarification question rules](../clarify/question-rules.md).

### 3. Research the codebase

- Read affected files.
- Understand existing patterns, integration layers, and the current architecture.

### 4. Identify architectural decisions

Before slicing, identify high-level decisions unlikely to change throughout
implementation. They go in the plan header, so every phase can reference them.

- Route structures / URL patterns
- Database schema shape
- Key data models
- Authentication / authorization approach
- Third-party service boundaries

### 5. Draft vertical slices

Break the work into **tracer bullet** phases. Each phase is a thin vertical
slice cutting through ALL integration layers end-to-end.

**Slice rules:**

- Each slice delivers a narrow but COMPLETE path through every layer (schema,
  API, UI, tests).
- A completed slice is demoable or verifiable on its own.
- Prefer many thin slices over few thick ones.
- Do NOT include specific file names, function names, or implementation details
  likely to change as later phases are built.
- DO include durable decisions: route paths, schema shapes, data model names.
- Give every phase a `**Depends on**` line — the phase numbers that must land
  first, or "none".
- [implement-plan](../implement-plan/SKILL.md) reads that line to decide what may
  run concurrently.
- A plan without that line is executed strictly sequentially.
- Every phase is then assumed to depend on all earlier ones.

**Granularity:**

- Small tasks (refactors, config changes, single-module work) may use a **single
  phase**.
- Decide the granularity yourself — do not ask the user to approve the phase
  breakdown.
- The finished plan file is the review surface.
- The user can merge or split phases there.
- Raise a phasing question only if two breakdowns imply genuinely different scope
  or risk.
- Such a phasing question belongs in step 2's clarification rounds.

### 6. Write the plan file

- Derive a slug from the task (e.g. `admin-dashboard`, `order-cancel`).
- Create the file `docs/plans/plan-<slug>.md` (create the directory if it
  doesn't exist).
- **Lifecycle** — the plan file is transient, not a record.
- It dies when its last acceptance criterion lands.
- [implement-plan](../implement-plan/SKILL.md) step 10 deletes it after landing.
- [finish-branch](../finish-branch/SKILL.md) option 1 deletes it after a local merge.
- One unticked criterion keeps the file alive.
- Rationale: the **Current state only** rule in `AGENTS.md`.

### 7. Self-review the plan

Read the written plan with fresh eyes before presenting it.

- **Placeholder scan.** Search for vagueness that would block an implementer;
  fix inline.
- Markers: "TBD", "TODO", "implement later", "fill in details".
- Instructions like "add appropriate error handling" or "add validation" that
  don't say how.
- "similar to Phase N" without restating the content.
- Acceptance criteria or phase descriptions that reference a file, function, or
  model not defined anywhere else in the plan.
- **Cross-phase consistency check.** Confirm names introduced in "Architectural
  decisions" recur identically everywhere in later phases; fix inline.
- Names covered: route paths, schema/table names, key model or function names.
- Drift — e.g. `Order` in one phase and `PurchaseOrder` in another — is a plan bug.
- Fix issues directly in the plan file before presenting it to the user.
- No need to re-review after fixing.

## Constraints

- **No code changes.** Only create the plan file.
- **Precise references.** In the plan file, anchor references to file path plus
  symbol name, e.g. `backend/api/product/http/handler.go — handleCheckout()`.
- Not line numbers — lines drift as later phases land.
- Use line numbers only for in-conversation citations while researching.
- **Readability-first.** Prefer simple, clear, idiomatic solutions.

## Quality

- Once the plan file is written, run the shared
  [self-review checklist](../quality.md) on it.
- Surface issues in the chat only if found.
- Chat and plan text follow the [output style contract](../output-style.md).

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

**Depends on**: <phase numbers that must land first, or "none">

### Context

- `path/file.go — symbolName()` — <why relevant>

### What to build

A concise description of this vertical slice. Describe the end-to-end
behavior, not layer-by-layer implementation.

### Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

<!-- Repeat this Phase block (heading, User stories, Depends on, Context,
     What to build, Acceptance criteria) for each remaining phase -->
```
