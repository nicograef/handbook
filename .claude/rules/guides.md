---
description: "Conventions for guides in guides/."
paths: "guides/**"
---

# Guide conventions

- Runbooks only; reference material lives in `reference/`.
- **Prerequisites** before the first step, numbered steps, every command in a fenced `bash` block, `diff` blocks for config changes. A **Verify** section (command plus expected output) follows the steps; **Troubleshooting**, if any, comes after it.
- Link to templates, scripts and reference pages instead of inlining them. Cite the source URL when a guide is based on an external resource.
- File name `<topic>.md`, lowercase, hyphens, no numbering.
