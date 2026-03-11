# admin

Personal knowledge base for infrastructure, server setup and daily CLI work.  
Focused on **Debian / Ubuntu**. Used for private projects and occasionally at work.

---

## Guides

Step-by-step instructions (runbook-style).

| Topic | File |
| ----- | ---- |
| Provision & harden a new VPS | [guides/provision-server.md](guides/provision-server.md) |
| Docker installation & Compose | [guides/docker-setup.md](guides/docker-setup.md) |
| Docker multi-stage builds | [guides/docker-multi-stage-builds.md](guides/docker-multi-stage-builds.md) |
| Let's Encrypt with Docker Compose | [guides/letsencrypt-docker.md](guides/letsencrypt-docker.md) |
| Nginx reverse proxy (HTTPS + SPA) | [guides/nginx-reverse-proxy.md](guides/nginx-reverse-proxy.md) |
| GitHub Actions CI/CD | [guides/github-actions-cicd.md](guides/github-actions-cicd.md) |
| GitHub Copilot Agent Mode setup | [guides/copilot-agent-setup.md](guides/copilot-agent-setup.md) |
| Go backend development | [guides/go.md](guides/go.md) |
| Java / Spring Boot backend | [guides/java-spring-boot.md](guides/java-spring-boot.md) |
| React frontend development | [guides/react.md](guides/react.md) |
| Dotfiles for GitHub Codespaces | [guides/dotfiles-codespaces.md](guides/dotfiles-codespaces.md) |

## Cheatsheets

Quick-reference commands (no context needed).

| Topic | File |
| ----- | ---- |
| Unix / shell commands | [cheatsheets/unix-commands.md](cheatsheets/unix-commands.md) |
| Docker Compose | [cheatsheets/docker-compose.md](cheatsheets/docker-compose.md) |
| Vim | [cheatsheets/vim.md](cheatsheets/vim.md) |

## Templates

Copy-paste-ready config files for new projects.

| File | Description |
| ---- | ----------- |
| [templates/.bashrc](templates/.bashrc) | Custom prompt with git branch |
| [templates/Makefile](templates/Makefile) | Full-stack Makefile (dev, prod, checks, release) |
| [templates/docker-compose.yml](templates/docker-compose.yml) | Compose starter (local dev, no TLS) |
| [templates/docker-compose.prod.yml](templates/docker-compose.prod.yml) | Production Compose (reverse proxy + Let's Encrypt) |
| [templates/nginx-tls.conf](templates/nginx-tls.conf) | Nginx TLS reverse proxy config |
| [templates/AGENTS.md](templates/AGENTS.md) | Agent instructions template for Copilot Agent Mode |
| [templates/copilot-instructions.md](templates/copilot-instructions.md) | Copilot instructions template (`.github/copilot-instructions.md`) |

## Scripts

Reusable bash scripts.

| Script | Description |
| ------ | ----------- |
| [scripts/setup-server.sh](scripts/setup-server.sh) | Provision a fresh Debian/Ubuntu VPS (user, SSH, UFW, fail2ban, Docker) |
| [scripts/prod-init.sh](scripts/prod-init.sh) | First-time production deploy (cert request + stack start) |
| [scripts/install-dotfiles.sh](scripts/install-dotfiles.sh) | Bootstrap shell config in a new Codespace or VM |
