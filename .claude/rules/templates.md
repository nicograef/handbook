---
description: "Conventions for editing or creating config templates in the templates/ directory."
paths: "templates/**"
---

# Template Conventions

## Requirements

- **Functional as-is** — a user must be able to copy the file into a project and use it
  immediately (after filling in clearly marked placeholders).
- **Optional sections commented out** with a short explanation above each block.
- **Placeholder values** use `<angle-bracket>` notation: `<your-domain>`, `<db-password>`.
- **Cross-referenced** — link the template from, or link to, the guide that consumes it.

## Style

- Keep inline comments short — explain *why*, not *what*.
- Group related settings with a section header comment (`# ── Section ──`).
- Prefer sensible defaults over empty values.

## File naming

Use the real filename the template represents: `docker-compose.yml`, `Makefile`, `nginx-tls.conf`.
