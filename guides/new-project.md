# Set Up a New Project Repository

Take an empty directory to a repository whose `make check` passes. Index: [README Journeys](../README.md#journeys).

## Prerequisites

- The dev machine passes [dev-machine.md#verify](dev-machine.md#verify).
- The backend lives in `backend/`, the frontend in `frontend/`, migrations in `database/`; the templates name these directories. Every backend runs Postgres.

| Input | Description | Example |
|-------|-------------|---------|
| `<project-name>` | Repo, directory and Compose project name (kebab-case) | `order-service` |
| `<github-owner>` | GitHub user or org that owns the repo | `nicograef` |
| `<visibility>` | Repo visibility | `public` or `private` |
| `<handbook>` | Path to your local handbook clone | `~/r/handbook` |
| `<database-name>` | Postgres database name | `orders` |
| `<project-go-version>` | Go release: the `go` directive of `go.mod`, the devcontainer Go feature, `setup-dev-tools.sh` | `1.27.1` |
| `<go-minor>` | Go minor of that release: the `Dockerfile.go` base tag | `1.27` |
| `<project-python-version>` | Python minor: `uv init`, the `Dockerfile.python` base tag | `3.12` |
| `<uv-version>` | uv floor: `pyproject.toml`, the `Dockerfile.python` base tag, `setup-dev-tools.sh` | `0.13.0` |
| `<pytest-marker>` | Opt-in pytest marker for integration tests | `integration` |
| `<node-major>` | Node major: `.node-version`, the `Dockerfile.spa` base tag, the devcontainer Node feature, the dev Compose image | `26` |

## Pick the stack

| Stack | Dockerfile templates | devcontainer features | Stack sections | `<other-stacks>` |
|-------|----------------------|-----------------------|----------------|------------------|
| Python + React | [`Dockerfile.python`](../templates/Dockerfile.python), [`Dockerfile.spa`](../templates/Dockerfile.spa) | Node, Docker-in-Docker | [Python](../reference/stack-conventions.md#python), [Node/TypeScript](../reference/stack-conventions.md#nodetypescript), [React](../reference/stack-conventions.md#react) | `go` |
| Python | [`Dockerfile.python`](../templates/Dockerfile.python) | Docker-in-Docker | [Python](../reference/stack-conventions.md#python) | `go frontend` |
| Go + React | [`Dockerfile.go`](../templates/Dockerfile.go), [`Dockerfile.spa`](../templates/Dockerfile.spa) | Go, Node, Docker-in-Docker | [Go](../reference/stack-conventions.md#go), [Node/TypeScript](../reference/stack-conventions.md#nodetypescript), [React](../reference/stack-conventions.md#react) | `python` |
| Go | [`Dockerfile.go`](../templates/Dockerfile.go) | Go, Docker-in-Docker | [Go](../reference/stack-conventions.md#go) | `python frontend` |
| React | [`Dockerfile.spa`](../templates/Dockerfile.spa) | Node | [Node/TypeScript](../reference/stack-conventions.md#nodetypescript), [React](../reference/stack-conventions.md#react) | `go python database` |
| Docs | — | — | — | `go python frontend database` |

A Docs repository runs [Create the repository](#create-the-repository), [Copy the base files](#copy-the-base-files) and [Set up the agent files](#set-up-the-agent-files). Of [Fill the templates](#fill-the-templates), it runs only the block deletion.
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
3. Block force pushes and deletion of the default branch with a ruleset. Expected: the call prints `default-branch`.
   ```bash
   gh api -X POST /repos/{owner}/{repo}/rulesets -q .name --input - <<'EOF'
   {"name": "default-branch", "target": "branch", "enforcement": "active",
    "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
    "rules": [{"type": "non_fast_forward"}, {"type": "deletion"}]}
   EOF
   ```
   It requires no status checks, so a direct push to `main` still lands. A private repository needs GitHub Pro, Team or Enterprise for [rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets).

## Copy the base files

1. Copy the editor, git and make files. Expected: `make help` prints the DEVELOPER and PRODUCTION sections.
   ```bash
   HANDBOOK=<handbook>
   cp "$HANDBOOK"/templates/{.editorconfig,.gitignore,Makefile} . && mkdir -p .vscode scripts
   cp "$HANDBOOK/templates/vscode-settings.json" .vscode/settings.json && cp "$HANDBOOK/templates/make-help.awk" scripts/
   ```

## Scaffold the stack

1. Copy the local Compose file, devcontainer, CI and Dependabot config; uncomment Postgres and your row's features. Expected: `docker compose config --quiet` exits 0.
   ```bash
   cp "$HANDBOOK/templates/docker-compose.yml" . && cp "$HANDBOOK/templates/setup-dev-tools.sh" scripts/
   mkdir -p .devcontainer .github/workflows && cp "$HANDBOOK/templates/devcontainer.json" .devcontainer/devcontainer.json
   cp "$HANDBOOK/templates/ci.yml" .github/workflows/ci.yml && cp "$HANDBOOK/templates/dependabot.yml" .github/dependabot.yml
   ```
2. Scaffold each tier your row names and copy its Dockerfile template. A backend row writes the first migration, which CI applies. Expected: each tier has its `Dockerfile`, a backend row `database/migrations/000001_init.up.sql`.
   ```bash
   uv init --package --python <project-python-version> backend && cp "$HANDBOOK/templates/Dockerfile.python" backend/Dockerfile   # Python
   (mkdir -p backend && cd backend && go mod init github.com/<github-owner>/<project-name> && go mod edit -go=<project-go-version>) && cp "$HANDBOOK/templates/Dockerfile.go" backend/Dockerfile   # Go
   pnpm create vite frontend --template react-ts --no-interactive && cp "$HANDBOOK/templates/Dockerfile.spa" frontend/Dockerfile && cp "$HANDBOOK/templates/nginx-spa.conf" frontend/nginx.conf   # React
   mkdir -p database/migrations && printf 'CREATE TABLE app_meta (key text PRIMARY KEY, value text NOT NULL);\n' > database/migrations/000001_init.up.sql   # Python or Go
   for d in $(ls -d backend frontend 2>/dev/null); do cp "$HANDBOOK/templates/.dockerignore" "$d"/; done
   ```
3. A Go backend adds its health server, linter config, tools and first sqlc query, and uncomments the Makefile's Go blocks. Expected: `go tool sqlc diff` and `go build -o /dev/null ./cmd/<project-name>` in `backend/` exit 0.
   ```bash
   mkdir -p backend/cmd/<project-name> && printf 'package main\n\nimport (\n\t"log"\n\t"net/http"\n\t"time"\n)\n\nfunc main() {\n\tmux := http.NewServeMux()\n\tmux.HandleFunc("GET /api/health", func(w http.ResponseWriter, _ *http.Request) {\n\t\t_, _ = w.Write([]byte("ok"))\n\t})\n\tsrv := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}\n\tlog.Fatal(srv.ListenAndServe())\n}\n' > backend/cmd/<project-name>/main.go
   cp "$HANDBOOK/templates/golangci.yml" backend/.golangci.yml && mkdir -p backend/sqlc/queries && printf -- '-- name: GetMeta :one\nSELECT value FROM app_meta WHERE key = $1;\n' > backend/sqlc/queries/meta.sql
   printf 'version: "2"\nsql:\n  - engine: postgresql\n    schema: ../database/migrations\n    queries: sqlc/queries\n    gen:\n      go: {package: db, out: internal/db}\n' > backend/sqlc.yaml
   (cd backend && go get -tool golang.org/x/tools/cmd/goimports github.com/sqlc-dev/sqlc/cmd/sqlc golang.org/x/vuln/cmd/govulncheck && go tool sqlc generate)
   sed -i '/^# >>> stack: go$/,/^# <<< stack: go$/{/stack: go$/!s/^# //}' Makefile
   ```

## Set up the toolchain

1. Pin Node and pnpm, then add the frontend checks: run the [Package scripts](../reference/stack-conventions.md#package-scripts) block where the comment marks it. Expected: `pnpm --dir frontend test` passes.
   ```bash
   echo <node-major> > frontend/.node-version && cd frontend && npm pkg set packageManager="pnpm@$(pnpm --version)"
   # run the Package scripts block from stack-conventions.md here
   printf 'pnpm-lock.yaml\n' > .prettierignore     # pnpm owns the lockfile format
   printf "import { expect, test } from 'vitest'\nimport App from './App'\n\ntest('App is a component', () => {\n  expect(typeof App).toBe('function')\n})\n" > src/App.test.tsx && pnpm run format && cd ..
   ```
2. Set the Python backend's uv floor and pytest table, and add uvicorn and its dev tools. Write the app factory, a smoke test and an integration test. Expected: `backend/.python-version` holds `<project-python-version>`, and `backend/uv.lock` names `psycopg`, `pytest` and `uvicorn`.
   ```bash
   printf '\n[tool.uv]\nrequired-version = ">=<uv-version>"\n' >> backend/pyproject.toml
   # append the [tool.pytest] block from stack-conventions.md#python here, <marker> = <pytest-marker>
   uv add --directory backend uvicorn && uv add --directory backend --dev pytest ruff ty 'psycopg[binary]'
   printf 'def app():\n    async def asgi(scope, receive, send):\n        if scope["type"] != "http":\n            return\n        status = 200 if scope["path"] == "/api/health" else 404\n        await send({"type": "http.response.start", "status": status, "headers": []})\n        await send({"type": "http.response.body", "body": b"ok"})\n\n    return asgi\n' > backend/src/backend/api.py
   mkdir -p backend/tests && printf 'from backend import main\n\n\ndef test_main_prints(capsys):\n    main()\n    assert capsys.readouterr().out\n' > backend/tests/test_smoke.py
   printf 'import os\n\nimport psycopg\nimport pytest\n\n\n@pytest.mark.<pytest-marker>\ndef test_first_migration_applied():\n    env = os.environ\n    with psycopg.connect(\n        host=env["DB_HOST"],\n        user=env["POSTGRES_USER"],\n        password=env["POSTGRES_PASSWORD"],\n        dbname=env["POSTGRES_DB"],\n    ) as conn:\n        assert conn.execute("SELECT count(*) FROM app_meta").fetchone() == (0,)\n' > backend/tests/test_database.py
   ```

## Copy the production files

1. Copy the Caddy production stack, the env template and the deploy scripts. Expected: `docker-compose.prod.yml` and `reverse-proxy/Caddyfile` exist.
   ```bash
   cp "$HANDBOOK"/templates/{docker-compose.prod.yml,.env.example} . && cp "$HANDBOOK"/templates/{prod-init.sh,backup-postgres.sh} scripts/
   mkdir -p reverse-proxy && cp "$HANDBOOK/templates/Caddyfile" reverse-proxy/Caddyfile
   cp "$HANDBOOK/templates/release.yml" .github/workflows/release.yml
   ```
2. Delete the tiers your row lacks from `docker-compose.prod.yml`, the `release.yml` matrix and the Caddyfile. Expected: `docker compose -f docker-compose.prod.yml config --services` lists only your tiers, `postgres` and `reverse-proxy`.
   The production Compose template pins the app images at `v0.1.0`. Push that as the first release tag, or bump the pins to it first, as [deploy.md#update](deploy.md#update) does.

## Fill the templates

1. Delete the blocks of your row's `<other-stacks>`. Expected: `grep -c 'stack: go$' Makefile` prints `0` on a Python row.
   ```bash
   for s in <other-stacks>; do sed -i "/# >>> stack: $s\$/,/# <<< stack: $s\$/d" $(ls Makefile .github/workflows/ci.yml .github/dependabot.yml scripts/setup-dev-tools.sh 2>/dev/null); done
   ```
2. Fill the names and versions. Expected: the `grep` prints nothing.
   ```bash
   PROJECT=<project-name> OWNER=<github-owner> DB=<database-name> MARKER=<pytest-marker> GOV=<project-go-version> GOMINOR=<go-minor> UV=<uv-version> PY=<project-python-version> NODE=<node-major>
   FILES=$(ls Makefile docker-compose*.yml .devcontainer/* scripts/setup-dev-tools.sh .github/*.yml .github/workflows/*.yml */Dockerfile frontend/nginx.conf 2>/dev/null)
   sed -i -e "s|<owner>|$OWNER|g; s|<project>|$PROJECT|g; s|<name>|$PROJECT|g; s|<package>|backend|g; s|<database-name>|$DB|g; s|<marker>|$MARKER|g" \
     -e "s|<project-go-version>|$GOV|g; s|<go-minor>|$GOMINOR|g; s|<uv-version>|$UV|g; s|<project-python-version>|$PY|g; s|<node-major>|$NODE|g; s|my-project-dev|$PROJECT-dev|" $FILES
   sed -i "s|^name: [a-z]*|name: $PROJECT|" docker-compose*.yml
   grep -n '^[^#]*<[a-z][a-z-]\+>' $FILES    # placeholders outside comments
   ```

## Set up the agent files

1. Import `AGENTS.md` from `CLAUDE.md`. Expected: `head -1 CLAUDE.md` prints `@AGENTS.md`.
   ```bash
   printf '@AGENTS.md\n' > CLAUDE.md
   ```
2. Write `AGENTS.md` with what the global [claude/global.md](../claude/global.md) cannot know: the project, its `make` targets, project-only rules. `/init` drafts it.
3. Create `docs/README.md`, one row per page with the question it answers, and `docs/decisions.md`, one line per decision from `D01`. A replaced line gets `replaced by DNN`.

## Verify

```bash
make help                                             # DEVELOPER and PRODUCTION sections list the targets
make check                                            # every check of the stack passes
docker compose -f docker-compose.prod.yml --env-file .env.example config --quiet && echo ok   # backend rows -> ok
```
