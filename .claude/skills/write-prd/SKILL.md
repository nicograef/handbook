---
name: write-prd
description: >-
  Creates a PRD through structured clarification, codebase exploration, and
  module design, then saves it as a local Markdown file. Use when user wants to
  write a PRD, create a product requirements document, or plan a new feature.
---

# Write a PRD

- Skip a step only when its output already exists — e.g. clarification done, codebase understood.
- Never skip exploration.
- **Named prose exception:** the PRD's Problem Statement and User Stories stay prose.
- Reason: PRD readers are non-technical. Do not "fix" those two slots into bullets.
- The ≤ 20-word sentence cap still applies to them.
- Everything else follows the [output style contract](../output-style.md).

## Workflow

### 1. Gather the problem description

- Ask the user for a long, detailed description of the problem to solve.
- Ask for any potential ideas for solutions.
- **Scope triage:** stop before clarification rounds if the request bundles multiple independent subsystems or features.
- Independent means each one could ship and be useful on its own.
- Help the user split such a request into separate PRDs.
- Each split gets its own PRD and, later, its own plan.
- Continue this workflow only once the scope is a single, cohesive PRD.

### 2. Explore the codebase

- Explore the repo to verify the user's assertions.
- Understand the current state of the codebase.

### 3. Clarify ambiguities

- Resolve unknowns through **1–3 rounds** of structured questions.
- Follow the canonical [clarification question rules](../clarify/question-rules.md).

### 4. Propose approaches

- Work out **2–3 candidate solution approaches** once ambiguities are resolved.
- Give each approach its trade-offs: effort, risk, reversibility, fit with the existing codebase.
- Then run the [ask gate](../clarify/question-rules.md#the-ask-gate) over them; the survivor
  becomes the recorded **Implementation Decisions** entry, with its reasoning.

### 5. Design modules

- Sketch the major modules you will build or modify to complete the implementation.
- Actively look for deep modules you can extract and test in isolation.
- A deep module hides substantial functionality behind a small, stable interface.
- Inject dependencies instead of constructing them.
- Return values instead of mutating inputs.
- Keep the interface surface small.
- Present the module design as part of the flow; do not block on a separate confirmation.
- Decide the test scope yourself, based on the design.
- Raise test scope as a clarification question only if it is a genuine judgment call the codebase cannot answer.
- Keep any such question inside the rounds from step 3.

### 6. Write the PRD

- Write the full PRD in one pass once you fully understand problem and solution.
- No section-by-section confirmation gates.
- The user reviews the finished document and requests changes there.
- That is cheaper and more informed than approving fragments.
- Scale each section's depth to the complexity of the feature.
- Use the template below and save it to `docs/prds/prd-<name>.md`.
- Create the directory if it doesn't exist.
- Use a short kebab-case name derived from the feature, e.g. `prd-user-onboarding.md`.

## PRD Template

```markdown
# PRD: <Feature Name>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A numbered list of user stories with at least one story per actor and one per
distinct capability the Solution names — no capability in the Solution section
is left without a matching story. Each user story is in the format:

1. As an <actor>, I want a <feature>, so that <benefit>

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being
outdated very quickly.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not
  implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)

## Out of Scope

A description of the things that are out of scope for this PRD.

## Further Notes

Any further notes about the feature.
```

## Lifecycle

- A shipped PRD is superseded by the docs that describe the built thing.
- Deleting it is a [prune](../prune/SKILL.md) proposal the user picks.
- No skill deletes a PRD automatically, this one included.
- Rationale: the **Current state only** rule in `AGENTS.md`.

## Constraints

- Do not include specific file paths or code snippets in Implementation Decisions; they go stale quickly.
- Only test external behavior in Testing Decisions, never implementation details.

## Quality

- Once the PRD file is written, run the shared [self-review checklist](../quality.md) on it.
- Format it per the shared [output style contract](../output-style.md), minus the named prose exception.
- Also run a PRD-specific self-review pass before presenting the final file:
  - Scan for placeholders, TBDs, or unresolved brackets left over from drafting.
  - Check internal consistency across User Stories, Implementation Decisions, Out of Scope, and Solution.
  - Confirm the scope is narrow enough for a single implementation plan.
  - If it is not, flag it and suggest splitting.
  - Flag any requirement that could reasonably be read two different ways.
