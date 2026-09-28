# Server Maintenance

## Image updates (every deploy)

- Every image in `docker-compose.prod.yml` carries an explicit tag, never `latest`; the deploy refuses anything else.
- The project copies one variant there: [nginx](../templates/docker-compose.prod.yml) or [Caddy](../templates/docker-compose.prod-caddy.yml).
- The app images come from the registry under a `vX.Y.Z` tag that [release.yml](../templates/release.yml) built. The server builds nothing.
- `postgres` uses a major-series tag and `nginx` a minor-series tag. `certbot` and `caddy` are pinned exactly.
- Never pull on a schedule. A deploy is the only moment images change, so it also prunes the superseded ones.

### Prerequisites

- The release tag pushed with `make prod-release VERSION=X.Y.Z`, and its images built.
- The tag change committed to the repo, so the running stack matches source. Edit the Compose file in git, not on the box.
- `BACKUP_DIR` (default `/opt/backups/postgres`) writable, for the pre-update backup.
- `.deploy-state` in `.gitignore`. [`prod-init.sh`](../scripts/prod-init.sh) records the last healthy tag there.

### Steps

1. **Bump the tag explicitly** in the Compose file. Pin to a concrete version,
   not a moving tag:

   ```diff
   -    image: ghcr.io/<owner>/<project>-backend:v1.4.0
   +    image: ghcr.io/<owner>/<project>-backend:v1.5.0
   ```

2. **Run the guarded deploy.** [`prod-init.sh`](../scripts/prod-init.sh) runs the safe deploy flow:

   - It refuses a `build:`, an untagged or `latest` image, and a downgrade below the recorded tag.
   - Migrations are forward-only, so an older release fails on a newer schema. A failed attempt counts too.
   - It takes a verified backup with [`backup-postgres.sh`](../scripts/backup-postgres.sh) before any container changes.
   - It pulls the pinned images and starts the stack with `up --wait`, which polls every healthcheck.
   - It polls `https://<domain>`, then records the tag in `.deploy-state`. On a failure it prints the rollback path.

   ```bash
   DOMAIN=<domain> make prod-deploy
   ```

   Expected: the last lines read `Deployed v1.5.0 — https://<domain>`, exit 0.
   `Downgrade refused` changes nothing; to go back, follow [Roll back](#roll-back).

3. **Prune the superseded images:**

   ```bash
   docker image prune -f
   ```

   Expected: dangling images left untagged by the bump are removed; the summary
   ends with a `Total reclaimed space: <N>` line (`0B` if nothing was orphaned).

> To reclaim more aggressively, use `docker system prune -af`. Its `--volumes` flag
> prunes only **anonymous** volumes — `postgres-data`, being named, survives it.
> **`docker volume prune --all` or `docker compose down --volumes` remove it too.**
> After `down` drops the containers, that includes the database. Deleting a volume
> needs a human decision, never an agent's.

### Roll back

The failed deploy printed the pre-update dump and the tag to return to. The same steps undo a healthy deploy.

1. **Set the app image tags back** to the previous release in git, and pull that commit on the server:

   ```diff
   -    image: ghcr.io/<owner>/<project>-backend:v1.5.0
   +    image: ghcr.io/<owner>/<project>-backend:v1.4.0
   ```

2. **Restore the pre-update dump** with the [full-restore commands](postgresql-operations.md#2-restore).
   The dump must come from the release you return to, or earlier.
   Skip the final `start backend`: step 3 starts the older release.

3. **Deploy with the override.** `ROLLBACK=1` asserts that step 2 happened; the script lifts the downgrade guard for this run only:

   ```bash
   ROLLBACK=1 DOMAIN=<domain> make prod-deploy
   ```

   Expected: a `ROLLBACK=1` warning block, then `Deployed v1.4.0 — https://<domain>`, exit 0.

## Reboot routine (monthly)

- Unattended-upgrades installs patches but **never auto-reboots**
  (see [`setup-server.sh`](../scripts/setup-server.sh)).
- Kernel and libc updates only take effect on the next reboot.
- On Debian only kernel updates set `/var/run/reboot-required`, so the reboot is unconditional.
- The health-ping heartbeat alerts while that flag is set; this routine clears it.
- Run it in a low-traffic maintenance window — a reboot drops all connections
  for ~1 min.

### Steps

1. **Apply every pending upgrade**, including held-back ones:

   ```bash
   sudo apt update && sudo apt full-upgrade
   ```

   Expected: apt lists the upgrades and asks to continue, or reports `0 upgraded`.

2. **Note whether the flag is set.** This is informational; the reboot follows either way:

   ```bash
   test -f /var/run/reboot-required && echo "reboot required" || echo "no flag set"
   ```

   Expected: `reboot required` after a kernel upgrade, otherwise `no flag set`.

3. **Reboot inside the maintenance window:**

   ```bash
   sudo reboot
   ```

   Expected: the SSH session drops; the host is back in ~30–60 s. Reconnect.

4. **Verify the stack came back.** Containers have `restart: unless-stopped`, so
   they should start on their own:

   ```bash
   docker compose -f docker-compose.prod.yml ps
   ```

   Expected: every service is listed with `STATUS` `Up …`, and `postgres` shows
   `(healthy)`. No service in `Restarting` or `Exit`.

5. **Confirm the site is reachable over HTTPS** from off the box:

   ```bash
   curl -sI https://<your-domain> | head -1
   ```

   Expected: `HTTP/2 200` (or a deliberate `301`/`308` redirect line if the root
   redirects). A hang or `curl: (7) Failed to connect` means the reverse proxy
   didn't come up — check `docker compose -f docker-compose.prod.yml logs
   reverse-proxy`.

## Disk, memory and service checks (monthly)

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

2. **Swap exists, and `/tmp` is not eating RAM** — see the swap and tmpfs
   comments in [`setup-server.sh`](../scripts/setup-server.sh) for why both matter.

   ```bash
   free -h && findmnt -no FSTYPE,SIZE,USED /tmp
   ```

   Expected: a non-zero `Swap` row, and `/tmp` **absent from `findmnt`** (a plain
   directory on disk, not tmpfs). Fix: `sudo systemctl mask tmp.mount` and reboot.

3. **Docker's share of the disk** — images, containers, volumes, build cache:

   ```bash
   docker system df
   ```

   Expected: four rows (`Images`, `Containers`, `Local Volumes`, `Build Cache`)
   with a `RECLAIMABLE` column. A large reclaimable figure is the cue to prune
   (see [image updates](#image-updates-every-deploy)); `postgres-data` under
   `Local Volumes` is **not** reclaimable and must stay.

4. **No failed systemd units:**

   ```bash
   systemctl --failed
   ```

   Expected: `0 loaded units listed.` Any listed unit is a regression to
   investigate (often `fail2ban` or a timer).

5. **fail2ban is active and jailing SSH:**

   ```bash
   sudo systemctl is-active fail2ban && sudo fail2ban-client status sshd
   ```

   Expected: `active`, then an `sshd` jail status block (`Currently banned`,
   `Total banned`, …). A non-zero `Total banned` is normal on a public box.
   (Jail config: [`setup-server.sh`](../scripts/setup-server.sh).)

6. **UFW is up and rate-limiting SSH:**

   ```bash
   sudo ufw status verbose
   ```

   Expected: `Status: active`, `Default: deny (incoming)`, a `22/tcp  LIMIT`
   rule, and the `80,443/tcp` rules the app needs.

## After an OOM kill

Processes vanish, nothing is logged as failed, and `uptime` shows no reboot.

The kernel's own report is usually unreadable — `dmesg_restrict=1` on Debian, and
a user outside `adm`/`systemd-journal` sees no kernel lines. Three readings settle
it without root.

1. **Confirm it was an OOM, and whether a limit or the whole box ran out:**

   ```bash
   cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/memory.events
   ```

   `oom_kill` counts kills since the cgroup was created, not since boot. A recreated
   `user-<uid>.slice` starts at zero. `max 0` and `high 0` beside a non-zero
   `oom_kill` mean **no cgroup limit was hit**. The machine itself ran out, so the
   fix is swap or less load.

2. **Find which unit died, and how big it got.** systemd writes a high-water mark
   when a scope exits, and it outlives every process in it:

   ```bash
   journalctl --since '1 day ago' | grep -E 'OOM killer|oom-kill|memory peak'
   ```

   The `Consumed … memory peak …` line names the culprit — one scope's peak against
   the machine's total is usually the whole diagnosis.

3. **Check whether the user manager itself died**, which is what turns one kill
   into the loss of every session:

   ```bash
   systemctl show user@$(id -u).service -p MainPID -p ActiveEnterTimestamp
   ```

   A start timestamp later than the kill means the manager was replaced.
   Everything in its slice went with it; [tmux.md](../cheatsheets/tmux.md) has
   the lingering that prevents this.

## Restore drill (quarterly)

Follow the [restore drill](postgresql-operations.md#4-restore-drill) into a throwaway DB;
an actual disaster uses the [full-restore commands](postgresql-operations.md#2-restore) instead.

