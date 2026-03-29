# Plan: Handbook Evaluation & Greenfield Comparison

> Source PRD: n/a (from task description)

## Goal

Evaluate the current handbook against what an ideal greenfield developer
handbook would look like, identify concrete gaps, and propose a convergence
roadmap — prioritised for a **single senior engineer** using this as a
**personal knowledge base**.

## Resolved decisions

- **Audience**: Personal reference only — no onboarding or team focus needed.
- **Infrastructure scope**: Docker Compose on VPS. Kubernetes is out of scope.
- **Theory files**: Frozen German imports — no translation, no expansion.
- **Skills directory**: Central to the handbook, evaluated equally with guides/templates/scripts.
- **Output**: Current-state evaluation + ideal-state comparison + convergence roadmap.

---

## Part A: Current-State Evaluation

### What works well (keep as-is)

| Area | Strength |
|------|----------|
| **Guides** (11 files, avg 4.4/5) | Runbook-style, copy-paste ready, verification steps. `copilot-agent-setup.md`, `letsencrypt-docker.md`, and `java-spring-boot.md` are exceptional. |
| **Scripts** (4 files, avg 4.6/5) | Defensive (`set -euo pipefail`), idempotent, color-coded logging, pre-flight checks. Best-in-class for a personal repo. |
| **Templates** (12 files, avg 4.3/5) | Functional as-is, security-conscious (`nginx-tls.conf` has HSTS + rate limiting), clear placeholder convention (`<angle-brackets>`). |
| **Theory** (9 files, avg 4.5/5) | Deep architectural coverage (DDD, CQRS, hexagonal). Comprehensive Go and React reference. |
| **Skills** (13 skills, avg 4.2/5) | Well-structured YAML frontmatter, actionable workflows, anti-pattern warnings. TDD skill has 4 reference files. |
| **AGENTS.md** (4.7/5) | Comprehensive boundaries, plan-first workflow, anti-duplication rules, conventional commits. |
| **Instructions** (5 files, 4.5/5) | Per-directory enforcement with `applyTo` patterns. Clear format requirements. |
| **Cross-cutting** | Consistent voice, strong cross-references over duplication, README as index. |

### What needs improvement

#### Critical gaps

| # | Gap | Impact | Evidence |
|---|-----|--------|----------|
| 1 | **Cheatsheets collection is too small** (3 files) | Missing quick-reference for daily tools: git, postgresql, make, curl/wget | You use Make heavily (template exists), git throughout, postgres in theory — but no cheatsheets |
| 2 | **No database operations guide** | No runbook for postgres backups, migrations, or recovery despite postgres being in your stack | `theory/postgresql.md` exists but no practical guide |
| 3 | **`unix-commands.md` is skeletal** | Only 5 commands (grep, netstat, journalctl, jq, split) — not useful as a cheatsheet | Missing: find, sed, awk, curl, ssh, tar, systemctl |
| 4 | **`docker-setup.md` is too brief** | ~50 lines, no links to related guides or cheatsheet | Other guides are 200-700 lines |
| 5 | **README lists templates that may not exist** | `.bash_aliases`, `.editorconfig`, `.gitignore` in README but not in visible file tree | Broken index or hidden files |

#### Medium issues

| # | Issue | Detail |
|---|-------|--------|
| 6 | **`ci.yml` has 4+ TODO placeholders** | Users must hunt and replace before it works |
| 7 | **`setup-dev-tools.sh` is 80% commented out** | Unclear which blocks to uncomment for which stack |
| 8 | **Skills have no discovery mechanism** | 13 skills, no index explaining when to use which |
| 9 | **No `.github/instructions/` for skills/** | No guidance on creating new skills or required format |
| 10 | **Cheatsheet format is inconsistent** | docker-compose uses code blocks, unix-commands uses raw snippets, vim uses tables |
| 11 | **Clarify skill referenced wrong tool name** | `AskQuestion` instead of `vscode_askQuestions` — fixed during this session |

#### Low priority / polish

| # | Issue | Detail |
|---|-------|--------|
| 12 | Guides don't cross-link uniformly | Some reference cheatsheets, some don't |
| 13 | No troubleshooting sections in most guides | Only `letsencrypt-docker.md` has one |
| 14 | No `.env.example` template | Referenced in docker-compose templates but no example file |
| 15 | Scripts lack `--dry-run` mode | Would make `setup-server.sh` safer to preview |

---

## Part B: Ideal Greenfield Handbook

If starting from scratch with the same stack (Go, React, TypeScript, PostgreSQL,
Docker, Debian/Ubuntu) and the same purpose (personal knowledge base + agent
skills), an ideal handbook would have this structure:

```
handbook/
├── AGENTS.md                          # repo-level agent instructions
├── README.md                          # full index of everything
├── install.sh                         # bootstrap script
│
├── guides/                            # step-by-step runbooks
│   ├── server/
│   │   ├── provision-server.md
│   │   ├── docker-setup.md
│   │   └── backup-restore.md          ← MISSING
│   ├── deployment/
│   │   ├── docker-multi-stage-builds.md
│   │   ├── letsencrypt-docker.md
│   │   ├── nginx-reverse-proxy.md
│   │   └── github-actions-cicd.md
│   ├── backend/
│   │   ├── go.md
│   │   ├── java-spring-boot.md
│   │   └── postgresql-operations.md   ← MISSING
│   ├── frontend/
│   │   └── react.md
│   └── tooling/
│       ├── copilot-agent-setup.md
│       └── dotfiles-codespaces.md
│
├── cheatsheets/                       # quick-reference, no prose
│   ├── git.md                         ← MISSING
│   ├── unix-commands.md               (needs expansion)
│   ├── docker-compose.md
│   ├── vim.md
│   ├── postgresql.md                  ← MISSING
│   ├── makefile.md                    ← MISSING
│   └── curl-wget.md                   ← MISSING (or merge into unix)
│
├── templates/                         # copy-paste config files
│   ├── (current set is solid)
│   └── .env.example                   ← MISSING
│
├── scripts/                           # reusable bash scripts
│   └── (current set is solid)
│
├── theory/                            # conceptual reference (German, frozen)
│   └── (current set, no changes)
│
├── skills/                            # reusable agent skills
│   ├── README.md                      ← MISSING (discovery index)
│   └── (current set)
│
└── .github/
    └── instructions/
        ├── (current 5 files)
        └── skills.instructions.md     ← MISSING
```

### Key differences from current state

| Aspect | Current | Ideal | Gap severity |
|--------|---------|-------|-------------|
| **Guide organisation** | Flat (11 files) | Subdirectories by domain | Low — flat is fine at this size |
| **Cheatsheet count** | 3 | 7-8 | **High** — daily tools missing |
| **Database operations** | Theory only | Theory + practical guide | **High** — stack gap |
| **Skills discoverability** | None | README.md index | **Medium** — 13 skills, no map |
| **Template completeness** | 12 files | 13 files (+.env.example) | Low |
| **Format consistency** | Mixed cheatsheet styles | Uniform table/code format | Medium |
| **Cross-linking** | Partial | Systematic | Low |

### What the greenfield would NOT need

- Kubernetes guides (out of scope)
- Theory translations (frozen)
- Team onboarding docs (personal use)
- Monitoring/observability guides (overkill for VPS + Compose)
- Pre-commit config (no linting pipeline needed for a docs repo)

---

## Part C: Convergence Roadmap

Prioritised actions to move the current handbook toward the ideal state.
Ordered by impact (high → low), effort-aware.

### Phase 1: Fill critical content gaps

- [x] **Expand `cheatsheets/unix-commands.md`** — add find, sed, awk, curl, ssh, tar, systemctl, lsof, du/df
- [x] **Create `cheatsheets/git.md`** — branches, rebasing, stashing, log, aliases, common workflows
- [x] **Create `cheatsheets/postgresql.md`** — psql commands, backup/restore, common queries, index management
- [x] **Create `guides/postgresql-operations.md`** — backup strategies, pg_dump/pg_restore, migrations with golang-migrate, monitoring queries

### Phase 2: Fix consistency issues

- [x] **Create `cheatsheets/makefile.md`** — target syntax, variables, pattern rules, phony targets (supports the Makefile template)
- [x] **Expand `guides/docker-setup.md`** — add links to multi-stage builds guide, compose cheatsheet; add post-install verification
- [x] **Standardise cheatsheet format** — pick one format (tables for short entries, fenced code for multi-line) and apply consistently
- [x] **Verify README template list** — confirm `.bash_aliases`, `.editorconfig`, `.gitignore` exist; fix README if they don't

### Phase 3: Improve discoverability & tooling

- [x] **Create `skills/README.md`** — problem → skill matrix (e.g., "planning a feature" → create-plan, "code review" → code-audit)
- [x] **Create `.github/instructions/skills.instructions.md`** — format requirements for new skills (YAML frontmatter, workflow section, constraints)
- [x] **Clean up `templates/ci.yml`** — replace TODOs with commented examples; make the Go path work out of the box
- [x] **Clean up `templates/setup-dev-tools.sh`** — uncomment Go + Node blocks as defaults; keep specialised tools commented

### Phase 4: Polish

- [x] **Add cross-links to all guides** — each guide should link to related cheatsheets, templates, and other guides
- [x] **Create `templates/.env.example`** — standard env vars for the docker-compose templates
- [x] **Add troubleshooting sections** to `github-actions-cicd.md`, `docker-multi-stage-builds.md`, `nginx-reverse-proxy.md`
- [x] **Add `--dry-run` flag** to `scripts/setup-server.sh`

---

## Open questions / Risks

- **Subdirectory structure for guides**: The ideal layout uses subdirectories (`guides/server/`, `guides/backend/`). At 11-15 files, flat is still manageable. Consider subdirectories only if the count exceeds ~20.
- **Cheatsheet format decision**: Tables vs. code blocks needs a deliberate choice before Phase 2. The instructions file should be updated to codify whichever format is chosen.
