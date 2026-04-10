# handbook

Personal knowledge base by **Nico** — senior software engineer from Freiburg, Germany.
10+ years of experience across freelance web development, fullstack engineering, and startup team leadership.
Current stack: **Go**, **React**, **TypeScript**, **PostgreSQL**, **Docker**.

Focused on **Debian / Ubuntu**. Covers infrastructure, backend, frontend, and DevOps workflows.

---

## Guides

Step-by-step instructions (runbook-style).

| Topic                             | File                                                                       |
| --------------------------------- | -------------------------------------------------------------------------- |
| Provision & harden a new VPS      | [guides/provision-server.md](guides/provision-server.md)                   |
| Docker installation & Compose     | [guides/docker-setup.md](guides/docker-setup.md)                           |
| Docker multi-stage builds         | [guides/docker-multi-stage-builds.md](guides/docker-multi-stage-builds.md) |
| Let's Encrypt with Docker Compose | [guides/letsencrypt-docker.md](guides/letsencrypt-docker.md)               |
| Nginx reverse proxy (HTTPS + SPA) | [guides/nginx-reverse-proxy.md](guides/nginx-reverse-proxy.md)             |
| GitHub Actions CI/CD              | [guides/github-actions-cicd.md](guides/github-actions-cicd.md)             |
| GitHub Copilot Agent Mode setup   | [guides/copilot-agent-setup.md](guides/copilot-agent-setup.md)             |
| Go backend development            | [guides/go.md](guides/go.md)                                               |
| Java / Spring Boot backend        | [guides/java-spring-boot.md](guides/java-spring-boot.md)                   |
| React frontend development        | [guides/react.md](guides/react.md)                                         |
| Dotfiles for GitHub Codespaces    | [guides/dotfiles-codespaces.md](guides/dotfiles-codespaces.md)             |
| PostgreSQL operations             | [guides/postgresql-operations.md](guides/postgresql-operations.md)         |

## Cheatsheets

Quick-reference commands (no context needed).

| Topic                 | File                                                           |
| --------------------- | -------------------------------------------------------------- |
| Unix / shell commands | [cheatsheets/unix-commands.md](cheatsheets/unix-commands.md)   |
| Docker Compose        | [cheatsheets/docker-compose.md](cheatsheets/docker-compose.md) |
| Vim                   | [cheatsheets/vim.md](cheatsheets/vim.md)                       |
| Git                   | [cheatsheets/git.md](cheatsheets/git.md)                       |
| PostgreSQL            | [cheatsheets/postgresql.md](cheatsheets/postgresql.md)         |
| Makefile              | [cheatsheets/makefile.md](cheatsheets/makefile.md)             |

## Theory

Conceptual reference material (German). Imported from a separate project — covers architecture patterns, domain knowledge, and technology deep-dives.

| Topic                       | File                                                 |
| --------------------------- | ---------------------------------------------------- |
| CQRS                        | [theory/cqrs.md](theory/cqrs.md)                     |
| Domain-Driven Design        | [theory/ddd.md](theory/ddd.md)                       |
| DevOps & Infrastructure     | [theory/devops.md](theory/devops.md)                 |
| Event Sourcing              | [theory/event-sourcing.md](theory/event-sourcing.md) |
| Go Backend Architecture     | [theory/go-backend.md](theory/go-backend.md)         |
| POS Systems & Gastronomy    | [theory/pos.md](theory/pos.md)                       |
| PostgreSQL                  | [theory/postgresql.md](theory/postgresql.md)         |
| React Frontend Architecture | [theory/react-frontend.md](theory/react-frontend.md) |
| Security & Authentication   | [theory/security.md](theory/security.md)             |

## Templates

Copy-paste-ready config files for new projects.

| File                                                                   | Description                                                       |
| ---------------------------------------------------------------------- | ----------------------------------------------------------------- |
| [templates/.bash_aliases](templates/.bash_aliases)                     | Personal shell aliases (git, make, pnpm, navigation)              |
| [templates/.editorconfig](templates/.editorconfig)                     | EditorConfig for consistent formatting (Go tabs, JS/TS 2-space)   |
| [templates/.gitignore](templates/.gitignore)                           | Universal .gitignore (OS, IDE, env, build artifacts, logs)        |
| [templates/devcontainer.json](templates/devcontainer.json)             | Dev Container config with commented feature blocks per stack      |
| [templates/Makefile](templates/Makefile)                               | Full-stack Makefile (dev, prod, checks, release)                  |
| [templates/docker-compose.yml](templates/docker-compose.yml)           | Compose starter (local dev, no TLS)                               |
| [templates/docker-compose.prod.yml](templates/docker-compose.prod.yml) | Production Compose (reverse proxy + Let's Encrypt)                |
| [templates/nginx-tls.conf](templates/nginx-tls.conf)                   | Nginx TLS reverse proxy config                                    |
| [templates/setup-dev-tools.sh](templates/setup-dev-tools.sh)           | Dev tool setup script skeleton (Go, Node/pnpm blocks)             |
| [templates/ci.yml](templates/ci.yml)                                   | GitHub Actions CI workflow (Go, Node, integration tests)          || [templates/.env.example](templates/.env.example)                           | Standard env vars for Docker Compose templates                    || [templates/AGENTS.md](templates/AGENTS.md)                             | Agent instructions template for Copilot Agent Mode                |
| [templates/copilot-instructions.md](templates/copilot-instructions.md) | Copilot instructions template (`.github/copilot-instructions.md`) |

## Scripts

Reusable bash scripts.

| Script                                                     | Description                                                            |
| ---------------------------------------------------------- | ---------------------------------------------------------------------- |
| [scripts/setup-server.sh](scripts/setup-server.sh)         | Provision a fresh Debian/Ubuntu VPS (user, SSH, UFW, fail2ban, Docker) |
| [scripts/prod-init.sh](scripts/prod-init.sh)               | First-time production deploy (cert request + stack start)              |
| [scripts/install-dotfiles.sh](scripts/install-dotfiles.sh) | Bootstrap shell config in a new Codespace or VM                        |

## Skills

Reusable agent skills — copy individual skill directories into project repos as needed.

| Skill                    | Directory                                                                      | Description                                                             |
| ------------------------ | ------------------------------------------------------------------------------ | ----------------------------------------------------------------------- |
| Clarify                  | [skills/clarify/](skills/clarify/)                                             | Structured clarifying questions before acting — never assume             |
| Code Audit               | [skills/code-audit/](skills/code-audit/)                                       | Cross-layer consistency, simplification, and repo verification audit    |
| Create Plan              | [skills/create-plan/](skills/create-plan/)                                     | Plan from PRD or task description — vertical slices + acceptance criteria |
| Write a PRD              | [skills/write-prd/](skills/write-prd/)                                     | Structured PRD creation → local `docs/prds/` file                       |
| Guided Implementation    | [skills/guided-implementation/](skills/guided-implementation/)                 | Step-by-step coaching through a user story or plan phase — developer writes all code |
| Implement Plan           | [skills/implement-plan/](skills/implement-plan/)                               | Execute a plan.md one section at a time — sequential task completion    |
| TDD                      | [skills/tdd/](skills/tdd/)                                                     | Red-green-refactor with vertical slices + reference files               |
| Test Quality             | [skills/test-quality/](skills/test-quality/)                                   | Review and refactor existing tests — remove brittle, implementation-detail tests |
| UX Review                | [skills/ux-review/](skills/ux-review/)                                         | Mobile UX, UI consistency, workflow friction, and terminology review    |
| Ubiquitous Language      | [skills/ubiquitous-language/](skills/ubiquitous-language/)                      | Extract DDD glossary → `UBIQUITOUS_LANGUAGE.md`                         |
| Design Interface         | [skills/design-interface/](skills/design-interface/)                            | "Design It Twice" — parallel sub-agents generate radically different APIs |
| Improve Architecture     | [skills/improve-architecture/](skills/improve-architecture/)                   | Find deepening opportunities → local `docs/rfcs/` RFC                   |
| Handbook Sync            | [skills/handbook-sync/](skills/handbook-sync/)                                 | Audit a project against handbook best practices and apply improvements   |
| PDF Extract              | [skills/pdf-extract/](skills/pdf-extract/)                                     | Extract text, tables, metadata from PDFs (with OCR fallback)            |
| Word Extract             | [skills/docx-extract/](skills/docx-extract/)                                   | Extract text, tables, images, metadata from .docx files                 |
| Excel Extract            | [skills/xlsx-extract/](skills/xlsx-extract/)                                   | Extract data, formulas, metadata from .xlsx workbooks                   |
| Understand               | [skills/understand/](skills/understand/)                                       | Deep codebase exploration to build a human's mental model               |
| Deslop                   | [skills/deslop/](skills/deslop/)                                               | Remove AI-generated slop from code, docs, and config files              |
