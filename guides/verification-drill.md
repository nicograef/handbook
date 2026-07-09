# End-to-End Verification Drill

Prove the whole handbook path works on a **throwaway box**: provision → harden →
deploy with real TLS → monitor → back up → restore → patch → tear down. Every
step runs the owning guide's own **Verify** block against a live server, so a
drift between the docs and reality shows up here instead of in production.

This is a runbook you **execute against a real, disposable VPS** — not a
thought experiment. It is the acceptance test for the ops lifecycle: the drill
ends only when every linked Verify block has passed on the throwaway box.

> **Operator-performed, not automatable.** Every step that creates an external
> resource (Hetzner server, DNS record, Better Stack monitor, real Let's Encrypt
> cert) is done by a human with the relevant account — it cannot run in CI.

## Prerequisites

- **Hetzner Cloud account** with a project and an uploaded SSH key (the drill's
  reference provider; see [provision-server.md](provision-server.md)).
- **Control of a scratch DNS name** — a throwaway subdomain you can point at the
  box and delete afterwards (e.g. `drill.<your-domain>`).
- **Better Stack account** on the free plan (see [monitoring.md](monitoring.md)).
- An SSH key pair on your local machine.
- `docker` + `docker compose`, `curl`, and `ssh` locally.
- **Duration:** a few hours end-to-end (most of it waiting on cert issuance,
  cron windows, and heartbeat grace periods).
- **Cost:** a Hetzner **CX23** (2 shared vCPU, 4 GB RAM) is **EUR 0.0088/h**
  plus **EUR 0.0008/h** for the IPv4 address ≈ **EUR 0.01/h all-in** (verified
  2026-07-09 from Hetzner Cloud pricing) — **well under one euro** for the whole
  drill, provided you complete the [teardown](#step-10--teardown) so nothing
  keeps billing.

## Step 1 — Provision a CX23

Operator: create the server in Hetzner Cloud.

1. Fill [`templates/cloud-init.yml`](../templates/cloud-init.yml) — set
   `<ssh-public-key>`, `<username>`, `<user-password>`, and point
   `HEALTH_PING_URL` at the `health` heartbeat you create in
   [Step 6](#step-6--monitoring-and-dead-man-alerting) (leave it as a placeholder
   for now; you re-run this step's Verify once it is filled).
2. Create the server following the **primary cloud-init path** in
   [provision-server.md → Primary: cloud-init (Hetzner)](provision-server.md#primary-cloud-init-hetzner),
   choosing **CX23** as `--type`:

   ```bash
   hcloud server create \
     --name drill --type cx23 --image debian-12 \
     --ssh-key <key-name> \
     --user-data-from-file cloud-init.yml
   ```

3. Wait for cloud-init to finish (`ssh <username>@<host> "sudo cloud-init status --wait"` → `status: done`).

## Step 2 — Verify provisioning

Run the [provision-server.md → Verify](provision-server.md#verify) block against
the box. It **must** include, explicitly:

- **SSH in as the new user succeeds** (`ssh <username>@<host>`), and
- **root login is denied** (`ssh root@<host>` is refused).

Also confirm UFW is active and rate-limiting SSH, fail2ban is `active`, Docker
runs without sudo, unattended-upgrades lists a `-security` allowed origin, and
`/etc/cron.d/report-health` is installed.

## Step 3 — Point DNS at the box

Operator: create a DNS **A record** for the scratch name (e.g. `drill.<your-domain>`)
pointing at the server's public IPv4. Wait for it to resolve:

```bash
dig +short drill.<your-domain>   # → the server's IP
```

The Let's Encrypt HTTP-01 challenge in Step 4 fails until this resolves, so do
not proceed until `dig` returns the box's IP.

## Step 4 — Deploy the drill stack with real TLS

The drill exercises **the handbook's deploy path**, not any application, so it
substitutes **stock images for the two `build:` services** in
[`templates/docker-compose.prod.yml`](../templates/docker-compose.prod.yml) —
**`backend`** and **`frontend`**. Both are normally built from local Dockerfiles;
here, replace each `build:` block with a stock image that satisfies the reverse
proxy's upstreams (`backend:8080` and `frontend:80`):

- **`frontend`** → `nginx:1.30-alpine` (serves a page on port 80 — matches the
  proxy's `/*` upstream as-is).
- **`backend`** → an nginx configured to listen on **8080** (the proxy's `/api/*`
  upstream). Simplest stock stand-in: `nginx:1.30-alpine` with a one-line command
  that rewrites the default server's `listen` to `8080`, e.g.

  ```yaml
  backend:
    image: nginx:1.30-alpine
    command: >
      /bin/sh -c "sed -i 's/listen  *80;/listen 8080;/' /etc/nginx/conf.d/default.conf
      && exec nginx -g 'daemon off;'"
    networks: [app-network, db-network]
  ```

  (No `depends_on` app build; keep the `postgres`, `reverse-proxy`, and `certbot`
  services from the template unchanged — the drill still exercises the real DB,
  proxy, and renewal loop.)

Then deploy for **real TLS issuance** with [`scripts/prod-init.sh`](../scripts/prod-init.sh),
which requests a live Let's Encrypt cert and starts the full stack (stage the
nginx configs and `.env` first — see
[letsencrypt-docker.md](letsencrypt-docker.md)):

```bash
DOMAIN=drill.<your-domain> EMAIL=<you@example.com> ./scripts/prod-init.sh
```

> The reverse-proxy nginx config (`nginx-tls.conf`) routes `/api/*` → `backend:8080`
> and `/*` → `frontend:80`; the stock stand-ins above satisfy both upstreams, so
> `https://drill.<your-domain>` returns the frontend nginx welcome page and
> `https://drill.<your-domain>/api/` returns the backend one.

## Step 5 — Verify TLS

Run the [letsencrypt-docker.md → Verify](letsencrypt-docker.md#verify) block
against the box: confirm `live/drill.<your-domain>/` exists in the `letsencrypt`
volume and the staging `renew --dry-run` prints *"Congratulations, all simulated
renewals succeeded"*. This proves the challenge → issuance → renewal path works
end-to-end on a real cert.

## Step 6 — Monitoring and dead-man alerting

Operator: create the monitors in Better Stack, following
[monitoring.md](monitoring.md).

1. Create the **HTTPS uptime monitor** (with the SSL/TLS-expiry alert) on
   `https://drill.<your-domain>` — [monitoring.md → Step 2](monitoring.md#step-2--https-uptime-monitor-with-ssl-expiry-alert).
   Confirm here whether the free-plan SSL-expiry toggle is actually available on
   your account (the caveat that step calls out).
2. Create the **three heartbeats** — `backup`, `cert-renewal`, `health` —
   [monitoring.md → Steps 3–5](monitoring.md#step-3--backup-heartbeat). Wire
   `HEALTH_PING_URL` into cloud-init / `/etc/default/report-health` (re-run
   [Step 2](#step-2--verify-provisioning)'s health-ping check after) and
   `BACKUP_PING_URL` / `CERT_PING_URL` into the server's Compose `.env`.
3. Run the [monitoring.md → Verify](monitoring.md#verify) block: fire each
   heartbeat by hand and confirm all four monitors flip to **up**.
4. **Prove dead-man alerting fires.** Deliberately **miss one ping window** on
   the **`health`** heartbeat: stop pinging it (e.g. temporarily unset
   `HEALTH_PING_URL` in `/etc/default/report-health`, or just do not run the
   cron) and wait past its **expected period + grace** (1 day + the 2–3 h grace
   from [monitoring.md → Step 5](monitoring.md#step-5--health-ping-heartbeat)).
   Confirm Better Stack sends the alert. Restore the URL afterward so the
   heartbeat recovers to **up**.

## Step 7 — Backup, then its failure mode

1. **Run a real backup.** Execute [`scripts/backup-postgres.sh`](../scripts/backup-postgres.sh)
   on the box against the running `postgres` service:

   ```bash
   BACKUP_DIR=/opt/backups/postgres COMPOSE_DIR=/opt/<project> \
     BACKUP_PING_URL=<backup-heartbeat-url> ./scripts/backup-postgres.sh
   ```

   Expect: a verified `backup-*.dump` in `BACKUP_DIR`, old dumps pruned, and the
   `backup` heartbeat pinged (flips to **up**).
2. **Exercise the failure mode.** The script verifies each dump with
   `pg_restore --list` and pings **only after** verification succeeds. Simulate a
   corrupt archive by **truncating a copy of the dump** so verification fails,
   then confirm the script exits **non-zero** and sends **no ping**:

   ```bash
   # take a good dump, truncate a copy to corrupt it, then feed it back in
   cp /opt/backups/postgres/backup-*.dump /tmp/corrupt.dump
   truncate -s 1024 /tmp/corrupt.dump          # chop the archive mid-file
   docker compose exec -T postgres pg_restore --list < /tmp/corrupt.dump; echo "exit: $?"
   ```

   The `pg_restore --list` on the truncated copy must exit non-zero — this is the
   exact check inside the script that gates the ping. Confirm that a run which
   hits this path leaves **no new verified dump** and the `backup` heartbeat does
   **not** receive a ping (so a missed window would alert, as designed).

## Step 8 — Restore drill

Walk the [postgresql-operations.md → Restore drill](postgresql-operations.md#4-restore-drill)
checklist against the verified dump from Step 7: restore into a **throwaway
database**, spot-check row counts, record the outcome, and drop the throwaway
DB. (The drill stack has no app tables, so verify against a table you seed by
hand, or confirm the restore completes cleanly with the expected schema.)

## Step 9 — Verify patching and the withheld health ping

1. **Unattended-upgrades dry run** — already covered in the provision Verify
   block; re-run it if needed:

   ```bash
   sudo unattended-upgrade --dry-run --debug 2>&1 | grep -i 'allowed origins'
   ```

2. **Simulate a pending reboot** and confirm `report-health` **withholds** the
   ping (an unhealthy box must not report healthy):

   ```bash
   sudo touch /var/run/reboot-required
   sudo report-health; echo "exit: $?"       # → "UNHEALTHY: reboot required", exit 1, no ping
   sudo rm /var/run/reboot-required           # clear the simulation
   ```

   With the ping withheld, the `health` heartbeat misses its next window and
   Better Stack alerts **after the grace period** — the same mechanism the
   [reboot routine](maintenance.md#reboot-routine-monthly) relies on to page you
   when a kernel patch needs a reboot. Confirm the alert fires, then re-run
   `report-health` on the (now clean) box and confirm it pings and the heartbeat
   recovers.

## Step 10 — Teardown

Operator: remove **everything** so nothing lingers or keeps billing. Tick each:

- [ ] **Delete the server** — `hcloud server delete drill` (stops all Hetzner
      compute + IPv4 charges).
- [ ] **Release the IPv4** if it was created as a separate primary IP
      (`hcloud primary-ip list` → `delete`), so it does not bill on its own.
- [ ] **Delete the scratch DNS A record** (and any `www` record) for
      `drill.<your-domain>`.
- [ ] **Delete the drill monitors** in Better Stack — the uptime monitor and all
      three heartbeats — so they stop counting against the 10-slot pool and stop
      alerting on the now-dead box.
- [ ] **Remove local scratch files** — the filled `cloud-init.yml` (contains the
      user password) and any `.env` with real ping URLs.
- [ ] Confirm the Hetzner project shows **no running servers** and **no primary
      IPs** before you walk away.

## Verify

The drill has passed when **all** of the following hold on the throwaway box:

- Provision Verify block green (SSH as user works, root denied) — Step 2.
- TLS Verify block green (real cert issued, staging dry-run succeeds) — Step 5.
- All four Better Stack monitors **up**, and a deliberately missed `health` ping
  **alerted** — Step 6.
- A real backup pinged the `backup` heartbeat; a truncated dump exited non-zero
  and pinged **nothing** — Step 7.
- Restore drill replayed a dump into a throwaway DB — Step 8.
- A simulated `reboot-required` **withheld** the health ping and alerted after
  grace — Step 9.
- Teardown checklist fully ticked; Hetzner project empty — Step 10.

**Every defect found is fixed in the repo and the affected step re-run** — the
drill ends only when every linked Verify block has passed on the throwaway box.

## Troubleshooting

```bash
# cloud-init didn't finish → read its output log on the box
ssh <username>@<host> "sudo tail -n 40 /var/log/cloud-init-output.log"

# certbot fails in prod-init → DNS almost certainly isn't pointing here yet
dig +short drill.<your-domain>
curl -4 http://drill.<your-domain>/.well-known/acme-challenge/test

# a heartbeat won't flip to "up" → the ping URL isn't reaching the job
grep -E 'BACKUP_PING_URL|CERT_PING_URL' .env
cat /etc/default/report-health

# health ping withheld unexpectedly → run the checks and read the reason
sudo report-health
```

For deeper failure modes, see each owning guide's own Troubleshooting section
([provision-server.md](provision-server.md), [letsencrypt-docker.md](letsencrypt-docker.md),
[postgresql-operations.md](postgresql-operations.md), [monitoring.md](monitoring.md)).

## Execution record

Log each drill run here. **No drill has been executed yet** — the row below is a
pending placeholder; replace it (and add a row per run) once the drill is run
against a real throwaway box.

| Date       | Server type | Duration | Cost | Findings → fixes                    |
| ---------- | ----------- | -------- | ---- | ----------------------------------- |
| _pending_  | CX23        | _—_      | _—_  | _not yet executed — no drill has been run_ |

---

See also:
- [guides/provision-server.md](provision-server.md) — provision & harden (Steps 1–2)
- [guides/letsencrypt-docker.md](letsencrypt-docker.md) — real TLS issuance (Steps 4–5)
- [guides/monitoring.md](monitoring.md) — Better Stack monitors & heartbeats (Step 6)
- [guides/postgresql-operations.md](postgresql-operations.md) — backup & restore drill (Steps 7–8)
- [guides/maintenance.md](maintenance.md) — reboot routine the health ping drives (Step 9)
- [templates/cloud-init.yml](../templates/cloud-init.yml) — user-data for Step 1
- [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml) — stack deployed in Step 4
- [scripts/prod-init.sh](../scripts/prod-init.sh) — first-time deploy with cert issuance
