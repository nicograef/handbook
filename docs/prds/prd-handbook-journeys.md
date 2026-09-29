# PRD: Handbook Journeys

Second of three PRDs from the 2026-09-29 multi-expert review. This one: complete and truthful journeys.
Layout: [prd-handbook-structure.md](prd-handbook-structure.md). Agent config: [prd-handbook-agent-layer.md](prd-handbook-agent-layer.md).

## Problem Statement

When I follow the handbook end to end, I get stuck or I get a broken result. The Python service path produces an image that fails its own production healthcheck. The second deploy fails because the backup directory belongs to root.

Some journeys stop halfway. Provisioning a server never gets my app onto it. No step clones the project, logs in to the registry or creates `.env`. A new project gets no production or release files, and a new laptop never installs Node, pnpm or uv.

Other pages contradict each other or the setup I actually use. Monitoring assumes the nginx stack, although Caddy is the default. TLS asks for an IPv4 record on an IPv6-only server. Deploy steps are spread over three pages, and a server setup step hides in the tmux sheet.

The stack material leads with Go and Java, while my daily work is Node/TypeScript and Python. Java costs upkeep on every version bump. I am learning Linux server administration, yet no page teaches services, logs or networking basics.

## Solution

Every journey is one chain of runbooks that ends in a Verify block I can run. A reader who starts at the README reaches a working result without guessing.

The journeys are new dev machine, new project, fresh server and deploy. Backup and restore, Postgres upgrade, maintenance and monitoring complete them. Each fact lives in one place; scripts explain themselves in their header, and guides link that header.

Templates match the stacks I use. Each stack gets a Dockerfile template with its own healthcheck. The project Makefile and CI run the same gate for pnpm and uv projects.

A reference page on Linux services teaches the commands the runbooks already use.

## User Stories

1. As the reader on a fresh laptop, I want one toolchain runbook, so that later guides work.
2. As the reader starting a Python and React project, I want matching production files, so that it deploys unedited.
3. As the reader with a new server, I want one deploy runbook, so that my app runs.
4. As the reader deploying an update, I want rollback in the same runbook, so that I find it under pressure.
5. As the reader on an IPv6-only server, I want DNS steps for my host type, so that TLS works.
6. As the reader on the Caddy stack, I want monitoring steps for Caddy, so that every monitor turns green.
7. As the reader, I want backups that the deploy user can write, so that deploys and cron backups both succeed.
8. As the reader, I want a restore drill runbook, so that I know a backup can be restored.
9. As the reader learning Linux administration, I want a services and logs reference, so that I can inspect a server.
10. As the maintainer, I want each behaviour described once, so that a script change updates exactly one doc.

## Implementation Decisions

### Critical fixes first

- The backend healthcheck comes from each image's own `HEALTHCHECK`, not from a `wget` call in Compose.
- The deploy user owns the backup directory, and the backup cron line goes into that user's crontab.
- Monitoring distinguishes the nginx and Caddy variants, including the expected monitor count.
- The DNS prerequisite names the record per host type: A plus AAAA for dual-stack, AAAA for IPv6-only.

### Runbook set

| Runbook | Content |
| --- | --- |
| `dev-machine` | SSH key, git identity, `gh auth login`, Node, pnpm, uv, Claude Code, then `install.sh` |
| `new-project` | Matrix Python + React, Python, Go + React, Go, React, Docs; copies Dockerfile, production and release files |
| `provision-server` | Unchanged scope; lingering becomes a step with its own Verify row |
| `deploy` | Project under `/opt/<project>`, `docker login ghcr.io`, `.env`, first deploy, update, rollback, TLS per variant |
| `backup-restore` | Backup setup, restore, quarterly drill |
| `postgres-upgrade` | Major-version upgrade |
| `maintenance` | Monthly checklist; the single home of the OOM and lingering explanation |
| `monitoring` | Prerequisites first, heartbeat creation, both proxy variants |

`letsencrypt-docker`, `postgresql-operations` and `docker-multi-stage-builds` are dissolved into the rows above, the Dockerfile templates and the stack conventions.

### Templates and conventions

- `Dockerfile.python`, `Dockerfile.go` and `Dockerfile.spa` join `templates/`, each with a `HEALTHCHECK`.
- The template Makefile `check` target runs the pnpm and uv gates in the documented gate order.
- CI gains a Python integration step. The template `.gitignore` gains `.deploy-state`.
- Stack conventions run Node/TypeScript, React, Python, Go.
- Java leaves the handbook: conventions, Dockerfile, matrix row, Makefile lines and editor settings.
- Conventions require a `packageManager` pin and state the real Python pin.
- Tool versions stay pinned in their files. CI reads `*-version-file` inputs where the action supports it; the `AGENTS.md` grep rule covers the rest.

### Linux reference

`reference/linux-services.md` covers systemd units, `journalctl`, Compose operations, ports and firewall. Every command on it already appears in a runbook, and those runbooks link it. `reference/system-resources.md` stays the sheet for hardware and live usage.

### Writing rules

- One task per runbook, 50 to 150 lines. Each step is one action plus its expected result.
- A list holds parallel items only. Reasoning is a short paragraph with connectives.
- Headings name tasks, never numbers. Links target headings, never another file's step number.
- Placeholders use `<angle-brackets>` throughout, Verify blocks included.
- Agent vocabulary (gate, lane, fold, lead) stays in skills. Runbooks say what the operator does.

## Testing Decisions

- `make check` and `make compose` pass after every phase.
- Each Dockerfile template builds on a stub app, and `docker inspect` reports it healthy.
- Every README journey opens a runbook that ends in Verify.
- Prior art: the `make compose` stage and the restore drill in `templates/ci.yml`.

## Out of Scope

- Folder moves and contract checks: [prd-handbook-structure.md](prd-handbook-structure.md).
- The unattended-agents guide and the agent config: [prd-handbook-agent-layer.md](prd-handbook-agent-layer.md).
- A Node/TypeScript backend path. gyva runs a Python API with a React frontend, so no consumer exists.
- A `versions.env` file with its own check stage.
- A networking reference beyond ports and firewall.
- Tag-pinned raw URLs for the frozen server scripts.

## Further Notes

`nicograef/lexiban` keeps its own copies of the Java files; git history holds the rest. PHP settings stay because `~/r/website` is a live PHP repo.
