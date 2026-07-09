---
name: clarify
description: >-
  Prevents the agent from making assumptions by forcing structured clarifying
  questions before acting. Use when the user wants thorough spec-gathering,
  disambiguation, or wants the agent to ask before assuming. Applies to any
  task type.
---

# Clarify

Never assume — always ask. Before acting on any task, identify ambiguities and
unknowns, then resolve them through structured questions. Walk down each
branch of the decision tree, resolving dependencies between decisions
one-by-one. Use this skill when clarification is the task itself or when
thorough spec-gathering is needed — create-plan and write-prd embed a lighter
clarification pass scoped to their own work.

## Workflow

Ask questions in rounds, each round drilling deeper based on prior answers.
Stop as soon as the decision tree is resolved, even after a single round — do
not pad with extra rounds. Continue only while unresolved branches remain.

### Round 1 — Scope & Intent

Identify what is ambiguous or underspecified in the user's request. Ask the
biggest unknowns first.

### Round 2+ — Drill deeper

Based on prior answers, ask follow-up questions on remaining gaps, edge cases,
or conflicting constraints. Confirm critical decisions before proceeding. Once
no unresolved branches remain, stop.

### After questions

Update the current plan or document with every decision made, then proceed with
the task.

## Question rules

Follow the canonical [clarification question rules](question-rules.md): explore
before asking, always recommend, context before question, structured over
free-text, max 5 questions per round, stop when resolved, and the
declined-answer fallback.

## Constraints

- Do not repeat questions the user has already answered.
- Never act on an unresolved ambiguity — get an answer or record a documented
  **Assumption** first.
