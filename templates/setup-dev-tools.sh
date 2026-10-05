#!/usr/bin/env bash
# setup-dev-tools.sh – install project-specific dev tools (idempotent)
#
# Called by devcontainer.json postCreateCommand, or run manually.
#
# Each `# >>> stack: NAME` section hard-requires its runtime, so a leftover Go section fails the
# postCreateCommand of a frontend-only repo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }
fatal() { error "$1"; exit 1; }

ensure_cmd() {
  local cmd="$1"
  local hint="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fatal "Missing required command '$cmd'. $hint"
  fi
}

info "Project root: $PROJECT_ROOT"
cd "$PROJECT_ROOT"

# >>> stack: go
# ── Go tools ─────────────────────────────────────────────────────────────────

ensure_cmd go "Install Go (see .devcontainer/devcontainer.json features)."

GO_BIN_PATH="$(go env GOPATH)/bin"
export PATH="$GO_BIN_PATH:$PATH"

# Pin to the version your CI uses. Built from source because golangci-lint can
# only analyze Go versions <= the Go version it was built with (prebuilt
# binaries often lag behind), and GitHub release downloads are blocked behind
# some proxies (e.g. Claude Code cloud sessions).
GOLANGCI_LINT_VERSION="v2.13.2"
GO_TOOLCHAIN="go<project-go-version>" # the `go` directive from backend/go.mod, e.g. 1.26.5

info "Ensuring golangci-lint ($GOLANGCI_LINT_VERSION)..."
if [ "v$(golangci-lint version --short 2>/dev/null | sed 's/^v//')" = "$GOLANGCI_LINT_VERSION" ]; then
  info "golangci-lint already installed: $GOLANGCI_LINT_VERSION"
else
  GOTOOLCHAIN="$GO_TOOLCHAIN" GOBIN="$GO_BIN_PATH" \
    go install "github.com/golangci/golangci-lint/v2/cmd/golangci-lint@${GOLANGCI_LINT_VERSION}"
  hash -r
fi

# goimports, sqlc and govulncheck are go.mod tools, pinned in go.mod and run through `go tool`.

echo "  go:             $(go version)"
echo "  golangci-lint:  $(golangci-lint --version | head -n 1)"
# <<< stack: go

# >>> stack: frontend
# ── Node / pnpm ─────────────────────────────────────────────────────────────

ensure_cmd node "Install Node (see .devcontainer/devcontainer.json features)."

# npm, not Corepack: Node 25 and later ship without Corepack.
info "Ensuring pnpm..."
if command -v pnpm >/dev/null 2>&1; then
  info "pnpm already installed: $(pnpm --version)"
else
  npm install -g pnpm@12
fi

# --frozen-lockfile: the lockfile is the contract; a setup never rewrites it.
info "Installing frontend dependencies..."
(cd "$PROJECT_ROOT/frontend" && pnpm install --frozen-lockfile)

echo "  node:           $(node --version)"
echo "  pnpm:           $(pnpm --version)"
# <<< stack: frontend

# >>> stack: python
# ── Python / uv ─────────────────────────────────────────────────────────────

# The official installer, because no devcontainer feature ships uv and pip
# would tie it to one interpreter.
info "Ensuring uv..."
if command -v uv >/dev/null 2>&1; then
  info "uv already installed: $(uv --version)"
else
  # The floor in [tool.uv] required-version of backend/pyproject.toml: uv refuses to run below it.
  curl -LsSf https://astral.sh/uv/0.12.18/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

# --frozen: the lockfile is the contract; a setup never rewrites it.
info "Syncing Python dependencies..."
(cd "$PROJECT_ROOT/backend" && uv sync --frozen)

echo "  uv:             $(uv --version)"
# <<< stack: python

info "Setup complete. Next step: make check"
