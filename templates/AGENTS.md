# Agent Instructions — <project-name>

# <One-paragraph project description.>
# <Include what the project IS and what it explicitly is NOT.>

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Backend   | <language, framework, key libraries> |
| Frontend  | <framework, bundler, language> |
| Database  | <engine, version> |
| Runtime   | <Docker, etc.> |

## Commands

# All commands via Makefile in the project root.

| Command | Description |
|---------|------------|
| `make dev` | Start dev stack |
| `make test` | Run all tests |
| `make lint` | Lint all code |
| `make build` | Build all artifacts |

# Run `make help` for the full list.

## Rules

# Numbered, hard rules the agent must always follow.
# Add project-specific rules here.

1. <First rule.>
2. <Second rule.>

## Boundaries

- ✅ **Always:** Verify before claiming — search the codebase before making assertions about existing code, structure, or behaviour. Never guess what a file contains or how something works — read the actual source.
- ✅ **Always:** Ask instead of assuming — when uncertain about requirements, design intent, or user expectations, ask structured questions to clarify. Only proceed with documented assumptions if the user explicitly declines to answer.
- ✅ **Always:** Web search for external knowledge — when working with external tools, libraries, or specs, consult authoritative sources (official docs, RFCs) instead of relying on training data.
- ✅ **Always:** <things the agent must do on every change>
- ✅ **Always:** <second always-rule>
- ⚠️ **Ask first:** <actions that need user confirmation>
- ⚠️ **Ask first:** <second ask-first rule>
- 🚫 **Never:** <hard prohibitions>
- 🚫 **Never:** <second prohibition>

## Quality Principles

- **Quality over quantity, correctness over speed.** Fewer, correct changes beat many fast changes.
- **Human-reviewable changes.** Every change must be clean, readable, and maintainable enough for a senior developer to review, understand, and maintain long-term. No clever code, no unnecessary abstractions, no changes that require deep context to understand.
- **Self-review checklist** (run silently before presenting changes — only report issues found in the chat):
  1. Are the changes **correct** — do they actually solve the stated problem?
  2. Are the changes **clean** — no dead code, no debug artifacts, consistent style?
  3. Are the changes **readable** — would a human reviewer understand them without extra explanation?
  4. Are the changes **maintainable** — no over-engineering, no unnecessary abstractions?
  5. Are the changes **in scope** — nothing beyond what was requested or clearly necessary?
  6. Are the changes **complete** — tests, validation, both sides updated where needed?
- **Scope guard.** If the agent notices it is making or about to make changes outside the task scope, it must stop, name the out-of-scope changes, and ask the user before proceeding.

## Areas

# Optional — describe the main areas/modules of the project.

# - **Admin**: routes `/admin/*`, directory `src/admin/`
# - **API**: routes `/api/*`, directory `src/api/`

## Git Workflow

- **Commit messages:** After completing a task, always propose a conventional commit message (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`) with a concise subject line and bullet-point body for multi-file changes. Do not commit — only output the message.
- **Reviewer summary.** After every completed task, the agent posts — in addition to the commit message — a narrative paragraph explaining: what was changed, why, and what the reviewer should pay attention to. The summary language matches the conversation language. The summary is written for a senior developer who wants to quickly understand intent and impact without reading every diff line.
- **No `--force` push or `--no-verify`.**
