---
name: write-prd
description: >-
  Creates a PRD through structured clarification, codebase exploration, and
  module design, then saves it as a local Markdown file. Use when user wants to
  write a PRD, create a product requirements document, or plan a new feature.
---

# Write a PRD

Skip a step only when its output already exists (e.g. the clarification is done
or the codebase is already understood). Never skip exploration.

## Workflow

### 1. Gather the problem description

Ask the user for a long, detailed description of the problem they want to
solve and any potential ideas for solutions.

**Scope triage:** If the request bundles multiple independent
subsystems/features (each could ship and be useful on its own), stop before
spending clarification rounds. Help the user split it into separate PRDs —
each gets its own PRD and, later, its own plan. Only continue with this
workflow once you're working a single, cohesive PRD's worth of scope.

### 2. Explore the codebase

Explore the repo to verify their assertions and understand the current state
of the codebase.

### 3. Clarify ambiguities

Resolve unknowns through **1–3 rounds** of structured questions, following the
canonical [clarification question rules](../clarify/question-rules.md).

### 4. Propose approaches

Once ambiguities are resolved, propose **2–3 candidate solution approaches**
with their trade-offs (effort, risk, reversibility, fit with the existing
codebase). Lead with a recommendation and your reasoning for it. Get the
user to pick one — or steer a hybrid — before moving on to module design.

### 5. Design modules

Sketch out the major modules you will need to build or modify to complete
the implementation. Actively look for opportunities to extract deep modules
that can be tested in isolation.

A deep module hides substantial functionality behind a small, testable
interface that rarely changes — see
[interface design](../tdd/interface-design.md).

Present the module design as part of the flow — do not block on a separate
confirmation. Decide the test scope yourself based on the design; raise it
as a clarification question (within the rounds from step 3) only if it is a
genuine judgment call the codebase cannot answer.

### 6. Write the PRD

Once you have a complete understanding of the problem and solution, write
the full PRD in one pass — no section-by-section confirmation gates. The
user reviews the finished document and requests changes there; that is
cheaper and more informed than approving fragments. Scale the depth of each
section to the complexity of the feature; a small feature doesn't need a
long-winded Problem Statement.

Use the template below and save it to `docs/prds/prd-<name>.md` (create the
directory if it doesn't exist). Use a short kebab-case name derived from the
feature (e.g. `prd-user-onboarding.md`).

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

## Constraints

- Do not skip exploration to save time: read the codebase to answer a
  question before asking the user.
- Clarify per the [question rules](../clarify/question-rules.md), capped at
  1–3 rounds total; stop as soon as ambiguities are resolved.
- Do not include specific file paths or code snippets in Implementation
  Decisions; they go stale quickly.
- Only test external behavior in Testing Decisions, never implementation
  details.

## Quality

- Once the PRD file is written, run the shared
  [self-review checklist](../quality.md) on it. Surface issues in the chat only
  if found.
- Also run a PRD-specific self-review pass before presenting the final file:
  - Scan for placeholders, TBDs, or unresolved brackets left over from drafting.
  - Check internal consistency — do the User Stories, Implementation Decisions,
    and Out of Scope sections agree with each other and with the Solution?
  - Confirm the scope is narrow enough to be covered by a single
    implementation plan; if not, flag it and suggest splitting.
  - Flag any requirement that could reasonably be read two different ways.
