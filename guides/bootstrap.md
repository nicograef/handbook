# Using This Handbook

Start here when you (or an agent) are told "follow the handbook to set up X".

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
2. **IPv6-only box only** — [ipv6-only-vps.md](ipv6-only-vps.md). Skip on dual-stack servers.
3. **Install the CLI tools the aliases expect** (optional) —
   [After provisioning](provision-server.md#after-provisioning); only if you SSH
   in to work on the box.
4. **Deploy TLS + reverse proxy** (web app only). Point DNS at the VPS first.

   - First deploy: [scripts/prod-init.sh](../scripts/prod-init.sh) with
     [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml).
   - Then [letsencrypt-docker.md](letsencrypt-docker.md) to verify and troubleshoot the certs.

5. **External monitoring** — [monitoring.md](monitoring.md).

   - Health-ping heartbeat: applies to any box.
   - HTTPS uptime monitor, cert heartbeat, backup heartbeat: once it hosts a web app.

6. **Backups** (app has a database) —
   [postgresql-operations.md](postgresql-operations.md) with
   [scripts/backup-postgres.sh](../scripts/backup-postgres.sh) on the daily cron.
7. **Ongoing upkeep** — [maintenance.md](maintenance.md).

**Done when** these Verify sections pass:

- [provision](provision-server.md#verify)
- [TLS](letsencrypt-docker.md#verify)
- [monitoring](monitoring.md#verify)
- [backups](postgresql-operations.md#verify)

## New dev machine

1. **CLI tools** — the apt line in [After provisioning](provision-server.md#after-provisioning).
   Add gh from its apt repo: [install_linux.md](https://github.com/cli/cli/blob/trunk/docs/install_linux.md).
2. Clone the handbook and run [`install.sh`](../install.sh). It symlinks the shell dotfiles, the Claude config and the shared skills into `$HOME`.
   A real file in the way moves to `<name>.bak`.
   With `~/.ssh/id_ed25519.pub` present, it sets up SSH commit signing.
3. **Signing key** — add that key to GitHub with key type "Signing Key":
   [adding a new SSH key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account).
4. **Editor** — [neovim.md](neovim.md) installs Neovim; `install.sh` has already linked its config.

**Done when** `ls -l ~/.claude/CLAUDE.md ~/.bash_aliases` shows both as symlinks into the clone.

## New project

**Gather first** — [new-project.md#inputs](new-project.md#inputs).

Follow [new-project.md](new-project.md) end-to-end; **done when** its Verify section passes.
