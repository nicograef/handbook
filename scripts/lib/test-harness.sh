# shellcheck shell=bash
# test-harness.sh – shared setup and verdict for the scripts/test-*.sh fixture tests
#
# Usage (sourced right after set -euo pipefail, never run):
#   # shellcheck source=scripts/lib/test-harness.sh
#   . "$(dirname "${BASH_SOURCE[0]}")/lib/test-harness.sh"
#   ...assertions that call log and fail...
#   finish
#
# What it does:
#   1. Sets REPO_ROOT and FIX, a temp dir removed on exit after the test's cleanup().
#   2. Defines log for progress and fail, which marks the test failed.
#   3. finish prints the verdict and exits 1 if any fail ran.

# shellcheck disable=SC2034 # REPO_ROOT and FIX are for the sourcing test
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIX="$(mktemp -d)"
FAILED=0

# A test redefines cleanup to release what it holds beyond FIX.
cleanup() { :; }
trap 'cleanup; rm -rf "$FIX"' EXIT

log() { printf '\033[1;34m▸ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31mFAIL: %s\033[0m\n' "$*" >&2; FAILED=1; }

finish() {
  if [[ "$FAILED" -ne 0 ]]; then
    printf '\033[1;31m%s: FAILED\033[0m\n' "$(basename "$0" .sh)" >&2
    exit 1
  fi
  printf '\033[1;32m%s: all checks passed\033[0m\n' "$(basename "$0" .sh)"
}
