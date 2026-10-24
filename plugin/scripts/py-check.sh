#!/usr/bin/env bash
# py-check.sh – PostToolUse Edit/Write hook that formats an edited .py file and checks it with the project's own ruff and ty.
#
# Usage:
#   plugin/scripts/py-check.sh < payload.json   # a PostToolUse hook; exit 2 feeds the findings back on stderr
#
# What it does:
#   1. Reads .tool_input.file_path from the payload; exits 0 unless it is an existing .py file.
#   2. Finds the nearest ancestor holding pyproject.toml; exits 0 unless it has .venv/bin/ruff.
#   3. From that root runs ruff format, then ruff check and, if .venv/bin/ty exists, ty check.
#      No ruff check --fix: F401 would delete an import one edit adds and the next edit uses.
#   4. On any failure prints the tools' output to stderr and exits 2. The edit is already applied.

set -euo pipefail

file="$(jq -r '.tool_input.file_path // empty')"
[[ "$file" == *.py && -f "$file" ]] || exit 0
file="$(realpath "$file")"

root="$(dirname "$file")"
while [[ ! -f "$root/pyproject.toml" ]]; do
  [[ "$root" == / ]] && exit 0
  root="$(dirname "$root")"
done
[[ -x "$root/.venv/bin/ruff" ]] || exit 0
cd "$root"

out=""
status=0
run() { # run <cmd...>: append the output of a failing command to out
  local o
  if ! o="$("$@" 2>&1)"; then
    out+="\$ $*"$'\n'"$o"$'\n'
    status=1
  fi
}

run .venv/bin/ruff format --quiet "$file"
run .venv/bin/ruff check --quiet "$file"
[[ -x .venv/bin/ty ]] && run .venv/bin/ty check "$file"

if [[ "$status" -ne 0 ]]; then
  printf "py-check: the project's gate fails on the edited file %s\n%s" "$file" "$out" >&2
  exit 2
fi
