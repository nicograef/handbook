---
description: "Use when editing or creating step-by-step guides in the guides/ directory."
applyTo: "guides/**"
---

# Guide Conventions

## Format

- **Runbook-style** — numbered steps a reader can follow top-to-bottom.
- Every command in a fenced `bash` block, copy-paste-ready.
- Use `diff` blocks for config file changes.
- Start with **prerequisites** (OS, packages, access) before the first step.
- End with a **Verify** section (command + expected output).

## Content rules

- No explanatory prose — keep it scannable.
- Link to templates and scripts instead of inlining them: `[Makefile](../../templates/Makefile)`.
- Link to cheatsheets for quick-reference material instead of repeating it.
- Include the source URL when the guide is based on an external resource.

## File naming

`<topic>.md` — lowercase, hyphens, no numbering. Example: `docker-setup.md`.

## After creating or renaming a guide

1. Add or update the entry in `README.md` (Guides table).
2. Search for references to the old filename: `grep -r '<old-name>' .`
