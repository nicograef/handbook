---
description: "Conventions for bash scripts in scripts/."
paths: "scripts/**"
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
- File name `<verb>-<noun>.sh`, executable (`chmod +x`).
