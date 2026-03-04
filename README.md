# admin

Personal knowledge base for infrastructure, server setup and daily CLI work.  
Focused on **Debian / Ubuntu**. Used for private projects and occasionally at work.

---

## Guides

Step-by-step instructions (runbook-style).

| Topic | File |
| ----- | ---- |
| Provision a new VPS | [guides/provision-server.md](guides/provision-server.md) |
| Harden a new Linux server | [guides/secure-linux.md](guides/secure-linux.md) |
| Docker installation & Compose | [guides/docker-setup.md](guides/docker-setup.md) |

## Cheatsheets

Quick-reference commands (no context needed).

| Topic | File |
| ----- | ---- |
| Unix / shell commands | [cheatsheets/unix-commands.md](cheatsheets/unix-commands.md) |
| Vim | [cheatsheets/vim.md](cheatsheets/vim.md) |

## Templates

Copy-paste-ready config files for new projects.

| File | Description |
| ---- | ----------- |
| [templates/.bashrc](templates/.bashrc) | Custom prompt with git branch |
| [templates/Makefile](templates/Makefile) | Makefile with self-documenting `make help` |
| [templates/docker-compose.yml](templates/docker-compose.yml) | Compose starter (Node + Postgres) |

## Scripts

Reusable bash scripts.

| Script | Description |
| ------ | ----------- |
| [scripts/setup-server.sh](scripts/setup-server.sh) | Provision a fresh Debian/Ubuntu VPS (user, SSH, UFW, fail2ban, Docker) |
