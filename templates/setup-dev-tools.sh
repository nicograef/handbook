#!/usr/bin/env bash
# setup-dev-tools.sh – install project-specific dev tools (idempotent)
#
# Called by devcontainer.json postCreateCommand, or run manually.
# Each block checks before installing — safe to re-run anytime.
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

# ── Base runtime checks ─────────────────────────────────────────────────────
# Uncomment the runtimes your project needs.

# info "Checking base runtimes..."
# ensure_cmd go "Install Go (see .devcontainer/devcontainer.json features)."
# ensure_cmd node "Install Node (see .devcontainer/devcontainer.json features)."

# ── Go tools ─────────────────────────────────────────────────────────────────
# Uncomment this block for Go projects.

# GO_BIN_PATH="$(go env GOPATH)/bin"
# export PATH="$GO_BIN_PATH:$PATH"
#
# info "Ensuring goimports..."
# if command -v goimports >/dev/null 2>&1; then
#   info "goimports already installed"
# else
#   go install golang.org/x/tools/cmd/goimports@latest
# fi
#
# info "Ensuring golangci-lint..."
# if command -v golangci-lint >/dev/null 2>&1; then
#   info "golangci-lint already installed: $(golangci-lint --version | head -n 1)"
# else
#   ensure_cmd curl "Install curl to bootstrap golangci-lint."
#   curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
#     | sh -s -- -b "$GO_BIN_PATH" latest
# fi
#
# info "Ensuring sqlc..."
# if command -v sqlc >/dev/null 2>&1; then
#   info "sqlc already installed: $(sqlc version)"
# else
#   go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
# fi

# ── Node / pnpm ─────────────────────────────────────────────────────────────
# Uncomment this block for Node projects using pnpm.

# info "Ensuring pnpm..."
# if command -v pnpm >/dev/null 2>&1; then
#   info "pnpm already installed: $(pnpm --version)"
# else
#   if command -v corepack >/dev/null 2>&1; then
#     corepack enable
#     corepack prepare pnpm@10 --activate  # TODO: set your pnpm version
#   else
#     fatal "pnpm not found and corepack unavailable. Install pnpm manually."
#   fi
# fi

# ── Frontend dependencies ───────────────────────────────────────────────────
# Uncomment if your project has a frontend/ directory with pnpm.

# info "Installing frontend dependencies..."
# cd "$PROJECT_ROOT/frontend" && pnpm install
# cd "$PROJECT_ROOT"

# ── Summary ──────────────────────────────────────────────────────────────────
info "Setup complete."

# Uncomment the lines matching your stack:
# echo "  go:             $(go version)"
# echo "  node:           $(node --version)"
# echo "  pnpm:           $(pnpm --version)"
# echo "  goimports:      $(goimports -V 2>/dev/null || echo 'installed')"
# echo "  golangci-lint:  $(golangci-lint --version | head -n 1)"
# echo "  sqlc:           $(sqlc version)"

info "Next step: make check"
