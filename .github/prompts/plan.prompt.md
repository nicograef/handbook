---
description: "Creates a plan.md with goal, context, and step-by-step checklist for a multi-file change. Research first, then plan — no changes yet."
agent: "agent"
argument-hint: "Describe the task or change..."
---

# Plan

You are in the **planning phase**. Your job is to analyse the task, research the affected files and create a plan. **Do not make any changes to content files yet.**

## Procedure

1. **Analyse** the task description.
2. **Research** — read affected files, understand cross-references, existing style, and link structure.
3. **Verify** — check your assumptions match the conventions in `AGENTS.md`.
4. **Create** `plan.md` in the project root.

## Rules

- **No content changes.** Only create/write `plan.md`.
- **Reference concrete files** so a follow-up session can start immediately.
- **No pure context-loading steps.** Every step must produce output (create/modify/delete a file, update an index). Context loading belongs in the instructions below the plan, not in a checklist step.
- **Keep it concise** — this is a knowledge base, not a code project. No boilerplate.

## Structure of plan.md

```markdown
# Plan: <title>

## Goal

<What should be achieved?>

## Affected files

<List of files that will be created, modified, or deleted — with brief reason for each>

## Context (reload every session)

Before starting work, read this plan and all files listed under "Affected files".
Context does not persist between sessions — always reload.

## Steps

- [ ] Step 1 — concrete, atomic action
- [ ] Step 2
- [ ] ...
- [ ] Update `README.md` (if files were added/renamed/removed)
- [ ] Verify links: `grep -r '<filename>' .`

## Open questions

<If any — otherwise omit this section>
```
