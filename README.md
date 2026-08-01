# handbook

Following the handbook to set something up? Start at [guides/bootstrap.md](guides/bootstrap.md).

## Guides

### Runbooks

| Topic                             | File                                                                       |
| --------------------------------- | -------------------------------------------------------------------------- |
| Using this handbook (start here)  | [guides/bootstrap.md](guides/bootstrap.md)                                 |
| Set up a new project repository   | [guides/new-project.md](guides/new-project.md)                             |
| Provision & harden a new VPS      | [guides/provision-server.md](guides/provision-server.md)                   |
| IPv6-only VPS (DNS64/NAT64, Docker) | [guides/ipv6-only-vps.md](guides/ipv6-only-vps.md)                       |
| Docker installation & Compose     | [guides/docker-setup.md](guides/docker-setup.md)                           |
| Docker multi-stage builds         | [guides/docker-multi-stage-builds.md](guides/docker-multi-stage-builds.md) |
| Let's Encrypt with Docker Compose | [guides/letsencrypt-docker.md](guides/letsencrypt-docker.md)               |
| Nginx reverse proxy (HTTPS + SPA) | [guides/nginx-reverse-proxy.md](guides/nginx-reverse-proxy.md)             |
| GitHub Actions CI/CD              | [guides/github-actions-cicd.md](guides/github-actions-cicd.md)             |
| GitHub Copilot Agent Mode setup   | [guides/copilot-agent-setup.md](guides/copilot-agent-setup.md)             |
| Dotfiles for GitHub Codespaces    | [guides/dotfiles-codespaces.md](guides/dotfiles-codespaces.md)             |
| Install the handbook plugin       | [guides/claude-plugin.md](guides/claude-plugin.md)                         |
| PostgreSQL operations             | [guides/postgresql-operations.md](guides/postgresql-operations.md)         |
| External monitoring (Better Stack)| [guides/monitoring.md](guides/monitoring.md)                               |
| Server maintenance & upkeep       | [guides/maintenance.md](guides/maintenance.md)                             |
| End-to-end verification drill     | [guides/verification-drill.md](guides/verification-drill.md)               |

### Stack conventions

Heading-grouped rules and idioms for a stack — reference material, not runbooks.

| Topic                             | File                                                                       |
| --------------------------------- | -------------------------------------------------------------------------- |
| Go backend conventions            | [guides/go.md](guides/go.md)                                               |
| Java / Spring Boot conventions    | [guides/java-spring-boot.md](guides/java-spring-boot.md)                   |
| React frontend conventions        | [guides/react.md](guides/react.md)                                         |
| Anti-sycophancy agent setup       | [guides/anti-sycophancy.md](guides/anti-sycophancy.md)                     |

## Cheatsheets

| Topic                 | File                                                           |
| --------------------- | -------------------------------------------------------------- |
| Unix / shell commands | [cheatsheets/unix-commands.md](cheatsheets/unix-commands.md)   |
| tmux                  | [cheatsheets/tmux.md](cheatsheets/tmux.md)                     |
| Docker Compose        | [cheatsheets/docker-compose.md](cheatsheets/docker-compose.md) |
| PostgreSQL            | [cheatsheets/postgresql.md](cheatsheets/postgresql.md)         |
| Makefile              | [cheatsheets/makefile.md](cheatsheets/makefile.md)             |

## Templates

| File                                                                   | Description                                                       |
| ---------------------------------------------------------------------- | ----------------------------------------------------------------- |
| [templates/.bash_aliases](templates/.bash_aliases)                     | Shell aliases (git, make, pnpm), history tuning, git prompt       |
| [templates/.tmux.conf](templates/.tmux.conf)                           | tmux defaults for remote work (mouse, scrollback, escape-time)    |
| [templates/.editorconfig](templates/.editorconfig)                     | EditorConfig for consistent formatting (Go tabs, JS/TS 2-space)   |
| [templates/.gitignore](templates/.gitignore)                           | Universal .gitignore (OS, IDE, env, build artifacts, logs)        |
| [templates/devcontainer.json](templates/devcontainer.json)             | Dev Container config with commented feature blocks per stack      |
| [templates/Makefile](templates/Makefile)                               | Full-stack Makefile (dev, prod, checks, release)                  |
| [templates/docker-compose.yml](templates/docker-compose.yml)           | Compose starter (local dev, no TLS)                               |
| [templates/docker-compose.prod.yml](templates/docker-compose.prod.yml) | Production Compose (reverse proxy + Let's Encrypt)                |
| [templates/docker-compose.initial-cert.yml](templates/docker-compose.initial-cert.yml) | Minimal Compose for first-time cert issuance (ACME challenge only) |
| [templates/nginx-initial-cert.conf](templates/nginx-initial-cert.conf) | Catch-all nginx config for the initial ACME challenge             |
| [templates/nginx-tls.conf](templates/nginx-tls.conf)                   | Nginx TLS reverse proxy config                                    |
| [templates/cloud-init.yml](templates/cloud-init.yml)                   | cloud-init user-data that fetches & runs `setup-server.sh`        |
| [templates/setup-dev-tools.sh](templates/setup-dev-tools.sh)           | Dev tool setup script skeleton (Go, Node/pnpm blocks)             |
| [templates/ci.yml](templates/ci.yml)                                   | GitHub Actions CI workflow (Go, Node, integration tests)          |
| [templates/dependabot.yml](templates/dependabot.yml)                   | Dependabot config (monthly, one grouped PR per ecosystem)         |
| [templates/.env.example](templates/.env.example)                       | Standard env vars for Docker Compose templates                    |
| [templates/AGENTS.md](templates/AGENTS.md)                             | Agent instructions template for Copilot Agent Mode                |
| [templates/copilot-instructions.md](templates/copilot-instructions.md) | Copilot instructions template (`.github/copilot-instructions.md`) |
| [templates/vscode-settings.json](templates/vscode-settings.json)       | VS Code workspace settings for consistent formatting              |
| [templates/claude-settings.json](templates/claude-settings.json)       | Project `.claude/settings.json` to adopt the handbook plugin      |

## Scripts

| Script                                                     | Description                                                            |
| ---------------------------------------------------------- | ---------------------------------------------------------------------- |
| [scripts/setup-server.sh](scripts/setup-server.sh)         | Provision a fresh Debian/Ubuntu VPS (user, SSH, UFW, fail2ban, Docker) |
| [scripts/prod-init.sh](scripts/prod-init.sh)               | First-time production deploy (cert request + stack start)              |
| [scripts/backup-postgres.sh](scripts/backup-postgres.sh)   | Verified, retained PostgreSQL backups for a Compose stack (cron)        |
| [scripts/report-health.sh](scripts/report-health.sh)       | Daily dead-man health ping (reboot-required + unattended-upgrades check) |
| [scripts/install-dotfiles.sh](scripts/install-dotfiles.sh) | Bootstrap shell config in a new Codespace or VM                        |
| [scripts/check-repo.sh](scripts/check-repo.sh)             | Repo self-check (links, shellcheck, README index, language, skills, compose, plugin); `make check` |
| [scripts/test-prune.sh](scripts/test-prune.sh)             | Fixture test for the prune skill's `prune-state.sh`; `make test-prune`  |

## Agent Setup

Configuration for Claude Code and GitHub Copilot — the instruction surface, skills, agents,
path-scoped rules, and dotfiles.

| Item                       | File / Directory                                                       |
| -------------------------- | ---------------------------------------------------------------------- |
| Canonical instructions     | [AGENTS.md](AGENTS.md)                                                  |
| Claude Code entrypoint     | [CLAUDE.md](CLAUDE.md) (imports `AGENTS.md`)                            |
| Copilot instructions       | [.github/copilot-instructions.md](.github/copilot-instructions.md)     |
| Skills index               | [.claude/skills/README.md](.claude/skills/README.md)                   |
| Web research agent         | [.claude/agents/web-researcher.md](.claude/agents/web-researcher.md)   |
| Plugin manifests           | [.claude-plugin/plugin.json](.claude-plugin/plugin.json), [.claude-plugin/marketplace.json](.claude-plugin/marketplace.json) |
| Plugin install & adoption  | [guides/claude-plugin.md](guides/claude-plugin.md)                     |
| Path-scoped rules (Claude) | `.claude/rules/`                                                        |
| Global Claude instructions | [claude/CLAUDE.md](claude/CLAUDE.md)                                   |
| Claude settings + hooks    | [claude/settings.json](claude/settings.json)                           |
| Status line script         | [claude/statusline.sh](claude/statusline.sh)                           |
| Repo self-check            | [Makefile](Makefile) (`make check`)                                    |
| Dotfiles entrypoint        | [install.sh](install.sh)                                               |
| Repo devcontainer          | [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json)     |

## License

MIT — see [LICENSE](LICENSE).
