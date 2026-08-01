---
name: clarify
description: >-
  Prevents the agent from making assumptions by forcing structured clarifying
  questions before acting. Use when the user wants thorough spec-gathering,
  disambiguation, or wants the agent to ask before assuming. Applies to any
  task type.
---

# Clarify

Never assume — always ask. Identify ambiguities and unknowns before acting, then
resolve them through structured questions, walking each branch of the decision
tree and resolving dependencies between decisions one-by-one. Use this skill when
clarification is the task itself or thorough spec-gathering is needed; create-plan
and write-prd embed a lighter clarification pass scoped to their own work.

## Workflow

1. Ask in rounds, biggest unknowns first — whatever is ambiguous or
   underspecified in the request — following the canonical
   [clarification question rules](question-rules.md).
2. Drill deeper on prior answers: remaining gaps, edge cases, conflicting
   constraints. Confirm critical decisions before proceeding. Stop as soon as the
   decision tree is resolved, even after a single round; do not pad with extra
   rounds.
3. Update the current plan or document with every decision made, then proceed
   with the task.

## Constraints

- Do not repeat questions the user has already answered.
- Never act on an unresolved ambiguity — get an answer or record a documented
  **Assumption** first.
