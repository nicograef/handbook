# handbook

Setting something up? Start at [guides/bootstrap.md](guides/bootstrap.md).

## Guides

### Runbooks

| Topic                             | File                                                                       |
| --------------------------------- | -------------------------------------------------------------------------- |
| Set up a new project repository   | [guides/new-project.md](guides/new-project.md)                             |
| Provision & harden a new VPS      | [guides/provision-server.md](guides/provision-server.md)                   |
| IPv6-only VPS (DNS64/NAT64, Docker) | [guides/ipv6-only-vps.md](guides/ipv6-only-vps.md)                       |
| Docker multi-stage builds         | [guides/docker-multi-stage-builds.md](guides/docker-multi-stage-builds.md) |
| Let's Encrypt with Docker Compose | [guides/letsencrypt-docker.md](guides/letsencrypt-docker.md)               |
| PostgreSQL operations             | [guides/postgresql-operations.md](guides/postgresql-operations.md)         |
| External monitoring (Better Stack)| [guides/monitoring.md](guides/monitoring.md)                               |
| Server maintenance & upkeep       | [guides/maintenance.md](guides/maintenance.md)                             |
| Audiobooks for ElevenReader       | [guides/audiobook-pipeline.md](guides/audiobook-pipeline.md)               |
| Unattended agent runs             | [guides/unattended-agents.md](guides/unattended-agents.md)                 |
| Neovim for text editing           | [guides/neovim.md](guides/neovim.md)                                       |

### Stack conventions

Heading-grouped rules and idioms per stack — reference material, not runbooks.

| Topic                             | File                                                                       |
| --------------------------------- | -------------------------------------------------------------------------- |
| Go, Java/Spring Boot, React, Python conventions | [guides/stack-conventions.md](guides/stack-conventions.md)  |

## Cheatsheets

| Topic                 | File                                                           |
| --------------------- | -------------------------------------------------------------- |
| tmux                  | [cheatsheets/tmux.md](cheatsheets/tmux.md)                     |
| PostgreSQL            | [cheatsheets/postgresql.md](cheatsheets/postgresql.md)         |

## Templates

| File                                                                   | Description                                                       |
| ---------------------------------------------------------------------- | ----------------------------------------------------------------- |
| [templates/.bash_aliases](templates/.bash_aliases)                     | Shell aliases (git, make, pnpm), history tuning, git prompt       |
| [templates/.tmux.conf](templates/.tmux.conf)                           | tmux defaults for remote work (mouse, scrollback, escape-time)    |
| [templates/init.lua](templates/init.lua)                               | Neovim config: prose defaults, 2-space indent, German keyboard remaps |
| [templates/.editorconfig](templates/.editorconfig)                     | EditorConfig for consistent formatting (Go tabs, JS/TS 2-space)   |
| [templates/.gitignore](templates/.gitignore)                           | Universal .gitignore (OS, IDE, env, build artifacts, logs, Claude local settings) |
| [templates/devcontainer.json](templates/devcontainer.json)             | Dev Container config with commented feature blocks per stack      |
| [templates/Makefile](templates/Makefile)                               | Full-stack Makefile (dev, prod, checks, release)                  |
| [templates/make-help.awk](templates/make-help.awk)                     | Renders `make help` by target class; `scripts/make-help.awk`     |
| [templates/docker-compose.yml](templates/docker-compose.yml)           | Compose starter (local dev, no TLS)                               |
| [templates/.dockerignore](templates/.dockerignore)                     | Build-context excludes: VCS, secrets, host toolchains, tests, docs |
| [templates/docker-compose.prod.yml](templates/docker-compose.prod.yml) | Production Compose (reverse proxy + Let's Encrypt)                |
| [templates/docker-compose.initial-cert.yml](templates/docker-compose.initial-cert.yml) | Minimal Compose for first-time cert issuance (ACME challenge only) |
| [templates/nginx-initial-cert.conf](templates/nginx-initial-cert.conf) | Catch-all nginx config for the initial ACME challenge             |
| [templates/nginx-tls.conf](templates/nginx-tls.conf)                   | Nginx TLS reverse proxy config                                    |
| [templates/nginx-spa.conf](templates/nginx-spa.conf)                   | SPA container nginx config: client-side routing + asset caching   |
| [templates/cloud-init.yml](templates/cloud-init.yml)                   | cloud-init user-data that fetches & runs `setup-server.sh`        |
| [templates/setup-dev-tools.sh](templates/setup-dev-tools.sh)           | Dev tool setup script skeleton (Go, Node/pnpm blocks)             |
| [templates/ci.yml](templates/ci.yml)                                   | GitHub Actions CI workflow (Go, Node, integration tests)          |
| [templates/dependabot.yml](templates/dependabot.yml)                   | Dependabot config (monthly, one grouped PR per ecosystem)         |
| [templates/.env.example](templates/.env.example)                       | Standard env vars for Docker Compose templates                    |
| [templates/vscode-settings.json](templates/vscode-settings.json)       | VS Code workspace settings for consistent formatting              |
| [templates/strip-visuals.lua](templates/strip-visuals.lua)             | Pandoc filter that removes what a narrator cannot speak           |

## Scripts

| Script                                                     | Description                                                            |
| ---------------------------------------------------------- | ---------------------------------------------------------------------- |
| [scripts/setup-server.sh](scripts/setup-server.sh)         | Provision a fresh Debian/Ubuntu VPS (user, SSH, swap, UFW, fail2ban, Docker) |
| [scripts/prod-init.sh](scripts/prod-init.sh)               | First-time production deploy (cert request + stack start)              |
| [scripts/backup-postgres.sh](scripts/backup-postgres.sh)   | Verified, retained PostgreSQL backups for a Compose stack (cron)        |
| [scripts/report-health.sh](scripts/report-health.sh)       | Daily dead-man health ping (reboot-required + unattended-upgrades + OOM check) |
| [scripts/install-dotfiles.sh](scripts/install-dotfiles.sh) | Symlink shell and Claude config on a dev machine; `install.sh`          |
| [scripts/agent-bus.sh](scripts/agent-bus.sh)               | Coordination bus for concurrent Claude Code sessions in one repo        |
| [scripts/check-repo.sh](scripts/check-repo.sh)             | Repo self-check; `make check`                                          |
| [scripts/test-prune.sh](scripts/test-prune.sh)             | Fixture test for the prune skill's `prune-state.sh`; `make test-prune`  |
| [scripts/test-agent-bus.sh](scripts/test-agent-bus.sh)     | Fixture test for `agent-bus.sh`; `make test-agent-bus`                  |
| [scripts/plan-run-guard.sh](scripts/plan-run-guard.sh)     | Stop hook that keeps a live plan run from yielding the turn             |
| [scripts/test-plan-run-guard.sh](scripts/test-plan-run-guard.sh) | Fixture test for `plan-run-guard.sh`; `make test-plan-run-guard`  |
| [scripts/md-to-epub.sh](scripts/md-to-epub.sh)             | Lint and render audiobook chapters into an ElevenReader EPUB           |
| [scripts/check-terms.sh](scripts/check-terms.sh)           | Verify no audiobook term is used before the chapter that explains it   |

## Agent Setup

| Item                       | File / Directory                                                       |
| -------------------------- | ---------------------------------------------------------------------- |
| Skills index               | [.claude/skills/README.md](.claude/skills/README.md)                   |
| Web research agent         | [.claude/agents/web-researcher.md](.claude/agents/web-researcher.md)   |
| Path-scoped rules (Claude) | `.claude/rules/`                                                        |
| Repo agent rules           | [AGENTS.md](AGENTS.md)                                                 |
| Global Claude instructions | [claude/CLAUDE.md](claude/CLAUDE.md)                                   |
| Claude settings + hooks    | [claude/settings.json](claude/settings.json)                           |
| Status line script         | [claude/statusline.sh](claude/statusline.sh)                           |
| Dotfiles entrypoint        | [install.sh](install.sh)                                               |

## License

MIT — see [LICENSE](LICENSE).
