# <project-name> — Copilot Instructions

# <One-line project description.>
# Full agent instructions: see `AGENTS.md` in the project root.

## Rules

# Keep this list short — only rules that apply everywhere.
# This file is loaded on every Copilot request (token budget).

1. <Most critical rule — e.g. "All API endpoints are POST-only.">
2. <Second rule — e.g. "Never use floats for money. Always cents (int).">
3. <Third rule — e.g. "Never edit generated code in `gen/`.">
4. <Fourth rule — e.g. "No secrets or passwords in code.">

## Quality Principles

- Quality over quantity, correctness over speed.
- Self-review before presenting: correct, clean, readable, maintainable, in scope.
- After every task, include a narrative summary paragraph for the reviewer.

## Commands

# All commands via **Makefile** in the project root: `make test`, `make lint`, `make build`, `make dev`.
# Run `make help` for the full list.
