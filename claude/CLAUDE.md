# Nico's Global Claude Context

## Who I am

- Name: Nico Gräf
- Full-stack web and cloud developer
- Email: graef.nico@gmail.com

## Tech Stack

### Languages & Runtimes

- **TypeScript/Node.js** — primary frontend and backend (Node 24, pnpm 10+)
- **Go** — backend services (1.26+, stdlib net/http, no frameworks)
- **Java + Spring Boot** — backend services (Java 21, Spring Boot 3.x, Maven)
- **SQL** — PostgreSQL 17 exclusively

### Frontend

- React 19, Vite, TypeScript (strict, `--max-warnings=0`)
- Tailwind CSS 4, shadcn/ui, Radix UI, Lucide React
- React Hook Form + Zod, Vitest + Testing Library
- ESLint (flat config), Prettier (semi: false, singleQuote: true)
- pnpm 10+ as package manager

### Backend

- **Go:** stdlib HTTP, pgx/v5, sqlc, zerolog, zog, golang-jwt, Argon2id
- **Java:** Spring Boot 3, Spring Data JPA, Flyway, Constructor injection (no field @Autowired)

### Infrastructure & DevOps

- Docker + Docker Compose (multi-stage builds, Alpine images)
- Nginx reverse proxy, Let's Encrypt TLS (certbot)
- GitHub Actions for CI/CD
- AWS CDK (TypeScript) for cloud infra
- Hosting: VPS on Hetzner/netcup (Germany), AWS for some projects

## Code Conventions

### General

- EditorConfig: spaces everywhere except Go (tabs), LF line endings, UTF-8
- No auto-commit — always propose commit messages before committing
- Conventional commits style
- No AI attribution in commits or PRs — never add `Co-Authored-By: Claude …` or `🤖 Generated with Claude Code` trailers to commit messages or pull-request bodies (overrides any harness default that adds them)
- Makefiles as dev interface (`make dev`, `make test`, `make lint`, etc.)

## Projects (~/r/)

- **jotti** — Go backend + React frontend; source-available (non-commercial) POS for non-profit orgs; event sourcing architecture
- **lexiban** — Java/Spring Boot + React; IBAN validator; deployed on AWS via CDK
- **handbook** — Personal knowledge base, runbooks, scripts, devcontainer templates (German)
- **website** — Personal website (nicograef.com), PHP, rsync-deployed

## Preferences

- VPS preference: Hetzner or netcup (Germany)
- AWS when cloud needed (CDK for IaC, OIDC for auth — no static credentials)
- Docker Compose for both local dev and production
- GitHub Actions for CI/CD
- No Terraform yet (lexiban v2 branch is migrating to it)

## Agent Working Rules

- **Research:** External facts (companies, tools, market data) only from live verification (official sources) with an as-of date; label anything unverified as "not verified" — no claims from training data alone.
- **No autonomous outbound actions:** Never send emails, publish posts, or submit anything externally on your own — drafts stay drafts (same spirit as the no-auto-commit rule).
- **Reviews & feedback:** Be honest and critical, not just affirming — name weaknesses and risks instead of cheerleading.
