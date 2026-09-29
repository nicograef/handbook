# Deploy

Take a provisioned server to a running app with TLS, update it, and roll it back.
TLS runs entirely inside Docker: Caddy, or nginx with a Certbot webroot challenge.

## Prerequisites

- The server passes [provision-server.md#verify](provision-server.md#verify), plus [ipv6-only-vps.md](ipv6-only-vps.md) on an IPv6-only box.
- DNS for `<domain>` and `www.<domain>` on a dual-stack server: an A record, and an AAAA record or none. Any AAAA record must point at this server too, since Let's Encrypt prefers IPv6.
- DNS on an IPv6-only server: an AAAA record only. IPv4-only clients cannot reach it.
- A release tag `v<X.Y.Z>` pushed with `make prod-release`, and its [release.yml](../templates/release.yml) run green.
- `docker-compose.prod.yml` in git pins the backend and frontend images to that `v<X.Y.Z>`, bumped as in [Update](#update).
- The project repo holds its variant's Compose and proxy files, as [new-project.md](new-project.md) copies them.
- Placeholders: `<username>` and `<host>` from provisioning, `<owner>/<project>` the GitHub repo, `<github-user>` your GitHub login.

## TLS variants

| Variant | Templates | Pick it when |
| ------- | --------- | ------------ |
| Caddy | [docker-compose.prod-caddy.yml](../templates/docker-compose.prod-caddy.yml) → `docker-compose.prod.yml`, [Caddyfile](../templates/Caddyfile) → `reverse-proxy/Caddyfile` | Default for a new project: Caddy issues and renews the certificate itself |
| nginx + Certbot | [docker-compose.prod.yml](../templates/docker-compose.prod.yml) → `docker-compose.prod.yml`, [docker-compose.initial-cert.yml](../templates/docker-compose.initial-cert.yml) → `docker-compose.initial-cert.yml`, [nginx-tls.conf](../templates/nginx-tls.conf) → `reverse-proxy/nginx.conf`, [nginx-initial-cert.conf](../templates/nginx-initial-cert.conf) → `reverse-proxy/nginx.initial-cert.conf` | You need per-client rate limiting (`limit_req`), or the team already runs nginx configs |

Each template is copied to the project path after its arrow. Both nginx Compose files carry the same top-level `name:`. Only the Certbot variant pings `CERT_PING_URL` per renewal.

## First deploy

Run every step on the server as `<username>`, logged in with `ssh <username>@<host>`. Command reference: [linux-services.md](../reference/linux-services.md).

1. **Create the project and backup directories**, owned by you. Expected: `ls -ld` on both shows `<username> <username>`.

   ```bash
   sudo install -d -o "$USER" -g "$USER" -m 0750 /opt/<project>
   sudo install -d -o "$USER" -g "$USER" -m 0700 /opt/backups/postgres
   ```

2. **Add a read-only deploy key**: paste the printed line under the repo's Settings → Deploy keys, **Allow write access** off. Expected: the key is listed as read-only ([GitHub deploy keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys)).

   ```bash
   ssh-keygen -t ed25519 -N '' -C '<project>-deploy@<host>' -f ~/.ssh/<project>-deploy
   cat ~/.ssh/<project>-deploy.pub
   ```

3. **Clone the repo** with that key; `git pull` keeps using it. Expected: ssh asks once to trust github.com; accept only [GitHub's published fingerprint](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints).

   ```bash
   git clone -c core.sshCommand="ssh -i $HOME/.ssh/<project>-deploy -o IdentitiesOnly=yes" \
     git@github.com:<owner>/<project>.git /opt/<project> && cd /opt/<project>
   ```

4. **Log in to the registry** with a classic personal access token scoped to `read:packages` only. GitHub Packages accepts no other token type ([Container registry docs](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry), checked 2026-09-29).
   Expected: `Login Succeeded`; Docker keeps the token in `~/.docker/config.json`.

   ```bash
   read -rs GHCR_TOKEN   # paste the token, press Enter
   printf '%s' "$GHCR_TOKEN" | docker login ghcr.io -u <github-user> --password-stdin; unset GHCR_TOKEN
   ```

5. **Create `.env`** readable by you only, then set every `<placeholder>`; the ping URLs follow in [monitoring.md](monitoring.md).
   Expected: `docker compose config --images` lists `ghcr.io/<owner>/<project>-backend:v<X.Y.Z>`, so plain `docker compose` targets production.

   ```bash
   cp .env.example .env && chmod 600 .env
   ```

   ```diff
   -# COMPOSE_FILE=docker-compose.prod.yml
   +COMPOSE_FILE=docker-compose.prod.yml
   ```

6. **Confirm the variant's proxy files** name your project and domain. Expected: each comment's result.
   Fix a mismatch in git on your machine, then `git pull` here; the server edits no tracked file.

   ```bash
   docker compose config | head -1                  # name: <project>
   docker compose -f docker-compose.initial-cert.yml config | head -1   # nginx: the same name: <project>
   grep -c '<domain>' reverse-proxy/*               # Caddyfile:3+, or nginx.conf:6+ beside nginx.initial-cert.conf:0
   ```

7. **Deploy the release.** The [prod-init.sh](../scripts/prod-init.sh) header lists every check and step it runs. Expected: the last lines read `Deployed v<X.Y.Z> — https://<domain>`, exit 0.

   ```bash
   DOMAIN=<domain> make prod-deploy
   ```

8. **Schedule the backup** per [backup-restore.md#daily-backup](backup-restore.md#daily-backup). Expected: `crontab -l` shows the backup line.

## Update

The server builds nothing and never pulls on a schedule; a deploy is the only moment images change.
`postgres` uses a major-series tag and `nginx` a minor-series tag; `certbot` and `caddy` are pinned exactly.

1. **Bump the app image tags** in `docker-compose.prod.yml` on your machine, then commit and push.
   Expected: `git log -1 --stat` names `docker-compose.prod.yml`.

   ```diff
   -    image: ghcr.io/<owner>/<project>-backend:v<X.Y.Z>
   +    image: ghcr.io/<owner>/<project>-backend:v<X.Y.Z+1>
   ```

2. **Pull, deploy and prune** on the server. Expected: `Deployed v<X.Y.Z+1> — https://<domain>`, then `Total reclaimed space`.
   `Downgrade refused` changes nothing; follow [Roll back](#roll-back).

   ```bash
   cd /opt/<project> && git pull --ff-only && DOMAIN=<domain> make prod-deploy && docker image prune -af
   ```

> `docker volume prune --all` and `docker compose down --volumes` delete the database; only a human decides that.

## Roll back

A failed update prints the pre-update dump and the tag to return to. The same steps undo a healthy update.

1. **Revert the tag bump** in git on your machine and push it. Expected: `git show --stat` names `docker-compose.prod.yml`.

   ```bash
   git revert <bump-commit> && git push
   ```

2. **Restore the pre-update dump** per [backup-restore.md#restore](backup-restore.md#restore), skipping the final `start backend`.
   Expected: `pg_restore` exits 0. The dump must come from the release you return to, or earlier.

3. **Pull and deploy with the override.** `ROLLBACK=1` asserts step 2 happened and lifts the downgrade guard once.
   Expected: a `ROLLBACK=1` warning block, then `Deployed v<X.Y.Z> — https://<domain>`, exit 0.

   ```bash
   cd /opt/<project> && git pull --ff-only && ROLLBACK=1 DOMAIN=<domain> make prod-deploy
   ```

## Verify

```bash
cd /opt/<project>                                        # each comment states the expected result
docker compose ps --format '{{.Service}}: {{.Status}}'   # every service Up, each healthcheck (healthy)
curl -sI https://<domain> | head -1                      # HTTP/2 200
curl -sI http://<domain> | head -1                       # 301 or 308, redirect to HTTPS
cat .deploy-state                                        # deployed=v<X.Y.Z> and an empty attempted=
echo | openssl s_client -connect <domain>:443 -servername <domain> 2>/dev/null | openssl x509 -noout -issuer -enddate   # issuer Let's Encrypt, notAfter ahead
docker compose exec certbot certbot renew --dry-run      # nginx: all simulated renewals succeeded
```

## Troubleshooting

```bash
docker compose pull            # "denied": the token expired or lacks read:packages; log in again
getent ahosts <domain>; ip -brief address                        # ACME fails: DNS must name this server
docker compose -f docker-compose.initial-cert.yml up -d reverse-proxy   # nginx, failed issuance: challenge server
curl -sI http://<domain>/.well-known/acme-challenge/test | head -1       # a 404 proves DNS and port 80 reach it
docker compose -f docker-compose.initial-cert.yml down
docker compose logs reverse-proxy | grep -i error                # Caddy: the ACME error names the challenge
```
