# Set Up a New Project Repository

Scaffold a new repo from the handbook's templates: pick a project shape, copy the
matching template subset in the right order, then wire up agent config, CI, and the
handbook plugin. This is the "New project" path of [bootstrap.md](bootstrap.md).

## Prerequisites

- `gh` CLI authenticated (`gh auth status`) — or plain `git` for the local-only path.
- A local clone of this handbook (for the `cp` commands below).
- The toolchain for your chosen stack installed (see the stack guide in [Step 3](#3-stack-scaffolding)).

### Inputs

| Input | Description | Example |
|-------|-------------|---------|
| `<project-name>` | Repo and directory name (kebab-case) | `order-service` |
| `<github-owner>` | GitHub user or org that owns the repo | `nicograef` |
| `<visibility>` | Repo visibility | `public` or `private` |
| `<stack>` | Project shape from the [Step 3 matrix](#3-stack-scaffolding) | `full-stack Go + React` |
| `<handbook>` | Path to your local handbook clone | `~/r/handbook` |
| `<backend-dir>` | Backend source directory (`ci.yml`, `dependabot.yml`) | `backend` |
| `<frontend-dir>` | Frontend source directory (`ci.yml`, `dependabot.yml`) | `frontend` |
| `<database-dir>` | Migrations directory (`ci.yml`) — db-backed stacks only | `database` |
| `<database-name>` | Postgres database name (`ci.yml`) — db-backed stacks only | `myapp` |
| `<project-go-version>` | `go` directive from `go.mod` (`setup-dev-tools.sh`) — Go stacks only | `1.26.5` |

## 1. Create the repository

Default branch is `main`.

```bash
gh repo create <github-owner>/<project-name> --<visibility> --clone
cd <project-name>
```

Local-only (no remote yet):

```bash
git init -b main <project-name> && cd <project-name>
```

## 2. Base files every repo gets

Copy the universal files. Set `HANDBOOK` to your clone, then:

```bash
HANDBOOK=<handbook>
cp "$HANDBOOK/templates/.editorconfig" .
cp "$HANDBOOK/templates/.gitignore" .
mkdir -p .vscode && cp "$HANDBOOK/templates/vscode-settings.json" .vscode/settings.json
cp "$HANDBOOK/templates/Makefile" .
```

- [templates/Makefile](../templates/Makefile) → trim targets to the stack (drop `prod-*`
  for a service you do not self-host, `fe`/`be` for a single-tier repo). See
  [cheatsheets/makefile.md](../cheatsheets/makefile.md).

## 3. Stack scaffolding

Pick the row for your `<stack>`; copy only its templates. `db` = uncomment the Postgres
service in the Compose file and copy `.env.example`.

| Project shape | Compose + env | devcontainer features | Dockerfiles | Stack guide |
|---------------|---------------|-----------------------|-------------|-------------|
| Full-stack Go + React | `docker-compose.yml` + `.env.example` (`db`) | Go + Node + Docker-in-Docker | backend + frontend | [go.md](go.md) + [react.md](react.md) |
| Go service only | `docker-compose.yml` + `.env.example` (`db`) | Go + Docker-in-Docker | backend | [go.md](go.md) |
| Java Spring Boot service | `docker-compose.yml` + `.env.example` (`db`) | `java` (add — not pre-listed) + Docker-in-Docker | backend | [java-spring-boot.md](java-spring-boot.md) |
| React frontend only | `docker-compose.yml` (app only, no `db`) | Node | frontend | [react.md](react.md) |
| Docs-only | — | — | — | — |

```bash
cp "$HANDBOOK/templates/docker-compose.yml" .          # skip for docs-only
cp "$HANDBOOK/templates/.env.example" .                # only shapes with a db
mkdir -p .devcontainer && cp "$HANDBOOK/templates/devcontainer.json" .devcontainer/devcontainer.json
mkdir -p scripts && cp "$HANDBOOK/templates/setup-dev-tools.sh" scripts/setup-dev-tools.sh
```

- [templates/setup-dev-tools.sh](../templates/setup-dev-tools.sh) — fill the
  `<project-go-version>` placeholder (Go stacks) and uncomment the frontend-deps block (repos
  with a `frontend/`); otherwise the devcontainer `postCreateCommand` fails.
- **Dockerfiles** — one per built tier, following
  [docker-multi-stage-builds.md](docker-multi-stage-builds.md) (Java and Node examples there;
  a Go backend uses the same two-stage pattern — compile a static binary into a minimal
  runtime image).
- Then follow the linked **stack guide(s)** for source layout and conventions.

## 4. CI and dependency updates

```bash
mkdir -p .github/workflows
cp "$HANDBOOK/templates/ci.yml" .github/workflows/ci.yml
cp "$HANDBOOK/templates/dependabot.yml" .github/dependabot.yml
```

- [templates/ci.yml](../templates/ci.yml) — delete the jobs that do not apply, fill
  `<backend-dir>` / `<frontend-dir>` / `<database-dir>` / `<database-name>`. Patterns:
  [github-actions-cicd.md](github-actions-cicd.md).
- [templates/dependabot.yml](../templates/dependabot.yml) — keep only the ecosystems your
  repo uses; adapt the directories.

## 5. Agent setup

```bash
cp "$HANDBOOK/templates/AGENTS.md" AGENTS.md
printf '@AGENTS.md\n' > CLAUDE.md          # first line imports AGENTS.md
mkdir -p .github && cp "$HANDBOOK/templates/copilot-instructions.md" .github/copilot-instructions.md
```

- [templates/AGENTS.md](../templates/AGENTS.md) — fill in every `<placeholder>` (tech stack,
  commands, structure, boundaries). Single source of truth for all agent surfaces. Its
  Communication section carries the anti-sycophancy rules — see
  [anti-sycophancy.md](anti-sycophancy.md) for the rationale and full countermeasure map.
- `CLAUDE.md` — sibling whose first line is `@AGENTS.md` so Claude Code loads the same rules.
- [templates/copilot-instructions.md](../templates/copilot-instructions.md) →
  `.github/copilot-instructions.md` — Copilot-only deltas, or delete it if none.
- Add deeper layers (contextual instructions, skills, agents, prompts) only when needed — see
  [copilot-agent-setup.md](copilot-agent-setup.md) for the layer table and when to add each.

## 6. Handbook plugin adoption

```bash
mkdir -p .claude && cp "$HANDBOOK/templates/claude-settings.json" .claude/settings.json
```

- [templates/claude-settings.json](../templates/claude-settings.json) →
  `.claude/settings.json` — cloud Claude sessions load the handbook skills with zero setup.
- On a dev machine that already loads the skills via the symlink tier, add the gitignored
  opt-out per [claude-plugin.md](claude-plugin.md#dev-machine-opt-out).

## Verify

```bash
make help                                        # lists the stack's make targets
head -1 CLAUDE.md                                # -> @AGENTS.md
git symbolic-ref --short HEAD                    # -> main
grep -Eo 'extraKnownMarketplaces|enabledPlugins' .claude/settings.json
# -> extraKnownMarketplaces
# -> enabledPlugins
```

---

See also:
- [guides/bootstrap.md](bootstrap.md) — the four bootstrap scenarios (VPS, Codespace, dev machine, project)
- [guides/copilot-agent-setup.md](copilot-agent-setup.md) — agent context layers
- [guides/claude-plugin.md](claude-plugin.md) — plugin adoption and dev-machine opt-out
- [guides/docker-multi-stage-builds.md](docker-multi-stage-builds.md) — production Dockerfiles
- [guides/github-actions-cicd.md](github-actions-cicd.md) — CI workflow patterns
- [guides/go.md](go.md) · [guides/react.md](react.md) · [guides/java-spring-boot.md](java-spring-boot.md) — stack conventions
