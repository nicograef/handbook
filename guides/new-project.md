# Set Up a New Project Repository

This is the "New project" journey of the [README](../README.md#journeys).
It ends in a repository that lists its make targets and holds a parsing production Compose file.

## Prerequisites

- The dev machine passes [dev-machine.md#verify](dev-machine.md#verify).
- Every input below has a value. Stack-specific rows apply only to stacks that have that tier.

| Input | Description | Example |
|-------|-------------|---------|
| `<project-name>` | Repo, directory and Compose project name (kebab-case) | `order-service` |
| `<github-owner>` | GitHub user or org that owns the repo | `nicograef` |
| `<visibility>` | Repo visibility | `public` or `private` |
| `<handbook>` | Path to your local handbook clone | `~/r/handbook` |
| `<backend-dir>` | Backend source directory | `backend` |
| `<frontend-dir>` | Frontend source directory | `frontend` |
| `<database-dir>` | Migrations directory | `database` |
| `<database-name>` | Postgres database name | `orders` |
| `<project-go-version>` | `go` directive of `go.mod` | `1.26.5` |
| `<project-python-version>` | Python minor in the `Dockerfile.python` base tag | `3.12` |
| `<uv-version>` | uv version in the `Dockerfile.python` base tag | `0.12.18` |
| `<node-major>` | Node major in the `Dockerfile.spa` base tag | `26` |

## Pick the stack

Each row names its Dockerfile templates, its devcontainer features and its [stack conventions](../reference/stack-conventions.md) sections.
Every stack with a backend runs Postgres. The stack sections set source layout, linters and tests.

| Stack | Dockerfile templates | devcontainer features | Stack sections |
|-------|----------------------|-----------------------|----------------|
| Python + React | [`Dockerfile.python`](../templates/Dockerfile.python), [`Dockerfile.spa`](../templates/Dockerfile.spa) | Node, Docker-in-Docker | [Python](../reference/stack-conventions.md#python), [Node/TypeScript](../reference/stack-conventions.md#nodetypescript), [React](../reference/stack-conventions.md#react) |
| Python | [`Dockerfile.python`](../templates/Dockerfile.python) | Docker-in-Docker | [Python](../reference/stack-conventions.md#python) |
| Go + React | [`Dockerfile.go`](../templates/Dockerfile.go), [`Dockerfile.spa`](../templates/Dockerfile.spa) | Go, Node, Docker-in-Docker | [Go](../reference/stack-conventions.md#go), [Node/TypeScript](../reference/stack-conventions.md#nodetypescript), [React](../reference/stack-conventions.md#react) |
| Go | [`Dockerfile.go`](../templates/Dockerfile.go) | Go, Docker-in-Docker | [Go](../reference/stack-conventions.md#go) |
| React | [`Dockerfile.spa`](../templates/Dockerfile.spa) | Node | [Node/TypeScript](../reference/stack-conventions.md#nodetypescript), [React](../reference/stack-conventions.md#react) |
| Docs | — | — | — |

A Docs repository runs [Create the repository](#create-the-repository), [Copy the base files](#copy-the-base-files) and [Set up the agent files](#set-up-the-agent-files) only.

## Create the repository

1. Create the repository with `main` as its default branch and enter it. Expected: `git status` prints `On branch main`.
   ```bash
   gh repo create <github-owner>/<project-name> --<visibility> --clone && cd <project-name>
   # without a remote: git init -b main <project-name> && cd <project-name>
   ```

## Copy the base files

1. Copy the editor, git and make files. Expected: `make help` prints the DEVELOPER and PRODUCTION sections.
   ```bash
   HANDBOOK=<handbook>
   cp "$HANDBOOK"/templates/{.editorconfig,.gitignore,Makefile} .
   mkdir -p .vscode scripts && cp "$HANDBOOK/templates/vscode-settings.json" .vscode/settings.json
   cp "$HANDBOOK/templates/make-help.awk" scripts/make-help.awk
   ```

## Scaffold the stack

1. Copy the local Compose file and the devcontainer, then uncomment Postgres and your row's features. Expected: `docker compose config --quiet` exits 0.
   ```bash
   cp "$HANDBOOK/templates/docker-compose.yml" .
   mkdir -p .devcontainer && cp "$HANDBOOK/templates/devcontainer.json" .devcontainer/devcontainer.json
   cp "$HANDBOOK/templates/setup-dev-tools.sh" scripts/setup-dev-tools.sh
   ```
2. Scaffold each tier your row names. Expected: `<backend-dir>/pyproject.toml`, `<backend-dir>/go.mod` or `<frontend-dir>/package.json` exists.
   ```bash
   uv init --package --python <project-python-version> <backend-dir>          # Python
   (mkdir -p <backend-dir> && cd <backend-dir> && go mod init github.com/<github-owner>/<project-name>)   # Go
   pnpm create vite <frontend-dir> --template react-ts --no-interactive       # React
   ```
3. Copy each Dockerfile template of your row, then `.dockerignore` and the SPA nginx config. Expected: every tier directory holds a `Dockerfile`.
   ```bash
   cp "$HANDBOOK/templates/Dockerfile.python" <backend-dir>/Dockerfile        # or Dockerfile.go
   cp "$HANDBOOK/templates/Dockerfile.spa" <frontend-dir>/Dockerfile
   cp "$HANDBOOK/templates/nginx-spa.conf" <frontend-dir>/nginx.conf
   for d in <backend-dir> <frontend-dir>; do cp "$HANDBOOK/templates/.dockerignore" "$d"/; done
   ```
4. A Go backend adds its tools to `go.mod` and swaps in the Go recipes the Makefile comments show. Expected: `go tool goimports -l .` runs.
   ```bash
   (cd <backend-dir> && go get -tool golang.org/x/tools/cmd/goimports github.com/sqlc-dev/sqlc/cmd/sqlc golang.org/x/vuln/cmd/govulncheck)
   ```

## Pin the toolchain versions

1. Pin Node and pnpm for the frontend. Expected: `.node-version` holds `<node-major>`, `package.json` names `pnpm@<version>`.
   ```bash
   echo <node-major> > <frontend-dir>/.node-version
   pnpm --dir <frontend-dir> pkg set packageManager="pnpm@$(pnpm --version)"
   ```
2. Pin uv for the Python backend, then lock. `uv init` already wrote `.python-version`. Expected: `uv.lock` exists.
   ```bash
   printf '\n[tool.uv]\nrequired-version = "==<uv-version>"\n' >> <backend-dir>/pyproject.toml
   uv lock --directory <backend-dir>    # a local uv other than <uv-version> fails: "Required uv version"
   ```

## Copy the production files

1. Copy the Caddy production stack, the env template and the deploy scripts. Expected: `docker-compose.prod.yml` and `reverse-proxy/Caddyfile` exist.
   ```bash
   cp "$HANDBOOK/templates/docker-compose.prod-caddy.yml" docker-compose.prod.yml
   mkdir -p reverse-proxy && cp "$HANDBOOK/templates/Caddyfile" reverse-proxy/Caddyfile
   cp "$HANDBOOK/templates/.env.example" .
   cp "$HANDBOOK"/scripts/{prod-init.sh,backup-postgres.sh} scripts/
   mkdir -p .github/workflows && cp "$HANDBOOK/templates/release.yml" .github/workflows/release.yml
   ```
   The nginx + Certbot stack swaps in the files [deploy.md#tls-variants](deploy.md#tls-variants) lists.
2. Name the images and the Compose project. Expected: `grep -c '<owner>' docker-compose.prod.yml` prints `0`.
   ```bash
   sed -i 's|<owner>|<github-owner>|g; s|<project>|<project-name>|g' docker-compose.prod.yml .github/workflows/release.yml
   sed -i 's|^name: .*|name: <project-name>|' docker-compose.prod.yml
   ```
3. Delete the tiers your row lacks from `docker-compose.prod.yml`, the `release.yml` matrix and the Caddyfile. A React stack also drops `postgres` and `backup-postgres.sh`.

## Set up CI and dependency updates

1. Copy the workflow and Dependabot config, then fill their `<angle-bracket>` directory and database inputs. Expected: `grep -c '<backend-dir>' .github/workflows/ci.yml` prints `0`.
   ```bash
   cp "$HANDBOOK/templates/ci.yml" .github/workflows/ci.yml
   cp "$HANDBOOK/templates/dependabot.yml" .github/dependabot.yml
   ```
2. Require SHA-pinned actions, so a tag reference fails the run. Expected: the call prints nothing.
   ```bash
   gh api -X PUT /repos/{owner}/{repo}/actions/permissions -F enabled=true -F sha_pinning_required=true
   ```

## Set up the agent files

1. Import `AGENTS.md` from `CLAUDE.md`. Expected: `head -1 CLAUDE.md` prints `@AGENTS.md`.
   ```bash
   printf '@AGENTS.md\n' > CLAUDE.md
   ```
2. Write `AGENTS.md` with what the global [claude/CLAUDE.md](../claude/CLAUDE.md) cannot know: the project, its `make` targets, project-only rules. `/init` drafts it.
3. Create `docs/README.md`, one row per page with the question it answers. Create `docs/decisions.md`, one line per decision numbered `D01`.
   A replaced line gets `replaced by DNN`.

## Verify

```bash
make help                                             # DEVELOPER and PRODUCTION sections list the targets
docker compose -f docker-compose.prod.yml --env-file .env.example config --quiet && echo ok   # -> ok
head -1 CLAUDE.md                                     # -> @AGENTS.md
git symbolic-ref --short HEAD                         # -> main
uv lock --check --directory <backend-dir>             # Python only: exit 0
```
