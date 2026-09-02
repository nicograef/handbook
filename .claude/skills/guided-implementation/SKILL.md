---
name: guided-implementation
description: >-
  Guides a developer step-by-step through implementing a user story or plan
  phase — without writing any code. The agent acts as navigator: it explores
  the codebase, breaks work into small vertical steps, explains what to do and
  why, and waits for the developer to implement each step. Use when the user
  wants coaching, guided coding, mentored implementation, or pair programming
  where they write all the code themselves.
---

# Guided Implementation

## Invocation

The user provides one of:

- A **user story** from a PRD (`docs/prds/prd-*.md`).
- A **phase** from a plan (`docs/plans/plan-*.md`).
- A **task description** in conversation.
- Unclear reference → resolve by reading first; ask only when two or more candidates survive the
  [ask gate](../clarify/question-rules.md).

## Workflow

### 1. Read the input

| Input | Read for context | Then |
| --- | --- | --- |
| User story from PRD | The full PRD | Focus on the story; note implementation and testing decisions |
| Phase from plan | The full plan — goal, architectural decisions, inventory | Focus on the phase |
| Task description | — | Take it as-is; clarify scope if ambiguous |

### 2. Break into vertical steps

**Slice rules (from the tracer-bullet philosophy):**

- Decompose the work into the smallest useful steps.
- Each step is one logical change — one method, one field, one component, one migration.
- Order steps so the developer can verify progress after each one — run tests, see output, check
  behavior.
- Present the step list as a numbered overview.
- Ask the developer, then wait for confirmation before proceeding:

> "Does this breakdown look right? Should any steps be split or reordered?"

### 3. Guide step by step

For each step, brief the developer with this structure:

| Part | Content |
| --- | --- |
| **What** | The change in concrete terms — file(s), code area, interface or function involved. Never write code or snippets. |
| **Why** | The design reasoning — problem solved, design decision behind it, fit into the larger picture. |
| **How** | Existing codebase patterns to follow — similar code, naming conventions, architectural precedent. Expected runtime behavior after the change. |
| **Verify** | How to confirm the step worked — which test to run, what behavior to check, what output to expect. |

- Then **stop and wait** — do not proceed until the developer confirms the current step is done.

### 4. Review after each step

When the developer signals completion, **read the changed code** and run a focused review.

- Be critical — this is not a rubber-stamp.
- The review covers the three dimensions below.

#### 4a. Correctness & Consistency

- Does the change actually solve the stated step?
- Cross-layer consistency: do types, validation, contracts, and schemas still agree across layers?
- Apply the [cross-layer checklist](../cleanup/cross-layer.md) to the layers this step touches.
- Are error cases handled at the boundary?
- Are naming and conventions consistent with the rest of the codebase?

#### 4b. Interface Quality

- Is the interface as small as possible?
- Could any parameter or method be removed without losing functionality?
- Apply the deep-module checklist ([write-prd/SKILL.md](../write-prd/SKILL.md) step 5).
- Is the code easy to use correctly and hard to misuse?
- Unnecessary abstractions, wrappers, or indirection layers? See
  [redundant abstractions](../cleanup/code-smells.md#redundant-abstractions).

#### 4c. Test Quality

- If the step includes a test, judge it against the
  [test anti-patterns](../test-quality/anti-patterns.md).

#### Review output

[Named prose exception](../output-style.md#named-prose-exceptions).

Present findings honestly and directly. For each issue found:

> **[Dimension]** — What is wrong → Where (file:lines) → Why it matters →
> What to change (without writing the fix)

If the code is clean on all dimensions, say so briefly — do not invent issues. **Do not proceed to
the next step until all issues are resolved.** If the developer pushes back on a finding, discuss
it — but hold firm on correctness and consistency issues.

If the developer gets stuck during implementation, before signaling completion, provide more
context. Trace the relevant code path, explain the underlying concept, or point to a concrete
example in the codebase.

### 5. After all steps

Once the last step is confirmed and you are working from a plan, check off completed tasks
(`- [ ]` → `- [x]`).

## Constraints

- **Never generate production code.** Do not write, generate, or commit code on the developer's
  behalf. However, you MAY:
  - Quote existing code from the codebase (with file path + line reference) to point the developer
    to patterns or examples.
  - Use pseudocode or short conceptual sketches in the chat to explain an approach — label these
    pseudocode, not copy-paste-ready code.
  - Suggest code in the chat when the developer explicitly asks for a hint.
  - The developer decides whether and how to use a suggestion.
- **Never skip ahead.** One step at a time; wait for explicit confirmation before moving on.
- **Verify before claiming.** Read the actual source; never guess what code contains or how
  something works. Cite file paths and line numbers.
- **Stay in scope.** Only guide work on the selected user story or phase.
- Mention out-of-scope issues at the end — don't derail the current step.
- **No horizontal slicing.** Do not plan all tests first, then all implementation.
- Each step is a complete vertical slice the developer can verify before moving on.
- **TDD when appropriate.** If the project uses a TDD workflow, or the TDD skill is active, guide
  each step test-first.
- Test-first briefing: "First write a test for X, then implement it."
- Otherwise leave the testing approach to the developer and only suggest when to verify.
- **Adapt granularity.** Keep briefings concise for an experienced developer; explain more deeply
  for a learner.
- Ask early: "How familiar are you with this part of the codebase?"

## Quality

- Once all steps are complete, run the shared [self-review checklist](../quality.md) on the
  finished work.
- The per-step review in step 4 is separate from this final pass.
- Follow the shared [output style contract](../output-style.md).
