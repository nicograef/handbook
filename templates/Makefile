# Makefile template — Full-Stack Project
# Usage: copy to project root and adapt targets
#
# In a recipe, $$ escapes the $ so the shell expands it, not make. A make variable
# holding shell output needs $(shell ...); `VAR := $$(cmd)` stores the literal text.

# Load .env variables (DB credentials etc.) for all targets.
# include .env
# export

# Compose project name: the prod targets and scripts/prod-init.sh must share it,
# because it prefixes the cert volumes the stack mounts.
PROJECT ?= myapp

# ── Local Development (one terminal per target) ──

.PHONY: db be fe

db:            ## Start database container
	docker compose up postgres

be:            ## Start backend (adapt command to your stack)
	@echo "TODO: add backend start command" >&2; exit 1
	# cd backend && ./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
	# cd backend && npm run dev

fe:            ## Start frontend dev server
	@echo "TODO: add frontend start command" >&2; exit 1
	# cd frontend && pnpm dev
	# cd frontend && npm run dev

# ── Code Quality ──

.PHONY: be-check fe-check check

be-check:      ## Backend: lint + test
	@echo "TODO: add backend checks" >&2; exit 1
	# cd backend && ./mvnw verify -B

fe-check:      ## Frontend: lint + test
	@echo "TODO: add frontend checks" >&2; exit 1
	# cd frontend && pnpm lint && pnpm test

check: be-check fe-check  ## Run all checks

# ── Local Stack (docker-compose.yml — no TLS) ──

.PHONY: up down logs

up:            ## Start all services locally
	docker compose up --build

down:          ## Stop local services
	docker compose down

logs:          ## Follow logs
	docker compose logs -f

# ── Production (docker-compose.prod.yml — HTTPS) ──

.PHONY: prod-init prod-up prod-down prod-logs

prod-init:     ## First-time prod setup (cert + stack)
	PROJECT=$(PROJECT) ./scripts/prod-init.sh

prod-up:       ## Start production stack (HTTPS)
	docker compose -p $(PROJECT) -f docker-compose.prod.yml up --build -d

prod-down:     ## Stop production stack
	docker compose -p $(PROJECT) -f docker-compose.prod.yml down

prod-logs:     ## Follow production logs
	docker compose -p $(PROJECT) -f docker-compose.prod.yml logs -f

# ── Release ──

.PHONY: prod-release

prod-release:  ## Push a prod-<timestamp> tag (add your own tag-triggered deploy workflow)
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$BRANCH" != "main" ]; then echo "Error: must be on main (currently on $$BRANCH)"; exit 1; fi
	@TAG=prod-$$(date +%Y%m%d-%H%M) && \
	git tag $$TAG && git push origin $$TAG && \
	echo "Pushed tag $$TAG"

# ── Utilities ──

.PHONY: db-shell help

db-shell:      ## Open psql shell in running PostgreSQL container (needs the .env include above)
	docker compose exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

# ssh-prod:    ## SSH into production server
# 	ssh user@your-server-ip

# ── Help ──

# Every documented target stands in exactly one CLASS_* list, and `make help` prints the
# lists as its sections. A target in none prints under UNCLASSIFIED.
CLASS_developer := db be fe be-check fe-check check up down logs db-shell help
CLASS_production := prod-init prod-up prod-down prod-logs prod-release

# Column the help text wraps at.
HELP_WIDTH ?= 96

# `$(firstword $(MAKEFILE_LIST))`, not the whole list: `include .env` would put `.env` in it.
help:          ## Show every target, by class (HELP_WIDTH=<n> moves the wrap column)
	@grep -hE '^[a-zA-Z_-]+:.*##' $(firstword $(MAKEFILE_LIST)) \
	  | awk -v width=$(HELP_WIDTH) \
	        -v developer='$(CLASS_developer)' -v production='$(CLASS_production)' \
	        -f scripts/make-help.awk

.DEFAULT_GOAL := help
