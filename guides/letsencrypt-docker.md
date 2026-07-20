# Let's Encrypt with Docker Compose

Automated TLS certificates via Certbot webroot challenge, running entirely inside Docker.

## Architecture

```
Browser → :443 → reverse-proxy (nginx: TLS termination)
                   ├─ /api/*  → backend:8080
                   └─ /*      → frontend:80

certbot container renews certs automatically (runs in a loop).
```

Three Compose files:

| File | Purpose |
| ---- | ------- |
| `docker-compose.yml` | Local dev (no TLS) |
| `docker-compose.initial-cert.yml` | First-time cert request only |
| `docker-compose.prod.yml` | Full production stack with HTTPS |

## Prerequisites

1. DNS A record pointing to the VPS IP (+ optional `www` subdomain)
2. Ports 80 and 443 open (`sudo ufw allow 80,443/tcp`)
3. Docker + Compose installed

### Inputs

Collect these before starting:

| Placeholder | Description | Example |
| ----------- | ----------- | ------- |
| `<domain>` | Primary domain served over HTTPS (replaces `example.com` in the steps) | `example.com` |
| `<www-domain>` | Optional `www` subdomain to add to the cert | `www.example.com` |
| `<email>` | Registration email for Let's Encrypt (replaces `you@example.com`) | `you@example.com` |
| `<project-name>` | Compose project name — the volume prefix set with `-p` (replaces `myapp`) | `myapp` |
| `CERT_PING_URL` | Optional cert-renewal heartbeat — see [Monitoring the renewal](#monitoring-the-renewal-heartbeat-vs-tls-expiry) | — |

## Step 1 — Initial Certificate

On first deploy there's no cert yet, so the full nginx config can't start.
Use a minimal nginx that only serves ACME challenges:

- [templates/docker-compose.initial-cert.yml](../templates/docker-compose.initial-cert.yml) — port 80 only, ACME webroot.
- [templates/nginx-initial-cert.conf](../templates/nginx-initial-cert.conf) — catch-all `default_server`; no domain edit needed.

Copy the config to the layout the Compose file expects, then request the cert:

```bash
# stage the minimal nginx config (mounted at ./reverse-proxy/nginx.initial-cert.conf)
mkdir -p reverse-proxy
cp templates/nginx-initial-cert.conf reverse-proxy/nginx.initial-cert.conf

# start minimal nginx (-p sets the project name → volume prefix)
docker compose -p myapp -f docker-compose.initial-cert.yml up -d

# request cert (replace domain + email)
docker run --rm \
  -v myapp_certbot-challenges:/var/www/certbot \
  -v myapp_letsencrypt:/etc/letsencrypt \
  certbot/certbot:v5.6.0 certonly \
    --webroot -w /var/www/certbot \
    -d example.com -d www.example.com \
    --email you@example.com \
    --agree-tos --non-interactive

# tear down minimal nginx
docker compose -p myapp -f docker-compose.initial-cert.yml down
```

> Volume names are prefixed with the Compose project name (e.g. `myapp_letsencrypt`).
> Check with `docker volume ls | grep letsencrypt`. Use the **same** `-p myapp` for the
> production stack so both share `certbot-challenges` and `letsencrypt`.

## Step 2 — Production Stack

Stage the TLS config, then start the full stack:

```bash
# stage the TLS nginx config (mounted at ./reverse-proxy/nginx.conf)
cp templates/nginx-tls.conf reverse-proxy/nginx.conf
# edit reverse-proxy/nginx.conf: replace example.com with your domain

# same -p myapp as Step 1 so the stack shares the cert volumes
docker compose -p myapp -f docker-compose.prod.yml up --build -d
```

See [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml) for the full Compose file.
See [templates/nginx-tls.conf](../templates/nginx-tls.conf) for the nginx TLS config.

## Auto-Renewal

Two **decoupled** loops in [`docker-compose.prod.yml`](../templates/docker-compose.prod.yml) keep certs fresh with no host cron and no Docker socket:

- **certbot** runs `certbot renew` every 24 h (no `--quiet`, so failures show up in `docker compose logs certbot`). Certbot only renews within 30 days of expiry.
- **reverse-proxy** runs `nginx -s reload` every 12 h, so a renewed cert is picked up within half a day without restarting the container.

### Monitoring the renewal (heartbeat vs. TLS-expiry)

The two loops are independent, so they need two independent signals:

- **Cert-renewal heartbeat** — after a successful `certbot renew`, the `certbot`
  service pings `CERT_PING_URL` (a Better Stack heartbeat). This is a dead-man's
  switch: a failed renew withholds the ping, so a missed window alerts. It gates
  on the **renew** only. Unset, the ping is skipped and the loop runs unchanged.
- **External TLS-expiry monitor** — an HTTPS uptime monitor with an SSL-expiry
  alert watches the live `:443` cert. Because renew and reload are decoupled, a
  renew can succeed while a stuck reload keeps serving the old cert; the
  heartbeat can't see that, but the external check on the endpoint can. It is the
  safety net for the reload half.

Set both up in [monitoring.md](monitoring.md); `CERT_PING_URL` is per-server
config in the Compose `.env`, never committed.

## Automation

For a fully automated first-time deploy, see [`scripts/prod-init.sh`](../scripts/prod-init.sh).

## Verify

Run this **manually after the first deploy** — a real renewal can't be exercised in CI, so
this staging dry-run is the check that the whole renewal path (challenge → issuance) works
end-to-end. `renew --dry-run` uses the Let's Encrypt staging environment, so it never touches
rate limits or your live cert.

```bash
# cert was issued (expect a live/<domain>/ directory)
docker run --rm -v myapp_letsencrypt:/etc/letsencrypt alpine \
  ls /etc/letsencrypt/live/

# staging dry-run against the running stack — must print
# "Congratulations, all simulated renewals succeeded"
docker run --rm \
  -v myapp_certbot-challenges:/var/www/certbot \
  -v myapp_letsencrypt:/etc/letsencrypt \
  certbot/certbot:v5.6.0 renew --dry-run
```

## Troubleshooting

```bash
# check if cert was issued
docker run --rm -v myapp_letsencrypt:/etc/letsencrypt alpine \
  ls /etc/letsencrypt/live/

# test renewal (dry run)
docker run --rm \
  -v myapp_certbot-challenges:/var/www/certbot \
  -v myapp_letsencrypt:/etc/letsencrypt \
  certbot/certbot:v5.6.0 renew --dry-run

# check cert expiry
docker run --rm -v myapp_letsencrypt:/etc/letsencrypt alpine \
  cat /etc/letsencrypt/live/example.com/fullchain.pem | openssl x509 -noout -dates

# common failure: DNS not pointing to this server
curl -4 http://example.com/.well-known/acme-challenge/test
```

---

See also:
- [guides/nginx-reverse-proxy.md](nginx-reverse-proxy.md) — nginx TLS config patterns
- [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml) — production Compose template
- [scripts/prod-init.sh](../scripts/prod-init.sh) — first-time deploy script
