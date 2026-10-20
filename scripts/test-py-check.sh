#!/usr/bin/env bash
# test-py-check.sh – fixture test for plugin/scripts/py-check.sh.
#
# Usage:
#   scripts/test-py-check.sh    # or: make test-py-check
#
# What it does:
#   1. Builds a scratch project under mktemp -d with stub .venv/bin/ruff and ty.
#      A stub fails when the file holds its marker (LINT_FAIL, TYPE_FAIL), so no real ruff is needed.
#   2. Feeds synthetic PostToolUse payloads and asserts the exit code and stderr.

set -euo pipefail

# shellcheck source=scripts/lib/test-harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/test-harness.sh"

HOOK="$REPO_ROOT/plugin/scripts/py-check.sh"
PROJ="$FIX/proj"
mkdir -p "$PROJ/.venv/bin" "$PROJ/src/pkg" "$FIX/loose"
touch "$PROJ/pyproject.toml"

stub() { # stub <name> <marker>: a tool that fails with "<name>: <marker>" when the last arg holds the marker
  cat > "$PROJ/.venv/bin/$1" <<STUB
#!/usr/bin/env bash
f="\${!#}"
if grep -q $2 "\$f"; then echo "$1: $2 in \$f"; exit 1; fi
echo "$1 ran" >> "$FIX/calls"
STUB
  chmod +x "$PROJ/.venv/bin/$1"
}
stub ruff LINT_FAIL
stub ty TYPE_FAIL

# expect <name> <code> <file> [stderr-substring]
expect() {
  local code=0 err
  : > "$FIX/calls"
  err="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$3" | bash "$HOOK" 2>&1 >/dev/null)" || code=$?
  if [[ "$code" -ne "$2" ]]; then fail "$1: expected exit $2, got $code ($err)"; return; fi
  if [[ -n "${4:-}" && "$err" != *"$4"* ]]; then fail "$1: stderr lacks '$4': $err"; return; fi
  log "$1 -> exit $code"
}

echo LINT_FAIL > "$PROJ/notes.txt"
expect "non-.py file" 0 "$PROJ/notes.txt"

echo LINT_FAIL > "$FIX/loose/x.py"
expect ".py without project venv" 0 "$FIX/loose/x.py"

expect "missing .py file" 0 "$PROJ/src/pkg/gone.py"

echo 'x = 1' > "$PROJ/src/pkg/clean.py"
expect "clean file" 0 "$PROJ/src/pkg/clean.py"
[[ "$(grep -c 'ty ran' "$FIX/calls")" -eq 1 ]] || fail "clean file: ty did not run"

echo LINT_FAIL > "$PROJ/src/pkg/lint.py"
expect "lint failure" 2 "$PROJ/src/pkg/lint.py" "ruff: LINT_FAIL"

echo TYPE_FAIL > "$PROJ/src/pkg/types.py"
expect "type failure" 2 "$PROJ/src/pkg/types.py" "ty: TYPE_FAIL"

rm "$PROJ/.venv/bin/ty"
expect "missing ty, type marker" 0 "$PROJ/src/pkg/types.py"
calls="$(cat "$FIX/calls")"
[[ "$calls" == $'ruff ran\nruff ran' ]] || fail "missing ty: expected ruff only, got: $calls"

finish
