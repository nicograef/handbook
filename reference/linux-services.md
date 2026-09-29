# Linux Services

The commands the server runbooks run, in the form they run them.
Steps: [provision-server.md](../guides/provision-server.md), [deploy.md](../guides/deploy.md), [maintenance.md](../guides/maintenance.md). Hardware and live usage: [system-resources.md](system-resources.md).

## systemd units

| Command | Does | Expected |
| --- | --- | --- |
| `systemctl --failed` | Lists units in the `failed` state | `0 loaded units listed.` |
| `sudo systemctl is-active fail2ban` | Prints one unit's state | `active` |
| `sudo systemctl restart fail2ban` | Stops and starts one unit | `is-active` prints `active` again |
| `sudo systemctl restart docker` | Restarts the Docker daemon, which rereads `/etc/docker/daemon.json` | Stops every container meanwhile: run it in a maintenance window. Containers with `restart: unless-stopped` come back up |
| `sudo systemctl mask tmp.mount` | Links the unit to `/dev/null`, so nothing can start it | Takes effect at the next reboot |
| `systemctl list-timers 'apt-daily*' --no-pager` | Lists matching timers with their next and last run | `apt-daily.timer` and `apt-daily-upgrade.timer` |
| `systemctl show user@$(id -u).service -p MainPID -p ActiveEnterTimestamp` | Prints two properties of your user manager | A start time after an OOM kill means it was replaced |
| `sudo loginctl enable-linger "$USER"` | Starts your user manager at boot and keeps it after the last logout | No output |
| `loginctl show-user "$USER" -p Linger` | Prints the linger flag | `Linger=yes` |

## journalctl

| Command | Does | Read |
| --- | --- | --- |
| `sudo journalctl -u <unit> -b` | One unit's log since the current boot | Add `-f` to follow, `-n 100` for the last lines |
| `journalctl --since '1 day ago'` | The last day of the journal, as far as you may read it | Outside `adm` and `systemd-journal`, only your own user's lines show |

## Compose operations

Run them in `/opt/<project>`: its `.env` sets `COMPOSE_FILE`, so plain `docker compose` targets production.

| Command | Does | Read |
| --- | --- | --- |
| `docker compose ps` | Lists the stack's containers with state and health | Every service `Up`, each healthcheck `(healthy)` |
| `docker compose ps --format '{{.Service}}: {{.Status}}'` | The same, one `service: status` line each | None `Restarting` or `Exit` |
| `docker compose logs <service>` | One service's container log | Add `-f` to follow, `--tail 100` for the last lines |
| `docker compose config --images` | Resolves the Compose file and prints its images | The backend image carries the `v<X.Y.Z>` tag of `docker-compose.prod.yml` |
| `docker compose config --volumes` | Resolves the Compose file and prints its named volumes | Includes `postgres-data` |
| `docker compose pull` | Pulls every image the file names | `denied`: log in to `ghcr.io` again |
| `docker compose up -d --wait postgres` | Starts one service and waits for its healthcheck | `Healthy` |
| `docker compose up -d certbot` | Recreates a service whose config or `.env` changed | Compose leaves unchanged services alone |
| `docker compose stop backend` | Stops one service, keeping its container | `Stopped` |
| `docker compose start backend` | Starts a stopped service | `Started` |
| `docker compose exec postgres sh -c` | Runs a shell command inside a running service | Single quotes make `$POSTGRES_USER` expand inside the container |
| `docker compose exec -T postgres sh -c` | The same without a TTY | Required when stdin is a file, such as `< "$DUMP"` |
| `docker compose down` | Removes the stack's containers and network, keeping volumes | The database survives |
| `docker compose -f docker-compose.initial-cert.yml up -d reverse-proxy` | Starts a second Compose file of the same project | nginx variant: the ACME challenge server alone |
| `docker system df` | Disk use of images, containers, volumes and build cache | The `RECLAIMABLE` column |
| `docker image prune -af` | Deletes every image no container uses, old release tags included | Volumes stay; a roll back re-pulls its tag from GHCR |
| `docker volume ls` | Lists volumes | `<project>_postgres-data` holds the database |
| `docker volume rm <old-volume>` | Deletes one volume and its data | Irreversible |
| `docker compose down --volumes` | Removes the stack's containers and its volumes | Deletes the database; only a human runs it |
| `docker volume prune --all` | Deletes every volume no container uses, named ones included | Deletes the database while the stack is down |

## Ports and firewall

Docker-published ports bypass UFW, so only the reverse proxy publishes ports ([Docker and ufw](https://docs.docker.com/engine/network/packet-filtering-firewalls/)).

| Command | Does | Expected |
| --- | --- | --- |
| `sudo ufw status verbose` | Firewall state, default policies and rules | `Status: active`, `Default: deny (incoming)`, `22/tcp` limited, `80/tcp` and `443/tcp` allowed |
| `sudo ss -tlnp` | Listening TCP sockets with their process | Only 22, 80 and 443 on `0.0.0.0` or `[::]`; the rest on loopback |
| `sudo sshd -T` | The effective sshd configuration | `passwordauthentication no`, `permitrootlogin no`, `kbdinteractiveauthentication no` |
| `sudo fail2ban-client status sshd` | The SSH jail's counters and banned addresses | A `Status for the jail: sshd` block |
| `sudo fail2ban-client get sshd journalmatch` | The journal filter the SSH jail reads | Includes `_COMM=sshd-session` |
| `getent ahosts <domain>` | The addresses DNS returns for a name | This server's address |
| `ip -brief address` | This server's own addresses | The one DNS must return |
| `curl -sI https://<domain>` | Response headers over HTTPS | `HTTP/2 200` |
| `curl -sI http://<domain>` | Response headers over plain HTTP | `301` or `308` to HTTPS |
| `curl -sI http://<domain>/.well-known/acme-challenge/test` | Probes the ACME challenge path | nginx: `404` means DNS and port 80 reach the proxy |

## Cron

| Command | Does | Expected |
| --- | --- | --- |
| `crontab -e` | Edits your own crontab, not root's | Cron picks the change up on save |
| `crontab -l` | Prints your crontab | The backup and TLS-expiry lines |
| `systemctl is-active cron` | Prints the cron daemon's state | `active` |
| `cat /etc/cron.d/report-health` | Prints the system cron file for the health ping | `0 * * * * root /usr/local/bin/report-health` |

Sources: [systemctl](https://www.freedesktop.org/software/systemd/man/latest/systemctl.html), [journalctl](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html), [loginctl](https://www.freedesktop.org/software/systemd/man/latest/loginctl.html), [docker compose](https://docs.docker.com/reference/cli/docker/compose/), [ufw](https://manpages.debian.org/trixie/ufw/ufw.8.en.html), [ss](https://manpages.debian.org/trixie/iproute2/ss.8.en.html).
