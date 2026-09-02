#!/usr/bin/env bash
# setup-dev-tools.sh – install project-specific dev tools (idempotent)
#
# Called by devcontainer.json postCreateCommand, or run manually.
#
# Delete the stack sections your project does not use, and their summary lines at
# the bottom. Each section hard-requires its runtime, so a leftover Go section
# fails the postCreateCommand of a frontend-only repo.
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

# ── Go tools ─────────────────────────────────────────────────────────────────
# Delete this whole section on a project without a Go backend.

ensure_cmd go "Install Go (see .devcontainer/devcontainer.json features)."

GO_BIN_PATH="$(go env GOPATH)/bin"
export PATH="$GO_BIN_PATH:$PATH"

info "Ensuring goimports..."
if command -v goimports >/dev/null 2>&1; then
  info "goimports already installed"
else
  go install golang.org/x/tools/cmd/goimports@latest
fi

# Pin to the version your CI uses. Built from source because golangci-lint can
# only analyze Go versions <= the Go version it was built with (prebuilt
# binaries often lag behind), and GitHub release downloads are blocked behind
# some proxies (e.g. Claude Code cloud sessions).
GOLANGCI_LINT_VERSION="v2.11.4"
GO_TOOLCHAIN="go<project-go-version>" # the `go` directive from your go.mod, e.g. go1.26.5

info "Ensuring golangci-lint ($GOLANGCI_LINT_VERSION)..."
if [ "v$(golangci-lint version --short 2>/dev/null | sed 's/^v//')" = "$GOLANGCI_LINT_VERSION" ]; then
  info "golangci-lint already installed: $GOLANGCI_LINT_VERSION"
else
  GOTOOLCHAIN="$GO_TOOLCHAIN" GOBIN="$GO_BIN_PATH" \
    go install "github.com/golangci/golangci-lint/v2/cmd/golangci-lint@${GOLANGCI_LINT_VERSION}"
  hash -r
fi

# info "Ensuring sqlc..."
# if command -v sqlc >/dev/null 2>&1; then
#   info "sqlc already installed: $(sqlc version)"
# else
#   go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
# fi

# ── Node / pnpm ─────────────────────────────────────────────────────────────
# Delete this whole section on a project without a Node frontend.

ensure_cmd node "Install Node (see .devcontainer/devcontainer.json features)."

info "Ensuring pnpm..."
if command -v pnpm >/dev/null 2>&1; then
  info "pnpm already installed: $(pnpm --version)"
else
  if command -v corepack >/dev/null 2>&1; then
    corepack enable
    corepack prepare pnpm@10 --activate
  else
    fatal "pnpm not found and corepack unavailable. Install pnpm manually."
  fi
fi

# ── Frontend dependencies ───────────────────────────────────────────────────
# Uncomment if your project has a frontend/ directory with pnpm.

# info "Installing frontend dependencies..."
# cd "$PROJECT_ROOT/frontend" && pnpm install
# cd "$PROJECT_ROOT"

# ── Summary ──────────────────────────────────────────────────────────────────
info "Setup complete."

echo "  go:             $(go version)"
echo "  node:           $(node --version)"
echo "  pnpm:           $(pnpm --version)"
echo "  goimports:      $(goimports -V 2>/dev/null || echo 'installed')"
echo "  golangci-lint:  $(golangci-lint --version | head -n 1)"
# echo "  sqlc:           $(sqlc version)"

info "Next step: make check"
