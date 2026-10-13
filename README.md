# handbook

## Journeys

Start here when you (or an agent) are told "follow the handbook to set up X".

- Gather the runbook's Prerequisites **before** step 1, so nothing is discovered mid-run.

| Journey | Follow | Done when |
| --- | --- | --- |
| New dev machine | [dev-machine.md](guides/dev-machine.md) | [Verify](guides/dev-machine.md#verify) passes |
| New project | [new-project.md](guides/new-project.md) | [Verify](guides/new-project.md#verify) passes |
| Fresh server | [provision-server.md](guides/provision-server.md); an IPv6-only box runs [Set DNS64 resolvers](guides/ipv6-only-vps.md#set-dns64-resolvers) before its dotfiles clone, then the rest of [ipv6-only-vps.md](guides/ipv6-only-vps.md) | [Verify](guides/provision-server.md#verify) passes |
| Deploy | [deploy.md](guides/deploy.md): deploy, then [Update](guides/deploy.md#update) or [Roll back](guides/deploy.md#roll-back) | [Verify](guides/deploy.md#verify) passes |
| Backup and restore | [backup-restore.md](guides/backup-restore.md): the [Daily backup](guides/backup-restore.md#daily-backup), and [Restore](guides/backup-restore.md#restore) on data loss | The quarterly [Restore drill](guides/backup-restore.md#restore-drill) passes |
| Postgres upgrade | [postgres-upgrade.md](guides/postgres-upgrade.md) | The app runs on the new major version |
| Maintenance | [maintenance.md](guides/maintenance.md), monthly | Every check shows its expected result |
| Monitoring | [monitoring.md](guides/monitoring.md) | [Verify](guides/monitoring.md#verify) passes |

A web app on a fresh server chains Fresh server, Deploy (which schedules the backup), then Monitoring.

## Dev machine

| File | Description |
| --- | --- |
| [guides/dev-machine.md](guides/dev-machine.md) | Set up a dev machine with `setup-dev-machine.sh`: clone, run, prompts, update, verify |
| [scripts/setup-dev-machine.sh](scripts/setup-dev-machine.sh) | Check a dev machine against the handbook, then install, update and configure what differs; `--check` reports only |
| [install.sh](install.sh) | Dotfiles entrypoint; runs `scripts/install-dotfiles.sh` |
| [scripts/install-dotfiles.sh](scripts/install-dotfiles.sh) | Symlink shell and Claude config on a dev machine; `--check` lists the links, `--status` what a run would change |
| [dotfiles/.bash_aliases](dotfiles/.bash_aliases) | Shell aliases (git, make, pnpm), editor, history tuning, git prompt |
| [dotfiles/.inputrc](dotfiles/.inputrc) | Readline: prefix history search on Up/Down, case-insensitive completion |
| [dotfiles/gitignore-global](dotfiles/gitignore-global) | Global git ignore: OS, editor and tooling junk |
| [dotfiles/.tmux.conf](dotfiles/.tmux.conf) | tmux defaults for remote work (mouse, scrollback, escape-time); Catppuccin Mocha colours |
| [dotfiles/nvim/init.lua](dotfiles/nvim/init.lua) | Neovim config on vim.pack: catppuccin, snacks picker and explorer, which-key, lualine; LSP, completion, format on save, treesitter and text objects; gitsigns, mini.icons; hardtime for learning; German keyboard remaps |
| [dotfiles/ptyxis/catppuccin-mocha-grey.palette](dotfiles/ptyxis/catppuccin-mocha-grey.palette) | Ptyxis palette: Catppuccin Mocha with a darker, less blue background, as in Neovim and tmux |
| [dotfiles/nvim/cheatsheet.md](dotfiles/nvim/cheatsheet.md) | Keys being learned, shown in a Neovim side float |
| [dotfiles/nvim/nvim-pack-lock.json](dotfiles/nvim/nvim-pack-lock.json) | Neovim plugin revisions `vim.pack` installs and pins |
| [dotfiles/nvim/parsers.txt](dotfiles/nvim/parsers.txt) | Tree-sitter parsers init.lua and setup-dev-machine.sh install |
| [templates/ssh_config](templates/ssh_config) | `~/.ssh/config` defaults: agent, keep-alive, hashed known_hosts |
| [guides/neovim.md](guides/neovim.md) | Neovim for prose and code: plugins, language servers, keys; the install steps for servers |
| [scripts/report-repo-status.sh](scripts/report-repo-status.sh) | Repos under `~/r` with unpushed, uncommitted or stashed work; `repo-status` |

## Project

| File | Description |
| --- | --- |
| [guides/new-project.md](guides/new-project.md) | Set up a new project repository |
| [reference/stack-conventions.md](reference/stack-conventions.md) | Node/TypeScript, React, Python, Go conventions |
| [templates/Makefile](templates/Makefile) | Full-stack Makefile (dev, prod, checks, release) |
| [templates/make-help.awk](templates/make-help.awk) | Renders `make help` by target class; `scripts/make-help.awk` |
| [templates/setup-dev-tools.sh](templates/setup-dev-tools.sh) | Dev tool setup script skeleton (Go, Node/pnpm, Python/uv blocks) |
| [templates/devcontainer.json](templates/devcontainer.json) | Dev Container config with commented feature blocks per stack |
| [templates/.editorconfig](templates/.editorconfig) | EditorConfig for consistent formatting (Go tabs, JS/TS 2-space) |
| [templates/.gitignore](templates/.gitignore) | Universal .gitignore (OS, IDE, env, build artifacts, logs, Claude local settings) |
| [templates/vscode-settings.json](templates/vscode-settings.json) | VS Code workspace settings for consistent formatting |
| [templates/docker-compose.yml](templates/docker-compose.yml) | Compose starter (local dev, no TLS) |
| [templates/Dockerfile.python](templates/Dockerfile.python) | Python (uv) backend image with a HEALTHCHECK; copied as `backend/Dockerfile` |
| [templates/Dockerfile.go](templates/Dockerfile.go) | Go backend image: static binary on Alpine with a HEALTHCHECK; copied as `backend/Dockerfile` |
| [templates/.dockerignore](templates/.dockerignore) | Build-context excludes: VCS, secrets, host toolchains, tests, docs |
| [templates/.env.example](templates/.env.example) | Standard env vars for Docker Compose templates |
| [templates/ci.yml](templates/ci.yml) | GitHub Actions CI workflow (Go, Node, Python, integration, security scans, upgrade path, restore drill) |
| [templates/release.yml](templates/release.yml) | GitHub Actions release workflow: a vX.Y.Z tag pushes the app images to GHCR |
| [templates/golangci.yml](templates/golangci.yml) | golangci-lint v2 config: security linters, layer guard, goimports |
| [templates/dependabot.yml](templates/dependabot.yml) | Dependabot config (monthly, one grouped PR per ecosystem) |

## Server

| File | Description |
| --- | --- |
| [guides/provision-server.md](guides/provision-server.md) | Provision & harden a new VPS |
| [guides/ipv6-only-vps.md](guides/ipv6-only-vps.md) | IPv6-only VPS (DNS64/NAT64, Docker) |
| [guides/deploy.md](guides/deploy.md) | Deploy a web app with TLS and a reverse proxy; update and roll back |
| [guides/backup-restore.md](guides/backup-restore.md) | PostgreSQL backup, restore and the quarterly restore drill |
| [guides/postgres-upgrade.md](guides/postgres-upgrade.md) | PostgreSQL major upgrade onto a fresh volume |
| [guides/monitoring.md](guides/monitoring.md) | External monitoring (Better Stack) |
| [guides/host-history.md](guides/host-history.md) | On-host history with sysstat: every minute, 28 days, read with `sar` and `sadf` |
| [guides/host-report.md](guides/host-report.md) | Read-only host report over SSH: a forced-command key and one exact sudo rule |
| [guides/maintenance.md](guides/maintenance.md) | Server maintenance: monthly checklist, OOM diagnosis |
| [reference/postgresql.md](reference/postgresql.md) | PostgreSQL: queries, indexes, golang-migrate migrations |
| [reference/linux-services.md](reference/linux-services.md) | Linux services: command sharp edges and resource-usage thresholds |
| [reference/netcup.md](reference/netcup.md) | netcup server API: auth, firewall model, endpoints, snapshots, DNS API |
| [scripts/setup-server.sh](scripts/setup-server.sh) | Provision a fresh Debian/Ubuntu VPS (user, SSH, swap, UFW, fail2ban, Docker); reruns on a set-up host |
| [templates/prod-init.sh](templates/prod-init.sh) | Production deploy and update: pin and downgrade guard, backup, health poll |
| [templates/backup-postgres.sh](templates/backup-postgres.sh) | Verified, retained PostgreSQL backups for a Compose stack (cron) |
| [scripts/host-audit.sh](scripts/host-audit.sh) | Read-only audit of the state `setup-server.sh` leaves: one ok/FAIL/note line per check |
| [scripts/report-health.sh](scripts/report-health.sh) | Hourly dead-man health ping: built-in and drop-in checks, `--check-only` prints one line per check |
| [scripts/netcup.sh](scripts/netcup.sh) | netcup server API from the laptop: login, servers, firewall policies, snapshots |
| [templates/netcup-firewall-web.json](templates/netcup-firewall-web.json) | netcup firewall policy for a web server: inbound SSH, HTTP, HTTPS, HTTP/3, NTP and DNS64 replies |
| [templates/netcup-firewall-ssh.json](templates/netcup-firewall-ssh.json) | netcup firewall policy for an SSH-only host: inbound SSH, NTP and DNS64 replies |
| [templates/docker-compose.prod.yml](templates/docker-compose.prod.yml) | Production Compose with the Caddy edge image: automatic TLS, pinned registry images, healthchecks, resource limits |
| [templates/Caddyfile](templates/Caddyfile) | Caddy site config: www redirect, security headers, API proxy, SPA fallback and cache headers; copied as `reverse-proxy/Caddyfile` |
| [templates/Dockerfile.edge](templates/Dockerfile.edge) | Edge image: Caddy with the Caddyfile and the pnpm-built SPA baked in, with a HEALTHCHECK; copied as `reverse-proxy/Dockerfile` |
| [templates/edge.dockerignore](templates/edge.dockerignore) | Allowlist for the edge image's repo-root build context; copied as `reverse-proxy/Dockerfile.dockerignore` |

## Agents

| File | Description |
| --- | --- |
| [guides/unattended-agents.md](guides/unattended-agents.md) | Unattended agent runs |
| [claude/global.md](claude/global.md) | Global Claude instructions, linked as `~/.claude/CLAUDE.md` |
| [claude/settings.json](claude/settings.json) | Claude settings; enables the `nico` plugin |
| [claude/statusline.sh](claude/statusline.sh) | Status line script |
| [plugin/.claude-plugin/plugin.json](plugin/.claude-plugin/plugin.json) | Manifest of the `nico` plugin: skills, agent, hooks and theme |
| [plugin/.claude-plugin/marketplace.json](plugin/.claude-plugin/marketplace.json) | Local marketplace listing the plugin, loaded in place |
| [plugin/hooks/hooks.json](plugin/hooks/hooks.json) | Plugin hooks: git guard, denial log, peer list at session start |
| [plugin/skills/](plugin/skills/) | Shared skills, one folder each, described by its frontmatter |
| [plugin/agents/web-researcher.md](plugin/agents/web-researcher.md) | Web research agent, `nico:web-researcher` |
| [plugin/themes/catppuccin.json](plugin/themes/catppuccin.json) | Claude Code theme `custom:nico:catppuccin`: `dark-ansi` with a selection that keeps every palette colour readable |
| [plugin/scripts/git-guard.sh](plugin/scripts/git-guard.sh) | PreToolUse hook that blocks force pushes, skipped hooks and commits gitleaks flags |
| [plugin/scripts/plan-run-guard.sh](plugin/scripts/plan-run-guard.sh) | Stop hook the implement-plan skill registers; keeps a live plan run from yielding the turn |
| [plugin/scripts/agent-bus.sh](plugin/scripts/agent-bus.sh) | Coordination bus for concurrent Claude Code sessions in one repo |
| [plugin/scripts/check-agents.sh](plugin/scripts/check-agents.sh) | Last activity of background agents, read off their task transcripts |

## Handbook upkeep

| File | Description |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Repo agent rules |
| `.claude/rules/` | Per-directory conventions, loaded by path |
| [scripts/check-repo.sh](scripts/check-repo.sh) | Repo self-check; `make check` |
| [scripts/test-agent-bus.sh](scripts/test-agent-bus.sh) | Fixture test for `agent-bus.sh`; `make test-agent-bus` |
| [scripts/test-plan-run-guard.sh](scripts/test-plan-run-guard.sh) | Fixture test for `plan-run-guard.sh`; `make test-plan-run-guard` |
| [scripts/test-git-guard.sh](scripts/test-git-guard.sh) | Fixture test for `git-guard.sh`; `make test-git-guard` |
| [scripts/test-report-health.sh](scripts/test-report-health.sh) | Fixture test for `report-health.sh`; `make test-report-health` |
| [scripts/test-report-repo-status.sh](scripts/test-report-repo-status.sh) | Fixture test for `report-repo-status.sh`; `make test-report-repo-status` |
| [scripts/test-setup-dev-machine.sh](scripts/test-setup-dev-machine.sh) | Fixture test for `setup-dev-machine.sh`; `make test-setup-dev-machine` |
| [scripts/test-dockerfiles.sh](scripts/test-dockerfiles.sh) | Builds the Dockerfile templates against stub apps until healthy, then probes the edge image's SPA routes; `make test-dockerfiles` |
| [scripts/lib/test-harness.sh](scripts/lib/test-harness.sh) | Shared setup and verdict the fixture tests source; `make test` runs them |
| [scripts/lib/skill-hooks.sh](scripts/lib/skill-hooks.sh) | Reads a SKILL.md's frontmatter hook commands; `check-repo.sh` and `test-plan-run-guard.sh` source it |

## License

MIT — see [LICENSE](LICENSE).
