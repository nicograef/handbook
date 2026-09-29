# External Monitoring with Better Stack

Stand up external monitoring for a single-VPS stack on [Better Stack](https://betterstack.com/)'s free plan.
One HTTPS uptime monitor watches the site; cron heartbeats watch backup, server health and TLS expiry.

## Prerequisites

- The stack passes [deploy.md#verify](deploy.md#verify), with its clone and `.env` under `/opt/<project>`.
- SSH access as the deploy user, with `sudo` for `/etc/default/report-health`.
- A Better Stack account on the free plan, with email alerts and optionally Slack configured once.
- Four free slots on Caddy, five on nginx: the free plan's 10 monitors and heartbeats share one pool.

| Placeholder | Description |
| ----------- | ----------- |
| `<project>` | Directory name of the clone under `/opt` |
| `<domain>` | Public domain the stack serves over HTTPS |
| `<heartbeat-url>` | Secret URL from a heartbeat's detail page |

Every heartbeat is a dead-man's switch: its job pings the URL only after full success.
A failure, a dead cron or a dead box withholds the ping, and the missed window alerts.
Heartbeat URLs are secrets and per-server configuration, so they never enter the repository.

| Heartbeat | Every | Grace | URL lives in | Pinged by |
| --------- | ----- | ----- | ------------ | --------- |
| Backup | 1 day | 3 h | `BACKUP_PING_URL` in `/opt/<project>/.env` | [scripts/backup-postgres.sh](../scripts/backup-postgres.sh) |
| Health | 1 hour | 30 min | `HEALTH_PING_URL` in `/etc/default/report-health` | [scripts/report-health.sh](../scripts/report-health.sh) |
| TLS expiry | 1 day | 3 h | the deploy user's crontab | the cron line in [TLS-expiry heartbeat](#tls-expiry-heartbeat) |
| Cert renewal, nginx only | 1 day | 36 h | `CERT_PING_URL` in `/opt/<project>/.env` | `certbot` service in [docker-compose.prod.yml](../templates/docker-compose.prod.yml) |

Each script's header states the conditions under which it pings.

## Create a heartbeat

Every heartbeat below starts with this step.

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

   Expected: `grep BACKUP_PING_URL /opt/<project>/.env` prints the line once.

## Health heartbeat

Provisioning writes `/etc/default/report-health` when it was given `HEALTH_PING_URL`; this step writes it otherwise.

1. [Create a heartbeat](#create-a-heartbeat) from the Health row.
   Expected: a Pending heartbeat and its `<heartbeat-url>`.
2. Write the URL to the defaults file, readable by root only:

   ```bash
   echo 'HEALTH_PING_URL=<heartbeat-url>' | sudo tee /etc/default/report-health >/dev/null
   sudo chmod 600 /etc/default/report-health
   ```

   Expected: `sudo cat /etc/default/report-health` prints the line.

## Uptime monitor

1. In Better Stack, create a monitor on `https://<domain>` with a 3-minute check frequency.
   Expected: the monitor turns **Up** within a few minutes.

## TLS-expiry heartbeat

Better Stack's SSL-expiry check is paid only, so a daily cron job checks the live certificate instead.
It pings only while the certificate served on `:443` has more than 7 days left.
A failed renewal or a stuck reload then withholds the ping.

1. [Create a heartbeat](#create-a-heartbeat) from the TLS expiry row.
   Expected: a Pending heartbeat and its `<heartbeat-url>`.
2. Add one line to the deploy user's crontab with `crontab -e`:

   ```bash
   0 7 * * * openssl s_client -connect <domain>:443 -servername <domain> </dev/null 2>/dev/null | openssl x509 -noout -checkend 604800 && curl -fsS -m 10 <heartbeat-url> >/dev/null
   ```

   Expected: `crontab -l | grep checkend` prints the line.

## Cert-renewal heartbeat

This heartbeat applies to the nginx variant only; Caddy renews and serves its certificate in one process.
On nginx, `certbot renew` and the nginx reload run as separate loops (see [deploy.md#tls-variants](deploy.md#tls-variants)).
This heartbeat proves the renewal; the TLS-expiry heartbeat proves the reload.

The 36 h grace is wide because the `certbot` loop sleeps 24 h between passes.

1. [Create a heartbeat](#create-a-heartbeat) from the Cert renewal row.
   Expected: a Pending heartbeat and its `<heartbeat-url>`.
2. Append the URL to the Compose `.env`:

   ```bash
   echo 'CERT_PING_URL=<heartbeat-url>' >> /opt/<project>/.env
   ```

   Expected: `grep CERT_PING_URL /opt/<project>/.env` prints the line once.
3. Recreate the `certbot` container so it reads the new variable:

   ```bash
   cd /opt/<project> && docker compose up -d certbot
   ```

   Expected: Compose reports the `certbot` container recreated and started.

## Verify

Fire every heartbeat once by hand, as the deploy user:

```bash
cd /opt/<project>
# backup: sends the stored URL a plain GET
curl -fsS -m 10 "$(grep -E '^BACKUP_PING_URL=' .env | tail -n 1 | cut -d= -f2-)" >/dev/null && echo "backup ping sent"
# health: runs the hourly check; exits 0 only when healthy and pinged
sudo report-health && echo "health ping sent"
# TLS expiry: runs the crontab command as cron would
crontab -l | grep -- '-checkend' | cut -d' ' -f6- | sh && echo "tls ping sent"
# cert renewal, nginx variant only: a no-op renew pass still pings
docker compose exec certbot sh -c 'certbot renew --webroot -w /var/www/certbot && wget -qO- "$CERT_PING_URL"' >/dev/null && echo "cert ping sent"
```

Expected: each command prints its `... ping sent` line.
The Better Stack dashboard then shows every monitor **Up**: four on Caddy, five on nginx.

| Variant | Monitors Up |
| ------- | ----------- |
| Caddy | Uptime, Backup, Health, TLS expiry |
| nginx | Uptime, Backup, Health, TLS expiry, Cert renewal |
