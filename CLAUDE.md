# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal knowledge base for infrastructure, server setup, and CLI workflows targeting Debian/Ubuntu. It contains no runnable application — all content is documentation, templates, scripts, and agent skills.

## Searching

```bash
grep -r '<term>' .          # search across all files
find . -name '*.md'         # list all Markdown files
```

## Language Rules

- All content is in **English** — no exceptions.
- **Exception:** `theory/` files are in German. Do not translate them.

## Content Conventions by Directory

### `guides/`
Runbook-style numbered steps. Every command in a fenced `bash` block. Use `diff` blocks for config changes. Start with prerequisites, end with a Verify section. No explanatory prose — optimise for scanning.

### `cheatsheets/`
Tables or commented code blocks only. No explanatory paragraphs. Group related commands under `##` headings.

### `templates/`
Must be functional as-is with `<angle-bracket>` placeholders. Optional sections commented out with a short explanation. Use the real filename the template represents (`docker-compose.yml`, `Makefile`).

### `scripts/`
Every script starts with `#!/usr/bin/env bash`, a one-line description comment, usage block, and `set -euo pipefail`. Use a `log()` helper for output, quote all variables, use `[[ ]]` for conditionals. Scripts must be idempotent. Filename: `<verb>-<noun>.sh`.

### `skills/`
Each skill in its own directory under `skills/<skill-name>/`. Every skill requires a `SKILL.md` with YAML frontmatter (`name`, `description`, optional `tools`), a **Workflow** section (numbered steps), and a **Constraints** section. Optional `REFERENCE.md` and additional `<topic>.md` files. Filename convention: `<verb-noun>/` or `<topic>/`, lowercase hyphens.

### `theory/`
Conceptual reference material in German. Self-contained per file, covering one topic comprehensively.

## Keeping the Repo Consistent

- `README.md` is the file index — update it after every add/remove/rename.
- Never duplicate content across files — cross-reference with relative links instead.
- After renaming or deleting a file, grep for all references and update them: `grep -r '<filename>' .`
- When a tool version changes, grep the whole repo and update every occurrence.

## Multi-File Changes: Plan-First Workflow

1. **Research** — read affected files, understand existing style and cross-references.
2. **Plan** — create `plan.md` in the project root: goal, affected files, step-by-step checklist.
3. **Execute** — work through the checklist, tick off each step immediately after completing it.
4. **Verify** — check links, confirm `README.md` is up to date, re-read changed files for consistency.
5. **Clean up** — delete `plan.md` when done.

For trivial single-file changes (typo fix, adding one section), skip the plan.

## Git

Propose a conventional commit message (`docs:`, `chore:`, `fix:`) after completing a task. Do not commit — only output the message. No `--force` push or `--no-verify`.
