# External Monitoring with Better Stack

Stand up the full external monitoring surface for a single-VPS stack on
[Better Stack](https://betterstack.com/)'s free plan: one HTTPS uptime monitor
(with a TLS/SSL-expiry alert) plus three cron heartbeats (backup, cert renewal,
health ping). Better Stack is external to the server, so it still alerts when
the box itself is down.

## The dead-man model

Every heartbeat is a **dead-man's switch**: a cron or service pings its URL
**only after full success**. Any failure withholds the ping; the missed window
then trips the alert after the grace period. This is service-portable — it
needs no `/fail` endpoint, just a plain `GET` on success — and it means a job
that never runs at all (dead cron, dead box) alerts by itself.

Division of labor for certs (two independent signals):

- The **cert-renewal heartbeat** proves `certbot renew` ran and succeeded.
- The **external TLS-expiry monitor** is the safety net for the *reload* half:
  after PRD 1, `certbot renew` and `nginx -s reload` are decoupled loops (see
  [letsencrypt-docker.md](letsencrypt-docker.md)), so a renew can succeed while
  a stuck reload keeps nginx serving the old cert. The heartbeat can't see that;
  the external SSL-expiry check on the live `:443` endpoint can.

## Ping URLs are configuration, never git

Each heartbeat has a secret URL. These are **per-server configuration and never
enter the repository**:

| URL | Where it lives | Consumed by |
| --- | -------------- | ----------- |
| `BACKUP_PING_URL` | server's Compose `.env` | [scripts/backup-postgres.sh](../scripts/backup-postgres.sh) |
| `CERT_PING_URL` | server's Compose `.env` | `certbot` service in [docker-compose.prod.yml](../templates/docker-compose.prod.yml) |
| `HEALTH_PING_URL` | `/etc/default/report-health` | `report-health` cron, persisted by provisioning |

`templates/.env.example` carries the two Compose-side URLs as commented
placeholders — copy them into the server's real `.env` and fill in the values.
`HEALTH_PING_URL` is persisted by provisioning (see the `report-health` step in
[provision-server.md](provision-server.md)); it is a host-side cron, not part of
the Compose stack.

## Prerequisites

- A Better Stack account (created in Step 1 — no card required for the free plan).
- The production stack deployed with a public HTTPS endpoint (see
  [letsencrypt-docker.md](letsencrypt-docker.md)).
- SSH access to the server to edit its `.env` and reach `/etc/default/report-health`.

> **Free plan (verified 2026-07-09 from betterstack.com pricing and docs):**
> 10 monitors from one shared pool covering both uptime monitors and heartbeats,
> built-in TLS/SSL-expiry alerts on uptime monitors, email + Slack alerts, and
> 3-minute checks. This runbook uses **4 of the 10 slots**: one uptime monitor
> and three heartbeats.

## Step 1 — Create the account

1. Sign up at [betterstack.com](https://betterstack.com/) and confirm the email.
2. In **Uptime**, note that monitors and heartbeats draw from the same pool of
   10. Configure alerts once under the team's on-call/notification settings:
   add your email and, optionally, a Slack integration — every monitor and
   heartbeat below reuses it.

## Step 2 — HTTPS uptime monitor with SSL-expiry alert

This monitor watches the public endpoint *and* the certificate.

1. **Uptime → Monitors → Create monitor.**
2. Type: **HTTPS**. URL: `https://<your-domain>`. Check frequency: 3 minutes.
3. Enable the **SSL / TLS certificate expiration** alert (alert while there are
   still days of validity left — the reload loop and a 30-day renewal window
   give ample runway).
4. Point the alert at the notification channel from Step 1. Save.

> **Verification point — free-plan SSL-expiry caveat.** The SSL-expiry toggle
> being free is **docs-verified but not account-verified** (as of 2026-07-09).
> **This step is where you confirm it.** If the toggle is paywalled on your
> account:
> - Re-pick the TLS-expiry source from live-verified free candidates (e.g. an
>   external cron that runs `openssl s_client -connect <domain>:443 | openssl
>   x509 -checkend` and pings a fourth heartbeat on success), and
> - **Record the decision here** (replace this callout with what you chose and
>   the as-of date), so the runbook reflects reality.

## Step 3 — Backup heartbeat

Proves the daily verified backup ran ([backup-postgres.sh](../scripts/backup-postgres.sh)
pings only after a dump is verified and retention applied).

1. **Uptime → Heartbeats → Create heartbeat.** Name: `backup`.
2. Expected period: **1 day** (the cron runs daily at 03:00).
3. **Grace period: a few hours** (e.g. 2–3 h) — enough to cover a slow dump or
   a delayed cron start without false alarms.
4. Copy the heartbeat URL into the server's Compose `.env`:

   ```bash
   # on the server, in the Compose project dir
   echo 'BACKUP_PING_URL=<heartbeat-url>' >> .env
   ```

   The cron loads this `.env` (see [postgresql-operations.md](postgresql-operations.md#3-automated-backup-cron)).

## Step 4 — Cert-renewal heartbeat

Proves `certbot renew` ran successfully in the `certbot` service loop.

1. **Create heartbeat.** Name: `cert-renewal`.
2. Expected period: **1 day** (the loop's cadence is `sleep 24h`).
3. **Grace period: generous — at least a full day, 24–36 h.** Why so wide:
   - The loop sleeps 24 h between passes and Let's Encrypt only renews within
     30 days of expiry, so **most passes are no-ops** — `certbot renew` succeeds
     without issuing anything and still pings. A tight grace would false-alarm
     on a single skipped or slow pass.
   - The renew is the only gated signal here; a failed *reload* is caught by the
     Step 2 TLS-expiry monitor, not this heartbeat.
4. Copy the URL into the server's Compose `.env`:

   ```bash
   echo 'CERT_PING_URL=<heartbeat-url>' >> .env
   docker compose -f docker-compose.prod.yml up -d certbot   # recreate to pick up the env var
   ```

   The `certbot` service pings this **only after a successful renew**; unset, it
   skips the ping and the loop runs unchanged. See the service definition in
   [docker-compose.prod.yml](../templates/docker-compose.prod.yml).

## Step 5 — Health-ping heartbeat

Proves the host is patched and not pending a reboot (the `report-health` cron,
installed by provisioning, pings only when healthy — no `reboot-required`, no
unattended-upgrades error). See the `report-health` step in
[provision-server.md](provision-server.md).

1. **Create heartbeat.** Name: `health`.
2. Expected period: **1 day** (the cron runs daily).
3. **Grace period: a few hours** (e.g. 2–3 h).
4. Persist the URL where provisioning reads it (or pass `HEALTH_PING_URL` at
   provision time so this is written for you):

   ```bash
   echo 'HEALTH_PING_URL=<heartbeat-url>' | sudo tee -a /etc/default/report-health
   ```

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

Expected: all four monitors show **up** in the dashboard. To prove the alerting
path end-to-end, deliberately skip one backup or health ping and confirm the
alert fires after the grace period.

## Troubleshooting

```bash
# Heartbeat stuck "down" but the job succeeds → the URL isn't reaching the cron.
# Confirm the server's .env has the var and the service was recreated:
grep -E 'BACKUP_PING_URL|CERT_PING_URL' .env
docker compose -f docker-compose.prod.yml exec certbot printenv CERT_PING_URL

# Cert heartbeat never pings → the renew is failing (so the ping is withheld,
# as designed). Read the loop's output:
docker compose -f docker-compose.prod.yml logs certbot | tail -20

# Health heartbeat never pings → host is unhealthy or the URL isn't persisted:
cat /etc/default/report-health
sudo report-health   # runs the checks; prints why it withheld the ping
```

---

See also:
- [scripts/backup-postgres.sh](../scripts/backup-postgres.sh) — backup script that pings `BACKUP_PING_URL`
- [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml) — certbot service that pings `CERT_PING_URL`
- [guides/letsencrypt-docker.md](letsencrypt-docker.md) — renewal loop and the heartbeat-vs-TLS-expiry division of labor
- [guides/postgresql-operations.md](postgresql-operations.md) — backup cron that consumes `BACKUP_PING_URL`
- [guides/provision-server.md](provision-server.md) — provisioning that persists `HEALTH_PING_URL`
