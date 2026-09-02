# Set Up a New Project Repository

This is the "New project" path of [bootstrap.md](bootstrap.md).

## Inputs

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

Set `HANDBOOK` to your clone.

```bash
HANDBOOK=<handbook>
cp "$HANDBOOK/templates/.editorconfig" .
cp "$HANDBOOK/templates/.gitignore" .
mkdir -p .vscode && cp "$HANDBOOK/templates/vscode-settings.json" .vscode/settings.json
cp "$HANDBOOK/templates/Makefile" .
```

## 3. Stack scaffolding

Pick the row for your `<stack>`; copy only its templates. `db` = uncomment the Postgres
service in the Compose file and copy `.env.example`.

| Project shape | Compose + env | devcontainer features | Dockerfiles | Stack guide |
|---------------|---------------|-----------------------|-------------|-------------|
| Full-stack Go + React | `docker-compose.yml` + `.env.example` (`db`) | Go + Node + Docker-in-Docker | backend + frontend | [stack-conventions.md#go](stack-conventions.md#go) + [#react](stack-conventions.md#react) |
| Go service only | `docker-compose.yml` + `.env.example` (`db`) | Go + Docker-in-Docker | backend | [stack-conventions.md#go](stack-conventions.md#go) |
| Java Spring Boot service | `docker-compose.yml` + `.env.example` (`db`) | `java` (add — not pre-listed) + Docker-in-Docker | backend | [stack-conventions.md#java](stack-conventions.md#java) |
| React frontend only | `docker-compose.yml` (app only, no `db`) | Node | frontend | [stack-conventions.md#react](stack-conventions.md#react) |
| Docs-only | — | — | — | — |

```bash
cp "$HANDBOOK/templates/docker-compose.yml" .          # skip for docs-only
cp "$HANDBOOK/templates/.env.example" .                # only shapes with a db
mkdir -p .devcontainer && cp "$HANDBOOK/templates/devcontainer.json" .devcontainer/devcontainer.json
mkdir -p scripts && cp "$HANDBOOK/templates/setup-dev-tools.sh" scripts/setup-dev-tools.sh
```

- **Dockerfiles** — one per built tier, following [docker-multi-stage-builds.md](docker-multi-stage-builds.md); Java and Node examples there.
- A Go backend uses the same two-stage pattern: compile a static binary into a minimal runtime image.
- Then follow the linked **stack guide(s)** for source layout and conventions.

## 4. CI and dependency updates

```bash
mkdir -p .github/workflows
cp "$HANDBOOK/templates/ci.yml" .github/workflows/ci.yml
cp "$HANDBOOK/templates/dependabot.yml" .github/dependabot.yml
```

## 5. Agent setup

```bash
cp "$HANDBOOK/templates/AGENTS.md" AGENTS.md
printf '@AGENTS.md\n' > CLAUDE.md          # first line imports AGENTS.md
```

- [templates/AGENTS.md](../templates/AGENTS.md) — Communication section carries the anti-sycophancy rules; see [anti-sycophancy.md](anti-sycophancy.md) for the rationale and full countermeasure map.
- Add deeper layers only when needed: contextual instructions, skills, agents, prompts.
- See [copilot-agent-setup.md](copilot-agent-setup.md) for the layer table and when to add each.

## 6. Handbook plugin adoption

```bash
mkdir -p .claude && cp "$HANDBOOK/templates/claude-settings.json" .claude/settings.json
```

## Verify

```bash
make help                                        # lists the stack's make targets
head -1 CLAUDE.md                                # -> @AGENTS.md
git symbolic-ref --short HEAD                    # -> main
grep -Eo 'extraKnownMarketplaces|enabledPlugins' .claude/settings.json
# -> extraKnownMarketplaces
# -> enabledPlugins
```
