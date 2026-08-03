---
description: "Conventions for editing or creating bash scripts in the scripts/ directory."
paths: "scripts/**"
---

# Script Conventions

## Header

Every script starts with:

```bash
#!/usr/bin/env bash
# <script-name>.sh – one-line description
#
# Usage:
#   <how to run it>
#
# What it does:
#   1. ...
#   2. ...

set -euo pipefail
```

## Style

- Use a `log()` helper for status output (coloured prefix); quote all variables: `"$var"`, not `$var`; use `[[ ]]` for conditionals.
- Make scripts **idempotent** — safe to run multiple times; provide configurable values at the top as env-var defaults: `VAR="${VAR:-default}"`.
- `set -euo pipefail` is mandatory.
- Guard destructive operations with pre-flight checks (e.g. root check, required env vars).
- Name files `<verb>-<noun>.sh` — lowercase, hyphens. Example: `setup-server.sh`.
- Hard caps: sentence ≤ 20 words, one claim; paragraph ≤ 3 lines; bullet ≤ 2 lines.
- Use a table or list before a paragraph — full contract: [output-style.md](../skills/output-style.md).

## After creating or renaming a script

Ensure the script is executable: `chmod +x scripts/<name>.sh`.
