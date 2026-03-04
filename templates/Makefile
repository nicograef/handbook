# Makefile template — Full-Stack Project
# Usage: copy to project root and adapt targets
#
# Features:
#   - .env auto-loading for all targets
#   - Local dev (one terminal per service)
#   - Docker Compose targets (local + production)
#   - Code quality checks (backend + frontend)
#   - Tag-based production releases

# Load .env variables (DB credentials etc.) for all targets.
# include .env
# export

# ── Local Development (one terminal per target) ──

.PHONY: db be fe

db:            ## Start database container
	docker compose up postgres

be:            ## Start backend (adapt command to your stack)
	@echo "TODO: add backend start command"
	# cd backend && ./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
	# cd backend && npm run dev

fe:            ## Start frontend dev server
	@echo "TODO: add frontend start command"
	# cd frontend && pnpm dev
	# cd frontend && npm run dev

# ── Code Quality ──

.PHONY: be-check fe-check check

be-check:      ## Backend: lint + test
	@echo "TODO: add backend checks"
	# cd backend && ./mvnw verify -B

fe-check:      ## Frontend: lint + test
	@echo "TODO: add frontend checks"
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
	./scripts/prod-init.sh

prod-up:       ## Start production stack (HTTPS)
	docker compose -f docker-compose.prod.yml up --build -d

prod-down:     ## Stop production stack
	docker compose -f docker-compose.prod.yml down

prod-logs:     ## Follow production logs
	docker compose -f docker-compose.prod.yml logs -f

# ── Release ──

.PHONY: prod-release

prod-release:  ## Tag current main commit → triggers prod deploy
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$BRANCH" != "main" ]; then echo "Error: must be on main (currently on $$BRANCH)"; exit 1; fi
	@TAG=prod-$$(date +%Y%m%d-%H%M) && \
	git tag $$TAG && git push origin $$TAG && \
	echo "Pushed tag $$TAG — prod deploy triggered"

# ── Utilities ──

.PHONY: db-shell help

db-shell:      ## Open psql shell in running PostgreSQL container
	docker compose exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

# ssh-prod:    ## SSH into production server
# 	ssh user@your-server-ip

help:          ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
