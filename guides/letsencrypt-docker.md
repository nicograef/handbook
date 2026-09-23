# Let's Encrypt with Docker Compose

Automated TLS certificates via Certbot webroot challenge, running entirely inside Docker.

## Prerequisites

1. DNS A record pointing to the VPS IP (+ `www` subdomain)
2. Any AAAA record for either name points to this server or is removed, since Let's Encrypt prefers IPv6

### Inputs

Collect these before starting:

| Placeholder | Description | Example |
| ----------- | ----------- | ------- |
| `<project-name>` | Compose project name — the volume prefix set with `-p` (replaces `myapp`) | `myapp` |

> Volume names are prefixed with the Compose project name (e.g. `myapp_letsencrypt`).
> Check with `docker volume ls | grep letsencrypt`. Use the **same** `-p myapp` for the
> production stack so both share `certbot-challenges` and `letsencrypt`.

## Automation

For a fully automated first-time deploy, see [`scripts/prod-init.sh`](../scripts/prod-init.sh).

## Verify

```bash
# cert was issued (expect a live/<domain>/ directory)
docker run --rm -v myapp_letsencrypt:/etc/letsencrypt alpine \
  ls /etc/letsencrypt/live/

# staging dry-run against the running stack — must print
# "Congratulations, all simulated renewals succeeded"
docker compose -p myapp -f docker-compose.prod.yml exec certbot certbot renew --dry-run
```

## Troubleshooting

```bash
# check cert expiry
docker run --rm -v myapp_letsencrypt:/etc/letsencrypt alpine \
  cat /etc/letsencrypt/live/example.com/fullchain.pem | openssl x509 -noout -dates

# common failure: DNS not pointing to this server
curl http://example.com/.well-known/acme-challenge/test
```
