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

1. <First rule.>
2. <Second rule.>

## Boundaries

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

- **Commit messages:** Conventional Commits in English (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`)
- **No auto-commit.** Agent proposes commit message, user commits.
- **No `--force` push or `--no-verify`.**
