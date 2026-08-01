---
description: "Conventions for editing or creating guides in the guides/ directory."
paths: "guides/**"
---

# Guide Conventions

Guides come in two shapes. Identify which one a file is before editing it.

## Runbook guides

Step-by-step procedures a reader follows top-to-bottom (server provisioning, deploys, backups).

- Numbered steps in order; every command in a fenced `bash` block, copy-paste-ready; use `diff` blocks for config file changes.
- Start with **Prerequisites** (OS, packages, access) before the first step; end with a **Verify** section (command + expected output).

## Stack-convention guides

Reference guides that state coding conventions for a stack (`go.md`, `java-spring-boot.md`,
`react.md`). They are heading-grouped rules and tables, not procedures.

- Group rules under `##`/`###` headings, or use tables; keep rationale to one line per rule.
- Open by naming the file a stack-convention guide; no runbook restructure is needed.

## Content rules

- No explanatory prose — keep it scannable; link to templates and scripts instead of inlining them: `[Makefile](../templates/Makefile)`.
- Link to cheatsheets for quick-reference material instead of repeating it; include the source URL when the guide is based on an external resource.

## File naming

`<topic>.md` — lowercase, hyphens, no numbering. Example: `docker-setup.md`.
