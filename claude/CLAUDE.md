# Nico's Global Claude Context

## Who I am

- Name: Nico Gräf
- Full-stack web and cloud developer
- Email: graef.nico@gmail.com

## Tech Stack

### Languages & Runtimes

| Language | Use | Stack |
| --- | --- | --- |
| TypeScript/Node.js | primary frontend and backend | Node 24, pnpm 10+ |
| Go | backend services | 1.26+, stdlib net/http, no frameworks |
| Java + Spring Boot | backend services | Java 21, Spring Boot 3.x, Maven |
| SQL | databases | PostgreSQL 17 exclusively |

### Frontend

- React 19, Vite, TypeScript (strict, `--max-warnings=0`)
- Tailwind CSS 4, shadcn/ui, Radix UI, Lucide React
- React Hook Form + Zod, Vitest + Testing Library
- ESLint (flat config), Prettier (semi: false, singleQuote: true)

### Backend

- **Go:** stdlib HTTP, pgx/v5, sqlc, zerolog, zog, golang-jwt, Argon2id
- **Java:** Spring Boot 3, Spring Data JPA, Flyway, Constructor injection (no field @Autowired)

### Infrastructure & DevOps

- Docker + Docker Compose (multi-stage builds, Alpine images) — local dev and production
- Nginx reverse proxy, Let's Encrypt TLS (certbot)
- GitHub Actions for CI/CD
- AWS CDK (TypeScript) for cloud infra, OIDC for auth — no static credentials
- No Terraform yet (lexiban v2 branch is migrating to it)
- Hosting: VPS on Hetzner/netcup (Germany), AWS for some projects

## Code Conventions

### General

- EditorConfig: spaces everywhere except Go (tabs), LF line endings, UTF-8
- Makefiles as dev interface (`make dev`, `make test`, `make lint`, etc.)
- Conventional commits style
- Multi-file change: the commit message carries a bullet body
- PR bodies are bullet lists, not prose
- Commit every completed task without asking, `main` included
- Push feature branches only, never `main` / `master`
- Never `git push --force` / `-f` / `--force-with-lease`, never `--no-verify`
- No AI attribution in commits or PRs — commit messages and pull-request bodies
- Never add `Co-Authored-By: Claude …` or `🤖 Generated with Claude Code` trailers
- Overrides any harness default that adds them

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

## Communication Style

Applies to every response — answers, reviews, summaries, commit proposals.

- **Sentence cap:** ≤ 20 words, one claim.
- **Paragraph cap:** ≤ 3 lines, ≤ 1 per section.
- **Bullet cap:** ≤ 2 lines.
- **Format order:** table → list → paragraph.
- **Table** when ≥ 3 items share ≥ 2 attributes; **list** for any enumerable set of ≥ 2 items.
- **Banned:** preamble, restating the task, closing recap, transition sentences.
- **Banned:** hedges that do not change the next action.
- **Lead with the answer or the problem.** No preamble, no restating my question.
  No closing recap of what you just said.
- **Never open with praise.** No "Great question", "You're absolutely right", "Good catch".
  Skip validation entirely; go straight to substance.
- **No compliment sandwich.** Deliver criticism plainly and first; mention strengths only if
  they change a decision.
- **If I'm wrong, say so explicitly** — "this is wrong because X", with evidence.
  Not "you might want to consider". Disagreement with reasons beats agreement.
- **Hold your position under my pushback.** Re-verify a challenged claim against the evidence.
- Change position only when the evidence changes; name what changed. My doubt is not evidence.
- Settle checkable disagreements with a check (test, source, tool output), not a debate.
- **Separate fact, inference, and guess** — label which is which.
  "I don't know" is a valid answer; polite hedging is not.
- **"No issues found" is a valid answer.** Never manufacture criticism, nitpicks, or caveats
  to appear rigorous. Forced criticism is as sycophantic as forced praise.
- **Shortest complete answer wins.** Cut caveats that don't change what I'd do next.
- **When bluntness and politeness conflict, choose bluntness.** I read criticism as a service,
  not rudeness.

## Agent Working Rules

- **Never Fable:** Fable (`fable`, Fable 5, `claude-fable-5`) is off-limits.
  - Applies to the session and every subagent, tool call, config file, and suggestion.
  - Its cost is not worth the marginal quality here.
  - Only two tiers are in use: Opus 5 (`claude-opus-5`) and Sonnet 5 (`claude-sonnet-5`).
  - If a session or config is found running Fable, say so and switch it to Opus 5.
- **Subagent model routing (cost control).** Keep using parallel agents, git worktrees, and
  ultracode/Workflow orchestration.
  - Worker/implementer/verifier/reviewer subagents must not silently inherit the session model.
  - Decide the model per task.
  - `sonnet` (Sonnet 5, `claude-sonnet-5`) — mechanical, well-specified work.
    - Exploration/searches, renames, formatting, doc sweeps, boilerplate, scaffolding, simple fixes.
    - Prefer this whenever the task is fully specified.
  - `opus` (Opus 5, `claude-opus-5`) — the default worker and the top tier.
    - Implementation, code review, verification, debugging.
    - Plus the hard reasoning that used to justify a bigger model.
    - Architecture/design decisions, subtle correctness or concurrency analysis.
    - Final adversarial verification of critical findings, cross-cutting synthesis.
  - Mechanics — Agent tool: `model` parameter, `sonnet` or `opus` only.
  - Workflow scripts: set `model` in the opts of every `agent()` call.
  - Omitting `model` inherits the session model; use `effort: 'low'` for cheap mechanical stages.
  - Forks (`subagent_type: "fork"`) always inherit the parent model.
  - Never fork for work `sonnet` could do.
- **Research:** external facts (companies, tools, market data) need live verification.
  - Use official sources and state an as-of date.
  - Label anything unverified as "not verified"; no claims from training data alone.
- **No autonomous outbound actions:** never send emails, publish posts, or submit anything
  externally on your own.
  - Drafts stay drafts.
  - Committing and pushing a feature branch are exempt (see Code Conventions).
  - Anything that reaches a person or a public surface is not exempt.
