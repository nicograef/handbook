---
description: "Use when editing or creating step-by-step guides in the guides/ directory."
applyTo: "guides/**"
---

# Guide Conventions

Guides come in two shapes. Identify which one a file is before editing it.

## Runbook guides

Step-by-step procedures a reader follows top-to-bottom (server provisioning, deploys, backups).

- Numbered steps in order.
- Every command in a fenced `bash` block, copy-paste-ready.
- Use `diff` blocks for config file changes.
- Start with **Prerequisites** (OS, packages, access) before the first step.
- End with a **Verify** section (command + expected output).

## Stack-convention guides

Reference guides that state coding conventions for a stack (`go.md`, `java-spring-boot.md`,
`react.md`). They are heading-grouped rules and tables, not procedures.

- Group rules under `##`/`###` headings, or use tables.
- Keep rationale to one line per rule.
- Open by naming the file a stack-convention guide; no runbook restructure is needed.

## Content rules

- No explanatory prose — keep it scannable.
- Link to templates and scripts instead of inlining them: `[Makefile](../templates/Makefile)`.
- Link to cheatsheets for quick-reference material instead of repeating it.
- Include the source URL when the guide is based on an external resource.

## File naming

`<topic>.md` — lowercase, hyphens, no numbering. Example: `docker-setup.md`.

## After creating or renaming a guide

1. Add or update the entry in `README.md` (Guides table).
2. Search for references to the old filename: `grep -r '<old-name>' .`
