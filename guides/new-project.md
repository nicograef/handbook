# Set Up a New Project Repository

This is the "New project" journey of the [README](../README.md#journeys). It ends in a repository whose `make check` passes.

## Prerequisites

- The dev machine passes [dev-machine.md#verify](dev-machine.md#verify).
- The backend lives in `backend/`, the frontend in `frontend/`, migrations in `database/`; the templates name these directories.

| Input | Description | Example |
|-------|-------------|---------|
| `<project-name>` | Repo, directory and Compose project name (kebab-case) | `order-service` |
| `<github-owner>` | GitHub user or org that owns the repo | `nicograef` |
| `<visibility>` | Repo visibility | `public` or `private` |
| `<handbook>` | Path to your local handbook clone | `~/r/handbook` |
| `<database-name>` | Postgres database name | `orders` |
| `<project-go-version>` | Go release for the `go` directive of `go.mod` | `1.26.5` |
| `<project-python-version>` | Python minor in the `Dockerfile.python` base tag | `3.12` |
| `<uv-version>` | uv version in the `Dockerfile.python` base tag | `0.12.18` |
| `<pytest-marker>` | Opt-in pytest marker for integration tests | `integration` |
| `<node-major>` | Node major in the `Dockerfile.spa` base tag | `26` |

## Pick the stack

Each row names its Dockerfile templates, devcontainer features, [stack conventions](../reference/stack-conventions.md) sections and the template blocks it deletes. Every backend runs Postgres.

| Stack | Dockerfile templates | devcontainer features | Stack sections | `<other-stacks>` |
|-------|----------------------|-----------------------|----------------|------------------|
| Python + React | [`Dockerfile.python`](../templates/Dockerfile.python), [`Dockerfile.spa`](../templates/Dockerfile.spa) | Node, Docker-in-Docker | [Python](../reference/stack-conventions.md#python), [Node/TypeScript](../reference/stack-conventions.md#nodetypescript), [React](../reference/stack-conventions.md#react) | `go` |
| Python | [`Dockerfile.python`](../templates/Dockerfile.python) | Docker-in-Docker | [Python](../reference/stack-conventions.md#python) | `go frontend` |
| Go + React | [`Dockerfile.go`](../templates/Dockerfile.go), [`Dockerfile.spa`](../templates/Dockerfile.spa) | Go, Node, Docker-in-Docker | [Go](../reference/stack-conventions.md#go), [Node/TypeScript](../reference/stack-conventions.md#nodetypescript), [React](../reference/stack-conventions.md#react) | `python` |
| Go | [`Dockerfile.go`](../templates/Dockerfile.go) | Go, Docker-in-Docker | [Go](../reference/stack-conventions.md#go) | `python frontend` |
| React | [`Dockerfile.spa`](../templates/Dockerfile.spa) | Node | [Node/TypeScript](../reference/stack-conventions.md#nodetypescript), [React](../reference/stack-conventions.md#react) | `go python database` |
| Docs | — | — | — | — |

A Docs repository runs only [Create the repository](#create-the-repository), [Copy the base files](#copy-the-base-files) and [Set up the agent files](#set-up-the-agent-files).
A React repository skips [Copy the production files](#copy-the-production-files): `prod-init.sh` does not deploy it. A static SPA goes to static hosting or behind an existing proxy.

## Create the repository

1. Create the repository with `main` as its default branch and enter it. Expected: `git status` prints `On branch main`.
   ```bash
   gh repo create <github-owner>/<project-name> --<visibility> --clone && cd <project-name>
   # without a remote: git init -b main <project-name> && cd <project-name>
   ```
2. Require SHA-pinned actions, so a tag reference fails the run. Expected: the call prints nothing.
   ```bash
   gh api -X PUT /repos/{owner}/{repo}/actions/permissions -F enabled=true -F sha_pinning_required=true
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

1. Copy the local Compose file, devcontainer, CI and Dependabot config; uncomment Postgres and your row's features. Expected: `docker compose config --quiet` exits 0.
   ```bash
   cp "$HANDBOOK/templates/docker-compose.yml" .
   mkdir -p .devcontainer && cp "$HANDBOOK/templates/devcontainer.json" .devcontainer/devcontainer.json
   cp "$HANDBOOK/templates/setup-dev-tools.sh" scripts/setup-dev-tools.sh
   mkdir -p .github/workflows && cp "$HANDBOOK/templates/ci.yml" .github/workflows/ci.yml
   cp "$HANDBOOK/templates/dependabot.yml" .github/dependabot.yml
   ```
2. Scaffold each tier your row names and copy its Dockerfile template. Expected: `backend/Dockerfile` or `frontend/Dockerfile` exists per tier.
   ```bash
   uv init --package --python <project-python-version> backend                  # Python
   cp "$HANDBOOK/templates/Dockerfile.python" backend/Dockerfile
   (mkdir -p backend && cd backend && go mod init github.com/<github-owner>/<project-name> && go mod edit -go=<project-go-version>)   # Go
   cp "$HANDBOOK/templates/Dockerfile.go" backend/Dockerfile
   pnpm create vite frontend --template react-ts --no-interactive               # React
   cp "$HANDBOOK/templates/Dockerfile.spa" frontend/Dockerfile && cp "$HANDBOOK/templates/nginx-spa.conf" frontend/nginx.conf
   for d in backend frontend; do cp "$HANDBOOK/templates/.dockerignore" "$d"/; done
   ```
3. A Go backend adds its linter config and tools, and swaps in the Makefile's commented Go recipes. Expected: `go tool goimports -l .` runs.
   ```bash
   cp "$HANDBOOK/templates/golangci.yml" backend/.golangci.yml
   (cd backend && go get -tool golang.org/x/tools/cmd/goimports github.com/sqlc-dev/sqlc/cmd/sqlc golang.org/x/vuln/cmd/govulncheck)
   ```

## Set up the toolchain

1. Pin Node and pnpm, then add the frontend gate the [Node/TypeScript](../reference/stack-conventions.md#nodetypescript) conventions name. Expected: `pnpm --dir frontend test` passes.
   ```bash
   echo <node-major> > frontend/.node-version && cd frontend
   npm pkg set packageManager="pnpm@$(pnpm --version)"
   pnpm add -D typescript@~7.0 oxlint-tsgolint prettier vitest     # writes pnpm-lock.yaml
   npm pkg set scripts.format="prettier --write ." "scripts.format:check=prettier --check ." scripts.lint="oxlint --type-aware --deny-warnings" scripts.typecheck="tsc -b" scripts.test="vitest run"
   printf 'pnpm-lock.yaml\n' > .prettierignore     # pnpm owns the lockfile format
   printf "import { expect, test } from 'vitest'\nimport App from './App'\n\ntest('App is a component', () => {\n  expect(typeof App).toBe('function')\n})\n" > src/App.test.tsx && pnpm run format && cd ..
   ```
2. Set the uv floor for the Python backend, add its dev tools and a smoke test. Expected: `backend/.python-version` holds `<project-python-version>`, and `backend/uv.lock` names `pytest`.
   ```bash
   printf '\n[tool.uv]\nrequired-version = ">=<uv-version>"\n' >> backend/pyproject.toml
   uv add --directory backend --dev pytest ruff ty    # a uv below <uv-version> fails: "Required uv version"
   mkdir -p backend/tests && printf 'from backend import main\n\n\ndef test_main_prints(capsys):\n    main()\n    assert capsys.readouterr().out\n' > backend/tests/test_smoke.py
   ```

## Copy the production files

1. Copy the Caddy production stack, the env template and the deploy scripts. Expected: `docker-compose.prod.yml` and `reverse-proxy/Caddyfile` exist.
   ```bash
   cp "$HANDBOOK/templates/docker-compose.prod-caddy.yml" docker-compose.prod.yml
   mkdir -p reverse-proxy && cp "$HANDBOOK/templates/Caddyfile" reverse-proxy/Caddyfile
   cp "$HANDBOOK/templates/.env.example" .
   cp "$HANDBOOK"/scripts/{prod-init.sh,backup-postgres.sh} scripts/
   cp "$HANDBOOK/templates/release.yml" .github/workflows/release.yml
   ```
   The nginx + Certbot stack swaps in the files [deploy.md#tls-variants](deploy.md#tls-variants) lists; the name fill below covers them.
2. Delete the tiers your row lacks from `docker-compose.prod.yml`, the `release.yml` matrix and the Caddyfile. Expected: `docker compose -f docker-compose.prod.yml config --services` lists only your tiers, `postgres` and `reverse-proxy`.
   Both production Compose templates pin the app images at `v0.1.0`. Push that as the first release tag, or bump the pins to it first, as [deploy.md#update](deploy.md#update) does.

## Fill the templates

1. Delete the blocks of your row's `<other-stacks>`. Expected: `grep -c 'stack: go$' .github/workflows/ci.yml` prints `0` on a Python row.
   ```bash
   for s in <other-stacks>; do sed -i "/# >>> stack: $s\$/,/# <<< stack: $s\$/d" .github/workflows/ci.yml .github/dependabot.yml scripts/setup-dev-tools.sh; done
   ```
2. Fill the names and versions. Expected: the `grep` prints nothing.
   ```bash
   PROJECT=<project-name> OWNER=<github-owner> DB=<database-name> MARKER=<pytest-marker> GOV=<project-go-version>
   FILES=$(ls Makefile docker-compose*.yml .devcontainer/* scripts/setup-dev-tools.sh .github/*.yml .github/workflows/*.yml */Dockerfile frontend/nginx.conf 2>/dev/null)
   sed -i -e "s|<owner>|$OWNER|g; s|<project>|$PROJECT|g; s|<name>|$PROJECT|g; s|<package>|backend|g; s|<database-name>|$DB|g" \
     -e "s|<marker>|$MARKER|g; s|<project-go-version>|$GOV|g; s|my-project-dev|$PROJECT-dev|" $FILES
   sed -i "s|^name: [a-z]*|name: $PROJECT|" docker-compose*.yml
   grep -n '^[^#]*<[a-z][a-z-]\+>' $FILES    # placeholders outside comments
   ```

## Set up the agent files

1. Import `AGENTS.md` from `CLAUDE.md`. Expected: `head -1 CLAUDE.md` prints `@AGENTS.md`.
   ```bash
   printf '@AGENTS.md\n' > CLAUDE.md
   ```
2. Write `AGENTS.md` with what the global [claude/CLAUDE.md](../claude/CLAUDE.md) cannot know: the project, its `make` targets, project-only rules. `/init` drafts it.
3. Create `docs/README.md`, one row per page with the question it answers, and `docs/decisions.md`, one line per decision from `D01`. A replaced line gets `replaced by DNN`.

## Verify

```bash
make help                                             # DEVELOPER and PRODUCTION sections list the targets
make check                                            # every gate of the stack passes
docker compose -f docker-compose.prod.yml --env-file .env.example config --quiet && echo ok   # -> ok
```
