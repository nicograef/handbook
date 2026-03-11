# GitHub Copilot Agent Mode — Project Setup

How to configure a repository so GitHub Copilot (Agent Mode, Chat, Inline) understands the project, follows conventions and produces consistent code.

## Overview

Four layers of context, loaded at different times:

| Layer | File | Loaded when |
|-------|------|-------------|
| **Root instructions** | `AGENTS.md` | Agent Mode — always |
| **Copilot instructions** | `.github/copilot-instructions.md` | Copilot Chat / Inline / Agent — always |
| **Contextual instructions** | `.github/instructions/*.instructions.md` | Automatically, when editing files matching `applyTo` |
| **Reusable prompts** | `.github/prompts/*.prompt.md` | On demand (`/prompt-name` in chat) |

Design principle: **layer context from always → contextual → on-demand** so the agent gets the right information at the right time without wasting token budget.

## AGENTS.md

Root-level file read by VS Code Agent Mode on every request. Contains everything an agent needs to work autonomously.

### Recommended sections

```markdown
# Agent Instructions — <project-name>

<One paragraph: what the project IS and what it explicitly is NOT.>

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Backend   | Go 1.24, net/http, pgx/v5 |
| Frontend  | React 19, Vite 6, TypeScript 5.7 |
| Database  | PostgreSQL 17 |
| Runtime   | Docker Compose, nginx |

## Commands

| Command       | Description |
|---------------|------------|
| `make test`   | Run all tests |
| `make lint`   | Lint all code |
| `make build`  | Build all artifacts |
| `make dev`    | Start dev stack |

## Rules

1. First hard rule.
2. Second hard rule.
...

## Boundaries

- ✅ **Always:** validate both sides, run tests
- ⚠️ **Ask first:** add dependencies, change DB schema
- 🚫 **Never:** edit generated code, commit secrets

## Areas

- **Admin**: routes, directories, guards
- **API**: routes, middleware

## Git Workflow

- Conventional Commits in English
- No auto-commit — agent proposes, user commits
- No --force push or --no-verify
```

### Best practices

- **Include what the project is NOT** — prevents agents from adding out-of-scope features.
- **Exact versions** in the tech stack — prevents agents from suggesting outdated APIs.
- **Boundaries with three levels** (✅/⚠️/🚫) — more effective than soft guidelines.
- **Command table** — agents run `make test` instead of guessing.

## .github/copilot-instructions.md

Compact subset of AGENTS.md. Loaded by Copilot in every mode (Chat, Inline, Agent). Keep it short — this file counts against token budget on every request.

```markdown
# <project> — Copilot Instructions

<One-line project description.>
Full agent instructions: see AGENTS.md in the project root.

## Rules

1. Most critical rule.
2. Second critical rule.
...
```

Only include rules that apply **everywhere** — things the agent must never get wrong regardless of context.

## .github/instructions/*.instructions.md

Contextual instructions loaded automatically when the agent edits files matching the `applyTo` glob pattern. Each file covers one area of the codebase.

### Structure

```markdown
---
description: "Use when working on Go backend code."
applyTo: "backend/**"
---

# Backend Conventions

## Commands

- **Build:** `make build-backend`
- **Test:** `make test`
- **Lint:** `make lint-backend`

## Directory layout

backend/
  api/          # HTTP handlers
  domain/       # Business logic
  repository/   # Data access

## Patterns

<Describe the patterns used in this area — ideally with code examples.>

## Code examples

<Full, copy-paste-ready code examples that show the canonical way to do things.>
```

### Best practices

- **One file per area** — `backend.instructions.md`, `frontend.instructions.md`, `database.instructions.md`.
- **Code examples are the most effective tool** — an agent that sees a complete handler example will replicate the pattern. Prose rules alone are often ignored.
- **Include directory layout** — agents need to know where files go.
- **List relevant commands** — so the agent runs the right check after making changes.
- Use `applyTo` to limit scope — `backend/**`, `frontend/**`, `scripts/**`.
- Files without `applyTo` (e.g. `new-feature.instructions.md`) are loaded based on `description` match.

## .github/prompts/*.prompt.md

Reusable prompts invoked via `/prompt-name` in Copilot Chat. Useful for recurring multi-step tasks.

### Scaffolding prompts

Automate the creation of new standardised artifacts (pages, endpoints, guides):

```markdown
---
description: "Creates a new API endpoint with all layers."
---

# New Endpoint

## Input

- **Domain**: e.g. product, user
- **Endpoint name**: e.g. create-product
- **Area**: admin or service

## Steps

1. Domain model + validation schema in `domain/<domain>/`
2. SQL query in `sqlc/queries/<domain>.sql`, then `sqlc generate`
3. Repository in `repository/<domain>_repo/`
4. Application service in `api/<domain>/application/`
5. HTTP handler in `api/<domain>/http/`
6. Register route
7. Unit test
```

### Plan → Progress → Implement workflow

A three-phase workflow for complex features, designed for iterative agent execution:

**Phase 1 — `/plan`**: Agent researches codebase, writes `docs/agents/<slug>/plan.md`.
- Only research + plan, no code changes.
- References concrete files and code locations.

**Phase 2 — `/progress`**: Agent converts plan into `progress.md` with checkbox tasks.
- Groups tasks into sections with dependency analysis.
- Includes parallelisation hints (which sections can run concurrently).
- Embeds agent instructions directly in the file.

**Phase 3 — `/implement`**: Agent claims and works through one section.
- Claims section with 🔒 marker, marks ✅ when done.
- Multiple agents can work in parallel on independent sections.
- Each agent runs build/lint/tests after completing a section.

```
docs/agents/<slug>/
  plan.md        # What to do and why
  progress.md    # Atomic task list with checkboxes
```

Co-ordination happens through file markers:

| Marker | Meaning |
|--------|---------|
| (none) | Available |
| 🔒     | Claimed — agent working on it |
| ✅     | Done — all tasks checked off |

This workflow is most valuable for **code projects with multi-step features**. For documentation-only projects, a lightweight variant works better.

### Lightweight variant (single-file plan)

For smaller projects or documentation repos, collapse the three phases into one:

1. A single `/plan` prompt creates `plan.md` in the project root with goal, affected files, and a **checkbox task list** (plan + progress combined).
2. The agent (or user) works through the checklist step by step, ticking off each item.
3. After all steps: verify links, confirm index files are up to date.
4. Delete `plan.md` when done.

No separate `/progress` or `/implement`, no `docs/agents/` directory, no parallelisation markers. The discipline of **research → plan → execute → verify → clean up** is preserved, with minimal overhead.

## Best Practices Summary

1. **Concrete over abstract** — code examples beat prose rules. An agent that sees a complete handler example replicates the pattern.
2. **Layer the context** — always-loaded files stay small; detail goes into contextual instructions loaded only when relevant.
3. **Boundaries over suggestions** — ✅/⚠️/🚫 matrices are more effective than "try to" guidelines.
4. **Commands in tables** — agents execute what they see. If the table says `make lint`, the agent runs it.
5. **Negative scope** — state what the project is NOT and what agents must NEVER do. Prevents scope creep.
6. **Single source of truth** — `copilot-instructions.md` extracts from `AGENTS.md`, never contradicts it.
7. **Test the setup** — ask the agent to explain the project rules back to you. If it gets something wrong, the instructions need clarification.
