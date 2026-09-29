---
description: "Conventions for guides in guides/."
paths: "guides/**"
---

# Guide conventions

- Runbooks: **Prerequisites** before the first step, numbered steps, every command in a fenced `bash` block, `diff` blocks for config changes. A **Verify** section (command plus expected output) follows the steps; **Troubleshooting**, if any, comes after it.
- Convention guides (`stack-conventions.md`): rules grouped under headings or in tables, one line of rationale per rule.
- Link to templates, scripts and cheatsheets instead of inlining them. Cite the source URL when a guide is based on an external resource.
- File name `<topic>.md`, lowercase, hyphens, no numbering.
