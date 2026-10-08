---
description: "Conventions for guides in guides/ and reference pages in reference/."
paths:
  - "guides/**"
  - "reference/**"
---

# Guide and reference conventions

- Guides are runbooks; reference material lives in `reference/`. A reference page links the guide that holds its steps.
- One topic per file, named `<topic>.md`: lowercase, hyphens, no numbering.
- Cite the source URL when a page is based on an external resource.

## Guides

- One task per runbook, 50 to 150 lines.
- **Prerequisites** before the first step, numbered steps, every command in a fenced `bash` block, `diff` blocks for config changes. A **Verify** section (command plus expected output) follows the steps; **Troubleshooting**, if any, comes after it.
- Each step is one action plus its expected result.
- Headings name tasks, never numbers. Links target headings, never another file's step number.
- Placeholders are `<angle-brackets>` everywhere, Verify blocks included.
- Agent vocabulary (gate, lane, fold, lead) stays out of runbooks.

## Reference pages

- Command pages: tables or commented code blocks under `##` headings, copy-paste-ready. A short paragraph appears only where a command needs context.
- Rule pages (`stack-conventions.md`): short rule paragraphs under one `##` heading per stack, each rule with its reason.
