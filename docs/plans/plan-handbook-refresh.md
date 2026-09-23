# Plan: Handbook refresh from the 2026-09 best-practice review

> Source PRD: n/a. Findings were researched and verified on 2026-09-23. Ids such as `server-1` name findings in that review.

## Goal

Every confirmed or corrected finding lands, and so does every consider item the owner accepted. Refuted and skipped items stay out.

## Architectural decisions

- **Versions**: Postgres 18 with the volume at `/var/lib/postgresql`, Java 25 (Temurin), Node 26 and TypeScript 6.x.
- **More versions**: certbot `v5.8.0`, golangci-lint `v2.13.2`, golang-migrate `v4.20.1` and the uv image `0.12.18-python3.12-trixie-slim`.
- **Devcontainer base**: `mcr.microsoft.com/devcontainers/base:ubuntu24.04`.
- **Models**: only `claude-opus-5-5` and `claude-sonnet-5`, enforced through `availableModels`.
- **Git policy**: pushing `main` is allowed. The git guard blocks force-push, `+refspec`, `--mirror` and `--no-verify`, never a branch.
- **Certificates**: certbot stays; the nginx ACME module is revisited at 1.0.
- **Monitoring**: passive dead-man heartbeats stay; no `/fail` reporting.

## Inventory

- `scripts/setup-server.sh`: the fail2ban jail, UFW, the sshd include, unattended-upgrades, the Docker apt repo and the user password.
- `templates/docker-compose*.yml` and `scripts/backup-postgres.sh`: Postgres image, ports, shm and backups.
- `templates/nginx-*.conf`, `scripts/prod-init.sh` and `guides/letsencrypt-docker.md`: TLS and certbot.
- `templates/ci.yml` and the repo templates: CI pins and triggers.
- `scripts/install-dotfiles.sh`: symlinks, git config, gh and signing.
- `claude/settings.json`: allow list, hooks, status line and models.
- `.claude/skills/*` and `guides/unattended-agents.md`: orchestration docs.
- `templates/strip-visuals.lua`, `scripts/md-to-epub.sh` and `scripts/check-terms.sh`: the audiobook pipeline.

## Resolved decisions

- Done before this plan: Opus 5.5 effort under `modelSettings` (`claude-config-1`) and pushing `main` allowed.
- Refuted, no change: `workstation-11` (delta guard) and `claude-config-5` (`denial_reason` is already correct).
- Dropped sub-change: removing tmux `escape-time` (`workstation-6`).
- Accepted by the owner: fold the duplicated CLAUDE.md lines, enforce the two models, automate SSH signing and add a Node/TypeScript section.
- Accepted as verified: `claude-config-7`, `tls-nginx-11`, `server-11` (hash part), `server-6`, `repo-ci-8`, `repo-ci-13`, `stacks-10` and `audiobook-6`.
- Better Stack SSL-expiry checks are paid only, so the fixed openssl fallback stays as the documented path.
- Phase 9 runs last, after the owner's sudo steps.
- Audiobook alert callouts are unwrapped to plain prose with a stderr note, never deleted.
- Skipped:
  - `monitoring-1`: grace periods already bound detection.
  - `postgres-13`: the minimal-docs rule.
  - `agent-orchestration-2`: a Stop hook cannot be talked out of blocking.
  - `agent-orchestration-3`: an L-sized migration of a working tool.
  - `tls-nginx-4`: the ACME module is still 0.x.
  - `repo-ci-4`: needs a new `.golangci.yml` template; `stacks-3` covers pinning.
  - `stacks-7`: a new rule.
  - `workstation-5`: passthrough risk and an untested terminal.
  - `workstation-8`: there is no arm64 host.
  - `docker-10` and `repo-ci-10`.

## Open questions / Risks

- **Human**: in phase 6, install gh from its apt repo on this laptop, then `rm ~/.local/bin/gh`.
- **Human**: phase 9 needs sudo for bubblewrap, socat and the AppArmor profile.
- **Risk**: the git guard hook is a guardrail, not a security boundary. `/usr/bin/git` and `sh -c` bypass it; only the sandbox closes that gap. So it stays inline, with no script.
- **Risk**: Postgres 18 refuses the old mount path, so the image tag and the volume path change in one commit.

## Phase 1: Server provisioning, upkeep and monitoring

**Depends on**: none

### Context

- `scripts/setup-server.sh`: the fail2ban `[sshd]` jail, UFW rules, the sshd include line, unattended-upgrades, Docker apt setup, the user password and `/etc/default/report-health`.
- `guides/provision-server.md` and `templates/cloud-init.yml`: setup and its Verify steps.
- `guides/maintenance.md`: the reboot routine and the Postgres version example.
- `guides/ipv6-only-vps.md`: the NAT64 resolvers.
- `scripts/report-health.sh` and `guides/monitoring.md`: heartbeat and cert expiry.

### What to build

- **fail2ban (`server-1`)**: the jail gets `journalmatch = _SYSTEMD_UNIT=ssh.service + _COMM=sshd + _COMM=sshd-session`. The Verify step checks `sshd-session` in `fail2ban-client get sshd journalmatch`.
- **UFW (`server-2`)**:
  - A comment on the UFW step says only the reverse proxy publishes ports.
  - Verify runs `sudo ss -tlnp`. Only 22, 80 and 443 may be public.
- **sshd (`server-7`)**:
  - The include line goes first, via `sed -i "1i …"`, and keeps its idempotency guard.
  - `sshd -t` runs before the restart.
  - Verify expects `no` three times from `sshd -T`.
- **unattended-upgrades (`server-4`)**:
  - Delete the `51unattended-upgrades-security` drop-in, its case block and the `SECURITY_ORIGIN` echo.
  - Keep `20auto-upgrades`.
  - The guide says the stock origins apply.
- **apt and UFW (`server-9`, `server-10`)**: delete `ufw allow ssh`, keep `ufw limit ssh`, and use one `apt full-upgrade -y`.
- **Docker repo (`server-6`)**:
  - Use `docker.asc` with a deb822 `docker.sources`.
  - Remove the old list and key first.
  - Drop `gnupg`.
- **User password (`server-11`)**:
  - `USER_PASSWORD_HASH` is made with `mkpasswd -m yescrypt` and applied via `chpasswd -e`.
  - Update `cloud-init.yml` and the guide to match.
- **Maintenance (`server-3`, `server-5`)**:
  - The reboot routine starts with `sudo apt update && sudo apt full-upgrade`.
  - The reboot becomes unconditional; `reboot-required` is informational.
  - State that on Debian only kernels set that flag.
  - The Postgres example becomes 18 → 18.6.
- **IPv6-only (`server-8`)**: the resolver `2a00:1098:2c::1` becomes `2a01:4f8:c2c:123f::1`. The "Expected" line points to the printf instead of repeating addresses.
- **Heartbeat secrecy (`monitoring-5`, `monitoring-6`)**:
  - Neither script logs the heartbeat URL.
  - `setup-server.sh` runs `chmod 600 /etc/default/report-health`, and the guide shows `sudo chmod 600`.
  - Docs use `<heartbeat-url>`.
- **Cert monitoring (`monitoring-2`, `monitoring-4`)**:
  - Renewal wording: "one third of remaining lifetime, or earlier per ARI".
  - The expiry threshold is 7 days.
  - The callout is replaced with the resolved decision: SSL-expiry checks are paid only.
  - The openssl fallback becomes `openssl s_client … -servername … | openssl x509 -noout -checkend $((7*86400)) && curl -fsS -m 10 <ping-url>`.

### Acceptance criteria

- [ ] `shellcheck scripts/setup-server.sh scripts/report-health.sh` passes.
- [ ] `grep -n 'sshd-session' scripts/setup-server.sh guides/provision-server.md` hits both files.
- [ ] `grep -rn '51unattended-upgrades-security\|SECURITY_ORIGIN\|ufw allow ssh\|dist-upgrade\|2a00:1098:2c::1' scripts guides templates` returns nothing.
- [ ] Neither script echoes the heartbeat URL; `grep -n 'chmod 600 /etc/default/report-health' scripts/setup-server.sh` hits.
- [ ] `guides/monitoring.md` has no open "record the decision" callout, and its thresholds say 7 days.
- [ ] `make check` passes.

## Phase 2: Postgres and Compose

**Depends on**: none

### Context

- `templates/docker-compose.yml` and `templates/docker-compose.prod.yml`: ports, images, volumes and the certbot pin.
- `templates/.env.example`: compose variables.
- `scripts/backup-postgres.sh`: verification, umask and `.env` reading.
- `guides/postgresql-operations.md` and `cheatsheets/postgresql.md`: restore, drill, migrate and indexes.

### What to build

- **Dev compose (`docker-1`, `docker-11`)**: ports bind `127.0.0.1:3000:3000` and `127.0.0.1:5432:5432`. The frontend image is `node:26-slim`.
- **Postgres 18 (`postgres-4`, `docker-7`)**:
  - Both compose files use `postgres:18` with the volume at `/var/lib/postgresql`.
  - The guide gets a "Major upgrade" section: dump, new image on a fresh volume, restore, ANALYZE.
- **Prod Postgres service (`postgres-5`, `postgres-6`)**: `shm_size: 128mb` and `stop_grace_period: 1m`.
- **certbot pin (`docker-8`)**: `certbot/certbot:v5.8.0`, in compose only.
- **Backup script (`postgres-1`, `postgres-2`, `postgres-12`)**:
  - Verify each dump with `pg_restore -f /dev/null < file`, and reword the comment, log line and header step.
  - Add `umask 077`.
  - Read only `BACKUP_PING_URL` from `.env`, without sourcing the file.
- **Compose targeting (`postgres-3`)**:
  - `.env.example` gets a commented, server-only `COMPOSE_FILE` and `COMPOSE_PROJECT_NAME` block.
  - The guide's Prerequisites say the server `.env` sets both.
  - Fix the script comment.
- **Guide (`postgres-2`, `postgres-7`, `postgres-8`)**:
  - The backup dir is created with `sudo install -d -m 0700`, and the restore drill runs as root.
  - The restore stops the backend first and starts it after.
  - The restore uses `--single-transaction`; the drill uses `--exit-on-error`.
  - `vacuumdb --analyze-in-stages` follows the restore.
  - The `pg_terminate_backend` block goes.
- **migrate pin (`postgres-9`)**: the guide pins golang-migrate `v4.20.1`. The install is `| sudo tar -xz -C /usr/local/bin migrate`, and the wrapper image is `migrate/migrate:v4.20.1`.
- **Wording (`postgres-10`, `postgres-11`)**:
  - The cheatsheet's `CREATE INDEX CONCURRENTLY` comment follows the verified wording.
  - Offsite storage reads "Storage Box over SFTP, or Object Storage over S3".

### Acceptance criteria

- [ ] `docker compose -f templates/docker-compose.yml config -q` and the prod file both pass.
- [ ] `grep -rn 'postgres:17\|/var/lib/postgresql/data\|certbot:v5\.[0-7]\|pg_restore --list' templates scripts guides` returns nothing.
- [ ] `shellcheck scripts/backup-postgres.sh` passes, and the script has no `source`/`.` of `.env`.
- [ ] Optional: a local truncated dump makes the check fail.
- [ ] `make check` passes.

## Phase 3: TLS, nginx and certbot bootstrap

**Depends on**: none

### Context

- `templates/nginx-spa.conf` and `templates/nginx-tls.conf`: SPA serving, headers and TLS.
- `scripts/prod-init.sh`: first certificate issuance and the email prompt.
- `guides/letsencrypt-docker.md`: prerequisites and the renewal dry run.

### What to build

- **SPA (`tls-nginx-1`, `tls-nginx-2`)**:
  - `root` moves to server level.
  - `location /assets/` gets `Cache-Control "public, max-age=31536000, immutable"` and `try_files $uri =404`, with no `expires`.
  - `location = /index.html` gets `Cache-Control "no-cache"`.
  - The header comment says to paste the lines into the `server` block.
- **TLS config (`tls-nginx-3`, `-5`, `-6`, `-7`, `-11`, `-12`)**:
  - HSTS becomes `max-age=63072000; includeSubDomains`, without `preload`.
  - The header links `configurator.tlsref.org`.
  - The shared `ssl_*` lines move to the top level.
  - Delete `ssl_session_tickets off` and `proxy_cache_bypass`.
  - Add `server_tokens off`, and set `X-Forwarded-For $remote_addr`.
- **prod-init (`docker-9`, `tls-nginx-8`, `tls-nginx-9`)**:
  - EMAIL is optional, passed via `EMAIL_ARGS` and logged as `${EMAIL:-none}`.
  - Issuance runs `$COMPOSE_PROD run --rm --no-deps --entrypoint certbot certbot certonly --webroot -w /var/www/certbot …`.
- **Guide (`tls-nginx-8`, `tls-nginx-10`)**:
  - The dry run is `docker compose -p myapp -f docker-compose.prod.yml exec certbot certbot renew --dry-run`.
  - Prerequisites say any AAAA record must point to this server or be removed.

### Acceptance criteria

- [ ] `nginx -t` passes for both confs in an `nginx:stable` container.
- [ ] Optional: a local SPA container serves `/assets/x.js` with the immutable header and `/` with `no-cache`.
- [ ] `grep -rn 'preload\|ssl-config.mozilla\|ssl_session_tickets\|proxy_cache_bypass' templates` returns nothing.
- [ ] `shellcheck scripts/prod-init.sh` passes, and the script runs to issuance with EMAIL unset.
- [ ] `make check` passes.

## Phase 4: Docker build guide and stack conventions

**Depends on**: none

### Context

- `guides/docker-multi-stage-builds.md`: Java, Python and Node build stages.
- `guides/stack-conventions.md`: Go, Java, React and Python rules; the Node/TypeScript section is new.
- `README.md`: the stack-conventions row.

### What to build

- **Build guide (`docker-2`, `docker-3`, `docker-4`, `docker-5`, `docker-6`)**:
  - The uv image is `ghcr.io/astral-sh/uv:0.12.18-python3.12-trixie-slim`.
  - uv and pnpm get cache mounts, with `--store-dir /pnpm/store`; Maven gets none.
  - Maven runs `dependency:go-offline`.
  - The Java runtime stage runs as `USER app`, uid 10001.
  - Java images are `eclipse-temurin:25-jdk-alpine` and `25-jre-alpine`.
- **Layouts (`stacks-1`, `stacks-6`)**:
  - Go: `cmd/<name>/main.go`, `internal/<domain>/{handler,service,store}.go` and `internal/config/`.
  - React: `features/<name>/`, shared `components/`, `lib/` and `test/`. Code leaves a feature folder only when a second feature uses it.
- **Java (`stacks-4`, `stacks-5`)**:
  - Java 25.
  - The test table uses `@WebMvcTest` with `MockMvcTester`, `@MockitoBean` for slices only, and plain JUnit.
  - A Repository row uses `@DataJpaTest` with Testcontainers `@ServiceConnection`. Re-check the Boot 4 `NON_TEST` default before writing.
- **Go tests (`stacks-2`)**: only integration files carry a build tag; unit tests are untagged. Cite `go.dev/gopls/settings` as the source.
- **Python (`stacks-8`, `stacks-9`, `repo-ci-9`, `stacks-10`)**:
  - Drop `target-version`, and use `[tool.pytest]` with `strict = true`.
  - CI uses `uv sync --locked`; the Dockerfile keeps `--frozen`.
  - The gate sentence changes to match, and one line notes that `uv audit` is a preview feature.
- **Node/TypeScript (`stacks-11`)**:
  - A new section covers Node 26, type stripping and `pnpm install --frozen-lockfile`.
  - It also covers typescript-eslint, Vitest and TypeScript pinned to 6.x.
  - The README row names Node/TypeScript.

### Acceptance criteria

- [ ] `grep -rn 'temurin:21\|uv:0\.9\|bookworm\|dependency:resolve\|-tags=unit\|target-version' guides` returns nothing.
- [ ] The Go and React trees agree with the rules stated under them.
- [ ] `make check` passes, including the prose caps and the README index.

## Phase 5: Repo and CI templates

**Depends on**: 4

### Context

- `templates/ci.yml`: triggers, checkouts, pins, Postgres service and migrate install.
- `templates/dependabot.yml`, `templates/Makefile`, `templates/devcontainer.json`, `templates/vscode-settings.json` and `templates/setup-dev-tools.sh`.
- `guides/new-project.md`: setup steps and the devcontainer table.

### What to build

- **CI (`repo-ci-5`, `repo-ci-7`, `repo-ci-8`, `repo-ci-9`, `repo-ci-12`)**:
  - pnpm setup drops `version:` and adds `package_json_file`.
  - Every checkout gets `persist-credentials: false`.
  - The `pull_request` trigger goes.
  - The Postgres service uses `postgres:18`.
  - `uv sync --locked` replaces the separate lockfile step.
- **CI pins (`repo-ci-6`, `stacks-2`, `stacks-3`, `stacks-10`)**:
  - The migrate tarball is checked against a hardcoded sha256 for `v4.20.1`.
  - `-tags=unit` goes.
  - goimports runs as `go tool goimports`, with no `@latest` install.
  - The uv version is pinned.
- **golangci-lint (`repo-ci-3`, `repo-ci-7`)**: `v2.13.2` in `ci.yml` and `setup-dev-tools.sh`, and `"go.lintTool": "golangci-lint-v2"`.
- **Templates (`repo-ci-1`, `repo-ci-11`, `repo-ci-14`, `repo-ci-15`, `repo-ci-16`)**:
  - The devcontainer is `base:ubuntu24.04` without the Python feature.
  - Dependabot's uv entry uses `directory: "/<backend-dir>"`.
  - Makefile placeholders become `@echo "TODO: …" >&2; exit 1`.
  - VS Code settings drop `[php]`, `[vue]`, renderWhitespace and minimap, and `[json]` uses Prettier.
- **Tools (`stacks-3`)**: `setup-dev-tools.sh` drops the `@latest` goimports install.
- **new-project.md (`repo-ci-13`, `repo-ci-15`, `stacks-11`)**:
  - Add a step with `gh api -X PUT /repos/{owner}/{repo}/actions/permissions -F enabled=true -F sha_pinning_required=true`.
  - The Python devcontainer cell reads "Docker-in-Docker".
  - Link the Node/TypeScript section.

### Acceptance criteria

- [ ] `actionlint templates/ci.yml` passes if actionlint is present; otherwise `yq` parses the file.
- [ ] `grep -rn 'golangci-lint.*v1\|v2\.[0-9]\.\|@latest\|postgres:17\|pull_request\|ubuntu26\|version: 12' templates` returns nothing, except in deliberate comments.
- [ ] `make check` passes.

## Phase 6: Workstation and dotfiles

**Depends on**: none

### Context

- `scripts/install-dotfiles.sh`: symlink sites, git config and the gh tarball.
- `templates/.bash_aliases`: fzf loading and the `gfp` alias.
- `templates/init.lua`, `templates/.tmux.conf`, `guides/neovim.md` and `guides/bootstrap.md`.

### What to build

- **Symlinks (`workstation-1`)**:
  - A `link()` helper moves a real destination to `.bak`, runs `mkdir -p` on the parent and then `ln -sfnT`.
  - All symlink sites use it.
- **gh (`workstation-3`)**:
  - The tarball install goes.
  - A missing gh logs a link to cli/cli `install_linux.md`, and `bootstrap.md` gets the same link.
- **Git config (`workstation-10`, `workstation-12`)**:
  - Set `fetch.prune true` and `rebase.autoStash true`.
  - SSH signing (`gpg.format ssh`, `user.signingkey`, `commit.gpgsign`, `gpg.ssh.allowedSignersFile`) is set only when `~/.ssh/id_ed25519.pub` exists.
  - `bootstrap.md` links GitHub's signing-key doc.
- **Shell (`workstation-2`, `workstation-10`)**: fzf loads via `eval "$(fzf --bash)"`, and the `gfp` alias goes.
- **Neovim and tmux (`workstation-4`, `workstation-7`, `workstation-9`)**:
  - The OSC 52 comment says Ptyxis ignores it.
  - The plugin update loop is `for d in "$P"/*/; do git -C "$d" pull; done`.
  - `grepprg` is set to rg only when rg is executable, and `grepformat` goes.
  - The dev path in `bootstrap.md` links the provision-server apt line first.
- **Human**: install gh from apt on this laptop, then `rm ~/.local/bin/gh`.

### Acceptance criteria

- [ ] `shellcheck scripts/install-dotfiles.sh templates/.bash_aliases` passes.
- [ ] Run twice against a temp `HOME` with a real file and a real directory at link targets. Both end as symlinks with `.bak` copies, without nesting.
- [ ] Without `id_ed25519.pub` in that `HOME`, no signing keys are set.
- [ ] `make check` passes.

## Phase 7: Claude Code configuration and git guard

**Depends on**: none

### Context

- `claude/settings.json`: `permissions.allow`, the PreToolUse git hook, `statusLine`, `workflowSizeGuideline` and the models.
- `claude/statusline.sh`: the jq read of the status JSON.
- `claude/CLAUDE.md`: Working rules and Communication.

### What to build

- **Allow list (`claude-config-2`, `claude-config-6`, `stacks-3`)**:
  - Delete `gh api`, `find`, `sed -n`, the broad `docker compose exec`, `docker compose down`, `git branch`, `uv tool` and `uv add`.
  - Keep the two `-T db psql/pg_dump` entries.
  - Delete the built-in read-only entries and the narrower duplicates.
  - Replace `goimports:*` with the `go tool` form.
  - Keep the deny list.
- **Git guard (`claude-config-3`)**: widen the existing inline PreToolUse hook; add no script.
  - It matches `git … push` and `git … commit` past `-C` and `-c` options.
  - On push it blocks `--force*`, short clusters containing `f`, `+refspec`, `--mirror` and `--no-verify`.
  - On commit it blocks `-n` and `--no-verify`.
  - It never blocks by branch.
- **Status line (`claude-config-10`)**: one jq call also reads `effort.level` and the five-hour and seven-day rate limits. Set `refreshInterval: 30`.
- **Settings (`claude-config-7`, `claude-config-8`)**:
  - Delete `workflowSizeGuideline`.
  - Add `availableModels: ["claude-opus-5-5", "claude-sonnet-5"]` and `enforceAvailableModels: true`.
- **CLAUDE.md (`claude-config-11`)**:
  - Fold "minimal docs" into the prose-file rule and "comments ≤ 2 sentences" into the comment rule.
  - Reword the test line: "Add an integration test only where a unit test cannot cover the boundary, and keep it fast."

### Acceptance criteria

- [ ] Piping hook payloads into the hook command blocks `git -C . push --force`, `git push +main`, `git push --mirror` and `git commit -n`.
- [ ] The same check allows `git push -n` and `git push origin main`.
- [ ] `jq . claude/settings.json` parses, and the allow list holds none of the deleted entries.
- [ ] `echo '<sample status JSON>' | claude/statusline.sh` prints the effort and rate limits, and degrades cleanly when they are absent.
- [ ] `make check` passes.

## Phase 8: Agent orchestration skills and guide

**Depends on**: 7

### Context

- `.claude/skills/decide/SKILL.md` and `.claude/skills/plan/SKILL.md`: invocability and the decide route.
- `.claude/skills/implement-plan/SKILL.md`: the watchdog note and failure strings.
- `.claude/skills/prog/SKILL.md`, `.claude/skills/parallel-sessions/SKILL.md` and `.claude/rules/skills.md`: `allowed-tools`.
- `.claude/skills/programme/SKILL.md` and `scripts/check-repo.sh — check_skills()`: the description length.
- `.claude/skills/testing/SKILL.md` and `guides/unattended-agents.md`.

### What to build

- **decide route (`agent-orchestration-5`)**:
  - `decide` loses `disable-model-invocation`.
  - `plan` fixes "finings" and routes to "the decide skill".
- **Watchdog and limits (`agent-orchestration-4`, `agent-orchestration-6`)**:
  - The `CLAUDE_CODE_RETRY_WATCHDOG` text follows the verified wording.
  - Add a Sonnet-limit row.
  - The auto-continue row names its interactive, claude.ai-login and under-24-hour conditions.
- **allowed-tools (`agent-orchestration-7`)**:
  - `parallel-sessions` gets `Bash(git *) Bash(~/.claude/agent-bus.sh *), Read, Grep, Glob`.
  - `prog` gets `Bash(git *), Read, Grep, Glob`.
  - `rules/skills.md` notes that allowed-tools pre-approves for one turn and deny still wins.
- **Description length (`agent-orchestration-8`)**:
  - The programme description is ≤ 250 characters.
  - `check_skills()` enforces the cap, citing `.claude/rules/skills.md`.
- **testing (`agent-orchestration-9`)**: the integration-test line matches the CLAUDE.md wording.
- **Unattended guide (`agent-orchestration-1`, doc part)**:
  - Replace the "stays blocked even here" bullet.
  - The replacement says deny rules cover Claude's usual command form only and are no security boundary.

### Acceptance criteria

- [ ] `make check` passes, including the new description-length check against every skill.
- [ ] `grep -rn 'disable-model-invocation' .claude/skills/decide` and `grep -rn 'finings\|stays blocked even here' .` return nothing.

## Phase 9: Sandbox trial for unattended runs

**Depends on**: 7, 8

### Context

- `claude/settings.json`: the `sandbox` block.
- `guides/unattended-agents.md`: Step 4.

### What to build

- **Human**:
  - Install `bubblewrap` and `socat`.
  - If `kernel.apparmor_restrict_unprivileged_userns` is 1, add the bwrap AppArmor profile from code.claude.com/docs/en/sandboxing and reload AppArmor.
- **Settings**: `"sandbox": {"enabled": true, "excludedCommands": ["docker"], "credentials": {"files": [{"path": "~/.ssh", "mode": "deny"}]}}`. Check each key against the sandboxing doc first.
- **Trial**: check that `make check`, `pnpm` and `git push` of a scratch branch still work.
- **On success**: rewrite Step 4 around auto mode plus sandbox.
- **On failure**: delete the Step 4 posture and remove the sandbox block.
- `templates/devcontainer.json` stays untouched.

### Acceptance criteria

- [ ] The trial result is recorded in the commit message.
- [ ] Step 4 describes only a posture that was exercised.
- [ ] `make check` passes.

## Phase 10: Audiobook pipeline

**Depends on**: none

### Context

- `templates/strip-visuals.lua`: the handlers that delete elements.
- `scripts/md-to-epub.sh`: the awk lint, the STRICT gate and the word count.
- `scripts/check-terms.sh`: term matching.
- `.claude/skills/audiobook/writing.md` and `guides/audiobook-pipeline.md`.

### What to build

- **Filter log (`audiobook-2`)**:
  - Each deleting handler writes one `io.stderr:write` line: CodeBlock, Table, RawBlock, RawInline, Math, Note and bare URLs.
  - Alert Divs (note, tip, important, warning, caution) log one line and return `el.content`.
- **Lint (`audiobook-2`)**:
  - The awk lint goes.
  - pandoc runs once per chapter, and stderr lines are prefixed with the chapter name.
  - `STRICT=1` dies on any line, and stdout feeds the word count.
  - Findings are chapter-scoped, without line numbers.
- **Term check (`audiobook-3`)**: `grep -qiP -- "\b\Q${term}\E\b"`, and the header comment describes whole-word matching.
- **Writing guide (`audiobook-1`, `audiobook-4`)**:
  - The sentence rule becomes "Short full sentences, one idea each, few subordinate clauses; telegram fragments sound rushed."
  - Figures are rounded and related, and symbols are spoken as words.
- **Pipeline guide (`audiobook-5`, `audiobook-6`)**:
  - Install via `sudo apt install pandoc`, with a one-line troubleshooting note.
  - The pricing row reads "Free plan: 10 h audio/month; Ultra: unlimited (24 h/day fair-use cap)".

### Acceptance criteria

- [ ] `shellcheck scripts/md-to-epub.sh scripts/check-terms.sh` passes.
- [ ] A fixture chapter with a table, a code block and a `> [!WARNING]` alert gives three stderr lines.
- [ ] The warning text appears in the EPUB, and `STRICT=1` exits non-zero.
- [ ] `check-terms.sh` no longer matches "API" inside "Kapitel".
- [ ] `make check` passes.
