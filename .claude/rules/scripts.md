---
description: "Conventions for bash scripts and config templates in scripts/, templates/ and the plugin."
paths:
  - "scripts/**"
  - "templates/**"
  - "plugin/**/*.sh"
---

# Script and template conventions

## Scripts

Header, then `set -euo pipefail`:

```bash
#!/usr/bin/env bash
# <script-name>.sh – one-line description
#
# Usage:
#   <how to run it>
#
# What it does:
#   1. ...
```

- Idempotent; configurable values as env-var defaults at the top (`VAR="${VAR:-default}"`); pre-flight checks before anything destructive.
- File name lowercase with hyphens, verb first for a one-shot task (`backup-postgres.sh`), noun for a tool or hook (`agent-bus.sh`); executable (`chmod +x`).

## Templates

- Functional as copied, after filling `<angle-bracket>` placeholders. Optional sections are commented out with one line saying when to enable them.
- Sensible defaults over empty values; comments explain why, not what. A template split into sections marks each with `# ── Section ──`.
- Use the real file name (`docker-compose.yml`, `Makefile`, `Caddyfile`) and link the template from the guide that uses it.
- Variants of one file carry a suffix (`Dockerfile.python`, `Dockerfile.go`); the guide's copy step names the real target file (`<dir>/Dockerfile`).
