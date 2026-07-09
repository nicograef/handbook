# Plan: Ops Lifecycle — Day-2 Operations at Industry Standard

> Source PRD: [docs/prds/prd-ops-lifecycle.md](../prds/prd-ops-lifecycle.md)

## Goal

The handbook grows a complete, tested operations lifecycle at solo scale: backups
that verify themselves and alert when they stop, external uptime and TLS-expiry
monitoring, automatic security patching with loud failure signals, hands-off
cloud-init provisioning, and a standing maintenance runbook. Definition of done:
every operational runbook has been executed successfully end-to-end on a real
VPS (the throwaway-box drill), and the standing lifecycle fails loudly instead
of silently.

## Architectural decisions

Durable decisions that apply across all phases:

- **Sequencing and workflow**: this plan starts only after PRD 1
  (`docs/plans/plan-fix-and-prune.md`) has fully landed — its six-stage
  self-check, initial-cert templates, nginx reload loop, and provisioning flags
  (`PASSWORDLESS_SUDO`, `USER_PASSWORD`) are this plan's baseline. Phases =
  commits: one conventional commit per phase, `make check` green at every
  commit, one branch for the whole plan.
- **Monitoring service**: Better Stack (free plan) is the single external
  service — uptime monitors with built-in TLS-expiry alerts plus cron
  heartbeats, from one shared pool of 10, email + Slack alerts, 3-minute checks
  (verified 2026-07-09 from betterstack.com pricing and docs). Four slots are
  used: one HTTPS uptime monitor (with SSL-expiry alert), three heartbeats
  (backup, cert renewal, daily health ping). UptimeRobot's free tier was
  disqualified: SSL-expiry and heartbeat monitors are paid-only (verified
  2026-07-09 against uptimerobot.com pricing).
- **Ping URLs are configuration, never committed**: Compose-side URLs
  (`BACKUP_PING_URL`, `CERT_PING_URL`) live in the server's `.env`;
  `templates/.env.example` carries commented placeholders. The host-side URL
  (`HEALTH_PING_URL`) is persisted by provisioning in
  `/etc/default/report-health`.
- **New scripts**: `scripts/backup-postgres.sh` (promoted from the PostgreSQL
  guide's code block) and `scripts/report-health.sh` (daily patch-status
  dead-man ping). Both follow `.claude/rules/scripts.md` and are covered by the
  self-check's shellcheck stage automatically.
- **Dead-man semantics**: a cron pings its heartbeat only after full success;
  any failure withholds the ping, so the alert fires after the grace period.
  This is service-portable (no dependency on a `/fail` endpoint). The cert
  heartbeat gates on `certbot renew` success only — renewal and nginx reload
  are decoupled loops after PRD 1, so a failed reload is caught by the external
  TLS-expiry monitor, not the heartbeat.
- **Cloud-init delivery**: `templates/cloud-init.yml` (`#cloud-config`) fetches
  the canonical script from
  `https://raw.githubusercontent.com/nicograef/handbook/main/scripts/setup-server.sh`
  in `runcmd` and executes it with the config env vars — no duplicated script
  logic. `scripts/setup-server.sh` fetches `scripts/report-health.sh` from the
  same raw-URL base. Requires the repo to stay public. Hetzner is the reference
  provider (console "Cloud config" field / `hcloud --user-data-from-file`,
  verified 2026-07-09); netcup officially supports only SSH-key injection at
  image install, no user-data field (verified 2026-07-09) — manual SSH is the
  netcup path.
- **New guides**: `guides/monitoring.md`, `guides/maintenance.md`,
  `guides/verification-drill.md` — runbook shape per `.claude/rules/guides.md`
  (Prerequisites, numbered steps, Verify, Troubleshooting), indexed in the
  README Guides table. The restore drill is a section in
  `guides/postgresql-operations.md`, not a new guide.
- **Drill parameters**: Hetzner CX23 (2 shared vCPU, EUR 0.0088/h + EUR 0.0008/h
  IPv4 — about EUR 0.01/h, verified 2026-07-09), a scratch DNS name for real TLS
  issuance, drill stack = the repo's Compose templates with stock images
  substituted for the two build contexts (no app build) so the drill exercises
  the handbook's path, not an application. All steps that create external
  resources (server, DNS record, monitors) are operator-in-the-loop — the
  implementing agent never creates cloud resources or accounts on its own.

## Inventory

Post-PRD-1 baseline (items marked *PRD 1* land before this plan starts):

- `guides/postgresql-operations.md — section "3. Automated Backup (cron)"` — the inline script to promote; `Restore` and `Verify` sections are prior art for the restore drill (throwaway-database restore).
- `scripts/setup-server.sh — run(), write_file(), set_sshd()/hardening drop-in (PRD 1), numbered-step structure, /etc/os-release derivation` — dry-run helpers and distro detection the new unattended-upgrades step reuses; env-var interface the cloud-init template drives.
- `guides/provision-server.md — What it does, Usage, Verify, Configuration` — restructured to cloud-init-first in Phase 5; gains the patching step in Phase 4.
- `templates/docker-compose.prod.yml — certbot service` — renewal loop (post-PRD 1: no `--quiet`, reverse-proxy has the 12h reload loop); gains the renewal heartbeat ping.
- `templates/.env.example` — commented-optional-sections pattern; gains the Monitoring block.
- `scripts/check-repo.sh` + `Makefile — check target` — post-PRD-1 six stages (links, lint, readme, language, skills, compose) automatically cover every new script and Compose template.
- `scripts/prod-init.sh` — first-deploy automation the drill executes.
- `guides/letsencrypt-docker.md — Auto-Renewal, Verify` — documents the renewal loop; gains the heartbeat semantics.
- `templates/nginx-tls.conf — ssl_protocols, ssl_prefer_server_ciphers, security headers` — cipher-pinning target of the polish pass.
- `.claude/rules/guides.md`, `.claude/rules/scripts.md`, `.claude/rules/templates.md` — shape and naming conventions for everything new.
- `README.md — Guides, Templates, Scripts tables` — every new file gets indexed (self-check enforces it).
- `docs/plans/plan-fix-and-prune.md` — definition of the PRD 1 target state this plan builds on.

## Resolved decisions

- Better Stack (free) as the sole monitoring service; healthchecks.io not used — one account and dashboard beats best-of-breed-per-job at this scale. (User-confirmed.)
- Patch notifications via dead-man ping cron (`scripts/report-health.sh`), not msmtp/MTA — no SMTP credentials on servers, reuses the monitoring service, and a dead cron alerts by itself. (User-confirmed.)
- Cloud-init fetches `setup-server.sh` from the public repo's raw URL on `main` — always current, zero duplication; pinning to a tag/SHA was declined as an unneeded manual step. (User-confirmed.)
- 8 thin phases, drill last as the integration test; polish pass (Phase 7) runs before the drill so the drill validates final content. (User-confirmed.)
- Dump verification = `pg_restore --list` on the fresh dump (structural check, no database needed); the dump is written under a temporary name and renamed only after verification passes, so the backup directory never contains an unverified dump.
- Restore drill cadence: quarterly (PRD default); the drill section lives in `guides/postgresql-operations.md` where backups are configured, and `guides/maintenance.md` references it from the cadence table.
- The offsite-gap callout sits in the backup section of `guides/postgresql-operations.md`: accepted risk, restic (to object storage, e.g. a Hetzner Storage Box) named as the upgrade path.
- `unattended-upgrades` is security-only, no `Automatic-Reboot`; origins are derived per-distro from `/etc/os-release` the same way the Docker install step already does.
- `scripts/report-health.sh` is unhealthy when `/var/run/reboot-required` exists or the most recent `unattended-upgrades` run logged an error in `/var/log/unattended-upgrades/unattended-upgrades.log`; unhealthy or failing runs never ping.
- With `HEALTH_PING_URL` unset, `report-health.sh` still runs its checks and reflects health in its exit status, but attempts no ping; `setup-server.sh` installs the script and cron either way and prints a notice when the URL is missing.
- Guide cross-links follow phase order to keep the link check green: Phase 1 does not link to `guides/monitoring.md` (created in Phase 3); Phase 3 adds the backlinks.

## Open questions / Risks

- **Better Stack SSL-expiry on the free plan is docs-verified, not
  account-verified** (as of 2026-07-09: the feature is built into uptime
  monitors per official docs, but no free account was created to confirm the
  toggle is not paywalled). Phase 3 verifies it when creating the monitor; if
  gated, the TLS-expiry source is re-picked there from live-verified candidates
  and the decision recorded in `guides/monitoring.md`. Heartbeats and uptime
  are unaffected.
- **User-data is readable from the instance metadata endpoint**, including
  `USER_PASSWORD`. Phase 5 documents the mitigation: rotate the password at
  first login (`passwd`) or opt into `PASSWORDLESS_SUDO=true`.
- **PRD 1 is still landing** (partially in the working tree today). If its plan
  drifts from `docs/plans/plan-fix-and-prune.md` — especially the deploy-path
  templates and the six-stage self-check — revisit this plan's Inventory before
  starting.
- The raw-URL fetch couples provisioning to the repo staying public and to
  GitHub availability at first boot; the manual-SSH fallback covers both.
- Phase 8 needs operator participation (Hetzner account, DNS control, Better
  Stack account, a few euros of billing) — it cannot run unattended.

---

## Phase 1: Trustworthy backup script

**User stories**: 1

### Context

- `guides/postgresql-operations.md — section "3. Automated Backup (cron)"` — the inline script body to promote; keeps usage and cron wiring only.
- `.claude/rules/scripts.md` — header, style, `<verb>-<noun>.sh` naming, env-var-default configuration.
- `scripts/check-repo.sh — check_shell()` — picks up the new script automatically.
- `templates/.env.example` — gains the commented Monitoring block.
- `README.md — Scripts table` — new row.

### What to build

Promote the guide's code block into `scripts/backup-postgres.sh` with this
behavior contract: load the Compose `.env` (cron runs bare), dump the database
custom-format via `docker compose exec -T` to a temporary filename, verify the
fresh dump structurally with `pg_restore --list`, rename it to its final
timestamped name only after verification passes, apply `RETENTION_DAYS`
pruning, and only then ping `BACKUP_PING_URL` (skip with a logged notice when
unset). Any failure exits non-zero and sends no ping (`set -euo pipefail` plus
explicit checks). Configuration at the top as env-var defaults: `BACKUP_DIR`,
`RETENTION_DAYS`, `COMPOSE_DIR`, `BACKUP_PING_URL`. Rewrite the guide's
section 3 to link the script and keep only: how to install it on the server,
the cron line, and a configuration table. Add a commented `# ── Monitoring ──`
block with a `BACKUP_PING_URL` placeholder to `templates/.env.example` (no
link to the monitoring guide yet — it does not exist until Phase 3).

### Acceptance criteria

- [ ] `scripts/backup-postgres.sh` exists, is executable, passes shellcheck, and is indexed in the README Scripts table.
- [ ] A run against a local scratch Compose stack (postgres from the templates) produces a verified dump with the final naming scheme and applies retention.
- [ ] A deliberately truncated dump fails verification: non-zero exit, no file renamed into the backup directory, no ping attempted.
- [ ] With `BACKUP_PING_URL` unset the script completes and prints a notice that no ping was sent; with it set (stand-in local URL) exactly one ping fires after retention.
- [ ] `guides/postgresql-operations.md` section 3 contains no inline script body — link, install step, cron line, and config table only.
- [ ] `templates/.env.example` documents `BACKUP_PING_URL` as commented, never-committed configuration.
- [ ] `make check` passes.

---

## Phase 2: Restore drill and offsite accepted risk

**User stories**: 2, 3

### Context

- `guides/postgresql-operations.md — Restore, Verify sections` — prior art: restore into a throwaway database; the drill formalizes it.
- `guides/postgresql-operations.md — backup section (post-Phase 1)` — where the offsite callout lands.

### What to build

A new "Restore drill" section in `guides/postgresql-operations.md`: a numbered,
copy-paste checklist with a quarterly cadence — pick the newest dump from
`BACKUP_DIR`, restore it into a throwaway database, spot-check the result
(row counts of one or two known tables via `psql`), record date and outcome,
drop the throwaway database. Frame it as the same checklist to follow under
real data-loss stress, referencing the existing full-restore commands for the
disaster case. In the backup section, add an explicit accepted-risk callout:
backups currently live on the same disk they protect, so server loss means
backup loss; this is a deliberate, documented decision at current scale, and
restic to object storage (e.g. a Hetzner Storage Box) is the named upgrade
path when the risk stops being acceptable.

### Acceptance criteria

- [ ] The restore drill is a numbered checklist with explicit spot-check commands and expected outputs, and states the quarterly cadence.
- [ ] The checklist was walked once against a local scratch Compose stack to prove every command is copy-paste correct.
- [ ] The offsite callout sits where backups are configured, names the risk as accepted, and names restic as the upgrade path.
- [ ] `make check` passes.

---

## Phase 3: External monitoring

**User stories**: 4, plus the alerting half of 1

### Context

- `templates/docker-compose.prod.yml — certbot service` — the renewal loop that gains the heartbeat ping.
- `templates/.env.example — Monitoring block (Phase 1)` — gains `CERT_PING_URL`.
- `guides/letsencrypt-docker.md — Auto-Renewal` — documents the new heartbeat semantics.
- `guides/postgresql-operations.md — backup section` — gains the deferred backlink to the monitoring guide.
- `.claude/rules/guides.md — Runbook guides` — required shape for the new guide.
- `README.md — Guides table` — new row.

### What to build

`guides/monitoring.md`, a runbook that stands up the whole external monitoring
surface on Better Stack's free plan: create the account, one HTTPS uptime
monitor with the SSL-expiry alert enabled (this step is the verification point
for the free-plan caveat — if the toggle turns out paywalled, re-pick the
TLS-expiry source from live-verified candidates and record the decision here),
and three heartbeats — backup (daily + grace), cert renewal (24h cadence +
generous grace), health ping (daily + grace). Document the dead-man model
(success-only pings, missed window = alert) and that ping URLs are per-server
configuration that never enters git. Wire the cert-renewal heartbeat: the
`certbot` service command in `templates/docker-compose.prod.yml` pings
`CERT_PING_URL` only after a successful `certbot renew` pass, guarded so an
unset variable skips the ping and keeps the loop working; add the commented
`CERT_PING_URL` placeholder to `templates/.env.example`. Update
`guides/letsencrypt-docker.md` Auto-Renewal to describe the heartbeat and the
division of labor: the heartbeat proves renewal runs, the external TLS-expiry
monitor is the safety net for the decoupled nginx reload. Add the backlink
from the backup section of `guides/postgresql-operations.md` to the monitoring
guide for `BACKUP_PING_URL` setup.

### Acceptance criteria

- [ ] `guides/monitoring.md` exists in runbook shape (Prerequisites, numbered steps, Verify, Troubleshooting) and is indexed in the README Guides table.
- [ ] The guide covers the uptime + TLS-expiry monitor and all three heartbeats (backup, cert renewal, health ping), including grace-period guidance and the free-plan SSL verification step.
- [ ] The `certbot` service pings only after a successful renew pass; with `CERT_PING_URL` unset the loop still works; `docker compose -f templates/docker-compose.prod.yml --env-file templates/.env.example config -q` passes.
- [ ] `templates/.env.example` documents `CERT_PING_URL` alongside `BACKUP_PING_URL`.
- [ ] `guides/letsencrypt-docker.md` explains heartbeat vs. TLS-expiry-monitor roles; `guides/postgresql-operations.md` links to the monitoring guide.
- [ ] `make check` passes.

---

## Phase 4: Automatic security patching

**User stories**: 5

### Context

- `scripts/setup-server.sh — run(), write_file(), /etc/os-release derivation, numbered steps` — the new step reuses the dry-run helpers and distro detection.
- `guides/provision-server.md — What it does, Verify, Configuration` — documents the new step and variable.
- `.claude/rules/scripts.md` — conventions for the new script.
- `README.md — Scripts table` — new row.

### What to build

Two pieces. First, `scripts/report-health.sh`: reads `HEALTH_PING_URL` from
`/etc/default/report-health` (falling back to the environment); healthy means
`/var/run/reboot-required` does not exist and the most recent
`unattended-upgrades` run logged no error in
`/var/log/unattended-upgrades/unattended-upgrades.log`; healthy pings the URL
once, unhealthy logs the reason, sends nothing, and exits non-zero; an unset
URL runs the checks and reflects health in the exit status without pinging.
Second, a new numbered step in `scripts/setup-server.sh`: install
`unattended-upgrades`, write the apt periodic config enabling daily
update + unattended-upgrade, write a drop-in restricting `Allowed-Origins` to
the security origin for the detected distro (Debian and Ubuntu both supported,
derived from `/etc/os-release` like the Docker step), explicitly no
`Automatic-Reboot`; then fetch `scripts/report-health.sh` from
`https://raw.githubusercontent.com/nicograef/handbook/main/scripts/report-health.sh`
into `/usr/local/bin/report-health`, persist `HEALTH_PING_URL` (new optional
env var) in `/etc/default/report-health` when provided (notice when not), and
install a daily cron entry for it. Every new write respects dry-run mode.
Update `guides/provision-server.md`: What-it-does list, Configuration table
(`HEALTH_PING_URL`), and Verify block (unattended-upgrades dry run, apt timers
active, health-ping cron present).

### Acceptance criteria

- [ ] `scripts/report-health.sh` exists, passes shellcheck, is indexed in the README Scripts table.
- [ ] With `/var/run/reboot-required` present (simulated) it exits non-zero and sends no ping; on a healthy host it pings a stand-in URL exactly once; with no URL configured it still reports health via exit status.
- [ ] `scripts/setup-server.sh` installs and configures unattended-upgrades security-only for both Debian and Ubuntu origins, without auto-reboot, and installs the health-ping script and cron; `--dry-run` previews every new write without touching the system.
- [ ] `guides/provision-server.md` documents the new step, the `HEALTH_PING_URL` variable, and extends Verify with the patching checks.
- [ ] `make check` passes.

---

## Phase 5: Cloud-init provisioning

**User stories**: 6

### Context

- `scripts/setup-server.sh — env-var interface` — `SSH_PUBLIC_KEY`, `USERNAME`, `EXTRA_UFW_PORTS`, `PASSWORDLESS_SUDO`/`USER_PASSWORD` (PRD 1), `HEALTH_PING_URL` (Phase 4) — everything the template must pass through.
- `guides/provision-server.md — Usage` — restructured to cloud-init-first.
- `.claude/rules/templates.md` — functional-as-is requirement, `<angle-bracket>` placeholders.
- `README.md — Templates table` — new row.

### What to build

`templates/cloud-init.yml`: a `#cloud-config` user-data template whose `runcmd`
downloads `scripts/setup-server.sh` from
`https://raw.githubusercontent.com/nicograef/handbook/main/scripts/setup-server.sh`
and executes it with the configuration env vars filled in from
`<angle-bracket>` placeholders (`<ssh-public-key>`, `<username>`,
`<user-password>`, `<health-ping-url>`, extra UFW ports) — no script logic
duplicated into the template. Restructure `guides/provision-server.md` Usage
into two paths: the primary path — fill the template, create the Hetzner
server with it (console "Cloud config" field or
`hcloud server create --user-data-from-file`), wait for cloud-init to finish,
verify via `/var/log/cloud-init-output.log` and the existing Verify block; and
the fallback path — the current manual `ssh root@host ... bash -s` pipe, which
is also the documented netcup path (netcup supports only SSH-key injection at
image install, no user-data field, verified 2026-07-09). Add the security
note: user-data (including `USER_PASSWORD`) is readable from the instance
metadata endpoint — rotate the password at first login or use
`PASSWORDLESS_SUDO=true`.

### Acceptance criteria

- [ ] `templates/cloud-init.yml` exists, begins with `#cloud-config`, parses as valid YAML, uses `<angle-bracket>` placeholders, contains no duplicated setup-script logic, and is indexed in the README Templates table.
- [ ] The fetch URL points at the canonical script path on `main` and matches the raw-URL base used in Phase 4.
- [ ] `guides/provision-server.md` presents cloud-init as the primary path (Hetzner reference), manual SSH as the fallback, and states the netcup limitation with its as-of date.
- [ ] The user-data security note (metadata endpoint, password rotation) is present.
- [ ] `make check` passes. (Real-boot proof of the template is Phase 8's job.)

---

## Phase 6: Maintenance runbook

**User stories**: 7

### Context

- `guides/monitoring.md` (Phase 3) — alerts referenced by the reboot routine.
- `guides/postgresql-operations.md — Restore drill (Phase 2)` — linked from the cadence table.
- `guides/provision-server.md` (Phases 4–5) — patching behavior the runbook builds on.
- `.claude/rules/guides.md — Runbook guides` — required shape.
- `README.md — Guides table` — new row.

### What to build

`guides/maintenance.md`: the standing upkeep runbook, organized around one
cadence table — monthly: check `/var/run/reboot-required` (or wait for the
health-ping alert), reboot in a maintenance window, verify the stack came back
(`docker compose ps`, HTTPS reachable — expected outputs stated); at every
deploy: update image tags in the Compose file and pull/rebuild explicitly (no
auto-pull in production, per PRD), prune superseded images; monthly: disk and
service checks (`df -h` with a stated usage threshold, `docker system df`,
`systemctl --failed`, fail2ban and UFW status — each with expected output);
quarterly: run the restore drill (link to the section in
`guides/postgresql-operations.md`). Link to existing guides and cheatsheets for
command details instead of duplicating them (single-source rule).

### Acceptance criteria

- [ ] `guides/maintenance.md` exists in runbook shape with a cadence table covering the monthly reboot routine, deploy-time image updates, disk and service checks, and the quarterly restore drill link.
- [ ] Every check states its expected output; no command content is duplicated from other guides where a link suffices.
- [ ] Indexed in the README Guides table; `make check` passes.

---

## Phase 7: Currency polish pass

**User stories**: — (PRD Implementation Decisions: polish pass)

### Context

- `templates/nginx-tls.conf — ssl_protocols, ssl_prefer_server_ciphers` — the cipher-pinning decision target.
- Version pins across the repo (non-exhaustive; grep is the tool): `nginx:1.30-alpine`, `certbot/certbot:v5.6.0`, `postgres:17`, golang-migrate `v4.19.1` in `guides/postgresql-operations.md`.
- `AGENTS.md — Version consistency rule` — every changed version updated at every occurrence.

### What to build

Live-verify the remaining currency items against official sources (per the
research rule: official docs only, as-of dates recorded) and land the
decisions where they live. For `templates/nginx-tls.conf`: check the current
authoritative TLS guidance (Mozilla SSL Configuration Generator, intermediate
profile) and either adopt an explicit cipher configuration or document why the
current protocols-only stance is the recommendation — either way a one-line
comment in the template names the source and date. For version pins: grep the
repo for every pinned image/tool version, check each against its official
release source, bump stale ones at every occurrence, and re-validate the
Compose templates through the self-check's compose stage.

### Acceptance criteria

- [ ] `templates/nginx-tls.conf` TLS settings match a current authoritative recommendation, with source and as-of date in a comment.
- [ ] Every pinned image/tool version in the repo was checked this phase; every changed pin is updated at all occurrences (grep-verified, no mixed versions).
- [ ] `make check` passes.

---

## Phase 8: Verification drill

**User stories**: 8

### Context

- `guides/provision-server.md`, `guides/letsencrypt-docker.md`, `guides/postgresql-operations.md`, `guides/monitoring.md`, `guides/maintenance.md` — every Verify block is the drill's checklist.
- `templates/cloud-init.yml` (Phase 5), `scripts/prod-init.sh`, `scripts/backup-postgres.sh` (Phase 1), `scripts/report-health.sh` (Phase 4) — the artifacts under test.
- `.claude/rules/guides.md — Runbook guides` — shape for the drill runbook.
- `README.md — Guides table` — new row.

### What to build

`guides/verification-drill.md`: the repeatable end-to-end drill, then its first
real execution. Runbook contents — Prerequisites: Hetzner account, control of
a scratch DNS name, Better Stack account, expected duration (a few hours) and
cost (CX23 at about EUR 0.01/h all-in, so well under one euro). Steps: create a
CX23 with the filled `templates/cloud-init.yml`; verify provisioning
(provision guide Verify block, including SSH as the new user and root-login
denial); point the scratch DNS A record at the box; deploy the drill stack
(Compose templates with stock images in place of the two build contexts) via
`scripts/prod-init.sh` for real TLS issuance; verify TLS (letsencrypt guide
Verify block); create the monitors and heartbeats per `guides/monitoring.md`
and verify dead-man alerting by deliberately missing one ping window; run
`scripts/backup-postgres.sh`, then exercise its failure mode (truncate a dump,
expect non-zero exit and no ping); walk the restore drill checklist; verify
patching (unattended-upgrades dry run; simulate `/var/run/reboot-required` and
observe the withheld health ping); tear everything down (delete server, DNS
record, drill monitors); write the execution record (date, server type,
duration, cost, findings) into the runbook's Execution record section. Execute
the drill for real with the operator in the loop for every external-resource
step. Every defect found is fixed in this plan and the affected step re-run —
the drill ends only when every Verify block has passed on the throwaway box.

### Acceptance criteria

- [ ] `guides/verification-drill.md` exists in runbook shape, indexed in the README Guides table, with expected cost and duration stated.
- [ ] The drill was executed for real on a throwaway VPS provisioned via `templates/cloud-init.yml`; every runbook Verify block passed (after fixing and re-running any that failed).
- [ ] The three deliberate failure tests were observed: corrupted dump → non-zero exit and no ping; missed heartbeat window → alert received; simulated reboot-required → health ping withheld.
- [ ] The execution record (date, server type, duration, cost, findings and their fixes) is written into the runbook.
- [ ] Teardown is complete: server deleted, DNS record removed, drill monitors cleaned up.
- [ ] `make check` passes.
