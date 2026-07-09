# Plan: Fix & Prune — Restore Repo Trust

> Source PRD: [docs/prds/prd-fix-and-prune.md](../prds/prd-fix-and-prune.md)

## Goal

One cleanup pass that restores trust: every finding of the 2026-07-09 five-expert
review fixed in place, everything that does not earn its context deleted, and the
repo self-check extended so the fixed bug classes cannot silently return.
Definition of done: a green `make check` means the repo is internally consistent,
and a fresh VPS provision plus first production deploy can follow the runbooks
without hitting any known defect.

## Architectural decisions

Durable decisions that apply across all phases:

- **Phases = commits**: one conventional commit per phase, prune-first ordering,
  full `make check` green at every commit. One branch for the whole plan.
- **Canonical rules surface**: `.claude/rules/*.md` with `paths:` frontmatter is
  the only path-scoped conventions surface. `.github/instructions/` is deleted;
  Copilot works through `AGENTS.md`.
- **New template files**: `templates/docker-compose.initial-cert.yml` and
  `templates/nginx-initial-cert.conf`, derived from jotti's in-production
  `docker-compose.initial-cert.yml` and `reverse-proxy/nginx.initial-cert.conf`.
- **Cert reload mechanism**: nginx-side periodic reload loop in the
  `reverse-proxy` service of `templates/docker-compose.prod.yml`
  (`while true; do sleep 12h; nginx -s reload; done & exec nginx -g 'daemon off;'`),
  jotti's proven pattern. The `certbot` service loop drops `--quiet`.
- **SSH hardening drop-in**: `scripts/setup-server.sh` writes
  `/etc/ssh/sshd_config.d/00-hardening.conf`. sshd uses first-obtained-value
  semantics and cloud images ship `50-cloud-init.conf`, so the `00-` prefix
  guarantees the hardening wins.
- **Provisioning script flags**: `PASSWORDLESS_SUDO` (default `false`) and
  `USER_PASSWORD` (required when `PASSWORDLESS_SUDO=false`, applied via
  `chpasswd`).
- **New self-check stages**: `skills` (skills-index completeness) and `compose`
  (compose templates parse against `templates/.env.example`), added to
  `scripts/check-repo.sh` and the `Makefile` in the style of the four existing
  stages.
- **Research fold target**: the durable, verified subset of
  `research/agentic-coding-insights.md` folds into
  `guides/copilot-agent-setup.md`; everything else dies with the file.

## Inventory

- `scripts/check-repo.sh — INDEX_DIRS, LANG_ALLOW, check_links(), check_shell(), check_readme(), check_language(), STAGE dispatch` — the self-check; prior art for new stages; indexes `theory` and `research` today.
- `Makefile — check/links/lint/readme/language targets` — dev interface to the self-check.
- `templates/docker-compose.prod.yml — reverse-proxy, certbot services` — renewal loop runs `--quiet`, nginx is never reloaded.
- `scripts/prod-init.sh — prerequisite checks` — `source .env` (shell-executes the env file); depends on `docker-compose.initial-cert.yml` + `reverse-proxy/nginx.initial-cert.conf`, which exist only as code blocks in the guide.
- `guides/letsencrypt-docker.md — Step 1, Auto-Renewal, Verify` — inlines the initial-cert compose file and nginx config as code blocks.
- `/home/nico/r/jotti/docker-compose.initial-cert.yml` and `/home/nico/r/jotti/reverse-proxy/nginx.initial-cert.conf` — in-production derivation sources (catch-all `default_server` ACME config).
- `scripts/setup-server.sh — set_sshd(), sudoers write, systemctl restart sshd, Docker install` — edits `/etc/ssh/sshd_config` in place, no `KbdInteractiveAuthentication`, unconditional NOPASSWD sudo, restarts the `sshd` alias unit; Docker section already derives the repo from os-release.
- `guides/provision-server.md — What it does, Manual Reference, Configuration` — documents the current (pre-hardening-fix) behavior.
- `guides/docker-setup.md — Install Docker on Debian / Ubuntu` — hardcodes `download.docker.com/linux/debian` in the GPG-key URL and the apt repo line.
- `.claude/rules/` (guides, cheatsheets, scripts, skills, templates, theory) vs `.github/instructions/` (same six) — duplicated surface with drift: scripts rules say "expected" where instructions say "mandatory"; `skills.instructions.md` has a `## Deployment` section missing from `.claude/rules/skills.md`; file-naming examples differ (`code-audit/` vs `cleanup/`).
- `.github/copilot-instructions.md` — points at `.github/instructions/`.
- `AGENTS.md — intro, Structure, Language` — names both rules surfaces; lists `theory/` and `research/`; language exception covers `theory/`.
- `.claude/skills/README.md — Skill Consumption Matrix, When to Use Which Skill, Adding a New Skill` — `commit` skill missing from the table; matrix claims about personal-skill loading need correction; links to `.github/instructions/skills.instructions.md`.
- `.claude/skills/commit/SKILL.md` — exists, indexed nowhere.
- `.claude/settings.json — Stop hook` — `scripts/check-repo.sh` as a relative path.
- `README.md — Guides, Theory, Research, Templates, Agent Setup sections` — Guides table mixes runbooks with the three stack-convention guides (`guides/go.md`, `guides/java-spring-boot.md`, `guides/react.md`); Theory/Research sections index the directories to be deleted.
- `guides/go.md`, `guides/react.md`, `guides/postgresql-operations.md` — "See also" links into `theory/`.
- `claude/CLAUDE.md — Projects list` — describes the handbook as "theory/ files in German"; stays in `LANG_ALLOW` (the maintainer's surname there contains an umlaut).
- `guides/postgresql-operations.md — Restore, Verify` — restore examples expand `$POSTGRES_USER`/`$POSTGRES_DB` in the host shell; the backup examples in the same file use single-quoted `sh -c` in-container expansion (the pattern to match).
- `templates/nginx-tls.conf — Security headers` — `Referrer-Policy no-referrer-when-downgrade`.
- `templates/.bash_aliases — sss` — `eval \`ssh-agent\` && ssh-add` spawns a new agent every time.
- `templates/docker-compose.yml — app service` — `node:24-slim` with no command; exits immediately under compose.
- `templates/.env.example` — sets `POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB`; the env file for compose validation.
- Five skills ported from the superpowers plugin (commit `597083b`): `systematic-debugging`, `receiving-feedback`, `using-git-worktrees`, `finish-branch`, `dispatching-parallel-agents` — no attribution today.

## Resolved decisions

- Cert reload: nginx-side 12h reload loop (jotti-proven), not a certbot deploy-hook — no docker socket in the certbot container. (User-confirmed.)
- Secure sudo default: `PASSWORDLESS_SUDO=false` requires `USER_PASSWORD` and sets it via `chpasswd`, so sudo password prompts work and the operator is never locked out (`adduser --disabled-password` leaves the account passwordless). `PASSWORDLESS_SUDO=true` restores today's NOPASSWD drop-in. (User-confirmed.)
- Research fold target: `guides/copilot-agent-setup.md` only; near-zero volume per the harvest gate. (User-confirmed.)
- Initial-cert templates use `nginx:1.30-alpine` (matching the existing templates, not jotti's 1.27) and the volume names `certbot-challenges` / `letsencrypt` (matching `templates/docker-compose.prod.yml`, so one compose project shares them).
- The initial-cert nginx config keeps jotti's catch-all form (`listen 80 default_server; server_name _;`) — no domain edit needed before first use.
- Missing `docker` during the compose check-stage is treated like missing `shellcheck` in `check_shell()`: log and fail (prior-art consistency).
- The three mislabeled convention docs are `guides/go.md`, `guides/java-spring-boot.md`, `guides/react.md`; `guides/copilot-agent-setup.md` stays in the runbook-style table.
- `claude/CLAUDE.md` stays in `LANG_ALLOW` after the language rule narrows — its umlaut is in the maintainer's surname, not German prose.
- The harvest gate's jotti-coverage check is already done and encoded in the PRD ("verified — tax law, compliance, and event sourcing are all documented there"); the prune phase does not re-verify it. Gaps discovered anyway are reported as notes for jotti, not implemented.

## Open questions / Risks

- The `compose` check-stage makes `docker` a dependency of `make check` (and thus the Stop hook), the same way `shellcheck` already is. Acceptable on the maintainer's machines; noted for environments without docker.
- Some minimal images lack the `Include /etc/ssh/sshd_config.d/*.conf` directive; the script must verify it exists in `/etc/ssh/sshd_config` and append it if missing, or the drop-in is silently ignored.
- `docker compose config` validates parsing and env interpolation only — it cannot prove the reload loop or a real renewal works. The documented staging dry-run covers that manually (a real renewal cycle cannot run in CI, per the PRD).

---

## Phase 1: Prune theory and research

**User stories**: 4 (generic unread theory gone), 1 (review findings fixed)

### Context

- `theory/` (11 German files) and `research/agentic-coding-insights.md` — the deletions.
- `guides/copilot-agent-setup.md` — fold target for the research file's durable guidance.
- `scripts/check-repo.sh — INDEX_DIRS, check_language()` — both directories are indexed; `check_language()` skips `theory/*`.
- `AGENTS.md — Structure, Language` — lists both directories; language exception names `theory/`.
- `README.md — Theory, Research sections` and the see-also links in `guides/go.md`, `guides/react.md`, `guides/postgresql-operations.md`.
- `claude/CLAUDE.md — Projects list` — "theory/ files in German".
- `.claude/rules/theory.md`, `.github/instructions/theory.instructions.md` — rules for a directory that no longer exists.

### What to build

Harvest first, then delete. Fold into `guides/copilot-agent-setup.md` only
research-file content that passes all three gate conditions (not covered in
jotti's docs, factually verified, clearly additive to the guide) — expected:
the verified Copilot loading facts that correct or extend the guide, e.g. the
personal-skill location split (`~/.claude/skills` for VS Code vs
`~/.agents/skills` for Copilot CLI) and the combined-loading fact (Copilot sends
AGENTS.md and copilot-instructions.md together, so duplicated content reaches
the model twice). Then delete `theory/` and `research/` entirely and remove
every reference: README sections, AGENTS.md structure lines and language
exception (narrowed to the German example phrases in
`.claude/skills/cleanup/readability-de.md`), the `theory/*` skip and both
directories in `scripts/check-repo.sh`, both theory rules files, the three
guides' see-also links, and the `claude/CLAUDE.md` project description. Git
history is the archive — no archive directory.

### Acceptance criteria

- [x] `theory/` and `research/` no longer exist; `git grep -n 'theory/'` and `git grep -n 'research/'` return no hits outside `docs/` (PRDs and this plan are historical documents).
- [x] `guides/copilot-agent-setup.md` gained only content passing the harvest gate; every migrated claim is one already marked verified in the research file.
- [x] `AGENTS.md` Language section reads: English everywhere, exception only for the German example phrases in `.claude/skills/cleanup/readability-de.md`.
- [x] `scripts/check-repo.sh` `INDEX_DIRS` is `(guides cheatsheets templates scripts)`; the `theory/*` case in `check_language()` is gone; `LANG_ALLOW` still contains `.claude/skills/cleanup/readability-de.md` and `claude/CLAUDE.md`.
- [x] `README.md` has no Theory or Research section.
- [x] `make check` passes.

---

## Phase 2: Single rules surface

**User stories**: 5 (one path-scoped rules surface), 6 (Copilot keeps working)

### Context

- `.claude/rules/*.md` (canonical) vs `.github/instructions/*.instructions.md` (to delete) — five remaining pairs after Phase 1: guides, cheatsheets, scripts, skills, templates.
- `.github/copilot-instructions.md` — currently points to `.github/instructions/`.
- `AGENTS.md — intro` — "Per-directory conventions live in `.claude/rules/*.md` (Claude) and `.github/instructions/*.instructions.md` (Copilot)".
- `.claude/skills/README.md — Adding a New Skill` — links to `.github/instructions/skills.instructions.md`.
- `guides/copilot-agent-setup.md — Overview, .github/instructions section` — presents the dual surface as the recommended setup.

### What to build

Diff each rules/instructions pair and merge unique instruction-side content into
the corresponding `.claude/rules/` file (known deltas: "mandatory" wording in
scripts, the `## Deployment` section and `cleanup/` naming example in skills;
sweep the other three pairs for anything similar). Then delete
`.github/instructions/` and repoint every reference: the Copilot entry file's
"Path-scoped conventions" pointer, the AGENTS.md intro sentence (Claude rules
are the only path-scoped surface; Copilot works through AGENTS.md), the skills
README's format-requirements link (now `.claude/rules/skills.md`), and the
README.md Agent Setup row for Copilot path-scoped rules. Trim
`guides/copilot-agent-setup.md` so it presents a single canonical home for
path-scoped conventions and names dual-surface duplication as the drift
anti-pattern this repo just fixed, instead of recommending it.

### Acceptance criteria

- [x] `.github/instructions/` no longer exists; no markdown link and no repo-specific reference points at it (generic descriptions of the Copilot mechanism in `guides/copilot-agent-setup.md` are allowed).
- [x] `.claude/rules/scripts.md` says `set -euo pipefail` is mandatory; `.claude/rules/skills.md` contains the Deployment section content and a consistent naming example.
- [x] `.github/copilot-instructions.md` still exists and defers to `AGENTS.md` without pointing at deleted paths.
- [x] `.claude/skills/README.md — Adding a New Skill` links to `.claude/rules/skills.md`.
- [x] `guides/copilot-agent-setup.md` no longer recommends maintaining two path-scoped surfaces.
- [x] `make check` passes.

---

## Phase 3: Deploy path becomes real

**User stories**: 2 (first deploy from templates alone, renewals reload the proxy), 1

### Context

- `/home/nico/r/jotti/docker-compose.initial-cert.yml`, `/home/nico/r/jotti/reverse-proxy/nginx.initial-cert.conf` — derivation sources.
- `templates/docker-compose.prod.yml — reverse-proxy, certbot services` — reload gap and `--quiet`.
- `guides/letsencrypt-docker.md — Step 1, Auto-Renewal, Verify` — inline code blocks to replace with template links; home of the documented staging dry-run.
- `scripts/prod-init.sh — prerequisite checks` — `source .env` to replace.
- `README.md — Templates table` — two new rows.

### What to build

The full first-deploy and renewal path from templates alone. Create
`templates/docker-compose.initial-cert.yml` (nginx:1.30-alpine, port 80 only,
mounts `./reverse-proxy/nginx.initial-cert.conf`, volumes `certbot-challenges`
and `letsencrypt`) and `templates/nginx-initial-cert.conf` (jotti's catch-all
ACME server block), both genericized to template conventions. In
`templates/docker-compose.prod.yml`, give `reverse-proxy` the 12h reload-loop
command and drop `--quiet` from the `certbot` loop so renewal failures reach
the logs. In `scripts/prod-init.sh`, replace `source .env` with key-presence
checks: for each of `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, verify
`.env` contains a non-empty `KEY=value` line via grep — the file is never
shell-executed. Rework `guides/letsencrypt-docker.md` Step 1 to link the two
new templates instead of inlining them, describe the reload loop in
Auto-Renewal, and add a documented manual verification step: a staging dry-run
of certificate issuance (`certbot renew --dry-run` against the running stack)
that an operator performs after first deploy, since a real renewal cannot run
in CI.

### Acceptance criteria

- [x] `templates/docker-compose.initial-cert.yml` and `templates/nginx-initial-cert.conf` exist, are indexed in the README Templates table, and every file `scripts/prod-init.sh` references ships as a template.
- [x] `docker compose -f templates/docker-compose.initial-cert.yml --env-file templates/.env.example config -q` and the same for `templates/docker-compose.prod.yml` succeed.
- [x] The `reverse-proxy` service runs nginx with the periodic reload loop; the `certbot` command contains no `--quiet`.
- [x] `scripts/prod-init.sh` contains no `source .env` and passes shellcheck; missing or empty keys still abort with the existing `error` helper.
- [x] `guides/letsencrypt-docker.md` links the templates instead of inlining them and documents the staging dry-run as a post-deploy verification step.
- [x] `make check` passes.

---

## Phase 4: Provisioning hardening

**User stories**: 3 (drop-in SSH hardening, insecure defaults opt-in), 1

### Context

- `scripts/setup-server.sh — set_sshd(), sudoers write, systemctl restart sshd` — the changes' home.
- `guides/provision-server.md — What it does, Configuration, Manual Reference` — documents the script's behavior and the manual equivalent.
- `guides/docker-setup.md — Install Docker on Debian / Ubuntu` — hardcoded `linux/debian` URLs.
- `scripts/setup-server.sh — REPO_URL` — the os-release derivation pattern the guide should match.

### What to build

SSH hardening that cloud images cannot override, and secure-by-default sudo. In
`scripts/setup-server.sh`: replace the `set_sshd()` main-config edits with
writing `/etc/ssh/sshd_config.d/00-hardening.conf` containing
`PubkeyAuthentication yes`, `PasswordAuthentication no`, `PermitRootLogin no`,
`KbdInteractiveAuthentication no`; pre-flight: ensure `/etc/ssh/sshd_config`
contains the `Include /etc/ssh/sshd_config.d/*.conf` directive and append it if
missing; restart the canonical `ssh` unit instead of `sshd`. Make passwordless
sudo opt-in: `PASSWORDLESS_SUDO=true` writes today's NOPASSWD drop-in; the
default requires `USER_PASSWORD` (abort with a clear error if unset) and sets
the user's password via `chpasswd` so sudo password prompts work. All new writes
respect dry-run mode. Update `guides/provision-server.md`: What-it-does list,
Configuration table (both new variables), Manual Reference showing the drop-in
file instead of `sshd_config` diffs, and a short trade-off note (NOPASSWD
convenience vs. password-prompted sudo; why the account needs a password when
opting out). In `guides/docker-setup.md`, derive the GPG-key URL and apt repo
line from `/etc/os-release` (`$ID`) as `scripts/setup-server.sh — REPO_URL`
already does.

### Acceptance criteria

- [x] `scripts/setup-server.sh` writes `/etc/ssh/sshd_config.d/00-hardening.conf` (including `KbdInteractiveAuthentication no`), guards the Include directive, no longer edits settings into `/etc/ssh/sshd_config`, and runs `systemctl restart ssh`.
- [x] Default run without `PASSWORDLESS_SUDO=true` and without `USER_PASSWORD` aborts before making changes; with `USER_PASSWORD` set it creates a password-capable sudo user without a NOPASSWD drop-in; `PASSWORDLESS_SUDO=true` reproduces today's behavior.
- [x] `--dry-run` previews every new write without touching the system; shellcheck passes.
- [x] `guides/provision-server.md` documents the drop-in, both new variables, and the sudo trade-off.
- [x] `guides/docker-setup.md` contains no hardcoded `download.docker.com/linux/debian`.
- [x] `make check` passes.

---

## Phase 5: Agent surface and indexes

**User stories**: 1, 5, 7 (index correctness — the machine guard follows in Phase 7)

### Context

- `.claude/skills/README.md — When to Use Which Skill, Skill Consumption Matrix` — missing `commit` row; matrix claims to correct.
- `.claude/skills/commit/SKILL.md` — the unindexed skill.
- Five ported skills' `SKILL.md` files: `systematic-debugging`, `receiving-feedback`, `using-git-worktrees`, `finish-branch`, `dispatching-parallel-agents`.
- `.claude/settings.json — Stop hook` — relative `scripts/check-repo.sh`.
- `README.md — Guides section` — the table to split.
- `scripts/install-dotfiles.sh — symlink map` — ground truth for which symlinks exist (`~/.claude/skills`, `~/.agents/skills`).

### What to build

Index and attribution corrections across the agent surface. Add the `commit`
skill to the When-to-Use table in `.claude/skills/README.md`. Correct the
Skill Consumption Matrix to the verified loading paths (VS Code Copilot reads
`~/.claude/skills`; Copilot CLI reads `~/.agents/skills` — GitHub's CLI docs do
not list `~/.claude/skills`) and keep explicit "not verified" labels on rows
that cannot be verified (server-side surfaces); the facts folded into
`guides/copilot-agent-setup.md` in Phase 1 are the in-repo source to stay
consistent with. Add a one-line attribution to each of the five ported skills'
`SKILL.md` (adapted from the MIT-licensed superpowers plugin; verify the
canonical repository URL and license from the plugin's GitHub page before
writing the line). Change the Stop hook command in `.claude/settings.json` to
`"$CLAUDE_PROJECT_DIR"/scripts/check-repo.sh`. Split the README Guides section
into two sub-tables — Runbooks (step-by-step procedures) and Stack conventions
(`guides/go.md`, `guides/java-spring-boot.md`, `guides/react.md`) — with honest
descriptions.

### Acceptance criteria

- [x] Every directory under `.claude/skills/` containing a `SKILL.md` has a row in `.claude/skills/README.md` (manual grep preview of the Phase 7 check), including `commit`.
- [x] Matrix rows state only verified loading paths; unverifiable rows carry an explicit "not verified" label; no claim contradicts `guides/copilot-agent-setup.md` or `scripts/install-dotfiles.sh`.
- [x] All five ported skills carry the one-line MIT attribution with a working origin URL.
- [x] `.claude/settings.json` uses `$CLAUDE_PROJECT_DIR` in the Stop hook and the hook still runs (verify by triggering a check).
- [x] README Guides section shows Runbooks and Stack conventions sub-tables; every guide file appears in exactly one of them.
- [x] `make check` passes.

---

## Phase 6: Small-fix batch

**User stories**: 1

### Context

- `guides/postgresql-operations.md — Restore, Verify` — host-shell variable expansion to convert; the Manual Backup section shows the target pattern.
- `templates/nginx-tls.conf — Security headers` — outdated Referrer-Policy.
- `templates/.bash_aliases — sss` — spawns a new ssh-agent every call.
- `templates/docker-compose.yml — app service` — exits immediately without a command.

### What to build

Four independent one-file fixes. Convert every restore and verify command in
`guides/postgresql-operations.md` that expands `$POSTGRES_USER` / `$POSTGRES_DB`
to the single-quoted `sh -c` in-container pattern the backup section already
uses (stdin redirection for the dump file stays on the host side of the
command). Change `Referrer-Policy` in `templates/nginx-tls.conf` to
`strict-origin-when-cross-origin` (the current recommendation and browser
default). Rewrite the `sss` alias in `templates/.bash_aliases` to reuse a
reachable agent — start `ssh-agent` only when `$SSH_AUTH_SOCK` is absent or the
agent does not respond, then `ssh-add`. Give the `app` service in
`templates/docker-compose.yml` a long-running command (`command: sleep infinity`
with a comment telling the user to replace it with their dev server command),
so the copied-as-is template does not exit immediately.

### Acceptance criteria

- [x] No restore/verify command in `guides/postgresql-operations.md` expands `$POSTGRES_USER` or `$POSTGRES_DB` in the host shell; all use single-quoted `sh -c`.
- [x] `templates/nginx-tls.conf` sends `Referrer-Policy strict-origin-when-cross-origin`.
- [x] Sourcing `templates/.bash_aliases` twice and running `sss` twice results in at most one ssh-agent process.
- [x] `docker compose -f templates/docker-compose.yml --env-file templates/.env.example config -q` succeeds and the `app` service has a long-running command.
- [x] `make check` passes.

---

## Phase 7: Self-check guards

**User stories**: 7 (docs and disk can never diverge unnoticed again)

### Context

- `scripts/check-repo.sh — check_readme(), check_shell(), STAGE dispatch` — prior art: bidirectional index diff, missing-tool handling, stage wiring.
- `Makefile — check target, help comments` — two new stage targets.
- `templates/.env.example` — the env file the compose stage validates against.
- `README.md — Scripts table` and the `check-repo.sh` header comment — both enumerate the stages and must list six.

### What to build

Two new stages in `scripts/check-repo.sh`, same silent-on-success/focused-error
style as the existing four. `check_skills()`: every directory under
`.claude/skills/` containing a `SKILL.md` must be linked in
`.claude/skills/README.md`, and every skill directory that README links must
exist on disk (bidirectional, like `check_readme()`). `check_compose()`: every
`templates/docker-compose*.yml` must pass
`docker compose -f <file> --env-file templates/.env.example config -q`; a
missing `docker` binary is logged as a failure exactly like missing
`shellcheck` in `check_shell()`. Wire both into the `all` stage and the STAGE
dispatch, add `skills` and `compose` Makefile targets, and update every place
that enumerates the stages (script header, Makefile comments, README Scripts
table row). Prove each stage once: temporarily remove a skill row from the
skills index — observe the failure — revert; temporarily corrupt a compose
template — observe the failure — revert.

### Acceptance criteria

- [x] `scripts/check-repo.sh skills` fails when a `SKILL.md` directory is missing from the skills index and when the index links a nonexistent skill directory; passes on the real repo.
- [x] `scripts/check-repo.sh compose` fails on an invalid compose template and passes on the real templates.
- [x] Both intentional-break tests were performed and reverted (failure output captured in the phase's verification notes).
- [x] `make check` runs all six stages; `make skills` and `make compose` run each individually; `make help` lists them.
- [x] Script header, Makefile, and README stage enumerations all list six stages.
- [x] `scripts/check-repo.sh` passes shellcheck; `make check` passes.
