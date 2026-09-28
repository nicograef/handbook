# Let's Encrypt with Docker Compose

Automated TLS certificates, running entirely inside Docker: Caddy, or nginx with a Certbot webroot challenge.

## Pick a variant

| Variant | Templates | Pick it when |
| ------- | --------- | ------------ |
| Caddy | [docker-compose.prod-caddy.yml](../templates/docker-compose.prod-caddy.yml), [Caddyfile](../templates/Caddyfile) | Default for a new stack: Caddy issues and renews the certificate itself, with no initial-cert step |
| nginx + Certbot | [docker-compose.prod.yml](../templates/docker-compose.prod.yml), [docker-compose.initial-cert.yml](../templates/docker-compose.initial-cert.yml), [nginx-tls.conf](../templates/nginx-tls.conf), [nginx-initial-cert.conf](../templates/nginx-initial-cert.conf) | You need per-client rate limiting (`limit_req`), or the team already runs nginx configs |

A project copies its variant's Compose template to `docker-compose.prod.yml`. Only this handbook names the Caddy file differently.

Caddy's core has no rate limiter. The Certbot variant pings `CERT_PING_URL` after each renewal; the Caddy variant has no such heartbeat.

## Prerequisites

1. DNS A record pointing to the VPS IP (+ `www` subdomain)
2. Any AAAA record for either name points to this server or is removed, since Let's Encrypt prefers IPv6

### Inputs

Collect these before starting:

| Placeholder | Description | Example |
| ----------- | ----------- | ------- |
| `<project-name>` | Compose project name — the top-level `name:` in every Compose file (replaces `myapp`) | `myapp` |
| `<domain>` | Public domain in `nginx-tls.conf` or the `Caddyfile` (replaces `example.com`) | `example.com` |

> Volume names are prefixed with the project name (e.g. `myapp_letsencrypt`).
> `docker-compose.initial-cert.yml` and `docker-compose.prod.yml` carry the **same** `name:`,
> so both share `certbot-challenges` and `letsencrypt`.

## Automation

[`scripts/prod-init.sh`](../scripts/prod-init.sh) runs the first deploy and every update for both variants.
It requests the Certbot certificate only when none exists.

## Verify

nginx + Certbot:

```bash
# cert was issued (expect a live/<domain>/ directory)
docker run --rm -v myapp_letsencrypt:/etc/letsencrypt alpine \
  ls /etc/letsencrypt/live/

# staging dry-run against the running stack — must print
# "Congratulations, all simulated renewals succeeded"
docker compose -f docker-compose.prod.yml exec certbot certbot renew --dry-run
```

Caddy:

```bash
# expect a "certificate obtained successfully" line per domain
docker compose -f docker-compose.prod.yml logs reverse-proxy | grep 'certificate obtained'

# expect HTTP/2 200
curl -sI https://example.com | head -1
```

## Troubleshooting

```bash
# check cert expiry
docker run --rm -v myapp_letsencrypt:/etc/letsencrypt alpine \
  cat /etc/letsencrypt/live/example.com/fullchain.pem | openssl x509 -noout -dates

# common failure: DNS not pointing to this server
curl http://example.com/.well-known/acme-challenge/test
```
