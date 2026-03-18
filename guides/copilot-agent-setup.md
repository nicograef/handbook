# GitHub Copilot Agent Mode — Project Setup

How to configure a repository so GitHub Copilot (Agent Mode, Chat, Inline) understands the project, follows conventions, and produces consistent code. This guide doubles as a checklist an agent can follow to **audit and improve** any existing repo's agent setup.

Based in part on lessons from [How to write a great agents.md](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/) — an analysis of 2,500+ repositories.

## Overview

Five layers of context, loaded at different times:

| Layer                       | File                                     | Loaded when                                          | Token cost      |
| --------------------------- | ---------------------------------------- | ---------------------------------------------------- | --------------- |
| **Root instructions**       | `AGENTS.md`                              | Agent Mode — always                                  | High (full)     |
| **Copilot instructions**    | `.github/copilot-instructions.md`        | Copilot Chat / Inline / Agent — always               | Low (compact)   |
| **Contextual instructions** | `.github/instructions/*.instructions.md` | Automatically, when editing files matching `applyTo` | Per-area        |
| **Custom agents**           | `.github/agents/*.md`                    | When invoked via `@agent-name` in chat               | Zero until used |
| **Reusable prompts**        | `.github/prompts/*.prompt.md`            | On demand (`/prompt-name` in chat)                   | Zero until used |

Design principle: **layer context from always → contextual → on-demand** so the agent gets the right information at the right time without wasting token budget.

### When to add each layer

Not every project needs all five layers. Add them incrementally:

| Project shape                                         | Recommended layers                                            |
| ----------------------------------------------------- | ------------------------------------------------------------- |
| Small / single-area                                   | `AGENTS.md` only                                              |
| Multi-area (backend + frontend, library + docs site)  | + `.github/copilot-instructions.md` + contextual instructions |
| Specialised roles (docs writer, test engineer)        | + custom agents                                               |
| Recurring multi-step tasks (scaffolding, migrations)  | + reusable prompts                                            |

### Cross-tool compatibility

If the repo also uses Cursor (`.cursor/rules/`, `.cursor/commands/`), keep the conventions aligned. `AGENTS.md` is the single source of truth — Cursor rules should point to it, not duplicate it.

### Start simple, iterate

The best agent setups grow through iteration, not upfront planning. Start with a minimal `AGENTS.md`, use it, and add detail when the agent makes mistakes. Each mistake is a signal that context is missing.

---

## Six Core Areas

Analysis of 2,500+ `agents.md` files shows that the most effective setups cover six areas. Hitting all six puts you in the top tier:

| Area                 | What to include                                                              |
| -------------------- | ---------------------------------------------------------------------------- |
| **Commands**         | Exact executable commands with flags — `npm test`, `cargo build --release`   |
| **Testing**          | Test framework, how to run tests, coverage expectations                      |
| **Project structure**| Directory layout with purpose of each top-level folder                       |
| **Code style**       | One real code example beats three paragraphs of description                  |
| **Git workflow**     | Commit conventions, branch strategy, PR/MR process                           |
| **Boundaries**       | What the agent must never touch — ✅ always / ⚠️ ask first / 🚫 never        |

Not every area needs its own section. Commands + boundaries are the highest-impact; add others as the agent makes mistakes.

---

## Common Failure Modes

Most agent files fail because they're too vague. Recognise these patterns:

- **"You are a helpful coding assistant"** — no persona, no constraints. The agent has no guardrails.
- **Prose-only rules, no code examples** — agents follow examples far more reliably than written rules.
- **Missing commands** — the agent guesses `npm test` when your project uses `make test` or `pnpm run test`.
- **No negative scope** — the agent adds features, refactors code, or creates files outside the project's intent.
- **Broken references** — AGENTS.md links to `docs/backend.md` but the file doesn't exist. Agents lose trust in the instructions.

---

## Auditing an Existing Repo

When an agent is asked to **analyze and improve** a repo's agent setup, follow this checklist:

### 1. Inventory existing files

- [ ] `AGENTS.md` — exists? Has recommended sections?
- [ ] `.github/copilot-instructions.md` — exists?
- [ ] `.github/instructions/*.instructions.md` — any contextual instructions?
- [ ] `.github/agents/*.md` — any custom agent personas?
- [ ] `.github/prompts/*.prompt.md` — any reusable prompts?
- [ ] `.cursor/` or other tool-specific configs — anything that should be ported?
- [ ] `docs/` — detailed documentation that could feed contextual instructions?

### 2. Evaluate AGENTS.md quality

Check coverage of the six core areas (see [Six Core Areas](#six-core-areas)):

- [ ] **Project description** with negative scope (what the project is NOT)
- [ ] **Tech stack** with exact versions
- [ ] **Commands** — exact, executable, with flags
- [ ] **Testing** — framework, run command, coverage expectations
- [ ] **Project structure** with directory table
- [ ] **Code style** — at least one canonical code example
- [ ] **Git workflow** — commit conventions, branch strategy
- [ ] **Boundaries** with ✅/⚠️/🚫 levels
- [ ] **Links to detail docs** (not inline — keeps AGENTS.md lean)
- [ ] No broken references to files that don't exist

### 3. Identify areas for contextual instructions

Look for distinct areas with different conventions:
- Different directories with different patterns (e.g., `backend/` vs `frontend/`)
- Different tech within the same repo (e.g., Go API vs React SPA)
- Each area should get its own `.instructions.md` with code examples

### 4. Identify candidates for custom agents

Consider agents for specialised, repeatable roles:
- Documentation writing (reads code, writes Markdown)
- Test creation (writes tests, never modifies source code)
- Linting/formatting (fixes style, never changes logic)

### 5. Identify recurring tasks for prompts

Look for tasks that happen repeatedly and follow a fixed pattern:
- Scaffolding new artifacts (components, endpoints, pages)
- Multi-step workflows (analyze → plan → implement)

### 6. Propose changes, then implement

Present findings as a decision list. Implementation order:
1. Fix broken references in AGENTS.md
2. Add missing AGENTS.md sections (boundaries, negative scope)
3. Create `.github/copilot-instructions.md`
4. Create contextual instructions (one per area)
5. Create prompts (highest-value recurring task first)

---

## AGENTS.md

Root-level file read by VS Code Agent Mode on every request. Contains everything an agent needs to work autonomously.

### Recommended sections

```markdown
# Agent Instructions — <project-name>

<One paragraph: what the project IS and what it explicitly is NOT.>

## Tech Stack

| Component | Technology                        |
| --------- | --------------------------------- |
| Backend   | Go 1.24, net/http, pgx/v5        |
| Frontend  | React 19, Vite 6, TypeScript 5.7 |
| Database  | PostgreSQL 17                     |
| Runtime   | Docker Compose, nginx             |

## Commands

| Command      | Description                    |
| ------------ | ------------------------------ |
| `make test`  | Run all tests                  |
| `make lint`  | Lint all code                  |
| `make build` | Build all artifacts            |
| `make dev`   | Start dev stack (Docker)       |

Include flags and options, not just tool names. The agent will reference these often.

## Testing

- Framework: Go `testing` + testify (backend), Vitest + Testing Library (frontend)
- Run: `make test` (all), `go test ./backend/...` (backend only)
- Every test must have meaningful assertions. No tautological tests.

## Boundaries

- ✅ **Always:** run tests after changes, validate both sides
- ⚠️ **Ask first:** add dependencies, change DB schema, modify shared config
- 🚫 **Never:** edit generated code, commit secrets, bypass CI checks

## Project Structure

| Path        | Purpose              |
| ----------- | -------------------- |
| `backend/`  | Go API server        |
| `frontend/` | React SPA            |
| `scripts/`  | Build & deploy tools |

## Git Workflow

- Conventional Commits in English (`feat:`, `fix:`, `docs:`)
- Feature branches off `main`
- No `--force` push or `--no-verify`

## More

- [Backend conventions](docs/backend.md)
- [Frontend patterns](docs/frontend.md)

IMPORTANT: Prefer retrieval-led reasoning over pre-training-led reasoning
for topics covered in the linked documentation.
```

### Best practices

- **Put commands early** — the agent references these constantly. Include flags and options, not just tool names.
- **Include what the project is NOT** — prevents agents from adding out-of-scope features. Example: _"This is NOT an installable library — artifacts are generated, not imported."_
- **Exact versions** in the tech stack — say "React 19 with TypeScript 5.7, Vite 6, Tailwind CSS 4" not "React project." Prevents agents from suggesting outdated APIs.
- **Boundaries with three levels** (✅/⚠️/🚫) — more effective than soft guidelines. Agents respect explicit prohibitions better than suggestions.
- **Code examples over explanations** — one real code snippet showing your style beats three paragraphs describing it. Show what good output looks like.
- **Link to detail docs, don't inline them** — keeps AGENTS.md under ~150 lines. Detailed conventions belong in `docs/` files or contextual instructions.
- **End with retrieval directive** — tell agents to read linked docs rather than rely on training data.

---

## .github/copilot-instructions.md

Compact subset of AGENTS.md. Loaded by Copilot in every mode (Chat, Inline, Agent). Keep it short — this file counts against token budget on **every** request.

```markdown
# <project> — Copilot Instructions

<One-line project description.>
Full agent instructions: see AGENTS.md in the project root.

## Rules

1. Most critical rule.
2. Second critical rule.
...
```

### What belongs here

Only rules that apply **everywhere** — things the agent must never get wrong regardless of which file it's editing:

- Package manager constraints (e.g., "use pnpm, never npm")
- Import conventions (e.g., "use `import type` for type-only imports")
- Generated file warnings (e.g., "never edit files with a generated header")
- Naming conventions that apply project-wide

### What does NOT belong here

- Area-specific patterns (put in contextual instructions)
- Detailed code examples (put in contextual instructions)
- Full project structure (already in AGENTS.md)

---

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

- **Test:** `make test`
- **Lint:** `make lint-backend`

## Directory layout

backend/
  api/          # HTTP handlers
  domain/       # Business logic
  repository/   # Data access

## Patterns

<Describe patterns with concise rules.>

## Code example: <canonical artifact>

<Full, copy-paste-ready code example showing THE canonical way to do things.>
```

### Best practices

- **One file per area** — `backend.instructions.md`, `frontend.instructions.md`, `database.instructions.md`. Identify areas by directory structure and distinct conventions.
- **Code examples are the most effective tool** — an agent that sees a complete handler example will replicate the pattern exactly. Prose rules alone are often ignored or misinterpreted. Include at least one full canonical example per area.
- **Include directory layout** — agents need to know where files go.
- **List relevant commands** — so the agent runs the right check after making changes.
- Use `applyTo` to limit scope — `backend/**`, `frontend/**`, `scripts/**`.
- Files without `applyTo` (e.g. `new-feature.instructions.md`) are loaded based on `description` match.
- **Pull from existing docs** — if the repo already has detailed docs (e.g., `docs/testing.md`), extract the most important rules and one code example into the instructions file. Link to the full doc for details.

---

## .github/agents/*.md

Custom agent personas invoked via `@agent-name` in Copilot Chat. Each file defines a specialist with a specific role, constraints, and tools. Unlike `AGENTS.md` (which instructs the general agent), these create **focused specialists** that excel at one job.

### Structure

```markdown
---
name: test-agent
description: "Writes and maintains unit tests for this project"
---

You are a QA engineer for this project.

## Your role
- You write comprehensive tests: unit, integration, and edge cases
- You understand the test framework and follow the project's testing conventions
- You never modify source code — only test files

## Project knowledge
- **Test framework:** Vitest + Testing Library
- **Test location:** `tests/`
- **Run tests:** `npm test`
- **Lint:** `npm run lint`

## Standards
- Every `it()` block must contain a meaningful `expect()` assertion
- Test the behaviour, not the implementation
- Group related tests with `describe()`

## Boundaries
- ✅ **Always:** Write to `tests/`, run tests after changes
- ⚠️ **Ask first:** Before adding test dependencies
- 🚫 **Never:** Modify source code in `src/`, remove failing tests
```

### When to use custom agents vs contextual instructions

- **Custom agents** — for _roles_ (docs writer, test engineer, security reviewer). They define a persona and can be invoked explicitly.
- **Contextual instructions** — for _areas_ of the codebase (backend, frontend, database). They load automatically based on which files are being edited.

### Best practices

- **Specific persona over general helper** — "Expert test engineer who writes Vitest tests" works. "Helpful coding assistant" does not.
- **Give agents tools** — include the exact commands the agent can run to validate its own work.
- **Tight boundaries** — each agent should have a clear "write zone" and "never touch" zone.
- **Start with one agent** — pick the simplest repeatable task (docs, tests, linting). Add more as needed.

---

## .github/prompts/*.prompt.md

Reusable prompts invoked via `/prompt-name` in Copilot Chat. Useful for recurring multi-step tasks.

### Scaffolding prompts

Automate the creation of new standardised artifacts (components, endpoints, pages). Adapt the steps to your project:

```markdown
---
description: "Scaffolds a new API endpoint with all layers."
---

# New Endpoint

## Input

- **Domain**: e.g. product, user, order
- **Endpoint name**: e.g. create-product, get-user
- **Method**: GET, POST, PUT, DELETE

## Steps

1. Create handler in `src/handlers/{domain}/{endpoint}.ts`
2. Add route registration in `src/routes/{domain}.ts`
3. Create request/response types in `src/types/{domain}.ts`
4. Create test file `tests/handlers/{domain}/{endpoint}.test.ts`
5. Run `npm test && npm run lint`
```

### Analyze → Plan → Implement workflow

A three-phase workflow for complex features, designed for iterative agent execution:

**Phase 1 — `/analyze`**: Agent researches codebase, writes `docs/agents/<slug>/analyze.md`.
- Pure analysis — no code changes, no implementation planning.
- Documents existing patterns, dependencies, and relevant code locations with precise `file:line` references.
- An agent in a new session must be able to find every referenced location without further research.

**Phase 2 — `/plan`**: Agent converts analysis into `plan.md` with implementation details and checkbox tasks.
- Derives concrete implementation steps (the _what_ and _how_) from the analysis.
- Groups tasks into sections (e.g. by layer: Domain, Repository, Handler, Frontend).
- Each section has a `Kontext:` block listing exactly which files and line ranges the agent must read before starting that section.
- Includes parallelisation hints (which sections can run concurrently).
- Embeds agent instructions directly in the file (context loading, section claiming, task workflow, commit message).
- **No pure context-loading sections** — every section must produce real output. Context loading belongs in the per-section `Kontext:` block, not in a separate section.

**Phase 3 — `/implement`**: Agent claims and works through one section.
- Selects the next available section, claims it with 🔒.
- **Loads context from the section's `Kontext:` block** — reads exactly those files, not more.
- Follows the agent instructions embedded in `plan.md` for task workflow and completion.
- Multiple agents can work in parallel on independent sections.
- Each agent runs build/lint/tests after completing a section.

```
docs/agents/<slug>/
  analyze.md     # Analysis — what exists, patterns, dependencies
  plan.md        # Atomic task list with per-section context
```

Co-ordination happens through file markers:

| Marker | Meaning                       |
| ------ | ----------------------------- |
| (none) | Available                     |
| 🔒      | Claimed — agent working on it |
| ✅      | Done — all tasks checked off  |

This workflow is most valuable for **code projects with multi-step features**. For documentation-only projects, a lightweight variant works better.

### Lightweight variant (single-file plan)

For smaller projects or documentation repos, collapse the three phases into one:

1. A single `/plan` prompt creates `plan.md` in the project root with goal, affected files, and a **checkbox task list** (analysis + task breakdown combined).
2. The agent (or user) works through the checklist step by step, ticking off each item.
3. After all steps: verify links, confirm index files are up to date.
4. Delete `plan.md` when done.

---

## Best Practices Summary

1. **Concrete over abstract** — one real code snippet showing your style beats three paragraphs describing it. Agents follow examples far more reliably than prose rules.
2. **Cover the six core areas** — commands, testing, project structure, code style, git workflow, and boundaries. Hitting all six puts you in the top tier.
3. **Put commands early** — agents reference these constantly. Include flags and options, not just tool names.
4. **Boundaries over suggestions** — ✅/⚠️/🚫 matrices are more effective than "try to" guidelines. "Never commit secrets" is the most common helpful constraint.
5. **Be specific about your stack** — say "React 19 with TypeScript 5.7, Vite 6" not "React project." Include versions and key dependencies.
6. **Negative scope** — state what the project is NOT and what agents must NEVER do. Prevents scope creep.
7. **Layer the context** — always-loaded files stay small; detail goes into contextual instructions loaded only when relevant.
8. **Single source of truth** — `copilot-instructions.md` extracts from `AGENTS.md`, never contradicts it.
9. **Start simple, iterate** — begin with a minimal `AGENTS.md`. Add detail when the agent makes mistakes. The best agent files grow through iteration, not upfront planning.
10. **Don't over-layer** — add contextual instructions, agents, and prompts only when they solve a real pain point. A single good `AGENTS.md` beats four mediocre files.
11. **Keep cross-references alive** — if `AGENTS.md` links to a file, that file must exist. Broken references erode agent trust in the instructions.
12. **Test the setup** — ask the agent to explain the project rules back to you. If it gets something wrong, the instructions need clarification.
