# External Monitoring with Better Stack

Stand up external monitoring for a single-VPS stack on [Better Stack](https://betterstack.com/)'s free plan.

- One HTTPS uptime monitor.
- Four cron heartbeats: backup, cert renewal, health ping, TLS expiry.

## The dead-man model

- Every heartbeat is a **dead-man's switch**: a cron or service pings its URL **only after full success**.
- Any failure withholds the ping; the missed window then trips the alert after the grace period.
- Service-portable — no `/fail` endpoint, just a plain `GET` on success.
- A job that never runs at all (dead cron, dead box) alerts by itself.
- Certs need two independent signals, because `certbot renew` and
  `nginx -s reload` are decoupled loops (see [letsencrypt-docker.md](letsencrypt-docker.md)).
  - **cert-renewal heartbeat** — proves `certbot renew` ran and succeeded.
  - **TLS-expiry heartbeat** — the safety net for the *reload* half.
  - A renew can succeed while a stuck reload keeps nginx serving the old cert.
  - The renewal heartbeat can't see that; the expiry check on the live `:443` endpoint can.

## Ping URLs are configuration, never git

Each heartbeat has a secret URL. These are **per-server configuration and never enter the repository**:

| URL | Where it lives | Consumed by | Period | Grace |
| --- | -------------- | ----------- | ------ | ----- |
| `BACKUP_PING_URL` | server's Compose `.env` | [scripts/backup-postgres.sh](../scripts/backup-postgres.sh) | 1 day | 2-3 h |
| `CERT_PING_URL` | server's Compose `.env` | `certbot` service in [docker-compose.prod.yml](../templates/docker-compose.prod.yml) | 1 day | 24-36 h |
| `HEALTH_PING_URL` | `/etc/default/report-health` | `report-health` cron, persisted by provisioning | 1 day | 2-3 h |
| TLS-expiry URL | the server user's crontab | the [TLS-expiry check](#tls-expiry-heartbeat) | 1 day | 2-3 h |

```bash
# on the server, in the Compose project dir
echo 'BACKUP_PING_URL=<heartbeat-url>' >> .env
echo 'CERT_PING_URL=<heartbeat-url>' >> .env
docker compose -f docker-compose.prod.yml up -d certbot   # recreate to pick up the env var
echo 'HEALTH_PING_URL=<heartbeat-url>' | sudo tee -a /etc/default/report-health >/dev/null
sudo chmod 600 /etc/default/report-health
```

- The cert-renewal grace is wide. The loop sleeps 24 h between passes. Most passes are no-op pings.
- Certbot renews at one third of remaining lifetime, or earlier per ARI.
- A failed *reload* is caught by the TLS-expiry heartbeat below, not this one.
- `report-health` pings only when `report-health.sh`'s three conditions hold.

## Prerequisites

- The production stack deployed with a public HTTPS endpoint (see [letsencrypt-docker.md](letsencrypt-docker.md)).
- SSH access to the server to edit its `.env` and reach `/etc/default/report-health`.
- Configure alerts once under the team's on-call/notification settings (email and, optionally, Slack) — every monitor and heartbeat below reuses it.

> **Free plan.** 10 monitors come from one shared pool covering uptime monitors and heartbeats.
> Email + Slack alerts and 3-minute checks; SSL-expiry checks on uptime monitors are paid only.
> This runbook uses **5 of the 10 slots**: one uptime monitor and four heartbeats.

### Inputs

Only `<your-domain>` — the public HTTPS endpoint the uptime monitor checks. The four ping URLs come from the heartbeats in the ping-URL table above.

## Uptime monitor

- Create an HTTPS monitor on `https://<your-domain>`, checked every 3 minutes.
- It watches the public endpoint; the certificate is left to the heartbeat below.

## TLS-expiry heartbeat

- Better Stack's SSL-expiry check is paid only, so a cron job checks the live certificate instead.
- It pings only while the served certificate has more than 7 days left.
- A stuck reload or a failed renewal withholds the ping and trips the alert.
- Add it with `crontab -e` on the server, as one line:

```bash
0 7 * * * openssl s_client -connect <your-domain>:443 -servername <your-domain> </dev/null 2>/dev/null | openssl x509 -noout -checkend $((7*86400)) && curl -fsS -m 10 <heartbeat-url> >/dev/null
```

## Verify

```bash
# 1. Uptime monitor is green
#    → check the monitor's page in the Better Stack dashboard.

# 2. Fire each heartbeat once by hand and confirm it flips to "up" in the UI.
#    Backup + health pings are plain GETs:
curl -fsS "<backup-heartbeat-url>"   >/dev/null && echo "backup ping sent"
curl -fsS "<health-heartbeat-url>"   >/dev/null && echo "health ping sent"

# 3. Cert heartbeat: run one renew pass in the container (no-op renew still pings).
docker compose -f docker-compose.prod.yml exec certbot \
  sh -c 'certbot renew --webroot -w /var/www/certbot && wget -qO- "$CERT_PING_URL"'

# 4. TLS-expiry heartbeat: run the crontab command once by hand.
openssl s_client -connect <your-domain>:443 -servername <your-domain> </dev/null 2>/dev/null \
  | openssl x509 -noout -checkend $((7*86400)) && curl -fsS -m 10 <heartbeat-url> >/dev/null
```

Expected: all five monitors show **up** in the dashboard.

- To prove the alerting path end-to-end, deliberately skip one backup or health ping.
- Confirm the alert fires after the grace period.
