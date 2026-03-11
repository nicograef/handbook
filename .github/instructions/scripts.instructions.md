---
description: "Use when editing or creating bash scripts in the scripts/ directory."
applyTo: "scripts/**"
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

- Use a `log()` helper for status output (coloured prefix).
- Quote all variables: `"$var"`, not `$var`.
- Use `[[ ]]` for conditionals.
- Make scripts **idempotent** — safe to run multiple times.
- Provide configurable values at the top as env-var defaults: `VAR="${VAR:-default}"`.

## Error handling

- `set -euo pipefail` is mandatory.
- Guard destructive operations with pre-flight checks (e.g. root check, required env vars).

## File naming

`<verb>-<noun>.sh` — lowercase, hyphens. Example: `setup-server.sh`.

## After creating or renaming a script

1. Add or update the entry in `README.md` (Scripts table).
2. Ensure the script is executable: `chmod +x scripts/<name>.sh`.
