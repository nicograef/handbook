---
description: "Conventions for editing or creating config templates in the templates/ directory."
paths: "templates/**"
---

# Template Conventions

## Requirements

- **Functional as-is** — copy the file into a project and use it immediately.
- Fill in clearly marked placeholders before use.
- **Optional sections commented out** with a short explanation above each block.
- **Placeholder values** use `<angle-bracket>` notation: `<your-domain>`, `<db-password>`.
- **Cross-referenced** — link the template from, or link to, the guide that consumes it.

## Style

- Keep inline comments short — explain *why*, not *what*.
- Group related settings with a section header comment (`# ── Section ──`).
- Prefer sensible defaults over empty values.
- Hard caps: sentence ≤ 20 words, one claim; paragraph ≤ 3 lines; bullet ≤ 2 lines.
- Use a table or list before a paragraph — full contract: [output-style.md](../skills/output-style.md).

## File naming

Use the real filename the template represents: `docker-compose.yml`, `Makefile`, `nginx-tls.conf`.
