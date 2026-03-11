---
description: "Use when editing or creating quick-reference cheatsheets in the cheatsheets/ directory."
applyTo: "cheatsheets/**"
---

# Cheatsheet Conventions

## Format

- **Tables or commented code blocks** — optimised for fast scanning.
- No explanatory paragraphs. Minimal prose.
- Group related commands under `##` section headings.
- Every command in a fenced `bash` block or table cell, copy-paste-ready.

## Content rules

- One topic per file.
- Link to guides for step-by-step walkthroughs instead of duplicating instructions.
- Include the source URL when the cheatsheet is based on an external resource.

## File naming

`<topic>.md` — lowercase, hyphens. Example: `docker-compose.md`.

## After creating or renaming a cheatsheet

1. Add or update the entry in `README.md` (Cheatsheets table).
2. Search for references to the old filename: `grep -r '<old-name>' .`
