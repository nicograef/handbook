---
description: "Scaffolds a new copy-paste-ready config template, then updates README.md."
---

# New Template

Create a new template in `templates/`. Follow these steps in order:

## Input

- **Filename**: The real config filename (e.g. `docker-compose.yml`, `nginx.conf`)
- **Description**: One-line purpose of this template

## Steps

1. **Create the template file** at `templates/<filename>`:
   - Must be **functional as-is** (after filling in `<placeholders>`).
   - Group settings with section header comments (`# ── Section ──`).
   - Comment out optional sections with a short explanation above each block.
   - Use `<angle-bracket>` placeholders: `<your-domain>`, `<db-password>`.
2. **Update `README.md`** — add a row to the Templates table.
3. **Check guides** — if any existing guide covers this topic, add a cross-reference link.

## Conventions

- English only.
- Prefer sensible defaults over empty values.
- Inline comments explain *why*, not *what*.
