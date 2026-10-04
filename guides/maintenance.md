# Server Maintenance

The monthly checklist: apply upgrades, reboot, reclaim disk, then check that everything came back.
Image updates and roll back happen at deploy time: [deploy.md#update](deploy.md#update).

Unattended-upgrades installs patches but never reboots (see [`setup-server.sh`](../scripts/setup-server.sh)).
Kernel and libc updates take effect only after a reboot, so the monthly reboot is unconditional.
The health-ping heartbeat alerts while `/var/run/reboot-required` exists; the reboot clears it.

## Prerequisites

- SSH access as `<username>` to a server that passed [provision-server.md#verify](provision-server.md#verify).
- The app deployed per [deploy.md](deploy.md) in `/opt/<project>`, whose `.env` sets `COMPOSE_FILE`.
- A low-traffic window: the reboot drops all connections for about a minute.
- On netcup: [`scripts/netcup.sh`](../scripts/netcup.sh) logged in on your laptop, and `<server>`, the server's id or name.

## Monthly checklist

1. **Apply every pending upgrade**, including held-back ones:

   ```bash
   sudo apt update && sudo apt full-upgrade
   ```

   Expected: apt lists the upgrades and asks to continue, or reports `0 upgraded`.

2. **Reboot inside the maintenance window:**

   ```bash
   sudo reboot
   ```

   Expected: the SSH session drops and the host is back within 30 to 60 s. Reconnect.
   Containers have `restart: unless-stopped`, so the stack starts on its own.

3. **Reclaim Docker's share of the disk.** List images, containers, volumes and build cache:

   ```bash
   docker system df
   ```

   Expected: four rows with a `RECLAIMABLE` column. A large figure is the cue to run `docker image prune -af`, as [Update](deploy.md#update) does.
   The `postgres-data` volume is **not** reclaimable and stays.

4. **Quarterly: run the [restore drill](backup-restore.md#restore-drill)** into a throwaway database.

   Expected: the throwaway database's row counts match the live one. An actual disaster uses [Restore](backup-restore.md#restore) instead.

## Verify

Run each check on the server, in `/opt/<project>`; run the HTTPS and netcup checks from your own machine.
[linux-services.md](../reference/linux-services.md) explains each command.

```bash
test -f /var/run/reboot-required && echo "reboot required" || echo "no flag set"
systemctl --failed
docker compose ps
curl -sI https://<domain> | head -1
# netcup only, from a handbook clone
scripts/netcup.sh firewall-get <server> | jq '{policies: [(.copiedPolicies + .userPolicies)[].name], ingressImplicitRule, egressImplicitRule, consistent}'
df -h /
swapon --show
findmnt -no FSTYPE /tmp
sudo fail2ban-client status sshd
sudo ufw status verbose
```

| Check | Passes when | Otherwise |
| --- | --- | --- |
| Reboot flag | `no flag set` | Reboot again; a kernel upgrade landed after the reboot |
| `systemctl --failed` | `0 loaded units listed.` | Read the unit's log: `sudo journalctl -u <unit> -b` |
| `docker compose ps` | Every service `Up`, `postgres` `(healthy)`; none `Restarting` or `Exit` | `docker compose logs <service>` |
| HTTPS | `HTTP/2 200`, or the deliberate `301`/`308` of a redirecting root | `docker compose logs reverse-proxy`; a hang means the proxy is down |
| netcup firewall | The netcup default policies, then `web-server`; `DROP_ALL` ingress, `ACCEPT_ALL` egress; `consistent` `true` | Re-run `firewall-attach` as [provision-server.md](provision-server.md#provision-over-ssh) does |
| `df -h /` | `Use%` under 80 % | Run `docker image prune -af`, or grow the volume the same day |
| `swapon --show` | One swap row | Create a swapfile as the swap block of [`setup-server.sh`](../scripts/setup-server.sh) does |
| `findmnt /tmp` | `tmpfs` (the Debian 13 default) or nothing (a directory on disk) | On a box running builds or agents, a tmpfs `/tmp` eats RAM: `sudo systemctl mask tmp.mount`, then reboot |
| fail2ban | A `Status for the jail: sshd` block; a non-zero `Total banned` is normal | `sudo systemctl restart fail2ban` |
| `ufw status verbose` | `Status: active`, `Default: deny (incoming)`, `22/tcp LIMIT`, `80/tcp` and `443/tcp` `ALLOW IN` | Re-add the UFW rules from [`setup-server.sh`](../scripts/setup-server.sh) |

The monthly netcup read also keeps its refresh token inside the 30 days it lives unused.
A full disk stops Postgres writes and breaks certificate renewal.
The swap and tmpfs comments in [`setup-server.sh`](../scripts/setup-server.sh) explain why both matter.

## Troubleshooting

### After an OOM kill

Processes vanish, nothing is logged as failed, and `uptime` shows no reboot.

The kernel's own report is usually unreadable: `dmesg_restrict=1` on Debian, and
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

   The `Consumed … memory peak …` line names the culprit. One scope's peak against
   the machine's total is usually the whole diagnosis.

3. **Check whether the user manager itself died**, which turns one kill into the loss of every session:

   ```bash
   systemctl show user@$(id -u).service -p MainPID -p ActiveEnterTimestamp
   ```

   A start timestamp later than the kill means the manager was replaced, and everything in its slice went with it.

The manager dies when the OOM killer takes `systemd --user` itself, which runs with `OOMScoreAdjust=100`.
Its `KillMode=mixed` then kills the rest of the slice. Swap keeps the OOM killer off the manager.
The swap comment in [`setup-server.sh`](../scripts/setup-server.sh) details it.

Lingering covers the other path. tmux runs each pane in a `tmux-spawn-*.scope` under `user@<uid>.service`.
Without lingering, the last logout stops that unit and every pane, whatever `KillUserProcesses=` says.
An OOM kill that ends your SSH sessions then takes tmux with it.

[provision-server.md](provision-server.md#turn-on-lingering) turns lingering on.
