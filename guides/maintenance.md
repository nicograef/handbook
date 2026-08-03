# Server Maintenance

## Image updates (every deploy)

**Rule: no auto-pull in production.**

- Image tags in [docker-compose.prod.yml](../templates/docker-compose.prod.yml)
  are **pinned**, and bumped **deliberately** at deploy time.
- Never float on `latest`; never pull on a schedule.
- A deploy is the only moment images change.
- So a deploy is also where you prune the images the bump superseded.

### Prerequisites

- SSH access to the server, in the Compose project dir.
- The tag change committed to the repo, so the running stack matches source.
- Edit the Compose file in git, not on the box.

### Steps

1. **Bump the tag explicitly** in the Compose file. Pin to a concrete version,
   not a moving tag:

   ```diff
   -    image: postgres:17
   +    image: postgres:17.6
   ```

2. **Fetch the new pinned images** (only the `image:` services pull; `build:`
   services rebuild):

   ```bash
   docker compose -f docker-compose.prod.yml pull
   docker compose -f docker-compose.prod.yml build
   ```

   Expected: `pull` reports `Pulled` (or `Already exists` for unchanged layers)
   per image and exits 0; `build` ends with `Successfully tagged` / no error.

3. **Recreate the stack** so containers run the new images:

   ```bash
   docker compose -f docker-compose.prod.yml up -d
   ```

   Expected: only the changed services are recreated (`Recreating …` /
   `Started`); unchanged ones report `Running`.

4. **Verify the stack is healthy** (see [reboot routine](#reboot-routine-monthly)
   for the full `ps` + HTTPS check), then **prune the superseded images**:

   ```bash
   docker image prune -f
   ```

   Expected: dangling images left untagged by the bump are removed; the summary
   ends with a `Total reclaimed space: <N>` line (`0B` if nothing was orphaned).

> To reclaim more aggressively, use `docker system prune` from
> [docker-setup.md](docker-setup.md#prune-unused-resources) instead.
> It removes all images with no running container, plus the build cache.
> Never pass `--volumes` on a stack with `postgres-data`.

## Reboot routine (monthly)

- Unattended-upgrades installs security patches but **never auto-reboots**
  (see [provision-server.md](provision-server.md)).
- Kernel and libc updates only take effect on the next reboot.
- The health-ping heartbeat alerts when a reboot is pending; this routine clears it.
- Run it in a low-traffic maintenance window — a reboot drops all connections
  for ~1 min.

### Steps

1. **Check whether a reboot is actually pending.** The health-ping already
   surfaces this ([monitoring.md](monitoring.md), Step 5), but confirm on the
   box:

   ```bash
   test -f /var/run/reboot-required && echo "reboot required" || echo "no reboot needed"
   ```

   Expected: `no reboot needed` on a patched box, or `reboot required` after a
   kernel/libc upgrade landed. If the latter, continue.

2. **Reboot inside the maintenance window:**

   ```bash
   sudo reboot
   ```

   Expected: the SSH session drops; the host is back in ~30–60 s. Reconnect.

3. **Verify the stack came back.** Containers have `restart: unless-stopped`, so
   they should start on their own:

   ```bash
   docker compose -f docker-compose.prod.yml ps
   ```

   Expected: every service is listed with `STATUS` `Up …`, and `postgres` shows
   `(healthy)`. No service in `Restarting` or `Exit`. (Command reference:
   [Docker Compose cheatsheet](../cheatsheets/docker-compose.md).)

4. **Confirm the site is reachable over HTTPS** from off the box:

   ```bash
   curl -sI https://<your-domain> | head -1
   ```

   Expected: `HTTP/2 200` (or a deliberate `301`/`308` redirect line if the root
   redirects). A hang or `curl: (7) Failed to connect` means the reverse proxy
   didn't come up — check `docker compose -f docker-compose.prod.yml logs
   reverse-proxy`.

## Disk and service checks (monthly)

1. **Disk headroom.** Threshold: **act when the stack's filesystem is ≥ 80 %
   used**.

   - Prune images (see [image updates](#image-updates-every-deploy)), or grow the
     volume before it fills.
   - A full disk stops Postgres writes and breaks `certbot renew`.

   ```bash
   df -h /
   ```

   Expected: the `/` row's `Use%` is **under 80 %**. At or above, take action the
   same day.

2. **Docker's share of the disk** — images, containers, volumes, build cache:

   ```bash
   docker system df
   ```

   Expected: four rows (`Images`, `Containers`, `Local Volumes`, `Build Cache`)
   with a `RECLAIMABLE` column. A large reclaimable figure is the cue to prune
   (see [image updates](#image-updates-every-deploy)); `postgres-data` under
   `Local Volumes` is **not** reclaimable and must stay.

3. **No failed systemd units:**

   ```bash
   systemctl --failed
   ```

   Expected: `0 loaded units listed.` Any listed unit is a regression to
   investigate (often `fail2ban` or a timer).

4. **fail2ban is active and jailing SSH:**

   ```bash
   sudo systemctl is-active fail2ban && sudo fail2ban-client status sshd
   ```

   Expected: `active`, then an `sshd` jail status block (`Currently banned`,
   `Total banned`, …). A non-zero `Total banned` is normal on a public box.
   (Jail config: [provision-server.md](provision-server.md).)

5. **UFW is up and rate-limiting SSH:**

   ```bash
   sudo ufw status verbose
   ```

   Expected: `Status: active`, `Default: deny (incoming)`, a `22/tcp  LIMIT`
   rule, and the `80,443/tcp` rules the app needs.

## Restore drill (quarterly)

- **Drill** — follow the
  [Restore drill in postgresql-operations.md](postgresql-operations.md#4-restore-drill).
- **Actual disaster** (restore into the live DB, not a throwaway) — use the
  [full-restore commands](postgresql-operations.md#2-restore) instead.

---

See also:
- [guides/monitoring.md](monitoring.md) — external heartbeats that alert between these checks
- [guides/postgresql-operations.md](postgresql-operations.md) — backup, restore, and the restore drill
- [guides/provision-server.md](provision-server.md) — unattended-upgrades stance, UFW, fail2ban
- [guides/letsencrypt-docker.md](letsencrypt-docker.md) — cert renewal loop
- [guides/docker-setup.md](docker-setup.md) — Docker install and pruning
- [cheatsheets/docker-compose.md](../cheatsheets/docker-compose.md) — Compose command reference
