# handbook

Setting something up? Start at [Journeys](#journeys); the file index follows, grouped by area.

## Journeys

Start here when you (or an agent) are told "follow the handbook to set up X".

- Gather the listed inputs **before** you start, so nothing is discovered mid-run.
- This section is routing only — every command lives in the linked guide.

### Fresh VPS

Provision a Debian/Ubuntu box, then layer on TLS, monitoring, and backups as the
workload needs.

**Gather first** — assemble the inputs from these sections before step 1:

- [provision-server.md#inputs](guides/provision-server.md#inputs)
- [letsencrypt-docker.md#inputs](guides/letsencrypt-docker.md#inputs) (web app only)
- [monitoring.md#inputs](guides/monitoring.md#inputs)

1. **Provision & harden** (always) — [provision-server.md](guides/provision-server.md)
   via the cloud-init primary path.
2. **IPv6-only box only** — [ipv6-only-vps.md](guides/ipv6-only-vps.md). Skip on dual-stack servers.
3. **Install the CLI tools the aliases expect** (optional) —
   [After provisioning](guides/provision-server.md#after-provisioning); only if you SSH
   in to work on the box.
4. **Deploy TLS + reverse proxy** (web app only) — [deploy.md](guides/deploy.md).
5. **External monitoring** — [monitoring.md](guides/monitoring.md).

   - Health-ping heartbeat: applies to any box.
   - HTTPS uptime monitor, cert heartbeat, backup heartbeat: once it hosts a web app.

6. **Backups** (app has a database) —
   [postgresql-operations.md](guides/postgresql-operations.md) with
   [scripts/backup-postgres.sh](scripts/backup-postgres.sh) on the daily cron.
7. **Ongoing upkeep** — [maintenance.md](guides/maintenance.md).

**Done when** these Verify sections pass:

- [provision](guides/provision-server.md#verify)
- [TLS](guides/letsencrypt-docker.md#verify)
- [monitoring](guides/monitoring.md#verify)
- [backups](guides/postgresql-operations.md#verify)

### New dev machine

Follow [dev-machine.md](guides/dev-machine.md) end-to-end; **done when** its Verify section passes.

### New project

**Gather first** — [new-project.md#inputs](guides/new-project.md#inputs).

Follow [new-project.md](guides/new-project.md) end-to-end; **done when** its Verify section passes.

## Dev machine

A developer laptop: dotfiles linked into `$HOME`, editor, terminal multiplexer.

| File | Description |
| --- | --- |
| [guides/dev-machine.md](guides/dev-machine.md) | Set up a dev machine: CLI tools, dotfiles, Claude config, editor, Docker |
| [install.sh](install.sh) | Dotfiles entrypoint; runs `scripts/install-dotfiles.sh` |
| [scripts/install-dotfiles.sh](scripts/install-dotfiles.sh) | Symlink shell and Claude config on a dev machine; `--check` lists the links |
| [dotfiles/.bash_aliases](dotfiles/.bash_aliases) | Shell aliases (git, make, pnpm), history tuning, git prompt |
| [dotfiles/.tmux.conf](dotfiles/.tmux.conf) | tmux defaults for remote work (mouse, scrollback, escape-time) |
| [dotfiles/init.lua](dotfiles/init.lua) | Neovim config: prose defaults, 2-space indent, German keyboard remaps |
| [guides/neovim.md](guides/neovim.md) | Neovim for text editing |
| [reference/tmux.md](reference/tmux.md) | tmux |
| [scripts/report-repo-status.sh](scripts/report-repo-status.sh) | Repos under `~/r` with unpushed, uncommitted or stashed work; `repo-status` |

## Project

Copy-once files and conventions for a new project repository.

| File | Description |
| --- | --- |
| [guides/new-project.md](guides/new-project.md) | Set up a new project repository |
| [reference/stack-conventions.md](reference/stack-conventions.md) | Go, Java/Spring Boot, Node/TypeScript, React, Python conventions |
| [guides/docker-multi-stage-builds.md](guides/docker-multi-stage-builds.md) | Docker multi-stage builds |
| [templates/Makefile](templates/Makefile) | Full-stack Makefile (dev, prod, checks, release) |
| [templates/make-help.awk](templates/make-help.awk) | Renders `make help` by target class; `scripts/make-help.awk` |
| [templates/setup-dev-tools.sh](templates/setup-dev-tools.sh) | Dev tool setup script skeleton (Go, Node/pnpm, Python/uv blocks) |
| [templates/devcontainer.json](templates/devcontainer.json) | Dev Container config with commented feature blocks per stack |
| [templates/.editorconfig](templates/.editorconfig) | EditorConfig for consistent formatting (Go tabs, JS/TS 2-space) |
| [templates/.gitignore](templates/.gitignore) | Universal .gitignore (OS, IDE, env, build artifacts, logs, Claude local settings) |
| [templates/vscode-settings.json](templates/vscode-settings.json) | VS Code workspace settings for consistent formatting |
| [templates/docker-compose.yml](templates/docker-compose.yml) | Compose starter (local dev, no TLS) |
| [templates/Dockerfile.python](templates/Dockerfile.python) | Python (uv) backend image with a HEALTHCHECK; copied as `<backend-dir>/Dockerfile` |
| [templates/Dockerfile.go](templates/Dockerfile.go) | Go backend image: static binary on Alpine with a HEALTHCHECK; copied as `<backend-dir>/Dockerfile` |
| [templates/Dockerfile.spa](templates/Dockerfile.spa) | React SPA image: pnpm build served by nginx with a HEALTHCHECK; copied as `<frontend-dir>/Dockerfile` |
| [templates/.dockerignore](templates/.dockerignore) | Build-context excludes: VCS, secrets, host toolchains, tests, docs |
| [templates/.env.example](templates/.env.example) | Standard env vars for Docker Compose templates |
| [templates/nginx-spa.conf](templates/nginx-spa.conf) | SPA container nginx server block: client-side routing + asset caching; copied as `<frontend-dir>/nginx.conf` |
| [templates/ci.yml](templates/ci.yml) | GitHub Actions CI workflow (Go, Node, Python, integration, security scans, upgrade path, restore drill) |
| [templates/release.yml](templates/release.yml) | GitHub Actions release workflow: a vX.Y.Z tag pushes the app images to GHCR |
| [templates/golangci.yml](templates/golangci.yml) | golangci-lint v2 config: security linters, layer guard, goimports |
| [templates/dependabot.yml](templates/dependabot.yml) | Dependabot config (monthly, one grouped PR per ecosystem) |

## Server

Provision, deploy, back up, monitor and maintain a VPS.

| File | Description |
| --- | --- |
| [guides/provision-server.md](guides/provision-server.md) | Provision & harden a new VPS |
| [guides/ipv6-only-vps.md](guides/ipv6-only-vps.md) | IPv6-only VPS (DNS64/NAT64, Docker) |
| [guides/deploy.md](guides/deploy.md) | First deploy of a web app with TLS and a reverse proxy |
| [guides/letsencrypt-docker.md](guides/letsencrypt-docker.md) | Let's Encrypt with Docker Compose |
| [guides/postgresql-operations.md](guides/postgresql-operations.md) | PostgreSQL operations |
| [guides/monitoring.md](guides/monitoring.md) | External monitoring (Better Stack) |
| [guides/maintenance.md](guides/maintenance.md) | Server maintenance & upkeep |
| [reference/postgresql.md](reference/postgresql.md) | PostgreSQL |
| [reference/system-resources.md](reference/system-resources.md) | System info and resource usage |
| [templates/cloud-init.yml](templates/cloud-init.yml) | cloud-init user-data that fetches & runs `setup-server.sh` |
| [scripts/setup-server.sh](scripts/setup-server.sh) | Provision a fresh Debian/Ubuntu VPS (user, SSH, swap, UFW, fail2ban, Docker) |
| [scripts/prod-init.sh](scripts/prod-init.sh) | Production deploy and update: pin and downgrade guard, backup, health poll |
| [scripts/backup-postgres.sh](scripts/backup-postgres.sh) | Verified, retained PostgreSQL backups for a Compose stack (cron) |
| [scripts/report-health.sh](scripts/report-health.sh) | Hourly dead-man health ping (reboot-required + unattended-upgrades + OOM check) |
| [templates/docker-compose.prod.yml](templates/docker-compose.prod.yml) | Production Compose (nginx + Certbot, pinned registry images) |
| [templates/docker-compose.prod-caddy.yml](templates/docker-compose.prod-caddy.yml) | Production Compose with Caddy: automatic TLS, healthchecks, resource limits |
| [templates/Caddyfile](templates/Caddyfile) | Caddy site config: www redirect, security headers, API and SPA routes |
| [templates/docker-compose.initial-cert.yml](templates/docker-compose.initial-cert.yml) | Minimal Compose for first-time cert issuance (ACME challenge only) |
| [templates/nginx-initial-cert.conf](templates/nginx-initial-cert.conf) | Catch-all nginx config for the initial ACME challenge |
| [templates/nginx-tls.conf](templates/nginx-tls.conf) | Nginx TLS reverse proxy config |

## Agents

Global Claude Code config, skills, agents and the scripts they call.

| File | Description |
| --- | --- |
| [guides/unattended-agents.md](guides/unattended-agents.md) | Unattended agent runs |
| [claude/CLAUDE.md](claude/CLAUDE.md) | Global Claude instructions |
| [claude/settings.json](claude/settings.json) | Claude settings + hooks |
| [claude/statusline.sh](claude/statusline.sh) | Status line script |
| [.claude/skills/README.md](.claude/skills/README.md) | Skills index |
| [.claude/agents/web-researcher.md](.claude/agents/web-researcher.md) | Web research agent |
| [scripts/agent-bus.sh](scripts/agent-bus.sh) | Coordination bus for concurrent Claude Code sessions in one repo |
| [scripts/check-agents.sh](scripts/check-agents.sh) | Last activity of background agents, read off their task transcripts |
| [scripts/plan-run-guard.sh](scripts/plan-run-guard.sh) | Stop hook that keeps a live plan run from yielding the turn |

## Handbook upkeep

Rules and checks for maintaining this repo.

| File | Description |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Repo agent rules |
| `.claude/rules/` | Per-directory conventions, loaded by path |
| [scripts/check-repo.sh](scripts/check-repo.sh) | Repo self-check; `make check` |
| [scripts/test-agent-bus.sh](scripts/test-agent-bus.sh) | Fixture test for `agent-bus.sh`; `make test-agent-bus` |
| [scripts/test-plan-run-guard.sh](scripts/test-plan-run-guard.sh) | Fixture test for `plan-run-guard.sh`; `make test-plan-run-guard` |
| [scripts/test-dockerfiles.sh](scripts/test-dockerfiles.sh) | Builds the Dockerfile templates against stub apps until healthy; `make test-dockerfiles` |

## License

MIT — see [LICENSE](LICENSE).
