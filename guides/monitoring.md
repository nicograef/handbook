# External Monitoring with Better Stack

Stand up external monitoring for a single-VPS stack on [Better Stack](https://betterstack.com/)'s free plan.
One HTTPS uptime monitor watches the site; cron heartbeats watch backup, server health and TLS expiry.

## Prerequisites

- The stack passes [deploy.md#verify](deploy.md#verify), with its clone and `.env` under `/opt/<project>`.
- The daily backup cron installed per [backup-restore.md#daily-backup](backup-restore.md#daily-backup).
- SSH access as the deploy user, with `sudo` for `/etc/default/report-health` and `/etc/report-health.d/`.
- A Better Stack account on the free plan, with email alerts and optionally Slack configured once.
- Free plan room: the stack uses 1 monitor and 3 heartbeats, of 10 each.

Every heartbeat is a dead-man's switch: its job pings the URL only after full success.
A failure, a dead cron or a dead box withholds the ping, and the missed window alerts.
Heartbeat URLs are secrets and per-server configuration, so they never enter the repository.

| Heartbeat | Every | Grace | URL lives in | Pinged by |
| --------- | ----- | ----- | ------------ | --------- |
| Backup | 1 day | 3 h | `BACKUP_PING_URL` in `/opt/<project>/.env` | [backup-postgres.sh](../templates/backup-postgres.sh) |
| Health | 1 hour | 30 min | `HEALTH_PING_URL` in `/etc/default/report-health` | [scripts/report-health.sh](../scripts/report-health.sh) |
| TLS expiry | 1 day | 3 h | the deploy user's crontab | the cron line in [TLS-expiry heartbeat](#tls-expiry-heartbeat) |

## Create a heartbeat

1. In Better Stack, open **Heartbeats → Create heartbeat**. Name it after its table row, set **Expect a heartbeat every** and the grace period from the table, then save.
   Expected: the heartbeat shows **Pending**, and its detail page shows the secret URL.

Source: [Better Stack heartbeat docs](https://betterstack.com/docs/uptime/cron-and-heartbeat-monitor/).

## Backup heartbeat

1. [Create a heartbeat](#create-a-heartbeat) from the Backup row.
   Expected: a Pending heartbeat and its `<heartbeat-url>`.
2. Append the URL to the Compose `.env`:

   ```bash
   echo 'BACKUP_PING_URL=<heartbeat-url>' >> /opt/<project>/.env
   ```

   Expected: `grep '^BACKUP_PING_URL=' /opt/<project>/.env` prints the line once.

## Health heartbeat

Provisioning writes `/etc/default/report-health` when it was given `HEALTH_PING_URL`.
That heartbeat then exists already; reuse it instead of creating a second one.

1. Check whether provisioning stored a URL:

   ```bash
   sudo grep -q '^HEALTH_PING_URL=.' /etc/default/report-health && echo "health URL set"
   ```

   Expected: `health URL set` means this section is done; no output means continue with the next step.
2. [Create a heartbeat](#create-a-heartbeat) from the Health row.
   Expected: a Pending heartbeat and its `<heartbeat-url>`.
3. Write the URL to the defaults file, readable by root only:

   ```bash
   echo 'HEALTH_PING_URL="<heartbeat-url>"' | sudo tee /etc/default/report-health >/dev/null
   sudo chmod 600 /etc/default/report-health
   ```

   Expected: `sudo cat /etc/default/report-health` prints the line.

## Add a health check

report-health runs the built-in checks `reboot`, `upgrades` and `oom`.
Each drop-in in `/etc/report-health.d/` adds one check, named after its file.

- A drop-in is an executable regular file named to match `^[a-z0-9-]+$`; other files are skipped.
- The drop-ins run in name order, each under a 30-second timeout.
- Exit 0 passes; a non-zero exit or a timeout fails the check and withholds the ping.
- The first stdout line is the reason; the hourly run logs a failure as `UNHEALTHY: <name>: <reason>`.

`report-health --check-only` prints one tab-separated `<name>`, `ok` or `fail`, `<reason>` line per check.
It exits 1 when any check fails, reads no defaults file and pings nothing.

1. Write the drop-in, owned by root and executable:

   ```bash
   sudo install -d -m 755 /etc/report-health.d
   printf '#!/usr/bin/env bash\n<command>\n' | sudo tee /etc/report-health.d/<name> >/dev/null
   sudo chmod 755 /etc/report-health.d/<name>
   ```

   Expected: `sudo ls -l /etc/report-health.d` lists `<name>` as `-rwxr-xr-x`.
2. Run every check once, without a ping:

   ```bash
   sudo report-health --check-only
   ```

   Expected: one `ok` line per check, `<name>` among them, and exit status 0.

## Uptime monitor

1. In Better Stack, create a monitor on `https://<domain>` with a 3-minute check frequency.
   Expected: the monitor turns **Up** within a few minutes.

## TLS-expiry heartbeat

A daily cron job checks the certificate the live `:443` endpoint serves, not the one on disk.
It pings only while that certificate has more than 7 days left.
A failed renewal then withholds the ping.

1. [Create a heartbeat](#create-a-heartbeat) from the TLS expiry row.
   Expected: a Pending heartbeat and its `<heartbeat-url>`.
2. Add one line to the deploy user's crontab with `crontab -e`:

   ```bash
   0 7 * * * openssl s_client -connect <domain>:443 -servername <domain> </dev/null 2>/dev/null | openssl x509 -noout -checkend 604800 && curl -fsS -m 10 <heartbeat-url> >/dev/null
   ```

   Expected: `crontab -l | grep checkend` prints the line.

## Verify

Fire every heartbeat once by hand, as the deploy user:

```bash
cd /opt/<project>
# backup: sends the stored URL a plain GET
curl -fsS -m 10 "$(grep -E '^BACKUP_PING_URL=' .env | tail -n 1 | cut -d= -f2-)" >/dev/null && echo "backup ping sent"
# health checks: one line per check, no ping
sudo report-health --check-only && echo "health checks pass"
# health: runs the hourly check, see the report-health.sh header
sudo grep -q '^HEALTH_PING_URL=.' /etc/default/report-health && sudo report-health && echo "health ping sent"
# TLS expiry: runs the crontab command as cron would
crontab -l | grep -- '-checkend' | cut -d' ' -f6- | sh && echo "tls ping sent"
```

Expected: the check run prints one `ok` line per check and `health checks pass`.
Every other command prints its `... ping sent` line.
The Better Stack dashboard then shows all four monitors **Up**: Uptime, Backup, Health and TLS expiry.

To prove alerting end to end, withhold the health ping for one cycle, then restore it:

```bash
sudo mv /etc/default/report-health /etc/default/report-health.off
# wait for the Health heartbeat's alert email, at most 90 minutes
sudo mv /etc/default/report-health.off /etc/default/report-health
```

Expected: the alert email arrives, and the next hourly ping resolves the incident.
