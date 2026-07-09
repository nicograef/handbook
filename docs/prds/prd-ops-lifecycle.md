# PRD: Ops Lifecycle — Day-2 Operations at Industry Standard

Second of three PRDs for the handbook rework (PRD 1: fix & prune; this one:
ops lifecycle quality; PRD 3: plug-and-play distribution). Executes after
PRD 1 — the verification drill exercises its deploy-path fixes.

## Problem Statement

After PRD 1 the handbook's content is internally consistent and free of known
defects — but it still only covers day 1. Provision and deploy are documented;
everything after is not:

- **Backups die with the server, and nobody has ever restored one.** The
  nightly dump lands on the same disk it protects, has no retention policy, no
  verification, and the restore path exists only as untested commands.
- **All failure is silent.** No external uptime monitoring, no TLS-expiry
  watch, no alert when a cron stops running — the cert-renewal bug class from
  the review would have surfaced as users seeing an expired-certificate error.
- **Security patching stops the day provisioning ends.** Packages are upgraded
  once by the setup script; there is no standing update policy, no reboot
  routine, no notification when one is required.
- **Provisioning still requires manual root SSH** into a fresh box, although
  both providers can deliver the setup script automatically at boot.
- **No runbook has ever been executed end-to-end.** The review proved this is
  where breaking bugs hide: the two worst defects were both on paths that were
  written but never run.

## Solution

The handbook grows a complete, tested operations lifecycle at solo-appropriate
scale — nothing that needs babysitting, everything that fails loudly:

- **Backups become trustworthy:** a real, check-gated backup script that
  verifies each dump after writing it, applies retention, and reports success
  to a dead-man switch — so a backup that stops running or produces garbage
  raises an alert. A restore drill with a defined cadence makes recovery a
  rehearsed checklist. The offsite gap is documented as an explicit accepted
  risk with a named upgrade path (restic), where the backups are configured —
  not hidden.
- **Failures become visible:** external uptime and TLS-expiry monitoring plus
  dead-man-switch pings on the crons that matter (backup, cert renewal). No
  self-hosted monitoring stack.
- **Patching becomes automatic:** unattended security upgrades with
  failure/reboot notifications, configured at provision time, plus a standing
  maintenance runbook (reboot cadence, deploy-time image updates, disk and
  service checks).
- **Provisioning becomes hands-off:** a cloud-init user-data template runs the
  existing setup script on first boot; manual SSH remains as the documented
  fallback.
- **Everything gets proven once:** a throwaway-VPS drill — provision → deploy
  → backup → restore → teardown, checking every runbook's Verify blocks —
  executed for real during implementation. Findings are fixed in this PRD, and
  the drill itself is kept as a repeatable runbook.

**Definition of done:** every operational runbook in the repo has been executed
successfully end-to-end on a real VPS, and the standing lifecycle (backup,
monitoring, patching) fails loudly instead of silently.

## User Stories

1. As an operator, I want backups that verify their own dumps, apply
   retention, and alert when they stop running, so that data loss is bounded
   and silent backup failure is impossible.
2. As an operator, I want a documented, rehearsed restore path, so that
   recovery under stress is a checklist rather than research.
3. As the maintainer, I want the missing offsite backup documented as an
   explicit accepted risk with an upgrade path, so that future-me makes an
   informed decision instead of forgetting the gap exists.
4. As an operator, I want external uptime and TLS-expiry alerts, so that I
   learn about outages and expiring certificates before users do.
5. As an operator, I want security patches applied automatically with failure
   notifications and a defined reboot routine, so that the CVE window closes
   without my attention.
6. As an operator provisioning a new VPS, I want cloud-init to run the setup
   script on first boot, so that a new box comes up hardened with zero manual
   steps.
7. As an operator, I want a standing maintenance runbook, so that routine
   upkeep is a predictable procedure instead of ad-hoc memory.
8. As the maintainer, I want every runbook executed once end-to-end on a real
   VPS and the drill kept as a runbook, so that "works on paper" is upgraded to
   "worked in practice" — now and after future changes.

## Implementation Decisions

- **Sequencing:** PRD 2 executes after PRD 1 — the drill exercises PRD 1's
  deploy-path fixes (initial-cert templates, renewal reload).
- **Backup script:** promoted from a guide code block into the scripts
  collection, gated by shellcheck and the repo self-check. Behavior contract:
  dump → verify the fresh dump structurally → apply retention → ping the
  dead-man switch only after verification succeeds; non-zero exit on any
  failure. The guide keeps usage and cron wiring only — the code lives once.
- **Restore drill:** documented procedure with a quarterly default cadence;
  the offsite gap gets an explicit callout at the point where backups are
  configured — accepted risk, plus restic named as the upgrade path.
- **Monitoring:** external SaaS only — uptime + TLS-expiry checks and a
  dead-man-switch service for crons (candidates: UptimeRobot, healthchecks.io;
  final pick at plan time under the live-verification rule). Ping URLs are
  configuration, never committed. The cert-renewal loop also pings on
  successful renew-and-reload.
- **Updates:** unattended-upgrades, security-only, with failure and
  reboot-required notifications — installed and configured by the provisioning
  script and documented in the provision guide. Reboot cadence and deploy-time
  image updates live in the new maintenance runbook; no auto-pull of images in
  production.
- **Cloud-init:** a user-data template that invokes the canonical setup script
  rather than duplicating its logic (exact fetch/embed mechanism chosen at
  plan time); cloud-init becomes the primary documented provisioning path with
  manual SSH as fallback. Hetzner is the reference provider; netcup support is
  verified at plan time.
- **Verification drill:** executed once for real during implementation —
  cheapest-tier throwaway box, a scratch DNS name for genuine TLS issuance,
  every runbook's Verify blocks as the checklist, teardown at the end. Defects
  found are fixed within this PRD. The drill is kept as a runbook recording
  expected cost and duration.
- **New guides** (monitoring, maintenance, drill) follow the established
  runbook shape — Prerequisites, steps, Verify, Troubleshooting — and are
  indexed per the repo rules.
- **Polish pass:** remaining unverified currency items (cipher pinning, patch
  versions) checked against official docs per the research rule; decisions
  documented where they land.

## Testing Decisions

- The repo self-check stays green throughout; the stages added in PRD 1
  automatically cover the new script and templates.
- The backup script's failure modes are exercised deliberately once during the
  drill: a corrupted or truncated dump must produce a non-zero exit and no
  dead-man ping.
- Dead-man alerting is verified by intentionally missing one ping window and
  observing the alert.
- The throwaway-VPS drill is the integration test for the entire PRD; its
  execution record (date, box type, findings) is written into the drill
  runbook.
- No unit-test infrastructure — observable behavior only, consistent with the
  repo's testing philosophy.

## Out of Scope

- Offsite backup implementation and remote retention (documented accepted
  risk; future PRD candidate).
- Self-hosted monitoring stacks (netdata, Prometheus/Grafana) and app-level
  monitoring (APM, error tracking).
- Auto-updating container images (watchtower or pull-crons).
- A scripted or automated drill via the hcloud CLI — follow-up candidate once
  the manual drill has stabilized.
- Fleet tooling (Ansible, etc.) — explicitly rejected at this scale by the
  review.
- PRD 3 scope, with one boundary correction: cloud-init delivery lands here in
  PRD 2, so PRD 3's "one-line VPS bootstrap" target shrinks to whatever it
  adds beyond that (if anything).

## Further Notes

- The drill requires a scratch DNS name pointing at the throwaway box for real
  TLS issuance; total drill cost is cents (hourly billing).
- External service choices (uptime monitor, dead-man switch) are deferred to
  plan time and must be verified live (current free-tier terms) per the
  research rule.
- Scale guidance from the review stands: bash + runbooks + cloud-init is the
  right automation level below ~5–10 servers; revisit only if the fleet grows.
