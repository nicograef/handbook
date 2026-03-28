---
name: create-plan
description: >-
  Research codebase context, clarify ambiguities through structured questions,
  and create a plan.md with inventory and atomic task list. Use when the user
  wants to plan a feature, refactor, or multi-step task before implementing.
---

# Create Plan

Research the codebase context, clarify unknowns, and create a structured
**plan.md** with inventory and task list.

## Workflow

1. **Analyse** the task description
2. **Research** the relevant codebase context — read affected files, understand
   existing patterns
3. **Clarify** ambiguities (see below) — resolve unknowns before writing
4. **Derive a slug** from the task (e.g. `admin-dashboard`, `order-cancel`)
5. **Create** the file `docs/plans/plan-<slug>.md`

## Clarification Phase

Before writing the plan, identify ambiguities in scope, approach, and
trade-offs. Resolve them through **1–3 rounds** of structured questions.

**Rules:**
- **Explore before asking.** If a question can be answered by reading the
  codebase, read the codebase instead of asking the user.
- **Always recommend.** Every question must include a recommended answer with
  brief reasoning.
- **Structured over free-text.** Use concrete options. Convert open-ended
  questions to multiple-choice with an "Other (specify)" escape hatch.
- **Max 5 questions per round.** Prioritise the most impactful unknowns.
- **Stop when resolved.** If all ambiguities are clear after 1 round, stop.
  Continue only if unresolved branches remain.

If the user declines to answer: proceed with recommended defaults and document
each assumption as a clearly marked callout (e.g. blockquote prefixed with
**Assumption:**).

Record all resolved decisions in the plan under a **Resolved decisions**
section.

## Rules

- **No code changes.** Only create the plan file.
- **Precise references.** Back every finding with file path and line numbers
  (e.g. `backend/api/product/http/handler.go:42-58`).
- **Tasks must be atomic** — one task = one clearly scoped action.
- **No pure context-loading sections.** Every section must produce output
  (create/modify/delete files).
- **Readability-first.** Prefer simple, clear, idiomatic solutions.

## Plan Template

```markdown
# Plan: <Title>

## Goal

<What should be achieved?>

## Inventory

<Relevant existing files, patterns, dependencies — each with file path:lines>

## Resolved decisions

<Decisions made during the clarification phase — one bullet per decision>

## Open questions / Risks

<If any — otherwise omit>

---

## Section 1: <Title>

Context:

- `path/file.go:10-45` — <why relevant>

- [ ] Task 1
- [ ] Task 2

## Section 2: <Title>

Context:

- `path/file.go:50-80` — <why relevant>

- [ ] Task 3
- [ ] Task 4
```
