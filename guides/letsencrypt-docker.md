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
2. Ports 80 and 443 open (`sudo ufw allow 80/tcp 443/tcp`)
3. Docker + Compose installed

## Step 1 — Initial Certificate

On first deploy there's no cert yet, so the full nginx config can't start.
Use a minimal nginx that only serves ACME challenges:

```yaml
# docker-compose.initial-cert.yml
services:
  reverse-proxy:
    image: nginx:1.27-alpine
    ports:
      - "80:80"
    volumes:
      - ./reverse-proxy/nginx.initial-cert.conf:/etc/nginx/conf.d/default.conf:ro
      - certbot-challenges:/var/www/certbot
      - letsencrypt:/etc/letsencrypt

volumes:
  certbot-challenges:
  letsencrypt:
```

Minimal nginx config (`reverse-proxy/nginx.initial-cert.conf`):

```nginx
server {
  listen 80;
  server_name example.com www.example.com;

  location /.well-known/acme-challenge/ {
    root /var/www/certbot;
  }
}
```

Request the certificate:

```bash
# start minimal nginx
docker compose -f docker-compose.initial-cert.yml up -d

# request cert (replace domain + email)
docker run --rm \
  -v myapp_certbot-challenges:/var/www/certbot \
  -v myapp_letsencrypt:/etc/letsencrypt \
  certbot/certbot:v2.11.0 certonly \
    --webroot -w /var/www/certbot \
    -d example.com -d www.example.com \
    --email you@example.com \
    --agree-tos --non-interactive

# tear down minimal nginx
docker compose -f docker-compose.initial-cert.yml down
```

> Volume names are prefixed with the Compose project name (e.g. `myapp_letsencrypt`).
> Check with `docker volume ls | grep letsencrypt`.

## Step 2 — Production Stack

Start the full stack with TLS:

```bash
docker compose -f docker-compose.prod.yml up --build -d
```

See [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml) for the full Compose file.
See [templates/nginx-tls.conf](../templates/nginx-tls.conf) for the nginx TLS config.

## Auto-Renewal

The `certbot` service in `docker-compose.prod.yml` runs a renewal loop:

```yaml
certbot:
  image: certbot/certbot:v2.11.0
  volumes:
    - certbot-challenges:/var/www/certbot
    - letsencrypt:/etc/letsencrypt
  entrypoint: /bin/sh
  command: -c "while true; do certbot renew --webroot -w /var/www/certbot --quiet; sleep 24h; done"
```

Certbot only renews when certs are within 30 days of expiry. Nginx picks up new certs on reload or container restart.

## Automation

For a fully automated first-time deploy, see [`scripts/prod-init.sh`](../scripts/prod-init.sh).

## Troubleshooting

```bash
# check if cert was issued
docker run --rm -v myapp_letsencrypt:/etc/letsencrypt alpine \
  ls /etc/letsencrypt/live/

# test renewal (dry run)
docker run --rm \
  -v myapp_certbot-challenges:/var/www/certbot \
  -v myapp_letsencrypt:/etc/letsencrypt \
  certbot/certbot:v2.11.0 renew --dry-run

# check cert expiry
docker run --rm -v myapp_letsencrypt:/etc/letsencrypt alpine \
  cat /etc/letsencrypt/live/example.com/fullchain.pem | openssl x509 -noout -dates

# common failure: DNS not pointing to this server
curl -4 http://example.com/.well-known/acme-challenge/test
```
