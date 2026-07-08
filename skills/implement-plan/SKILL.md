---
name: implement-plan
description: >-
  Work through the next open phase of a plan, implementing toward its
  acceptance criteria and checking each off as it is verified. Use when the
  user wants to execute an existing implementation plan one phase at a time.
---

# Implement Plan

Read the referenced plan and work through **one phase** at a time.

## Workflow

1. **Read the plan** and find the next phase with unmet acceptance criteria (`- [ ]`)
2. **Read that phase's Context block** — it lists the relevant files
3. **Implement the phase's "What to build"**, working toward its acceptance criteria
4. **Check off each acceptance criterion** (`- [ ]` → `- [x]`) once you have verified it
5. **After the phase's criteria are met**: run the project's build, lint, and test suite
6. **Stop** — do not start the next phase

## Constraints

- Prefer simple, clear, idiomatic solutions
- No performance optimisation at the cost of readability
- Small local duplication is fine when it makes the code more understandable

## Quality

- Before presenting results, run the shared [self-review checklist](../quality.md). Surface issues in the chat only if found.
- After task completion, propose a conventional commit message plus a short human-readable summary of what changed, why, and what the reviewer should focus on.
