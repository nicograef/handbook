# PRD: Fix & Prune — Restore Repo Trust

First of three PRDs for the handbook rework (this one: review fixes + pruning;
PRD 2: ops lifecycle quality; PRD 3: plug-and-play distribution).

## Problem Statement

The handbook is meant to be a trustworthy single source — memory, runbooks, and
copy-paste templates for every VPS and repo, plus the agent configuration that
travels with them. A five-expert review (2026-07-09) showed it currently cannot
be trusted end-to-end:

- **The production deploy path silently breaks.** Certificates renew but the
  reverse proxy is never reloaded, so any deployment from the templates serves
  an expired certificate ~60–90 days in. The first-deploy script depends on two
  files that exist only as code blocks inside a guide, so a first production
  deploy fails on a fresh project.
- **Provisioning has security gaps.** SSH hardening edits the main config,
  which cloud-image drop-ins can silently override; keyboard-interactive auth
  is not disabled; passwordless sudo is the unconditional default.
- **The repo violates its own core rule.** The path-scoped conventions exist
  twice (Claude rules and Copilot instructions) and have already drifted — the
  exact failure mode the single-source-of-truth rule exists to prevent.
- **A third of the repo is dead weight.** ~10,000 lines of LLM-generated German
  theory, never read by the maintainer, mostly reproducing what coding models
  already know — plus concrete defects (broken SQL presented as a correct
  pattern, self-contradicting numbers). As agent context it dilutes rather than
  helps, contradicting the repo's own context-hygiene principles.
- **The index guarantee has holes.** A skill exists that no index lists, the
  skill-consumption matrix makes an incorrect claim about how Copilot loads
  personal skills, and the Guides section mislabels three convention docs as
  runbooks.

## Solution

One cleanup pass that restores trust: every review finding fixed in place, and
everything that does not earn its context deleted.

- The theory and research directories are removed after a critical harvest
  gate: jotti's own docs already cover the domain content (verified — tax law,
  compliance, and event sourcing are all documented there); the research file's
  durable guidance is folded into the agent-surface documents that reference
  it; stack conventions are merged into the existing guides only where clearly
  additive. Git history is the archive.
- The Claude rules directory becomes the only path-scoped conventions surface.
  Unique content from the Copilot instructions copies is merged in first, then
  the duplicate surface is deleted; Copilot continues to work through the
  canonical agent instructions file.
- The deploy path becomes real: renewal reloads the proxy, the initial-cert
  files ship as templates (derived from jotti's proven, in-production
  versions), and the first-deploy script validates its environment safely.
- Provisioning hardening moves to a drop-in config that cloud images cannot
  override, and insecure conveniences become opt-in.
- Indexes are corrected and then machine-guarded: the repo self-check gains a
  skills-index completeness stage and compose-template validation, so the bug
  classes fixed here cannot silently return.

**Definition of done:** a green repo self-check means the repo is internally
consistent, and a fresh VPS provision plus first production deploy can follow
the runbooks without hitting any known defect.

## User Stories

1. As the maintainer, I want every review finding fixed, so that the runbooks
   and templates I copy from are trustworthy without re-verification.
2. As an operator deploying to production, I want the first-time deploy to work
   from templates alone and renewals to reload the proxy, so that TLS never
   breaks silently weeks after a successful deploy.
3. As an operator provisioning a fresh VPS, I want SSH hardening applied via a
   drop-in config and insecure defaults made opt-in, so that a cloud image
   cannot silently weaken the box.
4. As a coding agent consuming this repo, I want generic unread theory gone, so
   that my context stays load-bearing and no defective example misleads me.
5. As the maintainer, I want exactly one path-scoped rules surface, so that
   convention edits cannot drift between tools.
6. As a Copilot user, I want the canonical agent instructions to remain intact
   after the instructions directory is dropped, so that Copilot keeps working.
7. As the maintainer, I want the self-check to guard the indexes (including
   skills) and the compose templates, so that docs and disk can never diverge
   unnoticed again.

## Implementation Decisions

- **Ordering:** prune first, fixes after — deletions are the cheapest to review
  and give the fixes a clean base. One branch; one conventional commit per
  module; the repo self-check stays green at every commit.
- **Harvest gate (strict):** content leaves the theory/research directories
  alive only if it is (a) not already covered in jotti's docs, (b) factually
  verified — no unread LLM claims migrate anywhere, and (c) clearly additive to
  an existing guide. Expected migration volume: near zero. Gaps discovered in
  jotti's coverage are reported as notes for that repo, not implemented from
  this plan. Git history is the archive — no archive directory.
- **Research file:** durable agentic-coding guidance folds into the agent-setup
  documentation that references it; the time-bound audit content dies with the
  file.
- **Language rule:** with the German theory gone, the canonical instructions'
  language exception narrows to the cleanup skill's German example phrases; the
  self-check's language whitelist updates to match.
- **Single rules surface:** the Claude rules directory is canonical for
  path-scoped conventions. Unique deltas from the Copilot instructions copies
  are merged in before that directory is deleted. The Copilot entry-point
  instructions file stays (it defers to the canonical instructions); the
  Copilot prompt files stay (not duplicated content). The Copilot agent-setup
  guide is trimmed to describe the single-surface reality.
- **Cert renewal:** the renewal container gains a deploy-hook that reloads the
  reverse proxy; renewal failures become visible in logs (no more quiet mode).
  The exact reload mechanism is chosen at plan time; the requirement is:
  renewed certificates are served without manual intervention.
- **Initial-cert flow:** the initial-cert compose file and its nginx config
  ship as real templates, derived from jotti's in-production versions and
  genericized to the template conventions (env names, volume names).
- **First-deploy script:** env validation by key-presence checks instead of
  shell-sourcing the env file.
- **Provisioning:** SSH hardening written to a drop-in config (including
  disabling keyboard-interactive auth) so cloud-image files cannot override it;
  restart targets the canonical ssh unit; passwordless sudo becomes opt-in with
  a secure default; the guide presents the trade-off. The Docker guide derives
  the apt repo from os-release instead of hardcoding Debian.
- **Agent surface:** the commit skill gets indexed everywhere the index rule
  requires; the consumption matrix is corrected to the verified loading paths
  and unverified rows are labeled as such; adapted skills get a one-line
  attribution to their MIT-licensed origin; the project Stop hook uses the
  project-dir variable instead of a relative path.
- **README:** the Guides section splits into two sub-tables — Runbooks and
  Stack conventions — with honest descriptions; sections for deleted
  directories are removed.
- **Small-fix batch:** postgres restore examples use in-container variable
  expansion (matching the backup examples), Referrer-Policy moves to the
  current recommendation, the ssh-agent alias reuses an existing agent, and the
  dev compose template gets a long-running command or an explanatory comment.
- **New checks:** two new stages in the existing repo self-check, same style as
  the current stages — skills-index completeness (every skill directory with a
  skill file must appear in the skills index) and compose validation (each
  compose template parses with the example env file).

## Testing Decisions

- The repo self-check is the test suite. A good check here verifies observable
  consistency — links resolve, index matches disk, shellcheck passes, compose
  parses — never prose style or content quality.
- Every module must leave the full self-check green. Deletion modules are
  additionally verified by searching for any remaining reference to the removed
  paths (the dead-link stage covers markdown links; a reference grep covers
  plain-text mentions).
- Each new check stage is proven by breaking it once intentionally (a
  temporarily unindexed skill directory; a temporarily invalid compose
  template), observing the failure, then reverting. Prior art: the four
  existing stages.
- Deploy-path changes get a documented manual verification step (a staging
  dry-run of certificate issuance), since a real renewal cycle cannot run in
  CI; the compose-parse check covers what is automatable.

## Out of Scope

- **PRD 2 (ops lifecycle):** backups/restore, monitoring, unattended upgrades,
  cloud-init delivery, end-to-end runbook execution on a real VPS.
- **PRD 3 (plug-and-play):** plugin marketplace manifest, one-line VPS
  bootstrap, root devcontainer, Claude-web consumption.
- Structural moves beyond relabeling — no new top-level directories;
  conventions stay in guides.
- Rewriting or consolidating skills — all nineteen keep their content; only
  indexing and attribution change.
- Writing documentation into the jotti repo.
- Changes to the dotfiles install/symlink model — it works as designed.

## Further Notes

- Findings originate from the five-expert review of 2026-07-09 (docs/IA,
  agent tooling, theory quality, sysadmin/DevOps, live standards research);
  this PRD encodes only verified findings.
- jotti's in-production initial-cert files are the derivation source for the
  new templates — prefer proven configs over freshly written ones.
- Guiding principle after this PRD: the repo holds zero content the maintainer
  has never read.
