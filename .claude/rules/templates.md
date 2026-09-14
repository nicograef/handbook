---
description: "Conventions for config templates in templates/."
paths: "templates/**"
---

# Template conventions

- Functional as copied, after filling `<angle-bracket>` placeholders. Optional sections are commented out with one line saying when to enable them.
- Sensible defaults over empty values; section headers as `# ── Section ──`; comments explain why, not what.
- Use the real file name (`docker-compose.yml`, `Makefile`, `nginx-tls.conf`) and link the template from the guide that uses it.
