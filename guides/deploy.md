# Deploy

Deploy a web app with TLS and a reverse proxy on a provisioned VPS, update it, and roll it back.
TLS runs entirely inside Docker: Caddy, or nginx with a Certbot webroot challenge.

## Prerequisites

- The server passes [provision-server.md#verify](provision-server.md#verify).
- DNS records for the domain and its `www` subdomain point at the VPS, per host type:
  - Dual-stack server: an A record to its IPv4. Any AAAA record points to its IPv6 or is removed, since Let's Encrypt prefers IPv6.
  - IPv6-only server: an AAAA record only. IPv4-only clients cannot reach it; see [ipv6-only-vps.md](ipv6-only-vps.md#limits-no-on-box-workaround).

Collect these before starting:

| Placeholder | Description | Example |
| ----------- | ----------- | ------- |
| `<project-name>` | Compose project name — the top-level `name:` in every Compose file (replaces `myapp`) | `myapp` |
| `<domain>` | Public domain in `nginx-tls.conf` or the `Caddyfile` (replaces `example.com`) | `example.com` |

> Volume names are prefixed with the project name (e.g. `myapp_letsencrypt`).
> `docker-compose.initial-cert.yml` and `docker-compose.prod.yml` carry the **same** `name:`,
> so both share `certbot-challenges` and `letsencrypt`.

## TLS variants

| Variant | Templates | Pick it when |
| ------- | --------- | ------------ |
| Caddy | [docker-compose.prod-caddy.yml](../templates/docker-compose.prod-caddy.yml), [Caddyfile](../templates/Caddyfile) | Default for a new stack: Caddy issues and renews the certificate itself, with no initial-cert step |
| nginx + Certbot | [docker-compose.prod.yml](../templates/docker-compose.prod.yml), [docker-compose.initial-cert.yml](../templates/docker-compose.initial-cert.yml), [nginx-tls.conf](../templates/nginx-tls.conf), [nginx-initial-cert.conf](../templates/nginx-initial-cert.conf) | You need per-client rate limiting (`limit_req`), or the team already runs nginx configs |

A project copies its variant's Compose template to `docker-compose.prod.yml`. Only this handbook names the Caddy file differently.

Caddy's core has no rate limiter. The Certbot variant pings `CERT_PING_URL` after each renewal; the Caddy variant has no such heartbeat.

## First deploy

1. **Deploy TLS + reverse proxy** (web app only).
   First deploy: [scripts/prod-init.sh](../scripts/prod-init.sh) with the production Compose template of the
   [chosen variant](#tls-variants), copied to `docker-compose.prod.yml`.
   It runs the first deploy and every update for both variants, and requests the Certbot certificate only when none exists.

## Update

- Every image in `docker-compose.prod.yml` carries an explicit tag, never `latest`; the deploy refuses anything else.
- The app images come from the registry under a `vX.Y.Z` tag that [release.yml](../templates/release.yml) built. The server builds nothing.
- `postgres` uses a major-series tag and `nginx` a minor-series tag. `certbot` and `caddy` are pinned exactly.
- Never pull on a schedule. A deploy is the only moment images change, so it also prunes the superseded ones.

### Before you update

- The release tag pushed with `make prod-release VERSION=X.Y.Z`, and its images built.
- The tag change committed to the repo, so the running stack matches source. Edit the Compose file in git, not on the box.
- `BACKUP_DIR` (default `/opt/backups/postgres`) owned by the deploy user, for the pre-update backup.
- `.deploy-state` in `.gitignore`. [`prod-init.sh`](../scripts/prod-init.sh) records the last healthy tag there.

### Steps

1. **Bump the tag explicitly** in the Compose file. Pin to a concrete version,
   not a moving tag:

   ```diff
   -    image: ghcr.io/<owner>/<project>-backend:v1.4.0
   +    image: ghcr.io/<owner>/<project>-backend:v1.5.0
   ```

2. **Run the guarded deploy.** [`prod-init.sh`](../scripts/prod-init.sh) runs the safe deploy flow:

   - It refuses a `build:`, an untagged or `latest` image, and a downgrade below the recorded tag.
   - Migrations are forward-only, so an older release fails on a newer schema. A failed attempt counts too.
   - It takes a verified backup with [`backup-postgres.sh`](../scripts/backup-postgres.sh) before any container changes.
   - It pulls the pinned images and starts the stack with `up --wait`, which polls every healthcheck.
   - It polls `https://<domain>`, then records the tag in `.deploy-state`. On a failure it prints the rollback path.

   ```bash
   DOMAIN=<domain> make prod-deploy
   ```

   Expected: the last lines read `Deployed v1.5.0 — https://<domain>`, exit 0.
   `Downgrade refused` changes nothing; to go back, follow [Roll back](#roll-back).

3. **Prune the superseded images:**

   ```bash
   docker image prune -f
   ```

   Expected: dangling images left untagged by the bump are removed; the summary
   ends with a `Total reclaimed space: <N>` line (`0B` if nothing was orphaned).

> To reclaim more aggressively, use `docker system prune -af`. Its `--volumes` flag
> prunes only **anonymous** volumes — `postgres-data`, being named, survives it.
> **`docker volume prune --all` or `docker compose down --volumes` remove it too.**
> After `down` drops the containers, that includes the database. Deleting a volume
> needs a human decision, never an agent's.

## Roll back

The failed deploy printed the pre-update dump and the tag to return to. The same steps undo a healthy deploy.

1. **Set the app image tags back** to the previous release in git, and pull that commit on the server:

   ```diff
   -    image: ghcr.io/<owner>/<project>-backend:v1.5.0
   +    image: ghcr.io/<owner>/<project>-backend:v1.4.0
   ```

2. **Restore the pre-update dump** with the [full-restore commands](backup-restore.md#restore).
   The dump must come from the release you return to, or earlier.
   Skip the final `start backend`: step 3 starts the older release.

3. **Deploy with the override.** `ROLLBACK=1` asserts that step 2 happened; the script lifts the downgrade guard for this run only:

   ```bash
   ROLLBACK=1 DOMAIN=<domain> make prod-deploy
   ```

   Expected: a `ROLLBACK=1` warning block, then `Deployed v1.4.0 — https://<domain>`, exit 0.

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
