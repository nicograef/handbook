# External Monitoring with Better Stack

Stand up external monitoring for a single-VPS stack on [Better Stack](https://betterstack.com/)'s free plan.

- One HTTPS uptime monitor, with a TLS/SSL-expiry alert.
- Three cron heartbeats: backup, cert renewal, health ping.

## The dead-man model

- Every heartbeat is a **dead-man's switch**: a cron or service pings its URL **only after full success**.
- Any failure withholds the ping; the missed window then trips the alert after the grace period.
- Service-portable — no `/fail` endpoint, just a plain `GET` on success.
- A job that never runs at all (dead cron, dead box) alerts by itself.
- Certs need two independent signals, because `certbot renew` and
  `nginx -s reload` are decoupled loops (see [letsencrypt-docker.md](letsencrypt-docker.md)).
  - **cert-renewal heartbeat** — proves `certbot renew` ran and succeeded.
  - **external TLS-expiry monitor** — the safety net for the *reload* half.
  - A renew can succeed while a stuck reload keeps nginx serving the old cert.
  - The heartbeat can't see that; the external SSL-expiry check on the live `:443` endpoint can.

## Ping URLs are configuration, never git

Each heartbeat has a secret URL. These are **per-server configuration and never enter the repository**:

| URL | Where it lives | Consumed by | Period | Grace |
| --- | -------------- | ----------- | ------ | ----- |
| `BACKUP_PING_URL` | server's Compose `.env` | [scripts/backup-postgres.sh](../scripts/backup-postgres.sh) | 1 day | 2-3 h |
| `CERT_PING_URL` | server's Compose `.env` | `certbot` service in [docker-compose.prod.yml](../templates/docker-compose.prod.yml) | 1 day | 24-36 h |
| `HEALTH_PING_URL` | `/etc/default/report-health` | `report-health` cron, persisted by provisioning | 1 day | 2-3 h |

```bash
# on the server, in the Compose project dir
echo 'BACKUP_PING_URL=<heartbeat-url>' >> .env
echo 'CERT_PING_URL=<heartbeat-url>' >> .env
docker compose -f docker-compose.prod.yml up -d certbot   # recreate to pick up the env var
echo 'HEALTH_PING_URL=<heartbeat-url>' | sudo tee -a /etc/default/report-health
```

- The cert-renewal grace is wide. The loop sleeps 24 h between passes. Most passes are no-op pings, since Let's Encrypt only renews within
  30 days of expiry. A failed *reload* is caught by the TLS-expiry monitor below, not this heartbeat.
- `report-health` pings only when `report-health.sh`'s three conditions hold.

## Prerequisites

- The production stack deployed with a public HTTPS endpoint (see [letsencrypt-docker.md](letsencrypt-docker.md)).
- SSH access to the server to edit its `.env` and reach `/etc/default/report-health`.
- Configure alerts once under the team's on-call/notification settings (email and, optionally, Slack) — every monitor and heartbeat below reuses it.

> **Free plan.** 10 monitors come from one shared pool covering uptime monitors and heartbeats.
> Built-in TLS/SSL-expiry alerts on uptime monitors, email + Slack alerts, and 3-minute checks.
> This runbook uses **4 of the 10 slots**: one uptime monitor and three heartbeats.

### Inputs

Only `<your-domain>` — the public HTTPS endpoint the uptime monitor checks. The three ping URLs come from the heartbeats and monitor created below.

## Uptime monitor with SSL-expiry alert

This monitor watches the public endpoint *and* the certificate.

- Create an HTTPS monitor on `https://<your-domain>`, checked every 3 minutes.
- Enable its **SSL / TLS certificate expiration** alert.
- The reload loop and a 30-day renewal window give ample runway before expiry.

> **Verification point — free-plan SSL-expiry caveat.** The SSL-expiry toggle
> being free is **docs-verified but not account-verified**.
> **This step is where you confirm it.** If the toggle is paywalled on your
> account:
> - Re-pick the TLS-expiry source from live-verified free candidates.
> - Example: an external cron that runs `openssl s_client -connect <domain>:443 | openssl
>   x509 -checkend` and pings a fourth heartbeat on success.
> - **Record the decision here** — replace this callout with what you chose.
> - The runbook must reflect reality.

## Verify

```bash
# 1. Uptime monitor is green and reports a cert expiry date
#    → check the monitor's page in the Better Stack dashboard.

# 2. Fire each heartbeat once by hand and confirm it flips to "up" in the UI.
#    Backup + health pings are plain GETs:
curl -fsS "<backup-heartbeat-url>"   >/dev/null && echo "backup ping sent"
curl -fsS "<health-heartbeat-url>"   >/dev/null && echo "health ping sent"

# 3. Cert heartbeat: run one renew pass in the container (no-op renew still pings).
docker compose -f docker-compose.prod.yml exec certbot \
  sh -c 'certbot renew --webroot -w /var/www/certbot && wget -qO- "$CERT_PING_URL"'
```

Expected: all four monitors show **up** in the dashboard.

- To prove the alerting path end-to-end, deliberately skip one backup or health ping.
- Confirm the alert fires after the grace period.
