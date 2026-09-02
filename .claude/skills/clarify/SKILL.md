---
name: clarify
description: >-
  Prevents the agent from making assumptions by forcing structured clarifying
  questions before acting. Use when the user wants thorough spec-gathering,
  disambiguation, or wants the agent to ask before assuming. Applies to any
  task type.
---

# Clarify

Never act on an unresolved ambiguity. Resolve it by reading, then by deciding,
and only then by asking.

- Resolve unknowns through structured questions: walk each decision-tree
  branch, resolve dependencies between decisions one by one.
- create-plan and write-prd embed a lighter clarification pass scoped to
  their own work.
- Invoking this skill does not make every unknown a question. Each one still
  passes the [ask gate](question-rules.md#the-ask-gate); the ones that resolve
  to a single option are decided, not asked.

## Workflow

1. Ask in rounds, biggest unknowns first — ambiguous or underspecified parts
   of the request — per the [clarification question rules](question-rules.md).
   Every question clears the [ask gate](question-rules.md#the-ask-gate) first.
2. Drill deeper on prior answers: remaining gaps, edge cases, conflicting
   constraints. Confirm critical decisions before proceeding.
3. Update the current plan or document with every decision made, then
   proceed with the task.

## Constraints

- Do not repeat questions the user has already answered.
- Never act on an unresolved ambiguity — get an answer or record a documented
  **Assumption** first.
