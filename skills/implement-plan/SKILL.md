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

1. **Critically review the phase** before writing any code — check for ambiguous acceptance criteria, missing context, or conflicting instructions. Raise concerns with the user first; if there are none, proceed
2. **Read the plan** and find the next phase with unmet acceptance criteria (`- [ ]`)
3. **Read that phase's Context block** — it lists the relevant files
4. **Implement the phase's "What to build"**, working toward its acceptance criteria
5. **Check off each acceptance criterion** (`- [ ]` → `- [x]`) once you have verified it
6. **After the phase's criteria are met**: run the project's build, lint, and test suite
7. **Stop** — do not start the next phase

## When to stop

Stop and ask the user rather than guessing when:

- A required dependency, file, or instruction is missing or unclear
- Verification (build/lint/test) fails repeatedly for the same reason

## Constraints

- Prefer simple, clear, idiomatic solutions
- No performance optimisation at the cost of readability
- Small local duplication is fine when it makes the code more understandable

## Quality

- Before presenting results, run the shared [self-review checklist](../quality.md). Surface issues in the chat only if found.
- After task completion, propose a conventional commit message plus a short human-readable summary of what changed, why, and what the reviewer should focus on.
