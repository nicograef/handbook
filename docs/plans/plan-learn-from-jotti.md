# Plan: Learn from jotti

> Source PRD: n/a. Source: the jotti handbook compliance audit of 2026-09-27 and the owner's rulings on each item.

## Goal

The handbook takes over the jotti practices the owner picked and resolves the four contradictions the audit exposed. Dropped candidates are listed so that nobody reopens them.

## Resolved decisions

| Item | Ruling |
| --- | --- |
| Language | English by default; a project's `AGENTS.md` may name what it writes in its domain language (UI, operator docs, domain terms, statutes) |
| Testing by layer | Service logic: store interface plus a stateful fake. Repository and SQL: a real database only |
| Frontend tests | Fake the single API client and render with a real query client; never mock the project's own modules |
| Comments vs docs | The 2-sentence comment cap wins; longer reasoning lives in the doc the comment links |
| Go formatting | goimports in CI and hooks; gopls defaults in the editor (organizeImports, no gofumpt). Revisit once gopls bundles gofumpt ≥ 0.11 |
| pnpm | `pnpm install --frozen-lockfile` in the setup template |
| Node | The current Active LTS; move within a month of a new LTS |
| cn() | Stays: shadcn/ui generates `export { cn } from "cn"` since 2026-09-03 |
| Adopted | Vulnerability scans, generated-code drift, `pg_isready` over TCP, fork-PR trigger, current-state word scan, golangci template, forward-only migrations, restore drill in CI, safe deploy flow, compose `name:`, `make help` regex, Caddy variant, one-line `decisions.md`, glossary path |
| Dropped | check-pins template, self-expiring allowlists, `keep ≤ 0` retention, allowlist `.dockerignore`, SPA nginx tweaks, `make init` secrets, fuzzing guidance, format hook, cloud PR trailer, CRLF note |

## Open questions / Risks

- **Forward-only migrations** change the policy for every project; the CI template loses `migrate down -all`. gyva's migrations must be checked against the new rule when it next touches them.

## Phase 1: Rules and skills

**Depends on**: none

### What to build

- **Language:** `claude/CLAUDE.md` states the language exception in one sentence.
- **Testing:** `.claude/skills/testing/SKILL.md` states the by-layer rule and the frontend API-client rule, and loses the blanket "prefer a real test database over a mocked repository".
- **Distill:** `.claude/skills/distill/SKILL.md` replaces "the comment wins" with "the cap wins; the comment links the doc".
- **Glossary:** `plan/SKILL.md` and `cleanup/SKILL.md` use the repo's existing glossary first and fall back to `docs/UBIQUITOUS_LANGUAGE.md`.
- **Decisions:** `guides/new-project.md` introduces `docs/decisions.md`: one line per decision, and a replaced line gets "replaced by DNN".

### Acceptance criteria

- [x] `grep -n 'comment wins' .claude/skills/distill/SKILL.md` finds nothing
- [x] `grep -n 'Prefer a real test database' .claude/skills/testing/SKILL.md` finds nothing
- [x] `grep -n 'decisions.md' guides/new-project.md` finds the rule
- [x] `make check` green

## Phase 2: Stack conventions and editor templates

**Depends on**: none

### What to build

`guides/stack-conventions.md`:
- Go: the by-layer testing rule, and a link to `templates/golangci.yml`.
- Node: the Active LTS rule replaces the fixed version.
- React: the API-client fake rule.

`templates/golangci.yml` is new: a v2 config with errcheck, gosec, bodyclose, errorlint and a forbidigo layer-guard example, taken from jotti's config. `templates/vscode-settings.json` drops `gofumpt` and uses the gopls defaults with organizeImports on save. `templates/setup-dev-tools.sh` runs `pnpm install --frozen-lockfile`. `README.md` indexes the new template.

### Acceptance criteria

- [x] `grep -n 'gofumpt' templates/vscode-settings.json` finds nothing
- [x] `grep -n 'pnpm install' templates/setup-dev-tools.sh` shows `--frozen-lockfile`
- [x] `golangci-lint config verify -c templates/golangci.yml` passes
- [x] `grep -n 'Node 26' guides/stack-conventions.md` finds nothing
- [x] `make check` green (both indexes)

## Phase 3: CI template and database operations

**Depends on**: none

### What to build

`templates/ci.yml` gains:
- a security job with govulncheck per Go module and a blocking `pnpm audit` at high, plus a weekly `schedule` trigger;
- a generated-code drift step (sqlc as the example) on schema paths;
- `pg_isready -h 127.0.0.1` for the service health check;
- a commented `pull_request` trigger for public repos.

Migrations become forward-only. The template replaces `migrate down -all` with an upgrade-path job that applies the previous release's schema and then the current migrations. It also gets a restore drill that restores the backup into a throwaway container pinned to the stack's Postgres image. `guides/postgresql-operations.md` documents both rules.

### Acceptance criteria

- [x] `actionlint templates/ci.yml` clean
- [x] `grep -n 'down -all' templates/ci.yml guides/` finds nothing
- [x] `grep -n '127.0.0.1' templates/ci.yml` finds the `pg_isready` line
- [x] `make check` green

## Phase 4: Compose, Makefile and deploy

**Depends on**: 2

### What to build

Every compose template gets a top-level `name:`, and `templates/Makefile` drops `PROJECT`/`-p`. `templates/Makefile` `help` matches targets with `[a-zA-Z0-9_-]`. A Caddy variant (`templates/docker-compose.prod-caddy.yml` plus `templates/Caddyfile`) serves automatic TLS without certbot. It has app healthchecks, resource limits and a proxy gated on `service_healthy`. `guides/letsencrypt-docker.md` names when to pick which. `scripts/prod-init.sh` and `guides/maintenance.md` describe the safe deploy flow: pinned registry images, health polling after start, a backup before an update, and refusing a downgrade. `README.md` indexes the new templates.

### Acceptance criteria

- [x] `docker compose -f <each template> config -q` passes
- [x] `grep -n 'PROJECT\|COMPOSE_PROJECT_NAME\| -p ' templates/Makefile scripts/prod-init.sh` finds nothing
- [x] `caddy validate --adapter caddyfile --config templates/Caddyfile` passes (caddy image)
- [x] `make check` green

## Phase 5: Current-state gate

**Depends on**: 1, 2, 3, 4

### What to build

`scripts/check-repo.sh` gains a stage that scans prose for history words: previously, formerly, deprecated, no longer, used to. It has an allowlist in which each entry carries a reason. Violations the scan finds in the handbook are fixed.

### Acceptance criteria

- [x] a "previously" added to a guide makes `make check` fail
- [x] `make check` green
