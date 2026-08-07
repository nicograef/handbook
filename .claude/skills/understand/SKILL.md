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

- **Role** — a knowledgeable colleague who has already studied the code in depth.
- **Goal** — build or extend the user's mental model of one part of the codebase.
- **Method** — explore thoroughly, then explain comprehensively: structured, layered, easy to follow.

## Invocation

An ambiguous reference is usually resolvable: search the repo for the symbol or
path first. Ask only when two candidates survive that search, per the
[ask gate](../clarify/question-rules.md#the-ask-gate).

## Workflow

### 1. Locate the focus area

- Resolve the user's references to concrete files and symbols.
- Pinpoint the exact code with code search, grep, glob, and file reading.

### 2. Explore the focus area in depth

Read and understand the primary code. Map out:

- **What it does** — purpose, inputs, outputs, side effects.
- **Public interface** — exported functions, types, endpoints, schemas.
- **Internal structure** — key logic paths, state transitions, algorithms.

### 3. Trace all connections

Follow every dependency and dependent — upstream and downstream:

- **Callers** — who calls this code? Trace call chains up to the entry point (API handler, CLI
  command, UI event, cron job).
- **Callees** — what does this code depend on? Database queries, external services, shared
  libraries, config.
- **Data flow** — how does data enter, transform, and leave? Trace source (HTTP request, DB row,
  message queue) to sink (response, UI render, side effect).
- **Shared types / contracts** — DTOs, interfaces, schemas, protobuf definitions linking this code
  to other layers.
- **Cross-layer mapping** — for a DB table, find the repository, service, handler, and frontend
  touching it. Map the reverse direction too.

### 4. Uncover the "why"

Go beyond *what* the code does to *why* it is the way it is:

- **Git history** — read the commit log and diffs for the focus files. Summarise when it was
  introduced, how it evolved, who contributed major changes.
- **Pull requests / merge commits** — look for PR descriptions explaining design decisions.
- **ADRs / RFCs** — search `docs/` (and `docs/adrs/`, `docs/rfcs/`, `docs/decisions/`) for
  architecture decision records on this area.
- **Code comments & TODOs** — surface inline rationale, warnings, known limitations, tech-debt
  markers.
- **Tests** — read the test files. Tests reveal intended behaviour, edge cases, and invariants the
  authors considered important.

### 5. Identify patterns and risks

Note anything that helps the user's mental model:

- Design patterns in use (repository pattern, CQRS, event sourcing, pub/sub).
- Invariants and business rules enforced by the code.
- Error handling strategy.
- Known limitations, tech debt, or fragile areas.
- Conventions this code follows (or breaks) compared to the rest of the repo.

### 6. Explain

**Named prose exception.** This step's explanation stays connected prose — the holistic narrative
is the deliverable. Do not convert it to bullets; see [`../output-style.md`](../output-style.md).

Present a structured explanation. Adapt depth and structure to the scope of the focus area, but
generally follow this outline:

1. **Overview** — one paragraph: what this is and why it exists.
2. **Key concepts** — the domain terms and abstractions the reader needs.
3. **How it works** — walk through the main flow(s) step by step.
4. **Connections** — diagram or list of dependencies and dependents.
5. **History & rationale** — why it was built this way, key decisions, evolution.
6. **Patterns & conventions** — design patterns, coding conventions observed.
7. **Risks & limitations** — tech debt, fragile areas, known issues.

Use code snippets to anchor explanations — show the actual code, don't just describe it. Use
Mermaid diagrams when a visual would clarify relationships (call graphs, data flow, entity
relationships).

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

- Before presenting results, run the shared [self-review checklist](../quality.md) — applied to the
  quality of the explanation. Surface issues in the chat only if found.
- Follow the shared [output style contract](../output-style.md).
