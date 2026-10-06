# Linux Services

Sharp edges of the server commands, and when resource usage needs action.
Steps: [provision-server.md](../guides/provision-server.md), [deploy.md](../guides/deploy.md), [maintenance.md](../guides/maintenance.md).

## systemd units

| Command | Does | Expected |
| --- | --- | --- |
| `sudo systemctl restart docker` | Restarts the Docker daemon, which rereads `/etc/docker/daemon.json` | Stops every container meanwhile: run it in a maintenance window. Containers with `restart: unless-stopped` come back up |
| `sudo systemctl mask tmp.mount` | Links the unit to `/dev/null`, so nothing can start it | Takes effect at the next reboot |

## journalctl

| Command | Does | Read |
| --- | --- | --- |
| `journalctl --since '1 day ago'` | The last day of the journal, as far as you may read it | Outside `adm` and `systemd-journal`, only your own user's lines show |

## Compose operations

Run them in `/opt/<project>`: its `.env` sets `COMPOSE_FILE`, so plain `docker compose` targets production.

| Command | Does | Read |
| --- | --- | --- |
| `docker compose exec -T postgres sh -c` | Runs a shell command in a running service without a TTY | Required when stdin is a file, such as `< "$DUMP"` |
| `docker image prune -af` | Deletes every image no container uses, old release tags included | Volumes stay; a roll back re-pulls its tag from GHCR |

## Ports and firewall

Docker-published ports bypass UFW, so only the reverse proxy publishes ports ([Docker and ufw](https://docs.docker.com/engine/network/packet-filtering-firewalls/)).

## Resource usage

Monthly thresholds and fixes: [maintenance.md](../guides/maintenance.md#verify).

```bash
sudo apt install btop ncdu sysstat   # add-ons for the live view, ncdu, iostat and sar; the rest ships with Ubuntu
```

| Resource          | Command                        | Read                        | Act when                          |
| ----------------- | ------------------------------ | --------------------------- | --------------------------------- |
| CPU               | `uptime`                       | load average (1, 5, 15 min) | above `nproc` for 15 min          |
| RAM               | `free -h`                      | `available` column only     | swap `used` keeps growing         |
| Disk space        | `df -h`                        | `Use%`                      | ≥ 80 %                            |
| What fills a disk | `sudo ncdu -x /`               | largest folders first       | one folder grows unexpectedly     |
| Disk I/O          | `iostat -xz 2`                 | `%util`                     | near 100 for minutes              |
| Top processes     | `ps aux --sort=-%cpu \| head`  | `%CPU`, `RSS`               | one process pins a core for hours |
| Everything live   | `btop`                         | one panel per resource      |                                   |

History, once [host-history.md](../guides/host-history.md) records it; `-f /var/log/sysstat/saDD` reads day `DD`:

| Resource | Command | Read | Act when |
| --- | --- | --- | --- |
| CPU | `sar -u` | `%iowait`, `%steal` | `%steal` stays high for hours: other guests take the host's CPU |
| RAM | `sar -r` | `kbavail` | falls day over day |
| Load | `sar -q` | `ldavg-15` | above `nproc` for hours |
| Disk space | `sar -F MOUNT` | `%ufsused`, which counts the root reserve as used | ≥ 80 % |
| Memory pressure | `cat /proc/pressure/memory` | `some` and `full` `avg60`: the share of time one or all tasks stalled on memory | `full` above 0 for minutes on end |
| Any of them as JSON | `sadf -j -- -u -r -q -F` | one object per sample | |

Sources: [systemctl](https://www.freedesktop.org/software/systemd/man/latest/systemctl.html), [journalctl](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html), [docker compose](https://docs.docker.com/reference/cli/docker/compose/), [sar](https://manpages.debian.org/trixie/sysstat/sar.sysstat.1.en.html), [PSI](https://docs.kernel.org/accounting/psi.html).
