# GitHub Copilot Agent Mode — Project Setup

How to configure a repository so GitHub Copilot (Agent Mode, Chat, Inline) understands the project, follows conventions, and produces consistent code. This guide doubles as a checklist an agent can follow to **audit and improve** any existing repo's agent setup.

Based in part on lessons from [How to write a great agents.md](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/) — an analysis of 2,500+ repositories.

## Overview

Six layers of context, loaded at different times:

| Layer                       | File                                     | Loaded when                                          | Token cost      |
| --------------------------- | ---------------------------------------- | ---------------------------------------------------- | --------------- |
| **Root instructions**       | `AGENTS.md`                              | Every Copilot surface — always                       | High (full)     |
| **Copilot instructions**    | `.github/copilot-instructions.md`        | Copilot Chat / Inline / Agent — always               | Low (compact)   |
| **Contextual instructions** | `.github/instructions/*.instructions.md` | Automatically, when editing files matching `applyTo` | Per-area        |
| **Skills**                  | `.github/skills/<name>/SKILL.md`         | Loaded on demand when a task matches the skill       | Zero until used |
| **Custom agents**           | `.github/agents/*.agent.md`              | When invoked by name (agent picker / `@name`)        | Zero until used |
| **Reusable prompts**        | `.github/prompts/*.prompt.md`            | On demand (`/prompt-name` in chat)                   | Zero until used |

`AGENTS.md` is read by every Copilot surface (Chat, Inline, Agent Mode, code review, cloud agent, and Copilot CLI). One agent file at the repo root is the norm; nested `AGENTS.md` files apply to their subtree and the nearest file wins. A root `CLAUDE.md` is only a fallback when no `AGENTS.md` is present — do not maintain both with different content.

Design principle: **layer context from always → contextual → on-demand** so the agent gets the right information at the right time without wasting token budget.

### When to add each layer

Not every project needs all six layers. Add them incrementally:

| Project shape                                         | Recommended layers                                            |
| ----------------------------------------------------- | ------------------------------------------------------------- |
| Small / single-area                                   | `AGENTS.md` only                                              |
| Multi-area (backend + frontend, library + docs site)  | + `.github/copilot-instructions.md` + contextual instructions |
| Reusable expertise across tools (a repeatable workflow)| + skills                                                      |
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
- [ ] `.github/skills/<name>/SKILL.md` — any reusable skills?
- [ ] `.github/agents/*.agent.md` — any custom agent personas? (legacy `.chatmode.md` files should be renamed)
- [ ] `.github/prompts/*.prompt.md` — any reusable prompts?
- [ ] `.github/workflows/copilot-setup-steps.yml` — cloud-agent environment setup present if the agent needs tooling/deps?
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

### 4. Identify candidates for skills

Consider a skill for a reusable, self-contained workflow that should behave the same across tools (VS Code, Copilot CLI, cloud agent, code review):
- A repeatable review or refactor pass (readability review, test-suite cleanup)
- A domain workflow with its own steps and reference material

Skills are portable across agents; a custom agent is repo- and Copilot-specific. Prefer a skill when the workflow is not tied to a single tool.

### 5. Identify candidates for custom agents

Consider agents for specialised, repeatable roles:
- Documentation writing (reads code, writes Markdown)
- Test creation (writes tests, never modifies source code)
- Linting/formatting (fixes style, never changes logic)

### 6. Identify recurring tasks for prompts

Look for tasks that happen repeatedly and follow a fixed pattern:
- Scaffolding new artifacts (components, endpoints, pages)
- Multi-step workflows (analyze → plan → implement)

### 7. Propose changes, then implement

Present findings as a decision list. Implementation order:
1. Fix broken references in AGENTS.md
2. Add missing AGENTS.md sections (boundaries, negative scope)
3. Create `.github/copilot-instructions.md`
4. Create contextual instructions (one per area)
5. Create skills for portable, tool-agnostic workflows
6. Create custom agents for specialised roles
7. Create prompts (highest-value recurring task first)

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
| Backend   | Go 1.26, net/http, pgx/v5        |
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

For topics covered in the linked documentation, prefer reading those docs over
relying on training data.
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

Copilot loads both `AGENTS.md` and this file (combined) on every request, so **do not restate AGENTS.md rules here** — that only wastes token budget and creates two copies to keep in sync. This file holds **Copilot-only deltas**, or is omitted entirely when there are none.

```markdown
# <project> — Copilot Instructions

<One-line project description.>
Shared rules live in AGENTS.md (Copilot loads it too). Only Copilot-specific notes below.

## Rules

1. First Copilot-only rule.
2. Second Copilot-only rule.
...
```

### What belongs here

Only Copilot-specific deltas that are not already in `AGENTS.md`:

- Pointers to `.github/prompts/` and `.github/instructions/` if the project relies on them.
- Copilot-surface caveats (e.g. a rule that only applies in Copilot code review).

### What does NOT belong here

- Any rule already in `AGENTS.md` (Copilot reads it — no need to repeat).
- Area-specific patterns (put in contextual instructions).
- Detailed code examples (put in contextual instructions).
- Full project structure (already in AGENTS.md).

If there are no Copilot-only deltas, delete this file rather than duplicating `AGENTS.md`.

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
- **`applyTo` is required** — every instructions file needs an `applyTo` glob (e.g. `backend/**`, `frontend/**`, `scripts/**`) that scopes where it loads. Use `applyTo: "**"` for repo-wide instructions.
- Use `excludeAgent: "code-review"` or `excludeAgent: "cloud-agent"` to hide a file from a specific Copilot agent; without it, every agent loads the file.
- **Pull from existing docs** — if the repo already has detailed docs (e.g., `docs/testing.md`), extract the most important rules and one code example into the instructions file. Link to the full doc for details.

---

## .github/skills/<name>/SKILL.md

Skills are reusable, self-contained workflows defined as a `SKILL.md` file (with optional bundled reference files) in a per-skill directory. They follow the cross-tool [Agent Skills](https://agentskills.io) open standard, so the same skill works in Claude Code, Cursor, Codex CLI, and GitHub Copilot.

### Locations Copilot reads

| Location            | Scope                                  |
| ------------------- | -------------------------------------- |
| `.github/skills/`   | Repo skills (Copilot code review, cloud agent, VS Code, CLI) |
| `.claude/skills/`   | Personal + project skills (also read by VS Code Copilot) |
| `.agents/skills/`   | Personal skills for Copilot CLI (`~/.agents/skills`)   |

Agent Skills are generally available across the Copilot cloud agent, Copilot code review, Copilot CLI, and agent mode in VS Code and JetBrains.

For **personal** skills (in `$HOME`, not committed) the read paths differ per surface: VS Code reads `~/.copilot/skills`, `~/.claude/skills`, and `~/.agents/skills`; Copilot CLI reads only `~/.copilot/skills` and `~/.agents/skills` — not `~/.claude/skills`. A `~/.claude/skills` symlink covers Claude Code and VS Code but is invisible to Copilot CLI, so add a second `~/.agents/skills` symlink to cover the CLI too.

### Structure

```markdown
---
name: skill-name
description: "Reviews test suites for implementation-detail tests and redundancy."
---

# Skill Name

## Workflow

1. Numbered steps the agent follows.

## Constraints

- Hard rules and scope guards.
```

Bundled reference files (`REFERENCE.md`, `<topic>.md`) load only when the skill runs, keeping the always-loaded surface small.

### When to use a skill vs a custom agent

- **Skill** — for a portable, tool-agnostic *workflow* that should behave the same everywhere. Prefer this by default.
- **Custom agent** — for a Copilot-specific *persona/role* that a user invokes explicitly.

---

## .github/agents/*.agent.md

Custom agent personas selected from the agent picker (or invoked by name) in Copilot. Each file defines a specialist with a specific role, constraints, and tools. Unlike `AGENTS.md` (which instructs the general agent), these create **focused specialists** that excel at one job. The same `.agent.md` file works for the Copilot cloud agent and Copilot CLI.

> **Rename note:** the earlier `.chatmode.md` (custom chat mode) format is superseded by `.agent.md`. Rename existing `.chatmode.md` files to `.agent.md` and place them in `.github/agents/`; legacy files in `.github/chatmodes/` still load but should be migrated.

### Structure

```markdown
---
name: test-agent
description: "Writes and maintains unit tests for this project."
# Optional fields:
# tools: ["read", "edit", "search", "some-mcp-server/tool-1"]  # omit = all tools; [] = none
# mcp-servers: {}          # MCP server configs available to this agent
# model: <model id>        # pin a model
# target: <surface>        # which Copilot surface the agent targets
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

- Name the file `<name>.agent.md`; the `<name>` part becomes the agent's identifier and may only contain `.`, `-`, `_`, and alphanumerics.
- `description` is **required**; `name` and the rest are optional.
- The Markdown body (the prompt) is limited to **30,000 characters**.

### When to use custom agents vs contextual instructions

- **Custom agents** — for _roles_ (docs writer, test engineer, security reviewer). They define a persona and can be invoked explicitly.
- **Contextual instructions** — for _areas_ of the codebase (backend, frontend, database). They load automatically based on which files are being edited.

### Best practices

- **Specific persona over general helper** — "Expert test engineer who writes Vitest tests" works. "Helpful coding assistant" does not.
- **Give agents tools** — scope the `tools` list to what the agent needs; include the exact commands it can run to validate its own work.
- **Tight boundaries** — each agent should have a clear "write zone" and "never touch" zone.
- **Start with one agent** — pick the simplest repeatable task (docs, tests, linting). Add more as needed.

---

## .github/prompts/*.prompt.md

Reusable prompts invoked via `/prompt-name` in Copilot Chat. Useful for recurring multi-step tasks. These are an **IDE-only preview** feature (VS Code / JetBrains) — they are not loaded by the cloud agent or Copilot CLI. The optional `agent:` frontmatter field (formerly `mode:`) selects which agent runs the prompt: `ask`, `agent`, `plan`, or a custom agent name.

### Scaffolding prompts

Automate the creation of new standardised artifacts (components, endpoints, pages). Adapt the steps to your project:

```markdown
---
description: "Scaffolds a new API endpoint with all layers."
agent: agent
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
8. **Single source of truth** — `AGENTS.md` carries the shared rules; Copilot loads it on every surface. `copilot-instructions.md` holds only Copilot-only deltas (or is deleted), never a restatement of `AGENTS.md`.
9. **Start simple, iterate** — begin with a minimal `AGENTS.md`. Add detail when the agent makes mistakes. The best agent files grow through iteration, not upfront planning.
10. **Don't over-layer** — add contextual instructions, agents, and prompts only when they solve a real pain point. A single good `AGENTS.md` beats four mediocre files.
11. **Keep cross-references alive** — if `AGENTS.md` links to a file, that file must exist. Broken references erode agent trust in the instructions.
12. **Test the setup** — ask the agent to explain the project rules back to you. If it gets something wrong, the instructions need clarification.

---

See also:
- [templates/AGENTS.md](../templates/AGENTS.md) — agent instructions template
- [templates/copilot-instructions.md](../templates/copilot-instructions.md) — copilot instructions template
