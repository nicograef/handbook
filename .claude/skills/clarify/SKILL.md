---
name: clarify
description: >-
  Prevents the agent from making assumptions by forcing structured clarifying
  questions before acting. Use when the user wants thorough spec-gathering,
  disambiguation, or wants the agent to ask before assuming. Applies to any
  task type.
---

# Clarify

Never assume — always ask, before acting on ambiguity.

- Resolve unknowns through structured questions: walk each decision-tree
  branch, resolve dependencies between decisions one by one.
- Use when clarification is the task itself, or thorough spec-gathering is
  needed.
- create-plan and write-prd embed a lighter clarification pass scoped to
  their own work.

## Workflow

1. Ask in rounds, biggest unknowns first — ambiguous or underspecified parts
   of the request — per the [clarification question rules](question-rules.md).
2. Drill deeper on prior answers: remaining gaps, edge cases, conflicting
   constraints. Confirm critical decisions before proceeding.
3. Stop once the decision tree resolves, even after one round — don't pad
   with extra rounds.
4. Update the current plan or document with every decision made, then
   proceed with the task.

## Constraints

- Do not repeat questions the user has already answered.
- Never act on an unresolved ambiguity — get an answer or record a documented
  **Assumption** first.
