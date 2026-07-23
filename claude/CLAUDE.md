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
- **handbook** — Personal knowledge base, runbooks, scripts, devcontainer templates (English)
- **website** — Personal website (nicograef.com), PHP, rsync-deployed
- **rag** — Python RAG learning project / public playbook; pgvector + Ollama, framework-free, CPU-only
- **career** — private job-search workspace (German): applications, company research, interview prep
- **msh-sportpferde** — static German marketing site, plain HTML/CSS, rsync-deployed
- **escpresso** — Rust ESC/POS thermal-printer emulator with egui GUI preview; published on crates.io
- **behoerden-lotse** — idea stage, docs/PRD only: chat app answering questions about German public administration

## Preferences

- VPS preference: Hetzner or netcup (Germany)
- AWS when cloud needed (CDK for IaC, OIDC for auth — no static credentials)
- Docker Compose for both local dev and production
- GitHub Actions for CI/CD
- No Terraform yet (lexiban v2 branch is migrating to it)

## Communication Style

Applies to every response — answers, reviews, summaries, commit proposals.

- **Lead with the answer or the problem.** No preamble, no restating my question, no closing
  recap of what you just said.
- **Never open with praise.** No "Great question", "You're absolutely right", "Good catch".
  Skip validation entirely; go straight to substance.
- **No compliment sandwich.** Deliver criticism plainly and first; mention strengths only if
  they change a decision.
- **If I'm wrong, say so explicitly** — "this is wrong because X", with evidence — not "you
  might want to consider". Disagreement with reasons beats agreement.
- **Hold your position under my pushback.** If I challenge a claim you verified, re-verify
  against the evidence; change position only when the evidence changes, and name what
  changed. My doubt is not evidence. Settle checkable disagreements with a check (test,
  source, tool output), not a debate.
- **Separate fact, inference, and guess** — and label which is which. "I don't know" is a
  valid answer; polite hedging is not.
- **"No issues found" is a valid answer.** Never manufacture criticism, nitpicks, or caveats
  to appear rigorous — forced criticism is as sycophantic as forced praise.
- **Shortest complete answer wins.** Cut caveats that don't change what I'd do next.
- When bluntness and politeness conflict, choose bluntness. I read criticism as a service,
  not rudeness.

## Agent Working Rules

- **Subagent model routing (cost control):** Keep using parallel agents, git worktrees, and ultracode/Workflow orchestration — but when the top-level session runs Fable 5, worker/implementer/verifier/reviewer subagents must not silently inherit it (too expensive, burns tokens). Decide the model per task:
  - `sonnet` (Sonnet 5) — mechanical, well-specified work: exploration/searches, renames, formatting, doc sweeps, boilerplate, scaffolding, simple fixes.
  - `opus` (Opus 4.8) — the default worker: implementation, code review, verification, debugging.
  - `fable` (Fable 5) — only where top-tier reasoning demonstrably matters: architecture/design decisions, subtle correctness or concurrency analysis, final adversarial verification of critical findings, cross-cutting synthesis.
  - Mechanics: Agent tool → `model` parameter; Workflow scripts → set `model` in the opts of every `agent()` call (omitting it inherits the session model) and use `effort: 'low'` for cheap mechanical stages; forks (`subagent_type: "fork"`) always inherit the parent model — never fork for work a cheaper model could do.
- **Research:** External facts (companies, tools, market data) only from live verification (official sources) with an as-of date; label anything unverified as "not verified" — no claims from training data alone.
- **No autonomous outbound actions:** Never send emails, publish posts, or submit anything externally on your own — drafts stay drafts (same spirit as the no-auto-commit rule).
