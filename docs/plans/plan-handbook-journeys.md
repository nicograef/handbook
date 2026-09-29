# Plan: Handbook Journeys

> Source PRD: `docs/prds/prd-handbook-journeys.md`

## Goal

Every README journey (new dev machine, new project, fresh server, deploy, then backup and restore, Postgres upgrade, maintenance, monitoring) is one chain of runbooks that ends in a runnable Verify block. Templates match the Node/TypeScript, React, Python and Go stacks; Java leaves the handbook. A Linux services reference page teaches the commands the runbooks already use.

## Architectural decisions

- **Base**: the structure plan has landed, its phase 9 `install.sh` run included. `reference/` holds `postgresql.md`, `system-resources.md`, `tmux.md` and `stack-conventions.md`; `dotfiles/` holds the linked dotfiles; `guides/bootstrap.md` is gone; `guides/dev-machine.md` and `guides/deploy.md` exist with the steps moved out of it, each with `## Prerequisites` and `## Verify`; `make check` resolves `#anchor` links against GitHub heading slugs.
- **Choke files as structure leaves them**: `README.md` has the `##` headings Journeys, Dev machine, Project, Server, Agents, Handbook upkeep, License, and every indexed file sits in exactly one area; no phase here adds a `##` heading to it. The Journeys section holds the bootstrap routing verbatim, so it still links `provision-server.md#inputs`, `new-project.md#inputs`, `monitoring.md#inputs`, `#after-provisioning` and the `letsencrypt-docker.md` and `postgresql-operations.md` anchors. `scripts/check-repo.sh` runs the contracts stage with `INDEX_DIRS` = `guides reference templates dotfiles scripts claude`, and this plan leaves it unchanged. `.claude/rules/guides.md` states runbooks only; `.claude/rules/reference.md` holds the reference-page shapes; `.claude/rules/templates.md` is as on main.
- **Runbook set** (all in `guides/`): `dev-machine`, `new-project`, `provision-server`, `ipv6-only-vps`, `deploy`, `backup-restore`, `postgres-upgrade`, `maintenance`, `monitoring`. `letsencrypt-docker.md`, `postgresql-operations.md` and `docker-multi-stage-builds.md` are deleted.
- **Writing rules** (enforced from phase 2 on through `.claude/rules/guides.md`): one task per runbook, 50 to 150 lines; each step is one action plus its expected result; a list holds parallel items only, reasoning is a short paragraph; headings name tasks, never numbers; links target headings, never another file's step number; placeholders are `<angle-brackets>` everywhere, Verify blocks included; agent vocabulary (gate, lane, fold, lead) stays out of runbooks.
- **Runbook shape check**: criteria call this function, pasted into the shell once per phase. It prints nothing when every file passes.

  ```bash
  runbook_shape() {
    for f in "$@"; do
      n=$(wc -l < "$f")
      { [ "$n" -ge 50 ] && [ "$n" -le 150 ]; } || echo "$f: $n lines"
      grep -nE '^#{2,} +[0-9]|myapp|mydb|example\.com|your-domain|nico@' "$f" | sed "s|^|$f:|"
      grep -E '^## ' "$f" | tail -2 | tr '\n' ' ' | grep -qE '## Verify $|## Verify ## Troubleshooting $' || echo "$f: does not end in Verify"
    done
  }
  ```

- **One fact, one place**: a runbook links a script's header for what the script does and restates none of it.
- **Dockerfile templates**: `templates/Dockerfile.python`, `templates/Dockerfile.go`, `templates/Dockerfile.spa`. A project copies each as `<dir>/Dockerfile`, the name `release.yml` builds. Each carries its own `HEALTHCHECK` with a tool the runtime image ships. Backends answer `GET /api/health` on port 8080; the SPA answers `GET /` on port 80. The Go runtime is Alpine, so busybox `wget` probes it. Base-image pins follow the existing ones: `uv:0.12.18-python3.12-trixie-slim`, `node:26-alpine`, `nginx:1.30-alpine`, Go 1.26.
- **SPA nginx config**: `templates/nginx-spa.conf` becomes a complete `server` block. A project copies it as `<frontend-dir>/nginx.conf`, which `Dockerfile.spa` COPYs unedited.
- **Version pins**: CI reads `go-version-file: <backend-dir>/go.mod`, `node-version-file: <frontend-dir>/.node-version` and setup-uv `version-file: <backend-dir>/pyproject.toml` (`[tool.uv] required-version`). pnpm keeps reading `packageManager`. Every other pin stays literal and is found by the `AGENTS.md` grep rule.
- **Python pin**: `.python-version` is the pin; `requires-python` is the floor; the `Dockerfile.python` base tag repeats the pin literally.
- **Deploy on the server**: the project is a git clone under `/opt/<project>`, owned by the deploy user, cloned with a read-only SSH deploy key. `docker login ghcr.io` uses a classic personal access token scoped to `read:packages`. `.env` is copied from `.env.example`, sets `COMPOSE_FILE=docker-compose.prod.yml`, mode 600. A new project defaults to the Caddy variant.
- **Backups**: the deploy user's cron runs the clone's own `scripts/backup-postgres.sh`, so `git pull` keeps the one copy current.
- **Migrations**: golang-migrate commands and the forward-only rules move to `reference/postgresql.md`; they serve every backend stack.
- **Dockerfile test**: `scripts/test-dockerfiles.sh`, run by `make test-dockerfiles`, outside `make check`. It needs only Docker. Stubs carry the fewest dependencies: the Go stub uses the standard library only, the Python stub depends on uvicorn only, and the SPA stub has no dependencies and a build script that writes `dist/index.html`.
- **No phase runs `install.sh`**, and no phase edits `claude/`, `.claude/skills/`, `.claude/agents/`, `AGENTS.md` or `guides/unattended-agents.md`.
- **Frozen headings**: after phase 2 these headings exist, and phases 3 to 10 keep them as written:
  - `guides/deploy.md`: `## TLS variants` (`#tls-variants`), `## Update` (`#update`), `## Roll back` (`#roll-back`).
  - `guides/backup-restore.md`: `## Daily backup` (`#daily-backup`), `## Restore` (`#restore`), `## Restore drill` (`#restore-drill`).
  - `## Prerequisites` (`#prerequisites`) and `## Verify` (`#verify`) in `dev-machine.md`, `new-project.md`, `provision-server.md`, `deploy.md` and `monitoring.md`. Phase 2 renames `## Inputs` to `## Prerequisites` in `new-project.md` and `provision-server.md`.
  - The README Journeys section links runbook files and frozen headings only; phase 2 retargets every `#inputs` link to `#prerequisites`.
  - A cross-file link added after phase 2 targets a frozen heading or a heading in its own phase's files. No phase renames or deletes a heading that a file outside it links to. `rollback_hint()` names `Roll back` and `Restore` as written.

## Inventory

- `guides/new-project.md` — stack matrix with a Java row; Dockerfiles bullet links the multi-stage guide; numbered headings; copies no production or release files.
- `guides/docker-multi-stage-builds.md` — Java, Node and Python Dockerfiles; source of `Dockerfile.python` and `Dockerfile.spa`.
- `guides/letsencrypt-docker.md` — variant table, DNS prerequisite, inputs, TLS Verify and Troubleshooting; merges into `deploy.md`.
- `guides/postgresql-operations.md` — manual backup, restore, cron backup, restore drill, major upgrade, golang-migrate; split three ways.
- `guides/maintenance.md` — image updates and roll back (move to `deploy.md`), reboot routine, monthly checks, OOM diagnosis, restore-drill pointer; no Verify.
- `guides/monitoring.md` — dead-man model and ping-URL table before Prerequisites; no step creates a heartbeat.
- `guides/provision-server.md` — Verify table; `After provisioning` follows Verify and links `letsencrypt-docker.md`.
- `guides/ipv6-only-vps.md` — numbered headings.
- `guides/dev-machine.md` — steps moved from bootstrap: CLI tools, `install.sh`, signing key, editor, Docker; the CLI-tools step links `provision-server.md#after-provisioning`.
- `guides/deploy.md` — first-deploy step moved from bootstrap; links `provision-server.md#verify`, `letsencrypt-docker.md#pick-a-variant` and `letsencrypt-docker.md#verify`.
- `guides/new-project.md`, `guides/provision-server.md` — open with `## Inputs`, which the README Journeys section links.
- `reference/tmux.md` — hides the lingering setup step; links the maintenance OOM heading.
- `reference/system-resources.md` — links the maintenance monthly-checks heading.
- `reference/stack-conventions.md` — Go first, a Java section, no `packageManager` rule, claims CI and image resolve Python from one fact.
- `reference/postgresql.md` — links `postgresql-operations.md`.
- `templates/Makefile` — `be`, `fe`, `be-check`, `fe-check` are TODO stubs with Java lines.
- `templates/ci.yml` — literal `go-version`, `node-version` and uv `version`; Go-only `backend-integration-tests` job.
- `templates/.gitignore`, `templates/.editorconfig`, `templates/vscode-settings.json` — Java lines; no `.deploy-state`.
- `templates/setup-dev-tools.sh` — uv pin comment points at `ci.yml`.
- `templates/docker-compose.prod.yml`, `templates/docker-compose.prod-caddy.yml` — comments name the deleted guides and send usage to `maintenance.md`; the Caddy variant carries a Compose-level frontend healthcheck.
- `templates/nginx-spa.conf` — bare location blocks, header names the multi-stage guide.
- `scripts/prod-init.sh — rollback_hint()` — names `maintenance.md` and `postgresql-operations.md`; header comment names `letsencrypt-docker.md`.
- `scripts/backup-postgres.sh` — header names `postgresql-operations.md §3` and `/opt/scripts`.
- `scripts/check-repo.sh` — the gate; shellcheck covers every script; unchanged by this plan.
- `Makefile` — handbook dev interface; gains `test-dockerfiles`.
- `README.md` — Journeys section with the bootstrap anchors; file index grouped by area; stack-conventions row names Java.
- `.claude/rules/guides.md` — runbook conventions; gains the writing rules.
- `.claude/rules/templates.md` — "Use the real file name" rule; gains the stack-suffix variant.

## Resolved decisions

- Clarifying questions: none; the PRD, the owner decisions and the code settle every point.
- The Go runtime image is Alpine rather than distroless: the healthcheck then needs no health flag in the app.
- The Caddy variant's Compose-level frontend healthcheck goes; the SPA image carries it, as the backend images already do.
- Frontend Node pin is a `.node-version` file; the CI comment already names it.
- uv is pinned in `pyproject.toml` `[tool.uv] required-version`; uv itself then refuses a mismatched local version.
- The template Makefile `be-check` runs the uv gate and `fe-check` the pnpm gate, in the order `reference/stack-conventions.md` documents; a commented block shows the Go gate.
- The existing `backend-integration-tests` job becomes stack-neutral: Python steps (setup-uv, `uv sync`, `uv run pytest -m <marker>` with the opt-in marker from the Python conventions) sit beside the Go steps and share its Postgres service and `migrate up`.
- `templates/dependabot.yml` keeps its docker entry commented; its enable line already tells the copier when.
- Dev-machine install methods match the owner's laptop: Node as the `node` snap `26/stable`, pnpm via `npm install -g` with prefix `~/.local`, uv via pipx, Claude Code via its native installer. gh keeps the apt repo the moved bootstrap step names; the laptop's `gh` is a binary in `~/.local/bin`, so this one method differs.
- Maintenance is the single home of the OOM and lingering explanation; `provision-server.md` holds the lingering step; `reference/tmux.md` links both.
- No new `check-repo.sh` stage: line counts, heading numbers and journey endings are checked by one-shot commands in the criteria.
- Java settings in `claude/settings.json` belong to the agent-layer plan.

## Open questions / Risks

- `deploy.md` absorbs three sources and must stay at or under 150 lines. Linking script headers instead of restating them is what keeps it there.
- `make test-dockerfiles` pulls base images and resolves the stubs' lockfiles over the network; it stays out of `make check`.
- GHCR accepts only classic tokens for package reads at the time of writing; the deploy phase re-checks GitHub's Packages docs before writing the step.

## Phase 1: Stack templates

**User stories**: 2
**Depends on**: none

### Context

- `guides/docker-multi-stage-builds.md` — the Python and Node blocks become templates (read only).
- `templates/nginx-spa.conf`, `templates/docker-compose.prod.yml`, `templates/docker-compose.prod-caddy.yml` — comments and the frontend healthcheck.
- `.claude/rules/templates.md` — the real-file-name rule.
- `Makefile`, `README.md` — new target and index rows.
- `scripts/test-agent-bus.sh` — prior art for a fixture test with its own make target.

### What to build

Three Dockerfile templates a project copies unedited after filling placeholders, each with a `HEALTHCHECK`. `scripts/test-dockerfiles.sh` generates the header's minimal stub app per template in a temp dir, fills the placeholders, builds, runs, and waits until `docker inspect` reports `healthy`; it cleans up containers and images and exits non-zero on any failure. `make test-dockerfiles` runs it. `nginx-spa.conf` becomes a full `server` block. The compose templates point at the Dockerfile templates, and the Caddy variant drops its Compose-level frontend healthcheck. `.claude/rules/templates.md` gains one line: variants of one file carry a suffix (`Dockerfile.python`), and the guide's copy step names the real target file. The README indexes the three Dockerfile templates under Project and `scripts/test-dockerfiles.sh` under Handbook upkeep.

### Acceptance criteria

- [ ] `make test-dockerfiles` exits 0 and reports all three images healthy.
- [ ] `git grep -nE 'HEALTHCHECK' templates/Dockerfile.python templates/Dockerfile.go templates/Dockerfile.spa` prints one hit per file.
- [ ] `git grep -n 'COPY nginx.conf' templates/Dockerfile.spa` prints one line.
- [ ] `git grep -n 'docker-multi-stage-builds' templates/` prints nothing.
- [ ] `docker compose -f templates/docker-compose.prod-caddy.yml --env-file templates/.env.example config --format json | jq '.services.frontend.healthcheck'` prints `null`.
- [ ] `git grep -n 'Dockerfile\.python' .claude/rules/templates.md` shows the variant line.
- [ ] `make check` passes.

## Phase 2: Runbook set

**User stories**: 3, 4, 5, 7
**Depends on**: 1

### Context

- `guides/postgresql-operations.md` — split into `backup-restore.md`, `postgres-upgrade.md` and the migrations section of `reference/postgresql.md`.
- `guides/letsencrypt-docker.md` — merges into `guides/deploy.md`.
- `guides/docker-multi-stage-builds.md` — deleted; `guides/new-project.md` links it.
- `guides/maintenance.md` — image updates and roll back move to `deploy.md`; the restore-drill pointer targets `backup-restore.md`.
- `guides/monitoring.md`, `guides/provision-server.md`, `reference/postgresql.md` — inbound links to the deleted pages.
- `guides/dev-machine.md` — the CLI-tools link to `provision-server.md#after-provisioning`.
- `scripts/prod-init.sh — rollback_hint()`, `scripts/backup-postgres.sh` header, both compose templates' usage comments — name the deleted pages and `maintenance.md`.
- `README.md` — Journeys section, index and the stack-conventions row; `.claude/rules/guides.md` — runbook conventions.
- `guides/new-project.md`, `guides/provision-server.md` — `## Inputs` becomes `## Prerequisites`.

### What to build

A mechanical refactor that fixes the runbook set before any rewrite. Content moves as is; only headings change, to unnumbered task names, and the frozen headings from the header exist. `deploy.md` holds the first deploy, the TLS variant material, update and roll back. `backup-restore.md` holds manual backup, restore, cron setup and the restore drill; `postgres-upgrade.md` holds the major upgrade; golang-migrate lands in `reference/postgresql.md`. `letsencrypt-docker.md`, `postgresql-operations.md` and `docker-multi-stage-builds.md` are deleted, and every inbound link, script comment and hint string points at the new home. The compose usage comments name `guides/deploy.md`. Every inbound `#after-provisioning` link goes; `dev-machine.md`'s CLI-tools step carries the apt line itself. `new-project.md` and `provision-server.md` rename `## Inputs` to `## Prerequisites`. The README Journeys section routes the eight journeys to their runbooks and links runbook files and frozen headings only. The index lists `backup-restore.md` and `postgres-upgrade.md` under Server, and the stack-conventions row loses Java. `.claude/rules/guides.md` gains the writing rules from the header.

### Acceptance criteria

- [ ] `git grep -nE 'letsencrypt-docker|postgresql-operations|docker-multi-stage-builds|after-provisioning' -- . ':!docs/'` prints nothing.
- [ ] `ls guides/backup-restore.md guides/postgres-upgrade.md guides/deploy.md` lists all three.
- [ ] `{ grep -xE '## (TLS variants|Update|Roll back)' guides/deploy.md; grep -xE '## (Daily backup|Restore|Restore drill)' guides/backup-restore.md; } | wc -l` prints 6.
- [ ] `git grep -nE '^#{2,} +[0-9]' guides/deploy.md guides/backup-restore.md guides/postgres-upgrade.md` prints nothing.
- [ ] `git grep -nE 'deploy\.md, Roll back|backup-restore\.md, Restore' scripts/prod-init.sh` prints two lines.
- [ ] `git grep -n 'Usage (first deploy and every update' templates/` shows both compose files naming `guides/deploy.md`.
- [ ] `for f in dev-machine new-project provision-server deploy backup-restore postgres-upgrade maintenance monitoring; do awk '/^## Journeys/{j=1;next} /^## /{j=0} j' README.md | grep -q "guides/$f.md" || echo "$f"; done` prints nothing.
- [ ] `for t in '<angle-brackets>' '50 to 150' 'never numbers'; do grep -qF -- "$t" .claude/rules/guides.md || echo "$t"; done` prints nothing.
- [ ] `awk '/^## Journeys/{j=1;next} /^## /{j=0} j' README.md | grep -oE '\.md#[a-z0-9-]+' | sort -u | grep -vxE '\.md#(prerequisites|verify|tls-variants|update|roll-back|daily-backup|restore|restore-drill)'` prints nothing.
- [ ] `make check` passes.

## Phase 3: Project gate templates

**User stories**: 2
**Depends on**: none

### Context

- `templates/Makefile` — TODO stubs and Java lines.
- `templates/ci.yml` — version inputs; `backend-integration-tests` job.
- `templates/.gitignore`, `templates/.editorconfig`, `templates/vscode-settings.json`, `templates/setup-dev-tools.sh`.
- `reference/stack-conventions.md` — the documented gate order for Node and Python (read only).

### What to build

A copied project runs one gate locally and in CI. The template Makefile's `be`, `fe`, `be-check`, `fe-check` run uv and pnpm commands in the documented gate order, with a commented Go alternative and no Java. `ci.yml` reads the version files from the header, and `backend-integration-tests` gains the Python steps beside the Go ones, sharing its Postgres service and migrate install. `.gitignore` gains `.deploy-state` and loses `*.class`; `.editorconfig` and `vscode-settings.json` lose their Java entries; the uv comment in `setup-dev-tools.sh` points at `required-version`.

### Acceptance criteria

- [ ] `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest -shellcheck= templates/ci.yml` exits 0.
- [ ] `git grep -nE 'go-version:|node-version:|version: "0\.' templates/ci.yml` prints nothing.
- [ ] `git grep -n 'pytest -m' templates/ci.yml` shows the Python integration step.
- [ ] `git grep -c 'Install golang-migrate' templates/ci.yml` prints 2 (integration and upgrade path only).
- [ ] `make -n -f templates/Makefile check` prints the uv gate then the pnpm gate, with no `TODO`.
- [ ] `git grep -nx '.deploy-state' templates/.gitignore` prints one line.
- [ ] `git grep -niE '\bjava\b|mvnw|\*\.class' -- templates/` prints nothing.
- [ ] `make check` passes.

## Phase 4: New project runbook

**User stories**: 2
**Depends on**: 1, 2, 3

### Context

- `guides/new-project.md` — matrix with its Java row, copy steps, Verify.
- `reference/stack-conventions.md` — stack order, pins and the Java section.
- `templates/release.yml`, `templates/nginx-spa.conf`, `templates/.dockerignore`, `scripts/prod-init.sh`, `scripts/backup-postgres.sh`, both compose templates — files the runbook copies (read only).

### What to build

`new-project.md` follows the writing rules. Its matrix rows are Python + React, Python, Go + React, Go, React, Docs; the Java row goes. Each row names its Dockerfile template and stack sections. The copy steps copy each `Dockerfile.<stack>` to `<dir>/Dockerfile` and `nginx-spa.conf` to `<frontend-dir>/nginx.conf`. They also copy `.dockerignore`, the Caddy production Compose file with its Caddyfile, `.env.example`, `prod-init.sh`, `backup-postgres.sh` and `release.yml`. A pin step writes `<frontend-dir>/.node-version`, sets `packageManager` in `package.json`, and writes `.python-version` and `[tool.uv] required-version` for the Python backend. The nginx alternative links `deploy.md#tls-variants`. Verify proves a fresh repo lists its make targets and its production Compose file parses. `stack-conventions.md` runs Node/TypeScript, React, Python, Go with no Java section; it requires a `packageManager` pin and `.node-version`, and states the Python pin and uv `required-version` as the header fixes them.

### Acceptance criteria

- [ ] `grep -E '^## ' reference/stack-conventions.md` prints Node/TypeScript, React, Python, Go in that order.
- [ ] `for t in packageManager .node-version required-version; do grep -qF -- "$t" reference/stack-conventions.md || echo "$t"; done` prints nothing.
- [ ] `for t in Dockerfile.python Dockerfile.go Dockerfile.spa nginx-spa.conf .dockerignore docker-compose.prod-caddy.yml Caddyfile .env.example prod-init.sh backup-postgres.sh release.yml; do grep -qF -- "$t" guides/new-project.md || echo "$t"; done` prints nothing.
- [ ] `for t in .node-version packageManager .python-version required-version; do grep -qF -- "$t" guides/new-project.md || echo "$t"; done` prints nothing.
- [ ] `runbook_shape guides/new-project.md` prints nothing.
- [ ] `git grep -niwE 'java|spring|maven|mvnw' -- guides reference README.md` prints nothing.
- [ ] `make check` passes.

## Phase 5: Deploy runbook

**User stories**: 3, 4, 7
**Depends on**: 2

### Context

- `guides/deploy.md` — the merged material from phase 2.
- `scripts/prod-init.sh` — its header is what the runbook links (read only).
- `guides/provision-server.md`, `guides/backup-restore.md` — headings it links (read only).

### What to build

One runbook from a provisioned server to a running app, and back. Prerequisites: a provisioned server, DNS per host type, a pushed release tag. Steps: create `/opt/<project>`, add a read-only deploy key and clone, `docker login ghcr.io`, create `.env`, confirm the variant's proxy files, run the first deploy, and link `backup-restore.md#daily-backup` for the cron. Update and Roll back stay task headings in the same page. Verify and Troubleshooting cover both TLS variants. Script behaviour is a link to the `prod-init.sh` header, never a restated list.

### Acceptance criteria

- [ ] `git grep -nE 'docker login ghcr.io|/opt/<project>|COMPOSE_FILE|ROLLBACK=1' guides/deploy.md` shows each step.
- [ ] `git grep -n 'backup-restore.md#daily-backup' guides/deploy.md` shows the cron hand-off.
- [ ] `runbook_shape guides/deploy.md` prints nothing.
- [ ] `make check` passes.

## Phase 6: Backup and upgrade runbooks

**User stories**: 5, 7
**Depends on**: 2

### Context

- `guides/backup-restore.md`, `guides/postgres-upgrade.md` — moved material from phase 2.
- `reference/postgresql.md` — migrations section and links.
- `scripts/backup-postgres.sh` — header usage and cron example.

### What to build

`backup-restore.md` sets up the daily verified backup from the project clone, restores a dump, and runs the quarterly drill into a throwaway database; the accepted same-disk risk stays as one short paragraph. `postgres-upgrade.md` moves a stack to a new major version on a fresh volume and verifies the server version and row counts. Both follow the writing rules and link the `backup-postgres.sh` header instead of restating it. The script header's usage and cron line match the runbook.

### Acceptance criteria

- [ ] `git grep -n '/opt/scripts' -- guides reference scripts` prints nothing.
- [ ] `runbook_shape guides/backup-restore.md guides/postgres-upgrade.md` prints nothing.
- [ ] `make check` passes.

## Phase 7: Server upkeep runbooks

**User stories**: 6, 7
**Depends on**: 2

### Context

- `guides/provision-server.md` — Verify table; `After provisioning` after Verify.
- `guides/maintenance.md` — reboot routine, monthly checks, OOM diagnosis; no Verify.
- `guides/ipv6-only-vps.md` — numbered headings.
- `reference/tmux.md` — lingering section.
- `reference/system-resources.md` — link into maintenance.

### What to build

Lingering becomes a provisioning step with its own Verify row (`Linger=yes`). `After provisioning` dissolves: the IPv6-only and deploy pointers become intro links, and the tmux and CLI-tools apt line becomes a step before Verify. `maintenance.md` is one monthly checklist with a Verify that runs one command per check and states its passing result. `## Troubleshooting` follows Verify and holds the OOM section as `### After an OOM kill`, the only place explaining lingering and OOM. The checklist's quarterly item links `backup-restore.md#restore-drill`. `reference/tmux.md` keeps its commands and links both. `ipv6-only-vps.md` gets task headings. All three runbooks follow the writing rules; `ssh nico@` and every other literal becomes a placeholder.

### Acceptance criteria

- [ ] `git grep -n 'enable-linger' -- guides reference` shows `guides/provision-server.md` only, and `git grep -n 'Linger=yes' guides/provision-server.md` shows the Verify row.
- [ ] `git grep -n 'loginctl' reference/tmux.md` prints nothing, and `git grep -n 'provision-server.md' reference/tmux.md` shows the link.
- [ ] `git grep -n 'backup-restore.md#restore-drill' guides/maintenance.md` shows the quarterly item.
- [ ] `runbook_shape guides/provision-server.md guides/maintenance.md guides/ipv6-only-vps.md` prints nothing.
- [ ] `make check` passes.

## Phase 8: Monitoring runbook

**User stories**: 7
**Depends on**: 2

### Context

- `guides/monitoring.md` — model, ping-URL table, heartbeats, Verify.
- `scripts/report-health.sh`, `scripts/backup-postgres.sh` — headers the runbook links (read only).

### What to build

Prerequisites come first. A step creates each heartbeat in Better Stack and stores its URL where the ping-URL table says. The uptime monitor and TLS-expiry heartbeat follow, then the nginx-only cert heartbeat. Verify counts four monitors on Caddy and five on nginx. The dead-man model shrinks to a short paragraph; each script's ping condition is a link to its header.

### Acceptance criteria

- [ ] `grep -E '^## ' guides/monitoring.md | head -1` prints `## Prerequisites`.
- [ ] `runbook_shape guides/monitoring.md` prints nothing.
- [ ] `make check` passes.

## Phase 9: Dev machine runbook

**User stories**: 1
**Depends on**: 2

### Context

- `guides/dev-machine.md` — steps moved from bootstrap.
- `scripts/install-dotfiles.sh` — its header is what the runbook links for `install.sh` (read only).

### What to build

A fresh Ubuntu laptop reaches a working toolchain in one pass. Steps: SSH key, git identity, gh and `gh auth login`, Node, pnpm, uv, Claude Code, Docker, CLI tools with their own apt line, clone the handbook, then `install.sh`, the signing key and the editor. Install methods follow the header decision. Verify runs one version command per tool plus the symlink check.

### Acceptance criteria

- [ ] `for t in ssh-keygen 'git config --global user.' 'gh auth login' 'snap install node' 'npm install -g' 'pipx install uv' 'claude --version' install.sh; do grep -qF -- "$t" guides/dev-machine.md || echo "$t"; done` prints nothing.
- [ ] `git grep -n 'provision-server' guides/dev-machine.md` prints nothing.
- [ ] `runbook_shape guides/dev-machine.md` prints nothing.
- [ ] `make check` passes.

## Phase 10: Linux services reference and journey check

**User stories**: 6
**Depends on**: 4, 5, 6, 7, 8, 9

### Context

- `reference/linux-services.md` — new page.
- `guides/provision-server.md`, `guides/maintenance.md`, `guides/deploy.md` — the runbooks whose commands it collects, and which link it.
- `README.md` — index row; Journeys section.

### What to build

`reference/linux-services.md` covers systemd units, `journalctl`, Compose operations, ports and firewall, as command tables. Each table's first column holds the command in the literal form a runbook uses; the other columns explain it. Those runbooks link the page. `reference/system-resources.md` stays the hardware and live-usage sheet. The README indexes the page under Server, and every runbook passes the shape check.

### Acceptance criteria

- [ ] `` awk -F'|' '/^\|/{print $2}' reference/linux-services.md | grep -oE '`[^`]+`' | tr -d '`' | sort -u | while IFS= read -r c; do git grep -qF -- "$c" guides/ || echo "$c"; done `` prints nothing.
- [ ] `git grep -ln 'linux-services.md' guides/` lists `deploy.md`, `maintenance.md` and `provision-server.md`.
- [ ] `runbook_shape guides/{dev-machine,new-project,provision-server,ipv6-only-vps,deploy,backup-restore,postgres-upgrade,maintenance,monitoring}.md` prints nothing.
- [ ] `for f in dev-machine new-project provision-server deploy backup-restore postgres-upgrade maintenance monitoring; do awk '/^## Journeys/{j=1;next} /^## /{j=0} j' README.md | grep -q "guides/$f.md" || echo "$f"; done` prints nothing.
- [ ] `{ grep -xE '## (TLS variants|Update|Roll back)' guides/deploy.md; grep -xE '## (Daily backup|Restore|Restore drill)' guides/backup-restore.md; } | wc -l` prints 6.
- [ ] `git grep -nE '^#{2,} +[0-9]' -- guides ':!guides/unattended-agents.md'` prints nothing.
- [ ] `make check` passes.
