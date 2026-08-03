# Using This Handbook

Start here when you (or an agent) are told "follow the handbook to set up X".

- Each scenario below routes to an **ordered** sequence of existing guides.
- Gather the listed inputs **before** you start, so nothing is discovered mid-run.
- This file is routing only — every command lives in the linked guide.

## Fresh VPS

Provision a Debian/Ubuntu box, then layer on TLS, monitoring, and backups as the
workload needs.

**Gather first** — assemble the inputs from these sections before step 1:

- [provision-server.md#inputs](provision-server.md#inputs)
- [letsencrypt-docker.md#inputs](letsencrypt-docker.md#inputs) (web app only)
- [monitoring.md#inputs](monitoring.md#inputs)

1. **Provision & harden** (always) — [provision-server.md](provision-server.md)
   via the cloud-init primary path.
2. **IPv6-only box only** — [ipv6-only-vps.md](ipv6-only-vps.md): DNS64
   resolvers for IPv4-only services (GitHub!) and Docker IPv6 networking. Skip
   on dual-stack servers.
3. **Install dotfiles on the server** (optional) —
   [After provisioning](provision-server.md#after-provisioning); only if you SSH
   in to work on the box.
4. **Deploy TLS + reverse proxy** (web app only). Point DNS at the VPS first.

   - Follow [letsencrypt-docker.md](letsencrypt-docker.md).
   - Config patterns: [nginx-reverse-proxy.md](nginx-reverse-proxy.md).
   - First deploy: [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml)
     and [scripts/prod-init.sh](../scripts/prod-init.sh).

5. **External monitoring** — [monitoring.md](monitoring.md).

   - Health-ping heartbeat: applies to any box.
   - HTTPS uptime monitor, cert heartbeat, backup heartbeat: once it hosts a web app.

6. **Backups** (app has a database) —
   [postgresql-operations.md](postgresql-operations.md) with
   [scripts/backup-postgres.sh](../scripts/backup-postgres.sh) on the daily cron.
7. **Ongoing upkeep** — [maintenance.md](maintenance.md): image bumps, the
   monthly reboot routine, disk checks, and the quarterly restore drill.

**Done when** these Verify sections pass:

- [provision](provision-server.md#verify)
- [TLS](letsencrypt-docker.md#verify)
- [monitoring](monitoring.md#verify)
- [backups](postgresql-operations.md#verify)

## New Codespace

One-time account setup that makes every future Codespace bootstrap your shell and
Claude config automatically.

**Gather first** — a GitHub account with Codespaces enabled and this repo under
your account ([prerequisites](dotfiles-codespaces.md#prerequisites)).

1. **Enable account-level dotfiles** (one-time) —
   [dotfiles-codespaces.md → Setup](dotfiles-codespaces.md#setup-one-time).

   - Afterwards every new Codespace clones the repo and runs the installer
     automatically.
   - The handbook-plugin opt-out is written for you in each adopted repo.

2. **Verify in a fresh Codespace** — run the
   [Verify block](dotfiles-codespaces.md#verify) in a newly created Codespace.
3. **Per-project tooling** — copy
   [templates/devcontainer.json](../templates/devcontainer.json) into the
   project's `.devcontainer/` and uncomment the Dev Container Features it needs.

**Done when** the [Verify block](dotfiles-codespaces.md#verify) passes in a new
Codespace.

## New dev machine

Two tiers — pick by what the machine is for. A machine can carry both.

**Gather first** — symlink tier needs `bash`, `git`, `curl`
([prerequisites](dotfiles-codespaces.md#prerequisites)); plugin tier needs an
authenticated Claude Code CLI ([prerequisites](claude-plugin.md#prerequisites)).

1. **Machines you develop on (symlink tier)** — clone the handbook and run
   [`install.sh`](../install.sh); it symlinks shell + Claude config and the
   shared skills. See [dotfiles-codespaces.md](dotfiles-codespaces.md) for what
   the installer does.
2. **Machines that only need the skills (plugin tier)** — no clone; two commands
   install the plugin. See [claude-plugin.md](claude-plugin.md).
3. **Both tiers on one machine** — add the
   [dev-machine opt-out](claude-plugin.md#dev-machine-opt-out) in each adopted
   repo so the skills don't load twice.

**Done when** the symlink tier's [Verify block](dotfiles-codespaces.md#verify)
passes, or (plugin tier) `claude plugin details handbook` lists the skills
([Verify](claude-plugin.md#verify)).

## New project

**Gather first** — [new-project.md#inputs](new-project.md#inputs).

Follow [new-project.md](new-project.md) — it scaffolds the repo (templates, CI,
agent instructions, plugin adoption) end-to-end in one ordered sequence.

**Done when** [new-project.md](new-project.md)'s Verify section passes.
