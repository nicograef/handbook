# Plan: Distill the handbook

> Source PRD: n/a — produced by `/distill this whole handbook repo`, 2026-08-01.

## Goal

Reduce the handbook's prose to what a reader cannot get anywhere else.

Projected: **11,651 → ~7,575 Markdown lines (−35%)** across 88 files, plus ~120 lines of
comment blocks in 33 shell/config files.

Analysis basis: 13 read-only `opus` workers, 121 files read in full, 1,710 claims extracted,
365 duplicate clusters. No file was judged from a grep hit or its headings.

## Resolved decisions

Answered by the user before this plan was written. A later session must not re-derive them.

- **Keep-bar: private agent tooling first.** `.claude/skills/` is judged on context cost per
  invocation, not on being a teaching product. Paired Go+TypeScript examples that demonstrate
  the same point twice lose the second copy. Lines addressing "Nico" in the second person are
  correct as written and stay. Private-preference content that leaks into the public plugin
  (`distill/parallelism.md`'s sonnet/opus routing table, `prune/`'s `/home/nico` path
  examples, `web-researcher.md`'s "Nico's web research specialist") is correct under this bar
  and stays.
- **GitHub Copilot is not used on this repo.** `.github/prompts/*.prompt.md` lose their only
  reader. `guides/copilot-agent-setup.md` keeps only the per-surface facts.
- **The cheatsheets are not used as terminal recall.** Strictest derivability bar applies.
- **The `tutor` skill stays.** It has provably never run, but the user keeps it. Its FLAG is
  withdrawn; only its internal duplication is trimmed.
- **`templates/vscode-settings.json` is not relied on as shipped.** See *Out of scope* — the
  action this implies is outside a distillation's mandate.
- **Nothing is off-limits.** Including `claude/CLAUDE.md` (the live global instruction file)
  and the `distill`/`verify-docs`/`prune` skills that produced this plan.
- **Mode: plan-only.** This file is the sole artifact. No file in the corpus was modified.

## Architectural decisions

Durable constraints that apply to every phase.

- **Anchor breakage is silent.** `scripts/check-repo.sh` strips the fragment before resolving
  a link (`path="${target%%#*}"`), so `make check` validates file existence only. Every
  section deletion in a file with inbound anchors needs a manual `grep -rn '#<anchor>'`.
  Load-bearing anchors, verified present today:
  - `guides/postgresql-operations.md` — `#2-restore`, `#3-automated-backup-cron`,
    `#4-restore-drill`, `#verify` (5 inbound links from `maintenance.md`, `monitoring.md`,
    `verification-drill.md`, `bootstrap.md`). Its `## N.` numbering must not shift.
  - `guides/provision-server.md` — `#inputs`, `#verify`, `#after-provisioning`,
    `#primary-cloud-init-hetzner`.
  - `guides/monitoring.md` — `#inputs`, `#verify`, `#step-2--https-uptime-monitor-with-ssl-expiry-alert`,
    `#step-3--backup-heartbeat`, `#step-5--health-ping-heartbeat`.
  - `guides/new-project.md` — `#inputs`. `guides/maintenance.md` — `#reboot-routine-monthly`.
  - `guides/claude-plugin.md` — `#verify` (from `bootstrap.md:97`).
  - `guides/docker-setup.md` — `#prune-unused-resources` (from `maintenance.md:82`).
  - `.claude/skills/distill/parallelism.md` — `#execution-modes`, `#grouping-files`,
    `#apply-stage-partitioning` (from `verify-docs/SKILL.md:110,193`).
  - `.claude/skills/cleanup/code-smells.md` — `#redundant-abstractions`;
    `.claude/skills/cleanup/readability.md` — `#deep-nesting`.
- **Two indexes are machine-enforced.** `check-repo.sh` diffs `README.md` against `git ls-files`
  in both directions for `guides/ cheatsheets/ templates/ scripts/`, and diffs
  `.claude/skills/README.md` against the skill directories. A file deletion and its index row
  must land in the same change or `make check` fails.
- **Prose references are not link-checked.** `.claude/rules/skills.md:66` names
  `interface-design.md` and `mocking.md` as canonical naming examples in prose, not as links.
  Renaming or deleting either leaves that rule pointing at nothing, silently.
- **The >100-line TOC rule cuts both ways.** `.claude/rules/skills.md:57` requires a bullet TOC
  on every reference file over 100 lines. Files dropping below 100 lines in this plan should
  lose their TOC with the same edit: `tdd/mocking.md`, `cleanup/cross-layer.md`,
  `distill/restructure.md`.
- **Subtract, never restyle.** The line is between deleting content and re-authoring it:
  - Deleting a code block, a section, or a whole file, and **keeping the surrounding prose
    verbatim** — subtraction. This is the skill's core move and includes aggressive GUT.
  - Reordering and re-homing sections during a SPLIT or MERGE — allowed.
  - Rewriting surviving sentences, or reformatting existing prose into a new shape (e.g.
    collapsing eight explained patterns into a summary table) — **restyling, forbidden.**
  Where a worker's projection depended on the third, the projection is not taken. Where it
  depended on the first, it is — even when the cut is large.
  Concretely: `test-quality/anti-patterns.md` goes to ~115 lines by deleting code blocks and
  keeping every existing `**Why it's bad**` / `**Fix**` paragraph untouched. It does **not**
  go to the ~40 a table form would reach, because that requires authoring new cells.
- **Irreversible operations are never compressed.** Every exact command sequence for deploy,
  restore, migration, provisioning, cert issuance, and teardown survives verbatim. Where a
  worker declined a cut on these grounds it is recorded in the phase.

## Inventory

| Area | Files | Before | Projected |
| --- | ---: | ---: | ---: |
| `.claude/skills/` | 46 | 6,467 | ~3,645 |
| `guides/` | 20 | 3,674 | 2,294 |
| `cheatsheets/` | 7 | 681 | 129 |
| root (`README`, `AGENTS`, `CLAUDE`) | 3 | 266 | 224 |
| `.claude/rules/` | 5 | 230 | 163 |
| `templates/*.md` | 2 | 149 | 140 |
| `claude/CLAUDE.md` | 1 | 102 | 95 |
| `.github/` | 3 | 53 | 6 |
| `.claude/agents/` | 1 | 29 | 29 |
| Shell/config comment blocks | 33 | — | −120 |

---

## Phase 1: Whole-file removals

### What to build

Four files lose their last reader under the resolved keep-bar. Each removal is paired with the
index row and inbound reference that must die with it.

| File | Lines | Why | Also edit |
| --- | ---: | --- | --- |
| `cheatsheets/git.md` | 114 | ~60 rows are `git help <subcommand>` summaries. Its one non-derivable block, the alias list, documents aliases that **are not installed** — `install-dotfiles.sh` symlinks `templates/.bash_aliases`, which defines a different, non-overlapping set (`gfp`/`gct`/`gcm`/`gbv`/`glo`/`glg`). It also omits the repo's only load-bearing git constraints, which live in `AGENTS.md`. | `README.md` row 59 |
| `cheatsheets/vim.md` | 32 | All 13 rows are the first screen of `vimtutor`. The source of truth is inside the program the reader is already sitting in. Zero inbound links. | `README.md` row 58 |
| `.github/prompts/new-guide.prompt.md` | 23 | Copilot-invoke-only; Copilot is not used here. Every step restates `.claude/rules/guides.md`, which Claude Code auto-loads on `guides/**`. Has already drifted: it documents one guide shape where the rules file documents two, and instructs alphabetical README insertion into a table ordered by workflow. | `.github/copilot-instructions.md:8` pointer |
| `.github/prompts/new-template.prompt.md` | 22 | Same. Near-verbatim copy of `.claude/rules/templates.md` down to the `<your-domain>` / `<db-password>` examples. Only step 3 (cross-reference an existing guide) has no home in the rules file — fold that one line into `.claude/rules/templates.md`. | as above |

`.claude/skills/tdd/tests.md` (116) is also removed, but as a **DELETE, not a MERGE**. The
merge existed only to preserve one worked GOOD checkout example for a human reader; under the
private/agent keep-bar that example teaches nothing. Everything else in the file is already in
`test-quality/anti-patterns.md` — all six "Red flags" are numbered sections there, and the Go
block at `tests.md:91-97` is byte-identical to `anti-patterns.md:145-151`.
Repoint `tdd/SKILL.md:28` to `../test-quality/anti-patterns.md`.

**Not deleted, deliberately:** `.github/copilot-instructions.md`. It is an agent instruction
surface, so deletion needs per-file confirmation, and the case for deleting it rests on
`AGENTS.md:7`'s unverified claim that every Copilot surface reads `AGENTS.md` directly. Trim it
to 6 lines in Phase 7 and leave the delete question in *Open questions*.

### Acceptance criteria

- [ ] 5 files removed via `git rm`; total −307 lines.
- [ ] `README.md` rows 58 and 59 removed; `make check` README stage passes.
- [ ] `tdd/SKILL.md:28` points at `../test-quality/anti-patterns.md`.
- [ ] `.claude/rules/templates.md` carries the "cross-reference an existing guide" step.
- [ ] `grep -rn 'cheatsheets/git.md\|cheatsheets/vim.md\|tdd/tests.md\|new-guide.prompt\|new-template.prompt' .` returns nothing outside this plan.

---

## Phase 2: `cheatsheets/` — 681 → 129

### Context

Not used as terminal recall, so the derivability bar is strict. Four files are mirrors of
`templates/`, which is the executable source of truth and will drift from them.

### What to build

- **`unix-commands.md` 127 → 30.** Delete the `man`-page restatements: find (3-12), sed (24-31),
  awk (33-41), tar (65-74), systemctl (76-86), disk/processes (88-98), networking (100-108),
  splitting/counting (120-127). Keep the composed invocations that took an afternoon to
  assemble: `find -prune` (11), the multi-flag recursive grep (17), `curl -fsSL | bash` (46),
  the three ssh forms — `bash -s < script`, `-L`, `-D` (57-59), `rsync -avz --progress` (62),
  the journalctl ssh-login line (85), largest-files / `lsof -i` / the `'[n]ginx'` self-match
  dodge (93-95), and the jq-sort-then-side-by-side-diff pair (116-117).
- **`postgresql.md` 142 → 25.** Delete meta-commands (12-27, listed by `\?` in the session the
  reader is already in), role DDL (29-39), the four queries that are verbatim duplicates of
  `postgresql-operations.md` (44-53, 59-62, 72-74), Backup & Restore (84-104), Config & Tuning
  (108-125), Shortcuts (127-142). Keep connection forms incl. `PGPASSWORD` (5-10),
  `pg_cancel_backend` vs `pg_terminate_backend` (55-57), `CREATE INDEX CONCURRENTLY` (76-77),
  the seq_scan missing-index heuristic (79-81), and the runbook link (106).
  **The Backup & Restore deletion is a correctness fix, not just a cut** — it gives host-level
  `pg_dump -U admin -d mydb`, and Postgres here runs only under Compose.
- **`makefile.md` 90 → 15.** Delete Variables (12-22), .env Loading (24-32, duplicates
  `templates/Makefile:12-13` and `:91`), Pattern Rules (34-42, `%.o: %.c` is irrelevant to
  every language in this stack), Common Patterns (44-70, duplicates `templates/Makefile:82-84`,
  `:97`, `:99`), Useful Flags (72-80, `make --help`). Keep TAB-not-spaces and `.PHONY` (3-10) —
  "missing separator" is make's most common failure and the error names no cause — plus the
  dollar-escaping section (82-88, **see FLAG 1**) and the template link (90).
- **`docker-compose.md` 117 → 33.** Delete .env Integration (3-18), Healthchecks + Dependency
  Ordering (20-35), Internal Networks (37-55), Named Volumes (69-81), Multiple Compose Files
  (83-89) — all verbatim extracts of `templates/docker-compose.prod.yml` and
  `templates/Makefile`. Keep Port Binding (57-67): `127.0.0.1:5432:5432` is a security sharp
  edge that appears in **no** template, because `prod.yml` publishes no DB port at all. Keep
  Project Name (106-117): `postgresql-operations.md:216-219` hard-depends on it — the migrate
  runbook attaches to `<project>_db-network` and this is the only file explaining the prefix.
  **Keep Common Commands (91-104)** despite it being `docker compose --help`:
  `maintenance.md:9-14` declares an explicit single-source rule delegating all Compose command
  reference here, and six live links (`maintenance.md:11,127,215`, `docker-setup.md:99`,
  `docker-multi-stage-builds.md:121`, `postgresql-operations.md:335`) point at it as "command
  reference". Removing it would leave six links promising something the file no longer has.
- **`tmux.md` 59 → 26.** Delete the prefix-key (18-22), Windows (24-32) and Panes (34-42)
  tables — stock keybindings listed by `prefix + ?` inside the running session. Keep 1-16
  (prefix, config link, the survive-ssh rationale, session command), copy mode (44-52, the
  `mouse on` note is config-dependent), config reload (55-59).

### Acceptance criteria

- [ ] `cheatsheets/` totals 129 lines across 5 files.
- [ ] `cheatsheets/docker-compose.md` still contains a `## Common Commands` section.
- [ ] All six inbound links to `docker-compose.md` still resolve to content that matches their link text.
- [ ] `postgresql-operations.md:335` and `cheatsheets/postgresql.md:106` still cross-link.
- [ ] `make check` passes.

---

## Phase 3: `guides/` — 3,674 → 2,294

### Context

The dominant pattern is a guide narrating what a script or template already does. Under
`AGENTS.md`'s single-source rule the artifact wins and the prose becomes a link.

### What to build

**`copilot-agent-setup.md` 517 → 140** (GUT; the largest file in the repo). It answers three
unrelated questions and only one has a reader here. Delete: the "Six Core Areas" stated three
times (48-61, 93-106, 500-506); "start simple, iterate" twice (42-44, 508); Common Failure
Modes (65-73); Auditing an Existing Repo (77-146, a 70-line checklist for a task nothing here
drives); the AGENTS.md recommended-sections block (155-213, duplicates `templates/AGENTS.md`,
which is what `new-project.md:113` actually copies); Best practices (215-224); the
copilot-instructions block (231-242, duplicates `templates/copilot-instructions.md`); what
belongs / does not belong (244-258); the instructions-file example (268-307) for a surface line
266 says this repo dropped; the generic SKILL.md example (329-346, `.claude/rules/skills.md` is
canonical); the `.agent.md` example (361-396); agent best practices (402-412); the scaffolding
prompt (422-445); the Analyze→Plan→Implement workflow (447-485) for prompts that exist nowhere
in `.github/prompts/`; the Lightweight variant (487-494, duplicates `AGENTS.md`'s Plan-first
workflow); Best Practices Summary (498-511).
Keep the non-derivable payload — which Copilot surface loads which file from which path: 1-5,
7-34 (the six-layer table, cited by `new-project.md:126`), 36-40, 305-306, 311-325, 348-352,
357-359, 398-400, 418, 515-517.

**`provision-server.md` 232 → 150.** Delete the second copy of `setup-server.sh`'s own header
(5-17), the ssh-keygen block (24-27, duplicates the script's line 19), the Configuration table
and sudo trade-off (138-155, duplicates the script's 26-34 and 107-118), the SSH-hardening
rationale (162-167), and the "Manual Reference" subsections whose entire body is "see step N in
the script" (157-160, 183-195). Survives verbatim: both provisioning paths and all four exact
command blocks (38-97), Verify with expected output (99-136), After provisioning (197-223).
**Trap:** line 31 points at `#configuration`; if the Configuration table goes, that sentence
must be repointed at the script, not left dangling.
A third `ssh … bash -s` variant at 93-96 differs from 89-91 only by swapping `USER_PASSWORD`
for `PASSWORDLESS_SUDO=true` — kept anyway. It runs as root against a fresh box, and precision
on irreversible operations outranks the redundant-example rule.

**`maintenance.md` 216 → 150.** Delete the intro and single-source paragraph (3-14, whose four
links all reappear inline and again in See-also), the Cadence table (16-23 — all four section
headings already carry their cadence in parentheses), the pinned-tag example list (30-32), the
SSH-access prerequisite stated three times (92-96), 142-143, and the restore-drill framing
(198-205, near-verbatim `postgresql-operations.md:121-126`). Survives verbatim: 40-83, 99-138,
145-195 — every command, every diff block, every "Expected:" line, the ≥80% threshold, and the
postgres-data prune prohibition.

**`postgresql-operations.md` 335 → 250.** Trim the unused host-prerequisite (10, 12-14 — see
Conflict 1), the single-table dump that varies only `-t users` (39-45), the restatement of
`backup-postgres.sh`'s own header (76-80), the config table mirroring the script's env defaults
(102-107), the 11-line sample psql output (164-174), the four monitoring queries duplicated from
the cheatsheet (262-263, 268-271, 277-279, 285-286 — keep only the cache-hit-ratio query and
its >99% threshold at 289-295), and the Verify block's throwaway restore (299-307), which
re-runs the drill at 144-187 under a different database name.
Survives verbatim: Restore (47-72), the accepted-risk callout and its upgrade path (109-117),
the restore drill (119-189), migrations (190-255), Troubleshooting (313-329).
**Do not renumber the `## N.` headings** — five inbound anchors depend on them and `make check`
will not catch a break.
**Not split**, though backup-vs-migrations is literally `restructure.md`'s worked example of a
good boundary: after dedup the file lands at ~250 lines, and the split costs a 5-file link fix.

**`dotfiles-codespaces.md` 171 → 95.** Delete "Smoke test 1 … (PENDING)" (135-146), the
files-used table (9-19), "The script also:" (22-30), the lookup-order list reduced to one
sentence (52-66), the "Expected:" paragraph (129-133), Extending (148-164). Keep "Why no
.bashrc?" (32-36) — that is a non-derivable why — plus 38-50, 68-92, 94-127.

**`letsencrypt-docker.md` 167 → 120.** Delete the architecture diagram (7-13), the
three-Compose-file table (15-21), the renewal-monitoring block (100-115, near-verbatim
`monitoring.md:100-115`), and the first two Troubleshooting blocks (143-152). Keep verbatim
Steps 1-2 with the `-p` warning (41-91), Verify (121-139), Inputs (29-39), Auto-Renewal
(93-98), remaining Troubleshooting (153-160). Cutting 143-152 removes one of six
`certbot/certbot:v5.6.0` pins for free.

**`monitoring.md` 197 → 165.** Delete 6-7, the cert division-of-labor block (18-24, duplicate of
`letsencrypt-docker.md:100-115` — and line 21 carries the dead "after PRD 1" citation), the
prose restating the table's third column (37-41), the Inputs body (56-62 — **keep the heading**,
`bootstrap.md:24` anchors it), and "sign up and confirm the email" (66). Survives verbatim: the
dead-man model (9-17), the ping-URL table (28-36), the free-plan facts with their as-of date
(50-54), every vendor UI click-path with its period and grace-period reason (72-151), Verify and
Troubleshooting (152-187).

**`new-project.md` 196 → 150.** Delete the template-describing bullets (55-57, 82-84 — verbatim
halves of `README.md:71-72`), Step 7 "First commit" (139-146, restates the commit rule already
in `AGENTS.md` and `CLAUDE.md`), Step 8 (148-152, a pure forward-pointer to `bootstrap.md`,
which routes back here), and the expected-layout tree (155-176, mechanically derivable from the
eleven `cp` commands above it). Survives: Inputs (13-26, `bootstrap.md:101` anchors it), the
stack matrix (67-73), every `cp` block, the `setup-dev-tools.sh` gotcha (87-89), agent setup
(112-127), Verify (178-185).

**`docker-setup.md` 104 → 55** (GUT). Delete Prerequisites (3-7), the entire install block
(9-40 — automated in `setup-server.sh:189-216` with an identical package list and `usermod`,
and upstream at the `docs.docker.com` URL the guide itself cites at line 11), the log-rotation
`daemon.json` (48-64 — same JSON as `setup-server.sh:247-252`, and its own callout at 50-52
tells script-provisioned readers to skip it), and line 79. Keep the IPv6 `daemon.json` warning
(42-46), Prune (66-71 — **keep the `#prune-unused-resources` heading**, `maintenance.md:82`
anchors it), Verify (73-80), Troubleshooting (82-94), See also (96-104).

**`claude-plugin.md` 168 → 105.** Delete the `claude plugin list` sample output pinning
`Version: 6b62e37b333f` (96-102 — already three commits stale; any sample output of a
SHA-versioned command is stale on write), the "Verified 2026-08-01" paragraph (108-111), and the
entire Verify section of smoke-test records (113-161). **This empties a heading that
`bootstrap.md:97` anchors** — replace it with a one-command Verify block using
`claude plugin details handbook`, currently stranded at line 41.
Hand-written today (`b311ab5`); flagged as such rather than quietly cut.

**`react.md` 148 → 62.** Delete `pnpm create vite` (9-12), the tool table (14-25, duplicates
`claude/CLAUDE.md:18-25`), Formatting (57-64, duplicates `templates/ci.yml`), Forms (87-88), the
textbook fetch wrapper (104-114 — the two surrounding lines carry the rule), State Management
(116-121), Routing (123-125), test commands (133-136), Code Quality (142-149). Keep the engines
pin and `--frozen-lockfile` (27-33), Project Structure (35-49), TypeScript (51-55), Linting
(66-84), Component Design and the two API-layer rules (90-102).

**`java-spring-boot.md` 191 → 95.** Delete the layer-responsibility table (35-40, each cell is
the annotation's javadoc), the constructor-injection code block (50-64 — the rule at line 48
carries it), DTOs and Records (68-81), the Key Annotations table (84-97, verbatim Spring
reference docs), the `@Entity`/`JpaRepository` block (105-115), Clean Code and DDD (158-165).
Keep 1-33, line 42 ("a controller never talks to a repository"), line 48, Flyway (101-103,
117-125), Formatting and Linting (129-154), Testing (169-186), see-also (189-191).

**`go.md` 145 → 70.** Delete Project Setup (5-15, `go help mod`; the tooling line survives),
Formatting (36-50, duplicated in `templates/ci.yml`), Error Handling (73-87, Effective Go and
the stdlib `errors` doc), the golang-migrate commands (106-111, duplicated in
`postgresql-operations.md:230-236` and `templates/ci.yml`), Code Quality (138-146, Go Proverbs).
Keep Project Structure (17-34), Linting (52-71), the sqlc workflow (89-104), Testing (113-136).
**See FLAG 2** — line 71 links a local-looking `.golangci.yml` to external docs, and no such
file exists in the repo.

**`docker-multi-stage-builds.md` 122 → 85.** Delete `.dockerignore` (62-74), Layer Caching Tips
(76-87), Image Size Comparison (89-96 — four unsourced figures with no as-of date), line 58.
Keep Java (5-33), Node (34-61 minus 58), Troubleshooting (98-115).

**`nginx-reverse-proxy.md` 85 → 52.** Delete the intro restating the heading (1-3),
Prerequisites (5-9), the "Full Config" section (11-15), See also (80-85). Keep both Key Patterns
(17-44), Verify (46-57), Troubleshooting (59-78).
**Not split**, though a worker identified a clean seam: the SPA-fallback and asset-caching
snippets are the missing piece of `docker-multi-stage-builds.md:52` (which copies an
`nginx.conf` it never shows), and the troubleshooting entries belong beside
`letsencrypt-docker.md`. Executing it would eliminate a README-indexed file — a structure
decision, not a distillation one. Recorded in *Open questions*.

**`bootstrap.md` 115 → 95.** Delete the scenario routing table (8-13), the second copy of the
`setup-server.sh` capability list (27-28), the trailing See-also (108-115). Everything else is
the declared entry point and stays.

**`verification-drill.md` 293 → 265.** Delete the motivational framing (8-10), the
EUR 0.0088/h price breakdown (27-31 — keep "well under one euro" and the teardown warning; the
figure is a dated external fact that changes nothing a reader does), Step 2's restatement of
`provision-server.md`'s Verify block (58-66) inside a file whose own premise at line 5 is "every
step runs the owning guide's own Verify block", line 196 (verbatim `provision-server.md:118`,
and 192-193 already says so), and the Execution record (273-281 — a status table whose only row
is `_pending_`, plus three lines explaining that the row is a placeholder).
Steps 1 and 3-10 survive verbatim: the hcloud create line, the stock-image substitution, the
`prod-init.sh` invocation, the truncated-dump failure simulation, the reboot-required
simulation, and the teardown checklist are exact commands for irreversible or billing-relevant
operations.

**`ipv6-only-vps.md` 109 → 103.** The claim "`setup-server.sh` applies step 2 automatically" is
stated three times in a 109-line file (18-20, 106, 108). Keep one. Everything else stays: the
dated IPv6 availability lists, the DNS64 resolver trust trade-off, the `daemon.json` with its
RFC 6724 reasoning and default-bridge gotcha, Limits, Verify.

**`anti-sycophancy.md` 50 → 32.** Delete the Failure-modes table (8-16, a generic sycophancy
taxonomy the catalog's "Counters" column already names) and the first three "Why prompts alone"
bullets (31-35). Keep the framing and never-restate rule (1-5), the countermeasure catalog
(18-27), the null-result bullet (36-37), Applying to a new project (39-50).

**`github-actions-cicd.md` — FLAGGED, not trimmed.** See Conflict 2. No lines are cut until the
user resolves whether the template is missing a deploy job or the guide is aspirational.

**Corpus-wide pattern, deliberately not acted on:** every guide ends with a "See also" block
whose links already appear inline in the body (`provision-server.md` relists 3 of 4,
`maintenance.md` all 6, `monitoring.md` all 5). Only the three cases above are cut, where the
block was the last thing in a file already being trimmed. Removing them file-by-file would make
the corpus inconsistent; removing them all is a separate sweep, and either way the decision
belongs in `.claude/rules/guides.md`, which currently does not mention See-also blocks at all.

### Acceptance criteria

- [ ] `guides/` totals ~2,294 lines across 20 files.
- [ ] Every anchor in *Architectural decisions* still resolves: `grep -rn '#<anchor>'` for each, then confirm the heading exists.
- [ ] `guides/claude-plugin.md` has a non-empty `## Verify` section.
- [ ] `guides/docker-setup.md` still has a `## Prune unused resources` heading.
- [ ] `guides/provision-server.md:31` no longer points at a deleted `#configuration` section.
- [ ] `guides/postgresql-operations.md` `## N.` numbering is unchanged.
- [ ] `github-actions-cicd.md` is byte-identical to its pre-plan state.
- [ ] `make check` passes.

---

## Phase 4: `.claude/skills/cleanup/` — 1,655 → ~700

### Context

The largest skill in the repo, and the one where the private/agent keep-bar bites hardest. Five
overlapping taxonomies (principle / smell / architecture / readability / cross-layer) reach the
same defect from three or four entry points — so much so that `SKILL.md:107-108` needs a rule
telling the agent to suppress its own duplicate findings. That rule is evidence the split is
wrong, not evidence it works.

### What to build

- **`principles.md` 264 → ~60.** The KISS/DRY/SOLID definitions and Flag-when enumerations are
  pretrained. What survives is only the calibration a model would not default to: the DRY
  Do-NOT-flag list (76-84), the Open/Closed "2-3 branches is fine, do not over-engineer"
  threshold (118-120), and the "do not extract during cleanup, flag for later" discipline
  (102-103, 189-190). Also removes the file's own internal duplicate — 88-103 (Single
  Responsibility) and 175-191 (Separation of Concerns) are the same check twice.
- **`architecture.md` 214 → ~70.** Dependency direction, IoC, the repository pattern and
  anti-corruption layers are pretrained DDD vocabulary. Survives: the Deep-vs-Shallow
  Do-NOT-flag list (77-81), the anemic-model exception (106-110), the flag-as-separate-refactor
  discipline (18-19, 88-89, 175-176). Delete Cross-Layer Consistency (198-214) — 17 lines
  duplicating `cross-layer.md:13-36`, including the identical "max length 50 in UI but 255 in
  DB" example.
- **`code-smells.md` 352 → ~190.** GUT the structural half (12-133): God Class, Feature Envy,
  Shotgun Surgery, Primitive Obsession and Boolean Blindness are textbook Fowler a model names
  unprompted. Also delete Premature Abstraction (120-133) vs Redundant Abstractions (194-207) —
  the same smell twice in one file — and Style Drift (209-225), duplicated by
  `readability.md:88-101` and stated twice more in `SKILL.md`.
  **The AI-slop half (137-352) is not audience-sensitive and stays**: the config-comment
  Keep-lists (278-284, 320-321, 334-337) encode this repo's own template conventions and cannot
  be inferred from anywhere.
  Preserve the `#redundant-abstractions` anchor.
- **`readability.md` 299 → ~230.** Trim the code half (11-101) — naming-after-type, clever code,
  4+ nesting levels are pretrained; delete Consistent Style (88-101) and Long Functions (65-86),
  plus the intra-file repeats at 117/148, 136/192, 120/179.
  **The prose half stays whole**: the specific phrase lists are what make slop detection
  reproducible rather than vibes-based. Preserve the `#deep-nesting` anchor.
- **`readability-de.md` 280 → 250.** Cut only the duplicated *English* framing sentences (23-24,
  72, 89-90, 113, 129, 148-149, 162, 166-167, 209-213, 240-241, 256, 267) and the one-entry TOC
  (3). Every German phrase list is load-bearing and non-derivable. This is the one allow-listed
  German file — do not let a language check flag it.
- **`cross-layer.md` 57 → 33.** Delete the three-entry TOC on a 57-line file (7-9) and the
  Simplification pass (40-57), which has zero unique content against `architecture.md:65-89`,
  `code-smells.md:90-102`/`194-207`, and `readability.md:51-63`/`88-101`.
  `guided-implementation/SKILL.md:105` links this file as a standalone checklist — keep the path.
- **`SKILL.md` 189 → ~145.** Delete the intro restating the frontmatter (16-22), the
  reference-file bullet index (24-37), step 2's "learn the codebase's native voice" list (66-74
  — behaviour a frontier model performs unprompted; only 76-77 is load-bearing), step 6 Verify
  (156-163).
  **Keep 112-117** ("zero findings is a valid outcome … do not manufacture findings") despite it
  being near-verbatim `ux-review/SKILL.md:44-48` and restated in four more places. It is a
  load-bearing anti-sycophancy constraint at the exact point of temptation.

Two files link and then restate: `principles.md:57-58` and `architecture.md:86` both link
`code-smells.md#redundant-abstractions` and restate its bullets above the link. Delete the
restatement, keep the link.

### Acceptance criteria

- [ ] `cleanup/` totals ~700 lines across 7 files.
- [ ] `#redundant-abstractions` and `#deep-nesting` anchors still resolve.
- [ ] `cross-layer.md` has no TOC (now 33 lines) and is still linked from `guided-implementation/SKILL.md:105`.
- [ ] `readability-de.md` still passes the `check-repo.sh` language stage.
- [ ] `cleanup/SKILL.md` retains its Workflow, Constraints and Quality sections per `.claude/rules/skills.md`.

---

## Phase 5: `.claude/skills/tdd/` + `test-quality/` — 1,067 → ~375

### Context

These are one catalog stated four times plus two genuinely single-sourced procedures. Note the
framing correction a worker made and which this plan adopts: these skills do **not** document
this repo. They are executable instructions loaded when `/tdd` or `/test-quality` runs against
jotti, lexiban, rag, escpresso — repos that do have test suites. The absence of an app here is
irrelevant to their bar.

### What to build

- **`tdd/SKILL.md` 153 → ~55.** Delete the Philosophy essay (11-29), the "crap tests" bullets
  (36-44), the deep-modules paragraph and ASCII box diagram (82-95), and the "3. Incremental
  Loop" block (115-121), which is the identical code block already shown under "2. Tracer
  Bullet" at 102-107. Keep the loop, the vertical-slice prohibition, and Constraints.
- **`tdd/mocking.md` 161 → ~45.** Delete the TOC (3-4), "Designing for Mockability" in both
  languages (19-55), and the second-language repeats (42-55, 78-92, 127-139). Keep the boundary
  list (6-18) and the two anti-patterns — the only content carrying an opinion a model would not
  default to. Drops below 100 lines, so its TOC goes with it.
- **`tdd/interface-design.md` 73 → 40.** Delete "3. Small surface area" (70-73) and the
  TypeScript repeats of the Go blocks (34-44, 59-68). **Not deleted outright** — three referrers
  link it (`tdd/SKILL.md:71`, `guided-implementation/SKILL.md:115`, `write-prd/SKILL.md:52`) and
  removing it would mean inlining a sentence into each, which is authoring.
  `.claude/rules/skills.md:66` also names this file in prose as a canonical naming example.
- **`test-quality/anti-patterns.md` 280 → ~115.** Delete the preamble (3-5), the eight bare
  `---` separators, and **both** the Go and TypeScript BAD code blocks in all eight patterns.
  Every pattern already carries a one-line prose description under its H2 plus a
  `**Why it's bad**:` and a `**Fix**:` paragraph — all of which survive **verbatim**, so this
  is subtraction, not a rewrite. Under the private/agent keep-bar a model recognises
  `assert.True(t, mock.chargeCalled)` and `expect(gateway.charge).toHaveBeenCalledWith(…)`
  from the prose alone; the paired blocks demonstrate the same point twice for a human reader.
  **Held at ~115, not the ~40 a table form would reach** — reformatting the surviving prose
  into signal→why→fix table cells is authoring, which this skill does not do.
  **Reverse this cut first if the audience ever flips to public/human** — the worked examples
  are the product for that reader, and this is the single largest audience-dependent cut in
  the plan.
- **`test-quality/evaluation-criteria.md` 148 → 55** (GUT). The same eight-pattern catalog is
  stated three times inside this one file — as questions (13-43), as tag prose (52-93), as
  signals (136-148) — plus a fourth time with worked examples in `anti-patterns.md`. Keep the
  Decision Tree (8-45) and the Coverage Loss Protocol (96-107), the only place in the repo
  saying what to do when a Delete removes the last test for a behaviour. Delete Tag Definitions
  (50-93, also duplicating `test-quality/SKILL.md:52-57`), the Mocking Boundary Reference
  (110-131 — see Conflict 9), the Quick Reference Card (134-148), and the five bare `---` rules.
  `guided-implementation/SKILL.md:122` links this file; the Decision Tree is what it wants.
  At 55 lines it drops under the TOC threshold — it has no TOC today, which was already a
  pre-existing violation of `.claude/rules/skills.md:57`, now moot.
- **`test-quality/SKILL.md` 136 → ~88.** Delete Philosophy (9-27), the Keep/Refactor/Delete/Merge
  tag table (52-57, duplicating `evaluation-criteria.md`), "Rules during refactoring" (101-107),
  and the two bare `---` rules. Trim step 1 Discover (34-46) — a five-item checklist with glob
  patterns an agent already knows.
  **Keep 79-81** ("a mostly-Keep suite is a successful audit — do not manufacture Delete or
  Merge tags") despite being the third home of that rule. Operative at the moment of temptation.

### Acceptance criteria

- [ ] `tdd/` + `test-quality/` total ~375 lines across 6 files (was 7).
- [ ] Every `**Why it's bad**` and `**Fix**` paragraph in `anti-patterns.md` is byte-identical to its pre-plan text.
- [ ] `tdd/mocking.md` is under 100 lines and has no TOC.
- [ ] All three links to `interface-design.md` resolve.
- [ ] `guided-implementation/SKILL.md:122` still reaches a Decision Tree.
- [ ] `.claude/rules/skills.md:66`'s prose reference to `interface-design.md` and `mocking.md` is still accurate.
- [ ] All three `SKILL.md` files retain Workflow + Constraints sections.

---

## Phase 6: remaining skills — 2,148 → ~1,750

### Context

The dominant pattern here is a closing Anti-patterns / Constraints / Quick-reference section
that restates the body of the file it closes. Two files say so in their own text
(`restructure.md:157` "Covered above", `sources.md:148` "Covered above"). Across the
distill/verify-docs/prune family alone that is ~180 lines with no unique claim.
`distill/criteria.md:99-107` names exactly this pattern — "'Summary' sections that restate their
own document" — as a delete. The family fails its own rule in eight places.

### What to build

**distill / verify-docs / prune** (nothing off-limits; these skills distill themselves):

- `distill/SKILL.md` 362 → 275 — Constraints (304-357), roughly half restating workflow steps
  verbatim; the keep-bar (54-56) duplicating `criteria.md:12-14`; the verify-docs handoff stated
  three times (38-40, 293-302, 355-357); "Steps 1-7 write nothing to the corpus" verbatim twice
  inside one section (306-307, 351-352); the barrier rationale at 133.
- `distill/criteria.md` 207 → 185 — Quick reference table (195-208); keep the keep-bar here.
- `distill/parallelism.md` 164 → 115 — Anti-patterns (146-165, all five restate the body); the
  15× token figure (30-32) duplicating `dispatching-parallel-agents/SKILL.md:18-21`, which this
  file's own lines 15-18 declare canonical; the "What parallelizes" table (33-49), every row of
  which also appears inline at its own step in `distill/SKILL.md`; the barrier restated again at
  47-48. **Keep the model-routing table (50-63)** — correct under the private keep-bar.
  **Preserve `#execution-modes`, `#grouping-files`, `#apply-stage-partitioning`** — `verify-docs`
  reads all three.
- `distill/restructure.md` 161 → 125 — Anti-patterns (137-161); the ~30-line floor stated three
  times (44, 70-71, 141); grep-on-rename (134-135); the >100-line TOC rule (89-92, whose home is
  `.claude/rules/skills.md`). Drops near 100 lines — check its TOC.
- `verify-docs/SKILL.md` 245 → 200 — Constraints (218-240), seven of ten restating the step-5
  triage table; the clean-tree precondition (60-62); the scope boundary (30-35).
- `verify-docs/sources.md` 149 → 132 — Anti-patterns (132-149); keep "Everything TRUE" (145-146),
  which appears nowhere else.
- `prune/SKILL.md` 139 → 108 — step 4's three review classes (71-85, a summary of
  `criteria.md`'s three sections); dry-run semantics stated four times (40, 60, 87, and
  `criteria.md:123`); the "deletion is hard" line twice (frontmatter 8-9, 130-131); the slug
  definition (44-45); memory+index (100-102); the never-touched list (126-128).
  The `/home/nico` path examples stay — correct under the private bar.
- `prune/criteria.md` 129 → 112 — Gating rules (116-129); the memory-deletion restatement (58-60).
- `prune/state-map.md` — **KEEP whole.** Verified against `prune-state.sh` this session: class
  names and dispatch match `ACTIVE_CLASSES` and lines 191-219, env defaults match 28-29,
  dry-run/`--delete` behaviour matches the header. It is a non-derivable digest of a 238-line
  script plus a negative list the script cannot express.

**Workflow family:**

- `guided-implementation/SKILL.md` 199 → 168 — intro (18-21), 5c's restatement of the linked
  `evaluation-criteria.md` (121-126), 5d's generic readability bullets (128-135), 5e Scope Guard
  (137-141), line 163.
- `create-plan/SKILL.md` 195 → 172 — Quality bullets 2-3 (118-121), the Phase 2 block of the
  Plan Template (176-193, which varies nothing from Phase 1).
- `understand/SKILL.md` 136 → 115 — 19-20, the invocation reference-type list (23-30), "Offer to
  go deeper" (108-116).
- `clarify/SKILL.md` 52 → 28 (GUT) — the stop-when-resolved rule is stated four times (22-23,
  33-34, 45, and canonically in `question-rules.md:20-21`); the two round subsections carry no
  content beyond their headings; 43-46 links `question-rules.md` and then indexes all seven of
  its rules inline, which is the exact restatement the canonical file exists to prevent — and
  which `create-plan:35`, `write-prd:35`, `reflect:86`, `prune:93` and `distill:152` all avoid.
- `clarify/question-rules.md` 26 → 25; `quality.md` 19 → 17; `dispatching-parallel-agents` 65 →
  57; `using-git-worktrees` 87 → 82; `write-prd/SKILL.md` 148 → 130 (Constraints 126-135).
- `finish-branch/SKILL.md` 96 → 90 — step 3's explanatory tail (45-50) only.
  **Keep the "Never force-push" constraint (90-92)** even though the private bar permits cutting
  it as a duplicate of `AGENTS.md`. Deleting a force-push prohibition to save three lines is a
  bad trade, and these skills load in other repos whose `AGENTS.md` differs.
  Note the GIT_DIR/GIT_COMMON detection block is byte-identical in `finish-branch:41-42` and
  `using-git-worktrees:23-24` — kept in both; each skill loads independently.

**Authoring family** (all four verified to actually run, except `tutor`, which the user keeps):

- `reflect/SKILL.md` 112 → 95; `reflect/sources.md` 89 → 78 (the four-part contract stated twice).
- `receiving-feedback/SKILL.md` 70 → 62 (47-48, 53-54). The "Nico"-addressed lines at 41 and 60
  stay — correct under the private bar.
- `ux-review/SKILL.md` 90 → 82 (line 87 only). The Review Areas section stays: for an agent
  executing a checklist, "44×44 touch targets" is the operative content, not background.
- `ubiquitous-language/SKILL.md` 104 → 61 — intro (12-13), the duplicate exclusion rule
  (79-80 vs 72-74), constraints the worked example already demonstrates (77-78, 82-88), and
  Re-running (90-98, derivable for a model audience).
- `tutor/question-design.md` 76 → 62; `tutor/session-state.md` 111 → 95. `tutor/SKILL.md` KEEP —
  cited three times by `guides/anti-sycophancy.md` as the canonical grading-skill pattern.
  `session-state.md` stays over 100 lines and still needs the TOC it currently lacks — a
  pre-existing `.claude/rules/skills.md:57` violation, recorded but not fixed here.
- `.claude/skills/README.md` 66 → 44 — the verification bookkeeping inside the "Loaded?" column
  (13-19), the paragraph at 21 reduced to its one non-derivable why, Typical Workflow (50-59),
  the quality.md linking policy (65). **Keep the consumption matrix** — it serves the
  maintainer, who is the confirmed audience.
- `.claude/agents/web-researcher.md` — **KEEP.** The personal framing at line 7 is correct under
  the private bar. Only FLAG 3 remains open.

### Acceptance criteria

- [ ] The three `#`-anchors into `distill/parallelism.md` still resolve from `verify-docs/SKILL.md`.
- [ ] Every `SKILL.md` still has Workflow + Constraints (and Quality where it produces artifacts).
- [ ] `finish-branch/SKILL.md` still states the force-push prohibition.
- [ ] `.claude/skills/README.md` lists every skill directory and vice versa — `make check` skills stage passes.
- [ ] `distill/restructure.md` and any other file crossing the 100-line boundary has its TOC added or removed to match.

---

## Phase 7: instruction surfaces, rules, root — 549 → 418

### Context

These read as restating the obvious because that is their job. Trimmed, never deleted; every cut
below is a verbatim duplicate or a factual error, not a judgment about whether a rule is worth
stating.

### What to build

- **`AGENTS.md` 110 → 93.** Delete the repo description (3-5, restating `README.md:1-7`), the
  Structure list (17-21, 25-28 — an `ls` of the repo root that `README.md`'s own Agent Setup
  table already indexes with working links, and which this file's line 51 declares the index),
  and the Searching table (30-35 — `grep -r` and `find -name`, restated verbatim in
  `CLAUDE.md:5-10`).
  **Keep 22-24 and 27**: the `agents` symlink and the Claude Code v2.1.197 manifest limitation,
  and `.devcontainer` as a proven instance of `templates/devcontainer.json`, are non-derivable
  why. Everything from 37 down — prohibitions, the PR-trailer injection sharp edge at 62-65, the
  plan/git contract — survives verbatim.
  **Line 19 is factually wrong** and dies with the Structure list. See Conflict 6.
- **`CLAUDE.md` 21 → 15.** Delete the Searching block (5-10), which restates the file it imports
  at line 1 and contradicts line 3's own comment ("Claude-only deltas"). Keep the /compact
  section (12-15) — Claude-Code-specific and unique — and the git non-negotiables (17-21) as a
  prohibition, even as the third copy. See Open question 3 on whether the "survive compaction"
  rationale holds.
- **`README.md` 135 → 116.** Delete the author bio (3-5), the scope sentence (7, restating
  `AGENTS.md:3-4`), the decorative `---` between two headings (11), the four section subtitles
  that restate their own heading (17, 51, 65, 92), and the Skills section (104-110 — seven lines
  for what the Agent Setup table carries as one row at 121). Keep the subtitle at line 40: it is
  the only non-Claude-only place stating the runbook/stack-convention distinction.
  All five index tables and the License block stay verbatim — `check_readme` diffs them against
  `git ls-files` in both directions.
- **`claude/CLAUDE.md` 102 → 95.** Delete only verbatim self-duplication in Preferences: line 67
  is byte-identical to line 35; 64 restates 37; 66 restates 33; 65 restates 36 except for the
  OIDC clause. Fold the two genuinely new facts (AWS auth via OIDC with no static credentials,
  and the Terraform status) into Infrastructure & DevOps. Delete line 24 (restates line 13).
  Projects (52-60), Communication Style (70-92) and Agent Working Rules (96-102) stay whole.
  This is the live global instruction file — a cut here changes machine behaviour immediately.
- **`.claude/rules/*` 230 → 163.** The one repeated pattern across all five is the "After
  creating or renaming …" checklist; every item either restates `AGENTS.md:51`/`:53` or is
  enforced by `check-repo.sh`, which the Stop hook in `.claude/settings.json` runs at every
  session end. Two survivors: `chmod +x` (`scripts.md:46`) and the skills discovery index
  (`skills.md:79`).
  Per-file: `cheatsheets.md` 29→17, `guides.md` 44→30, `scripts.md` 47→36, `skills.md` 81→59
  (the YAML example block at 29-37, File Naming 64-65, Deployment 70-72), `templates.md` 29→21
  (plus the one folded-in step from Phase 1).
  **Do not merge these into `AGENTS.md`.** `AGENTS.md:8-10` designates `.claude/rules/*.md` as
  the only path-scoped conventions surface, and `copilot-agent-setup.md:40` records the
  deliberate decision to canonicalise there — this repo already deleted its parallel
  `.github/instructions/` copies for that reason. Merging would undo a documented design
  decision and inflate the always-loaded token budget.
- **`.github/copilot-instructions.md` 8 → 6** (delete the `.github/prompts/` pointer at line 8,
  now dangling after Phase 1).
- **`templates/AGENTS.md` 133 → 124** (the dangling "see Quality Principles" cross-reference at
  122-124, the commented Areas block at 103-109). This is a product shipped to other projects,
  judged as such, not as this repo's instructions.

**Not touched:** the Communication rule set exists in four places (`AGENTS.md:70-85`,
`claude/CLAUDE.md:73-95`, `templates/AGENTS.md:87-94`, catalogued by `anti-sycophancy.md:21`).
The triplication is deliberate and documented — three delivery surfaces, and Copilot never reads
`~/.claude/CLAUDE.md`. Neither copy is safely deletable. But the three have already drifted:
`templates/AGENTS.md` says "developer" where `AGENTS.md` says "user", and `claude/CLAUDE.md`
adds "No compliment sandwich" and "When bluntness and politeness conflict, choose bluntness"
that the other two lack. Recorded as Open question 4.

### Acceptance criteria

- [ ] `make check` README stage passes — all five index tables still match disk.
- [ ] `AGENTS.md` no longer references `templates/.bashrc`.
- [ ] `CLAUDE.md` still carries the /compact preservation rule and the three git non-negotiables.
- [ ] `claude/CLAUDE.md` still states the OIDC/no-static-credentials rule and the Terraform status.
- [ ] `.claude/rules/scripts.md` still states `chmod +x`; `.claude/rules/skills.md` still states the discovery-index step.
- [ ] `~/.claude/CLAUDE.md` still resolves through the symlink and loads.

---

## Phase 8: comment blocks in scripts and configs — −120 lines

### Context

Comments only. The executable statements around them are out of scope and must not be touched,
reordered, or "fixed". 19 of 23 template/config files come back KEEP — the comment discipline in
`templates/` is already high and `.claude/rules/templates.md` is visibly being followed. No
promotional comments exist anywhere in the repo.

### What to build

Scripts: `check-repo.sh` 231→200 (the "What it does" list replaced by a pointer to the Makefile,
the invocation lines, the stage-argument list, and seven 3-line ruler banners);
`test-prune.sh` 311→292 (five ruler banners, one lone ruler, the enumerated assertion list);
`prod-init.sh` 131→122 (Prerequisites, `# ── Colors ──`, three step banners);
`backup-postgres.sh` 99→95; `setup-server.sh` 341→334 (the "Before running:" checklist and two
narrating comments); `install-dotfiles.sh` 145→141; `report-health.sh` 69→68;
`prune-state.sh` 239→235; `templates/Makefile` 99→92; `templates/nginx-tls.conf` 90→82;
`templates/.tmux.conf` 21→20; `templates/vscode-settings.json` 184→183 (the
`"//": "Last update at 3/17/2026…"` pseudo-comment key only).

**Comments that must survive — unrecoverable from any other source:**

- `claude/statusline.sh:6-8` — records that omitting `set -euo pipefail` is *deliberate*, against
  a rule `.claude/rules/scripts.md:30` calls mandatory. Delete it and the next agent "fixes" the
  script into one that blanks the status line on any missing field. See Conflict 7.
- `templates/setup-dev-tools.sh:50-53` — three stacked reasons golangci-lint is built from
  source (Go-version ceiling, lagging prebuilts, proxy-blocked GitHub downloads in cloud sessions).
- `templates/nginx-tls.conf:4-6` — Mozilla intermediate v6.0 with source URL and as-of date, plus
  why `ssl_ciphers` and OCSP stapling are deliberately *absent*. Documents two things not in the
  file. (Its architecture diagram at 7-11 is the one judgment-call TRIM in this group.)
- `templates/docker-compose.prod.yml:119-120` — `$$` Compose-interpolation escaping and
  busybox-wget-in-certbot-image; `:59,74` — "No exposed ports", documenting a deliberate absence.
- `templates/.bash_aliases:39-44` — the fzf/bash-completion ordering trap.
- `templates/dependabot.yml:38` — Dependabot's docker updater scans Dockerfiles, not Compose pins.
- The `── N. <name> ──` banners in `setup-server.sh` — they look decorative and are not:
  `provision-server.md:185-195` and `ipv6-only-vps.md:108` cite them **by name**. The equivalent
  banners in `prod-init.sh`, `check-repo.sh` and `test-prune.sh` have no such citations.
- Every commented-out optional block in `templates/` — in a template these are the interface, not
  dead code (`cleanup/code-smells.md`, *Template Pollution*).

### Acceptance criteria

- [ ] No executable line in any script or config differs — `git diff` shows comment-only changes.
- [ ] `shellcheck` stage of `make check` passes.
- [ ] Every comment in the survive-list above is present and unmodified.
- [ ] `grep -n '── ' scripts/setup-server.sh` still shows every numbered banner.

---

## Phase 9: indexes, links, verification

### What to build

Run last, when the file set is final. Never delegate this phase — index and link edits converge
on shared files.

1. `grep -rn '<filename>'` for each of the 5 deleted files; fix every hit.
2. Re-read `README.md` and `.claude/skills/README.md`; entries must match disk exactly.
3. Manually grep every anchor listed in *Architectural decisions* — `make check` will not catch
   a broken fragment.
4. Run `make check` (links, shellcheck, README index, language, skills, compose, plugin).
5. Re-read the largest surviving file end to end. If it now reads as a list of links with no
   content of its own, the trim went too far — restore.
6. Report actual before/after from `git diff --stat`, not the projections in this plan.

### Acceptance criteria

- [ ] `make check` passes.
- [ ] Zero hits for deleted filenames outside this plan file.
- [ ] Every anchor in *Architectural decisions* resolves to an existing heading.
- [ ] `git diff --stat` totals are reported and compared against the ~7,575-line projection.
- [ ] The commit body lists every FLAG below with its `file:line`.

---

## Conflicts to resolve

Not distillation actions. Two docs disagreeing means at least one is wrong and readers are
being misled today. **Never resolve one silently.**

1. **`postgresql-operations.md:10,12-14` vs `backup-postgres.sh:15`** — the guide lists
   `postgresql-client` on the host as a prerequisite; the script says "the host is not assumed to
   have postgresql-client installed". Every command in the guide runs inside the container, so
   nothing needs the host package. Phase 3 trims the guide's lines on that basis — confirm before
   applying.
2. **`github-actions-cicd.md` vs `templates/ci.yml`** — the guide documents an AWS OIDC deploy
   job, a `prod-*` tag trigger, and "`deploy` runs last". `ci.yml` has none of them (verified:
   grep for deploy/tags/OIDC/aws returns only a comment at `ci.yml:12-13` and two `-tags=` Go
   flags). `templates/Makefile:79-84` pushes a `prod-*` tag and prints "prod deploy triggered",
   which the shipped `ci.yml` cannot act on. The guide also claims Java 21 + Maven caching (no
   Java job exists) and an active `docker` Dependabot ecosystem (commented out at
   `dependabot.yml:39-48`). **Either the template is missing a deploy job or the guide is
   aspirational.** No lines cut until resolved.
3. **`provision-server.md:85-86` documents a command that fails.** Verified by execution: the
   `--dry-run` preview exits 1 with "ERROR: USER_PASSWORD is not set", because
   `setup-server.sh:83-86` requires `USER_PASSWORD` and has no dry-run exemption — unlike the
   root check at line 71, which does. `setup-server.sh:6`'s own usage header carries the same
   broken example. Fix needs either a `USER_PASSWORD` in the example or a `DRY_RUN` exemption in
   the guard.
4. **`maintenance.md:82` vs `docker-setup.md:69`** — `maintenance.md` prohibits `--volumes` on a
   stack with `postgres-data` and links to `docker-setup.md#prune-unused-resources`, which
   presents `docker system prune -af --volumes` with no warning. The reader lands on the exact
   command the referrer just banned.
5. **Plan-file location has three answers.** `AGENTS.md:97,101` says `plan.md` in the project
   root; `create-plan/SKILL.md:14,82` says `docs/plans/plan-<slug>.md`; `prune/criteria.md:100-102`
   treats both as valid. `docs/plans/` did not exist until this file was written.
   *This plan follows `distill/SKILL.md:218`, which specifies `docs/plans/plan-distill-<scope>.md`
   for plan-only runs — but that instruction is itself a party to the conflict.*
6. **`AGENTS.md:89-90` vs `check-repo.sh` `LANG_ALLOW`** — the doc says the only German-allowed
   file is `readability-de.md`; the script allow-lists two, the second being `claude/CLAUDE.md`
   (load-bearing: it contains an umlaut in the owner's surname). The documented rule and the
   enforced rule disagree.
7. **`.claude/rules/scripts.md:30` vs `claude/statusline.sh:6-8`** — the rule states
   `set -euo pipefail` is mandatory with no exception clause; the script documents a deliberate
   omission. The script's comment is the more valuable of the two, but an agent reading only the
   rule will "fix" the script.
8. **`install-dotfiles.sh:16-18` states a wrong reason.** It says the stock Codespaces `.bashrc`
   provides the git-branch prompt. `templates/.bash_aliases:74-76` and
   `dotfiles-codespaces.md:32-36` both say the handbook's own aliases file does, and overrides the
   stock PS1 by sourcing order. Two of three agree; the script comment is the outlier. Its
   *conclusion* (don't replace `.bashrc`) is right.
9. **Two mocking-boundary references disagree.** `tdd/mocking.md:6-18` lists four boundaries;
   `test-quality/evaluation-criteria.md:110-131` lists five (adding message queues / event buses)
   plus a four-row "do not mock" table. Neither links the other. Database mocking is hedged three
   different ways: "sometimes — prefer test DB" (`mocking.md:10`), "optional — prefer a real test
   DB" (`evaluation-criteria.md:118`), and listed flatly as a boundary to preserve mocks at
   (`test-quality/SKILL.md:105`). Phase 5 deletes the `evaluation-criteria.md` copy, which
   *resolves this by side effect* — confirm that is the intended direction.
10. **`monitoring.md:21` cites "PRD 1"**, which exists nowhere in the repo. The surrounding claim
    is true (`letsencrypt-docker.md:95-98` confirms the two decoupled loops); only the citation is
    dead residue from an uncommitted planning artifact.
11. **`claude-plugin.md:141` says 18 skills, `:111` says 22.** There are 22. Line 41's phrasing
    ("one skill per `.claude/skills/` dir") is the version-proof form and should be the survivor.
12. **`cheatsheets/git.md:100-104` documents aliases that are not installed** — resolved by the
    Phase 1 deletion, listed here for completeness.
13. **`.claude/rules/skills.md:21-27` vs `research/SKILL.md`** — the rule requires every `SKILL.md`
    to have a Constraints section; `research/SKILL.md` has none, and no H1 either. Either the rule
    is wrong or the file is. `check-repo.sh` does not enforce section presence.
14. **`.claude/rules/skills.md:59-60` vs three files** — the >100-line TOC rule is violated by
    `test-quality/anti-patterns.md` (280), `evaluation-criteria.md` (148) and
    `tutor/session-state.md` (111). Nothing enforces it mechanically.
15. **`finish-branch/SKILL.md:88-89` vs `AGENTS.md` Git** — `AGENTS.md` grants blanket push
    authority for feature branches; `finish-branch` gates the same action behind an explicit user
    pick. An agent loading both gets conflicting instructions on the push path.
16. **`templates/copilot-instructions.md` vs `copilot-agent-setup.md:231-242`** — two different
    skeletons for the same product file (`## Copilot-only notes` vs `## Rules`, different pointer
    sentences). Resolved by side effect in Phase 3, which deletes the guide's copy;
    `new-project.md:115` copies the template, confirming which is canonical.

## FLAGs — unverifiable from this session, not proposed for deletion

1. **`cheatsheets/makefile.md:86`** — `BRANCH := $$(git rev-parse --abbrev-ref HEAD)` under the
   heading "dollar signs must be doubled". As a *variable assignment* this does not invoke the
   shell; it assigns the literal string `$(git rev-parse …)`. The `$$` form is correct only inside
   a recipe, which is how `templates/Makefile:80` uses it. A variable assignment needs
   `:= $(shell …)`. Verified by reading both files; not executed. Phase 2 keeps the section — fix
   or delete it deliberately.
2. **`guides/go.md:71`** — renders as ``See [`.golangci.yml`](https://golangci-lint.run/…)``: the
   link text is a local filename, the target is external docs, and `find . -name '.golangci.yml'`
   has no hit anywhere in the repo. A reader will look for a file that does not exist.
3. **`.claude/agents/web-researcher.md:4`** — declares `mcp__context7`, but this session's live
   server prefix is `mcp__plugin_context7_context7`. `mcp__plugin_playwright_playwright` (also
   listed) *does* match. So the Context7 instruction at line 20 may point at a tool the agent
   cannot call. MCP server names differ per machine — needs one live check. Separately, the same
   line grants `Bash` and `Write` to an agent whose hard rule 5 forbids all outbound actions;
   `Bash` can curl/POST.
4. **`.claude/rules/*.md` all use a `paths:` frontmatter key.** Nothing in this repo documents the
   Claude Code rules frontmatter schema, and `git log` shows the mechanism landed in one commit
   (`4d1a7ec`) with no verification note. If the key should be `globs:` or `applyTo:`, all five
   files silently never load — which would also explain why nothing in this session surfaced them.
   Worth one live check *before* Phase 7 touches them.
5. **`guides/verification-drill.md` has never been executed** — the file says so at line 275, and
   git shows it added once on 2026-07-10 and untouched since. Every command in it is unverified
   against a live box, which is the inverse of the guides it orchestrates.
6. **`claude/statusline.sh:37`** — `# Colors (dim-friendly: bold white for separators, cyan for
   model, default for rest)` does not describe the block beneath it: no bold-white value exists
   (separators use `DIM`, `\033[2m`), and GREEN/YELLOW/RED are defined and used, so "default for
   rest" is wrong too. The *code* is self-consistent; the comment describes a superseded palette.
   Flagged rather than rewritten.
7. **`tdd/mocking.md:117-122`** — a "GOOD" Go helper whose body is a comment placeholder
   ("// seed via real constructor args, fixtures, or exported test hooks") that does not do what
   the comment describes; the returned `Service` has default state, so the example does not
   demonstrate its own point.
8. **`monitoring.md:83-91` embeds a permanently open TODO in a runbook.** It defers a live
   question ("is the free-plan SSL-expiry toggle actually free on your account?") to execution
   time and tells the reader to record the answer in that file. `verification-drill.md` Step 6.1
   points back at it — but no drill has ever run. Pending since 2026-07-09 with no closing
   mechanism. Kept (it is operative), but nothing will ever close it.
9. **Two dated external facts, both "verified 2026-07-09", both ~3 weeks stale and drift-prone:**
   the Hetzner CX23 hourly price (`verification-drill.md:27-31`, cut in Phase 3) and the Better
   Stack free-plan limits (`monitoring.md:50-54`, kept).
10. **`templates/nginx-tls.conf:6`** says "Let's Encrypt is retiring OCSP" in the present
    progressive. If the retirement has completed, the tense is wrong and the sentence reads as
    forward-looking when it is historical. Needs live verification — do not rewrite from memory.
11. **`.claude/settings.json` registers a Stop hook running `scripts/check-repo.sh`, documented
    nowhere.** `README.md:127` indexes "Claude settings + hooks" pointing at `claude/settings.json`
    (the dotfiles one), not at `.claude/settings.json`. A maintainer wondering why the repo
    self-check fires unprompted after every turn has nowhere to look. **A gap to fill, not
    something to cut** — noted because a distillation pass could easily make it worse.
12. **`docker-multi-stage-builds.md` has no Go example**, but `new-project.md:90-93` routes Go
    backends there ("the same two-stage pattern"), and the Troubleshooting entry Phase 3 keeps
    (`CGO_ENABLED=0`) is Go-specific. Not a contradiction; the file's own troubleshooting implies
    a stack it never demonstrates.

## Open questions

1. **`.github/copilot-instructions.md` — delete or keep at 6 lines?** Copilot is not used here,
   and `copilot-agent-setup.md:258` states this repo's own rule: "If there are no Copilot-only
   deltas, delete this file rather than duplicating AGENTS.md." After Phase 1 removes its prompts
   pointer, it has no deltas. But it is an agent instruction surface, so deletion needs explicit
   confirmation, and the case rests on `AGENTS.md:7`'s unverified claim that every Copilot surface
   reads `AGENTS.md` directly.
2. **`templates/copilot-instructions.md` and the Copilot half of `templates/AGENTS.md` — still
   shipped?** The user confirmed Copilot is unused *on this repo*, which is narrower than unused
   *anywhere*. `new-project.md:115` copies the template into every new project. Kept pending an
   answer.
3. **Does `CLAUDE.md:17-21` need to exist?** It is the third copy of the same three git rules
   (`AGENTS.md:107-110`, `claude/CLAUDE.md:44-45`), justified in-file by "survive compaction".
   Unverified that Claude Code drops imported `CLAUDE.md` content on compaction — `CLAUDE.md` is
   re-injected into the system context each turn, which would make the third copy unnecessary.
   Kept as a prohibition regardless.
4. **The Communication rule set has drifted across its three deliberate homes.**
   `templates/AGENTS.md` says "developer" where `AGENTS.md` says "user"; `claude/CLAUDE.md` has
   two rules the others lack. Reconciling them is an edit, not a deletion, so it is out of this
   plan's scope — but `anti-sycophancy.md`'s opening line, "Rules are linked, never restated; each
   lives in exactly one canonical place", is **false about its own catalog**.
5. **Should `guides/nginx-reverse-proxy.md` be dissolved?** After its trim it is two config
   snippets plus troubleshooting, and the two halves have natural homes elsewhere
   (`docker-multi-stage-builds.md:52` copies an `nginx.conf` it never shows;
   `letsencrypt-docker.md` owns reverse-proxy troubleshooting). Executing it eliminates a
   README-indexed file — a structure decision, not a distillation one.
6. **Should the corpus-wide "See also" convention be settled?** Every guide has one; every one
   relists links already inline. Either sweep them all or write the decision into
   `.claude/rules/guides.md`, which currently does not mention them.
7. **`.claude/skills/cleanup/` is five overlapping taxonomies.** Phases 4 cuts the duplication but
   keeps the shape. The cheaper structural fix — one defect catalogue plus one routing table
   instead of five files that each restate the others — is a redesign, not a distillation.
8. **RESOLVED — the no-rewrite constraint was changed after this plan was written.**
   `distill/SKILL.md`'s *"Never rewrite in your own voice. Subtract."* read as an absolute ban
   on producing text, while step 6 and `restructure.md` mandate authoring leaf scope headers,
   index rows and TOCs. It has been replaced by *"Rewrite freely; never invent or alter a
   claim."* — restyling, condensing and restructuring are allowed; every fact, command, flag,
   path, version and constraint must survive exactly as stated.
   **Three projections in this plan are now conservative** because they were written under the
   old rule and deliberately held back:
   - `test-quality/anti-patterns.md` (Phase 5, ~115) — the ~40-line signal→why→fix table form
     is now permitted.
   - `tdd/interface-design.md` (Phase 5, 40) — held at TRIM only because deleting it would
     require inlining a sentence into each of its three referrers. That is now allowed, so
     DELETE is viable.
   - `test-quality/SKILL.md` step 1 Discover (Phase 5, ~88) — can collapse further.
   Re-derive these three before applying Phase 5. Do **not** assume the change licenses deeper
   cuts anywhere else: every other projection in this plan was already limited by the keep-bar
   or by an inbound link, not by the rewrite rule.
9. **`readability-de.md` is the more complete catalogue.** It carries four slop categories with no
   English counterpart, three of which are not German-specific: knowledge-cutoff hints, false
   extension ("from X to Y"), and formatting tells (bold overuse, emoji headings).
   `distill/criteria.md:110` names the *English* `readability.md` as canonical — so the canonical
   file is the weaker of the two.

## Out of scope

**`templates/vscode-settings.json`.** The user indicated it is not relied on as shipped, and
~100 of its 184 lines are an auto-generated `explorer.fileNesting.patterns` blob (Bazel, Tauri,
Godot, Svelte, Flutter, LaTeX, .NET) plus clearly personal keys —
`vsicons.dontShowNewVersionMessage`, `claudeCode.preferredLocation`,
`workbench.preferredLightColorTheme: "Dark 2026"`, `chat.tools.urls.autoApprove` for
`http://localhost:8889`, `chat.tools.terminal.autoApprove` for java/mvn/sdk. It reads as a
user-settings export, not a workspace template, and `new-project.md:51` copies it verbatim into
every new repo.

**Trimming it is a config change, not a prose change**, and this skill does not touch code or
configuration values. Phase 8 removes only its one pseudo-comment key. Reducing it to an actual
workspace template is a separate task.

## Next step

This plan was produced by `/distill`, which decided **what to keep** — it never checked whether
what it kept is **true**. Those are different questions with different sources.

Run [`/verify-docs`](../../.claude/skills/verify-docs/SKILL.md) in a **fresh session** after this
plan is applied. Do not run it in the session that produced this plan: a session cannot audit its
own output.
