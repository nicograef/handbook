---
description: "Conventions for guides in guides/."
paths: "guides/**"
---

# Guide conventions

- Runbooks only; reference material lives in `reference/`.
- One task per runbook, 50 to 150 lines.
- **Prerequisites** before the first step, numbered steps, every command in a fenced `bash` block, `diff` blocks for config changes. A **Verify** section (command plus expected output) follows the steps; **Troubleshooting**, if any, comes after it.
- Each step is one action plus its expected result.
- A list holds parallel items only; reasoning is a short paragraph.
- Headings name tasks, never numbers. Links target headings, never another file's step number.
- Placeholders are `<angle-brackets>` everywhere, Verify blocks included.
- Agent vocabulary (gate, lane, fold, lead) stays out of runbooks.
- Cite the source URL when a guide is based on an external resource.
- File name `<topic>.md`, lowercase, hyphens, no numbering.
