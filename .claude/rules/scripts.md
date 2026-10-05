---
description: "Conventions for bash scripts in scripts/, templates/ and skill directories."
paths:
  - "scripts/**"
  - "templates/*.sh"
  - ".claude/skills/**/*.sh"
---

# Script conventions

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

- Idempotent; configurable values as env-var defaults at the top (`VAR="${VAR:-default}"`); a `log()` helper for status output; pre-flight checks before anything destructive.
- Quote every variable, use `[[ ]]`; `make lint` runs shellcheck.
- File name lowercase with hyphens, verb first for a one-shot task (`backup-postgres.sh`), noun for a tool or hook (`agent-bus.sh`); executable (`chmod +x`).
