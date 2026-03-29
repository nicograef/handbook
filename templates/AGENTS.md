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

## Areas

# Optional — describe the main areas/modules of the project.

# - **Admin**: routes `/admin/*`, directory `src/admin/`
# - **API**: routes `/api/*`, directory `src/api/`

## Git Workflow

- **Commit messages:** After completing a task, always propose a conventional commit message (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`) with a concise subject line and bullet-point body for multi-file changes. Do not commit — only output the message.
- **No `--force` push or `--no-verify`.**
