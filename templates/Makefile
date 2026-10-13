# In a recipe, $$ escapes the $ so the shell expands it, not make. A make variable
# holding shell output needs $(shell ...); `VAR := $$(cmd)` stores the literal text.

# Load .env variables (DB credentials etc.) for all targets.
# include .env
# export

BACKEND_DIR ?= backend
FRONTEND_DIR ?= frontend

# ── Local Development (one terminal per target) ──

# Each `# >>> stack: NAME` block belongs to one stack; a repo deletes the blocks of the stacks it lacks.
# A Go backend uncomments its blocks.

# >>> stack: database
.PHONY: db

db:            ## Start database container
	docker compose up postgres
# <<< stack: database

# >>> stack: python
.PHONY: be

be:            ## Start backend with reload on :8080
	cd $(BACKEND_DIR) && uv run uvicorn --factory <package>.api:app --reload --port 8080
# <<< stack: python

# >>> stack: go
# .PHONY: be
#
# be:            ## Start backend on :8080
# 	cd $(BACKEND_DIR) && go run ./cmd/<name>
# <<< stack: go

# >>> stack: frontend
.PHONY: fe

fe:            ## Start frontend dev server
	cd $(FRONTEND_DIR) && pnpm dev
# <<< stack: frontend

# ── Code Quality ──

# Each gate mirrors ci.yml's steps and order, so a green `make check` predicts a green CI.
# Each stack block adds its gate to `check`.

.PHONY: check

check:         ## Run all checks

# >>> stack: python
.PHONY: be-check
check: be-check

be-check:      ## Backend: uv gate (sync, lint, format, types, tests, audit)
	cd $(BACKEND_DIR) && uv sync --locked
	cd $(BACKEND_DIR) && uv run ruff check .
	cd $(BACKEND_DIR) && uv run ruff format --check .
	cd $(BACKEND_DIR) && uv run ty check .
	cd $(BACKEND_DIR) && uv run pytest
	cd $(BACKEND_DIR) && uv audit
# <<< stack: python

# >>> stack: go
# # `sqlc diff` fails on stale generated code, as ci.yml's drift check does, but ignores a dirty tree.
# .PHONY: be-check
# check: be-check
#
# be-check:      ## Backend: Go gate (modules, generated code, format, vet, lint, build, tests, vulns)
# 	cd $(BACKEND_DIR) && go mod verify
# 	cd $(BACKEND_DIR) && go mod tidy -diff
# 	cd $(BACKEND_DIR) && go tool sqlc diff
# 	cd $(BACKEND_DIR) && go tool goimports -l . | (! grep .)
# 	cd $(BACKEND_DIR) && go vet ./...
# 	cd $(BACKEND_DIR) && golangci-lint run
# 	cd $(BACKEND_DIR) && go build ./...
# 	cd $(BACKEND_DIR) && go test -race ./...
# 	cd $(BACKEND_DIR) && go tool govulncheck ./...
# <<< stack: go

# >>> stack: frontend
.PHONY: fe-check
check: fe-check

# The package.json scripts named in reference/stack-conventions.md (Node/TypeScript).
fe-check:      ## Frontend: pnpm gate (install, format, lint, types, tests, build, audit)
	cd $(FRONTEND_DIR) && pnpm install --frozen-lockfile
	cd $(FRONTEND_DIR) && pnpm run format:check
	cd $(FRONTEND_DIR) && pnpm run lint
	cd $(FRONTEND_DIR) && pnpm run typecheck
	cd $(FRONTEND_DIR) && pnpm run test
	cd $(FRONTEND_DIR) && pnpm run build
	cd $(FRONTEND_DIR) && pnpm audit --audit-level high
# <<< stack: frontend

# ── Local Stack (docker-compose.yml — no TLS) ──

.PHONY: up down logs

up:            ## Start all services locally
	docker compose up --build

down:          ## Stop local services
	docker compose down

logs:          ## Follow logs
	docker compose logs -f

# ── Production (docker-compose.prod.yml — HTTPS) ──

# The Compose files carry the project name (`name:`), so every target reaches the same stack.

.PHONY: prod-deploy prod-down prod-logs

prod-deploy:   ## First deploy or update to the pinned tags (cert, backup, downgrade guard, health poll)
	./scripts/prod-init.sh

prod-down:     ## Stop production stack
	docker compose -f docker-compose.prod.yml down

prod-logs:     ## Follow production logs
	docker compose -f docker-compose.prod.yml logs -f

# ── Release ──

.PHONY: prod-release

prod-release:  ## Push tag v$(VERSION); .github/workflows/release.yml builds the images (VERSION=X.Y.Z)
	@echo "$(VERSION)" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' \
	  || { echo "Error: set VERSION=X.Y.Z (got '$(VERSION)')" >&2; exit 1; }
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$BRANCH" != "main" ]; then echo "Error: must be on main (currently on $$BRANCH)" >&2; exit 1; fi
	git tag v$(VERSION) && git push origin v$(VERSION)

# ── Utilities ──

# >>> stack: database
.PHONY: db-shell

db-shell:      ## Open psql shell in running PostgreSQL container (needs the .env include above)
	docker compose exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)
# <<< stack: database

# Enable once the server is provisioned.
# ssh-prod:    ## SSH into production server
# 	ssh <username>@<host>

# ── Help ──

# Every documented target stands in exactly one CLASS_* list, and `make help` prints the
# lists as its sections. A target in none prints under UNCLASSIFIED.
CLASS_developer := db be fe be-check fe-check check up down logs db-shell help
CLASS_production := prod-deploy prod-down prod-logs prod-release

HELP_WIDTH ?= 96

.PHONY: help

# `$(firstword $(MAKEFILE_LIST))`, not the whole list: `include .env` would put `.env` in it.
help:          ## Show every target, by class (HELP_WIDTH=<n> moves the wrap column)
	@grep -hE '^[a-zA-Z0-9_-]+:.*##' $(firstword $(MAKEFILE_LIST)) \
	  | awk -v width=$(HELP_WIDTH) \
	        -v developer='$(CLASS_developer)' -v production='$(CLASS_production)' \
	        -f scripts/make-help.awk

.DEFAULT_GOAL := help
