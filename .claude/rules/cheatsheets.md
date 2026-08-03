---
description: "Conventions for editing or creating cheatsheets in the cheatsheets/ directory."
paths: "cheatsheets/**"
---

# Cheatsheet Conventions

## Format

- Tables or commented code blocks, optimised for fast scanning — no explanatory paragraphs, minimal prose.
- Group related commands under `##` section headings; every command in a fenced `bash` block or table cell, copy-paste-ready.

## Content rules

- One topic per file; link to guides for step-by-step walkthroughs instead of duplicating instructions.
- Include the source URL when the cheatsheet is based on an external resource.
- Hard caps: sentence ≤ 20 words, one claim; paragraph ≤ 3 lines; bullet ≤ 2 lines.
- Use a table or list before a paragraph — full contract: [output-style.md](../skills/output-style.md).

## File naming

`<topic>.md` — lowercase, hyphens. Example: `docker-compose.md`.
