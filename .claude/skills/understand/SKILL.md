---
name: understand
description: >-
  Explores a codebase deeply to build a human's mental model. Use when the user
  wants to understand a specific part of the codebase holistically — database
  schema, API, function, domain model, business logic, frontend component,
  architecture, or any other concept. Invoke with one or more references to the
  code in question (file paths, function names, module names).
---

# Understand

## Invocation

An ambiguous reference is usually resolvable: search the repo for the symbol or
path first. Ask only when two candidates survive that search, per the
[ask gate](../clarify/question-rules.md#the-ask-gate).

## Workflow

The exploration itself is model-known. Two items are easy to miss.

- **Cross-layer mapping** — for a DB table, find the repository, service, handler, and frontend
  touching it. Map the reverse direction too.
- **ADRs / RFCs** — search `docs/` (and `docs/adrs/`, `docs/rfcs/`, `docs/decisions/`) for
  architecture decision records on this area.

### Explain

[Named prose exception](../output-style.md#named-prose-exceptions).

Present a structured explanation, adapted in depth to the focus area, following this outline:

1. **Overview** — one paragraph: what this is and why it exists.
2. **Key concepts** — the domain terms and abstractions the reader needs.
3. **How it works** — walk through the main flow(s) step by step.
4. **Connections** — diagram or list of dependencies and dependents.
5. **History & rationale** — why it was built this way, key decisions, evolution.
6. **Patterns & conventions** — design patterns, coding conventions observed.
7. **Risks & limitations** — tech debt, fragile areas, known issues.

Anchor explanations with code snippets; use Mermaid for relationships.

## Constraints

- **Read-only.** Never modify code, create files, or propose changes; this skill only explores and
  explains.
- **Verify before claiming.** Read the actual source; never guess what code contains or how it
  works.
- **Cite locations.** Anchor key claims to a file and line range (e.g.
  `src/orders/checkout.ts:42-67`).
- **Cite history.** Use commit hashes for history claims.
- **Synthesis.** A synthesis paragraph needs no citation of its own when the sections it draws on
  are already cited.
- **Stay focused.** Explore connections broadly; keep the explanation centred on the user's focus
  area. Don't dump the entire codebase.
- **No assumptions about intent.** If evidence (git history, ADRs, comments) leaves a design choice
  unclear, say so explicitly. Never speculate.

## Quality

- Follow the shared [output style contract](../output-style.md).
