# Plan: Distill and clean up the handbook

> Source PRD: n/a — `/distill` + `/cleanup` analysis run, 43 agents (13 analysts, 26 adversarial reviewers, 3 sweeps, 1 architect), decisions taken by Nico on 2026-09-02.

## Goal

Cut the prose corpus from 10,729 to roughly 6,900 Markdown lines (about −36%) without losing a rule, command, path, version or constraint that has no other home. Every surviving line names a reader and what breaks without it. Duplicated rules get one canonical home; the rest link to it.

## Architectural decisions

- **Loader map** (verified against `scripts/install-dotfiles.sh`, `guides/copilot-agent-setup.md`, `guides/claude-plugin.md`, `.claude-plugin/plugin.json`):
  - L1 Claude Code on Nico's machine, handbook repo: `~/.claude/CLAUDE.md` (= `claude/CLAUDE.md`) + `CLAUDE.md` → `@AGENTS.md` + `.claude/rules/*.md` on path match + skills.
  - L2 Claude Code on Nico's machine, any other repo: `~/.claude/CLAUDE.md` + `~/.claude/skills` + `~/.claude/agents` only. Never `AGENTS.md`, never `.claude/rules`.
  - L3 Claude cloud session on the handbook: repo files only; never `claude/CLAUDE.md`.
  - L4 Copilot (every surface): `AGENTS.md`; never `.claude/rules`, never `claude/CLAUDE.md`, never `output-style.md`.
  - L5 project built from `templates/`: the copied `AGENTS.md` only.
  - L6 plugin consumer: `.claude/skills/**` and `.claude/agents/**` only, on demand.
- **Canonical homes** (everything else links): caps + banned list + report shape → `.claude/skills/output-style.md`; ask gate → `.claude/skills/clarify/question-rules.md`; verification budget → `.claude/skills/verification-depth.md`; scope guard, verify-before-done, supersede check → `.claude/skills/quality.md`; memory rule → `.claude/skills/reflect/targets.md`; model routing → `.claude/skills/dispatching-parallel-agents/SKILL.md` § Model routing (distill and implement-plan keep their per-stage tables); deep-module design checklist → `.claude/skills/write-prd/SKILL.md` step 5; worktree detection → `.claude/skills/using-git-worktrees/SKILL.md` steps 1-2; git hazards → `.claude/skills/implement-plan/integration.md` § Hazards; concurrent sessions → `.claude/skills/parallel-sessions/SKILL.md`.
- **Deliberate duplicates that stay** (a loader reaches nothing else): caps + tone + git rules in `AGENTS.md` (L3, L4), in `claude/CLAUDE.md` (L2), in `templates/AGENTS.md` (L5).
- **Pointers from `claude/CLAUDE.md`** use `~/.claude/skills/<path>` — repo-relative paths resolve nowhere in L2.
- **Comment beats doc**: where a script or template comment and a guide explain one mechanism, the guide section dies (`.claude/skills/distill/criteria.md` § Code and config comments).
- **Line references** in this plan are pinned to commit `fad62ea` (`git show fad62ea:<path> | cat -n`). `AGENTS.md` and `templates/AGENTS.md` gained one Communication bullet after that commit — map those two by content.
- **Changed after the pin by the upstream distill commit `d1967d6`** (diff `fad62ea..HEAD` before mapping): the five `.claude/rules/*.md`, `dispatching-parallel-agents/SKILL.md` (gained § Model routing), `distill/parallelism.md`, `implement-plan/SKILL.md`, `implement-plan/orchestration.md`, `guides/audiobook-pipeline.md`, `guides/copilot-agent-setup.md`, `guides/maintenance.md`.

## Inventory

- `scripts/check-repo.sh — check_links(), check_readme(), check_skills(), check_prose()` — the gates; `make check` runs all. Anchors are stripped before the link test, so heading renames are never caught by CI.
- `scripts/check-repo.sh — INDEX_DIRS, LANG_ALLOW, PARA_ALLOW` — index dirs, German-allowed files, paragraph-cap exemptions.
- `README.md` — index of guides, cheatsheets, templates, scripts, agent setup; `.claude/skills/README.md` — skills index (`make skills` parses its `](name/)` links).
- `guides/anti-sycophancy.md` — registry mapping each tone rule to its file; must be updated wherever a home moves.
- `guides/bootstrap.md` — scenario router; links `#verify` and `#inputs` anchors in guides.

## Resolved decisions

- **Audience**: (b) Nico plus his agents; plugin consumers read `.claude/skills/**` and `.claude/agents/**`. Public readers and template adopters are not a keep reason. An `audience-sensitive` note "would be KEEP for (c)/(d)" does not protect a cut; "would be DELETE/GUT for (a)" does not deepen one.
- **Model-known procedures are derivable**: debugging loop, TDD loop, code-exploration steps, DDD glossary steps, refactoring catalogue. Those skills keep only constraints, calibration and the artifact contract.
- **Off-limits**: `cheatsheets/` is not deleted (trimmed instead). Everything else listed below is approved.
- **Mode**: apply; one final commit `docs: distill handbook` per phase group is acceptable, FLAGs go in the commit body of the landing commit.
- **Execution routing**: every phase worker runs on `sonnet` with `effort: 'high'` — each row names the file, the lines and the keepers, so the work is fully specified; `effort: 'low'` is too cheap for line-range edits with keep lists. Reviewers, the Phase 1 probe and post-fold verification run on `opus`. This overrides implement-plan's default of `opus` for phase implementation.
- **Conflict resolutions** (both locations were reported; Nico approved these):
  - Scope guard: `templates/AGENTS.md` § Quality Principles adopts `quality.md` wording — finish the scope, name the out-of-scope change in the report; never stop to ask.
  - "Ask instead of assuming" (`AGENTS.md` § Working rules, `templates/AGENTS.md` § Boundaries) → one bullet: decide before you ask; `AGENTS.md` links `.claude/skills/clarify/question-rules.md`.
  - Banned trailers in `claude/CLAUDE.md` gain `Claude-Session: …`.
  - `claude/CLAUDE.md`: "never `--no-verify`" applies to any git command, not only push.
  - `claude/CLAUDE.md` § Model tiers drops "at high or xhigh effort" (`claude/settings.json` pins it).
  - `AGENTS.md` § Language names three German-bearing files: the two skill files plus `claude/CLAUDE.md` (matches `LANG_ALLOW`).
  - `guides/claude-plugin.md` § Verify: `claude plugin details` verifies a first install; `claude plugin list` (installed SHA) verifies an update. `guides/bootstrap.md` plugin row follows.
  - React data fetching: hooks orchestrate calls through the service layer; no raw `fetch` in components or hooks. Stated once.
  - `.claude/skills/cleanup/cross-layer.md` "Align the other layers": in cleanup's repo-wide mode the misaligned layers are reported; in guided-implementation the developer aligns them.
  - Rule of Three wording ("second or third use case") in `cleanup/principles.md` § YAGNI.
  - `distill/` spells the marker `audience_sensitive` everywhere; the worker return block gains `read_in_full`.
  - `implement-plan/SKILL.md` step 2 strips the `origin/` prefix from the detected base branch, like `finish-branch` step 2.
  - `prune/SKILL.md`: "without asking" and "do not ask first" are scoped to a user-invoked `/prune`; the model-invoked path keeps "confirm intent first".
  - Mock boundary: prefer a real test DB; mock the driver only when none is available (`test-quality/SKILL.md` § Constraints, `test-quality/anti-patterns.md` row 2).
  - `guided-implementation/SKILL.md` step 1 "ask which story" → resolve by reading first; ask only when two or more candidates survive the gate.
  - `test-quality/SKILL.md` § Constraints: "Never keep call-count or argument-order assertions on internal methods" (a REFACTOR that verifies via output is allowed).
- **Verified corrections allowed** (tool output from the analysis session, not invention): `agent-bus.sh peers` prints `No other live session is working in this repo.` when alone (the "empty output" clause is false in `claude/CLAUDE.md` and `parallel-sessions/SKILL.md`); web-researcher's `mcp__context7` tool grant matches nothing — the tools are `mcp__plugin_context7_context7__query-docs` and `__resolve-library-id`; `terms.yml` lines are `term: chapter-file.md` (`scripts/check-terms.sh`); `templates/docker-compose.prod.yml` usage line needs `-p <project>`; `templates/claude-settings.json` has three keys, not two.

## Open questions / Risks

- **FLAGs — never edited by this plan; the landing commit body lists each with its `file:line`:**
  - `CLAUDE.md` § Non-negotiables: does `/compact` drop the `@AGENTS.md` import while keeping the host file? If not, the section is a triplicate.
  - `templates/vscode-settings.json`: personal settings or shared template? Auto-approve lists, `security.workspace.trust.untrustedFiles: open`, 102-line file-nesting dump.
  - `templates/Makefile`: prod targets lack `-p $(PROJECT)` that `scripts/prod-init.sh` uses; `db`/`db-shell` address a service `templates/docker-compose.yml` ships commented out; `check` passes on TODO echoes.
  - `templates/devcontainer.json` `postCreateCommand` runs `setup-dev-tools.sh`, which aborts without Go and Node and with an unreplaced `<project-go-version>`.
  - `.claude/skills/implement-plan/integration.md` landing mutex uses `git update-ref`, denied by `claude/settings.json`; git pin 2.47.3 there, in `using-git-worktrees/SKILL.md` and `finish-branch/SKILL.md` (installed: 2.53.0).
  - `.claude/skills/prune/state-map.md`: pin 2.1.224 (installed 2.1.258; `file-history/`, `tasks/`, `debug/` absent); claims a `--days` default the script does not have.
  - `guides/provision-server.md`: `--image debian-12` vs "Debian 13 `main`".
  - `guides/monitoring.md` free-plan SSL-expiry callout (unresolved assumption, kept).
  - `guides/postgresql-operations.md` § Verify checks `backup-*.dump` in the cwd while cron writes to `/opt/backups/postgres`; `guides/bootstrap.md` gates on it.
  - `guides/ipv6-only-vps.md` host IPv6 table: unsourced external facts.
  - `guides/letsencrypt-docker.md` `curl -4` fails on an IPv6-only host.
  - `.claude/skills/tutor/question-design.md` "Recall" format is not in `session-state.md`'s schema.
  - `scripts/md-to-epub.sh` vs `guides/audiobook-pipeline.md`: three different claims about a missing `meta.yml`.
  - `.claude/skills/tdd/mocking.md`: two Go examples are wrong; file untouched.
  - `.claude/skills/cleanup/readability-de.md`: no German corpus in the repo; the audiobook Round C (the one German producer) never loads it. Keep or wire in?
  - `.claude/skills/dispatching-parallel-agents/SKILL.md` cost figure is unsourced.
  - `.claude/skills/receiving-feedback/SKILL.md` names a stack (Go, React/TS, sqlc) the global context says is not yet provided.
  - Code strings (out of scope for a docs pass): `scripts/check-terms.sh` die() says "step 6" (skill says 7); `scripts/setup-server.sh` prints `guides/docker-setup.md` twice; `scripts/check-repo.sh` INDEX_DIRS keeps `cheatsheets` (stays valid); `scripts/agent-bus.sh` help path has no test assertion.
- **Dissolved by this plan**: `d1967d6` reported a conflict between `cheatsheets/docker-compose.md` (`down -v` with a neutral comment) and `docker-setup.md`'s volume prohibition — Phase 6 deletes that Common Commands block and Phase 4 makes `guides/maintenance.md` the canonical prohibition.
- **Risk**: anchors. `make links` never checks `#fragments`. Every phase that removes a heading greps the repo for the anchor and reports hits outside its files to Phase 15.

## Apply method (binding for every phase)

- Read the target file with `cat -n` and confirm each plan range by content before cutting; edit bottom-up.
- **Never invent a claim.** Restyle, condense, merge and reorder surviving prose; add no fact, command, flag, path, version or rule. The corrections listed under Resolved decisions are the only additions.
- "→ link" means one line: the trigger plus a relative link that resolves from the file's directory (`test -e`). GUT means rebuild the file from the listed survivors in their original order.
- No debris: no lead-in ending in a colon, no empty heading, no TOC row for a removed section, no in-file anchor to a removed heading, no bullet TOC on a reference file under 100 lines.
- Compression removes words, never a rule, condition, exception or caveat; over-long sentences are split.
- MERGE deduplicates while moving; the source is then deleted. Delete with `git rm`.
- Fix inbound links inside the phase's own files; report hits in other files (`grep -rn`) to Phase 15.
- Scripts and templates: comment lines only. FLAG items are not edits.
- Gate per phase: `scripts/check-repo.sh links` and `scripts/check-repo.sh prose` clean for the phase's files.

---

## Phase 0: Shared-contract additions

**Depends on**: none — landed already (see git log for the commit touching these four files).

### Acceptance criteria

- [x] `.claude/skills/output-style.md` § Report shape carries rules 5 ("Never manufacture findings") and 6 ("No social filler").
- [x] `.claude/skills/clarify/question-rules.md` § The ask gate carries "Applies to every skill and every subagent, `AskUserQuestion` included."
- [x] `AGENTS.md` and `templates/AGENTS.md` § Communication carry "Compression removes words, never a rule, condition, exception or caveat."

---

## Phase 1: Global instruction surfaces

**Depends on**: Phase 0. Review tier: gate plus one adversarial probe (every session loads these files).

### Context

- `claude/CLAUDE.md` — installed as `~/.claude/CLAUDE.md` on every repo (L1, L2).
- `AGENTS.md` — the only always-on surface for L3 and L4.
- `.github/copilot-instructions.md` — a third caps copy; its one unique line moved in Phase 0.

### What to build

| File | Action | Cut (pinned lines) | Keep / change |
| --- | --- | --- | --- |
| `claude/CLAUDE.md` | GUT → ~95 lines | L59-62 (banned-preamble stated twice → one bullet); L85-93 § Decide before you ask → trigger bullet + `~/.claude/skills/clarify/question-rules.md`; L103-111 § Autonomy → keep the levers bullet and the wake-up bullet, drop the rest; L112 drop "at high or xhigh effort"; L118-119 motivational sentence; L136-150 § Verification → two bullets (tier by blast radius; gate runs once) + `~/.claude/skills/verification-depth.md`; L151-156 § Memory → one bullet + `~/.claude/skills/reflect/targets.md`; L157-161 § Research → keep L159-160 verbatim, rest → `~/.claude/agents/web-researcher.md` pointer; L162-169 § Concurrent sessions → peers, announce, radar bullets + `~/.claude/skills/parallel-sessions/SKILL.md` § Subagent routing L118-135 → the sonnet and opus one-liners, the Fable-only-on-explicit-instruction rule, and a pointer to `~/.claude/skills/dispatching-parallel-agents/SKILL.md#model-routing`; the mechanics bullets L132-135 go | Keep in full: Who I am, Company context, Code Conventions incl. No shortcuts, Communication Style, Never end a turn (L94-102), Model tiers, No outbound. Corrections: L35 "never `--no-verify`" unscoped; L37 add `Claude-Session: …`; L163 replace the false "empty output means you are alone" with the verified banner text. |
| `AGENTS.md` | TRIM | L15 (agents-field note; `guides/claude-plugin.md` owns it); L19 self-falsifying meta line; L21 folded into L31 as "Read `README.md` first; update it after every add, remove or rename"; L44 "Keep files concise" | L33-34: keep the `grep -r` rule, add "`make links` checks file targets only". § Working rules "Ask instead of assuming" → decide-before-ask bullet linking `.claude/skills/clarify/question-rules.md`. § Language names three exception files. |
| `CLAUDE.md` | KEEP | — | FLAG (compaction). |
| `.github/copilot-instructions.md` | DELETE | whole file | Update `AGENTS.md` surface table row and `guides/copilot-agent-setup.md` layer table (Phase 3 owns that guide — report the hit). |

### Acceptance criteria

- [x] `claude/CLAUDE.md` ≤ 100 lines; every pointer inside it starts with `~/.claude/` and resolves on this machine; `grep -c "Claude-Session" claude/CLAUDE.md` = 1; the string "empty output" is gone.
- [x] `AGENTS.md` has no line "Each rule is stated once", no v2.1.197 note, one README rule, three Language exceptions, and a decide-before-ask bullet linking the ask gate.
- [x] `.github/copilot-instructions.md` is deleted and `AGENTS.md` no longer lists it as a surface.
- [x] `scripts/check-repo.sh links` and `prose` clean for the three files.

---

## Phase 2: Instruction stack — templates, rules, shared contracts, agent

**Depends on**: Phase 0.

### What to build

| File | Action | Cut | Keep / change |
| --- | --- | --- | --- |
| `templates/AGENTS.md` | TRIM | § Boundaries: "Verify before claiming" and "Never guess" bullets → one; § Quality Principles L118-119 restated sentence; § Git Workflow L149 "Commit messages:" label → "Commit:" | § Boundaries "Ask instead of assuming" pair → one decide-before-ask bullet; § Quality Principles scope guard → `quality.md` wording; add one bullet: after `gh pr create`, re-read the PR body and strip an injected trailer. Keep the L60-61 comment ("Agents follow examples more reliably than written rules"). |
| `templates/copilot-instructions.md` | DELETE | whole file | `guides/new-project.md` step 5 loses the `cp` line and the "delete if no deltas" bullet (Phase 5 owns it — report). README row goes (Phase 15). |
| `.claude/rules/cheatsheets.md` | KEEP | — | caps already collapsed to one link by `d1967d6` |
| `.claude/rules/guides.md` | TRIM | L23 "Open by naming the file a stack-convention guide" | caps already collapsed by `d1967d6` |
| `.claude/rules/scripts.md` | TRIM | L30 (`set -euo pipefail` repeats the header) | L28: keep the quoting clause; append "`make lint` (shellcheck) catches a subset". |
| `.claude/rules/skills.md` | TRIM | L12-17 ASCII tree; L67-69 → "`make skills` verifies the index in both directions" | caps already collapsed by `d1967d6` |
| `.claude/rules/templates.md` | KEEP | — | caps already collapsed by `d1967d6` |
| `.claude/skills/verification-depth.md` | TRIM | Anti-pattern rows L92-95 (restate the body); TOC L9-16 once the file is under 100 lines | Fold L96 ("resume the author") into § A finding that recurs / § Mechanise, and L97 ("`ultracode` deepens a tier, never raises it") into § The tier is what a late catch costs. |
| `.claude/skills/clarify/SKILL.md` | TRIM | L17-18 (restates frontmatter); L32-33 (restates question-rules "Stop when resolved") | Keep L12-13 and L40-41. |
| `.claude/agents/web-researcher.md` | TRIM | L7-8 motivational lines; L38-52 caps table, banned list, generic report shape | Replace the Output block with the research-specific rules only (counts line with verified/not-verified, per-claim sources, as-of date, open-questions section, target file, prose stays in the response) plus a link `../skills/output-style.md`. Fix the `tools:` grant to the two verified Context7 tool names. |
| `.claude/skills/output-style.md` | TRIM | L58 enforcement sentence (Makefile owns) | Keep the Named prose exceptions table. |

### Acceptance criteria

- [x] `templates/copilot-instructions.md` deleted; `templates/AGENTS.md` carries the quality.md scope guard, one decide-before-ask bullet and the PR-trailer strip bullet.
- [x] No `.claude/rules/*.md` contains "≤ 20 words"; each keeps its file-naming section.
- [x] `.claude/skills/verification-depth.md` has no Anti-patterns table and no TOC, and still contains "resume the author" and "deepens".
- [x] `.claude/agents/web-researcher.md` has no `| Sentence |` table row, links `../skills/output-style.md`, and its `tools:` line names `mcp__plugin_context7_context7__query-docs`.
- [x] `scripts/check-repo.sh links` and `prose` clean for the phase's files.

---

## Phase 3: Handbook-meta guides and repo config

**Depends on**: none.

### What to build

| File | Action | Cut | Keep / change |
| --- | --- | --- | --- |
| `guides/claude-plugin.md` | TRIM | L6-10 two-tier framing (keep the one link to `dotfiles-codespaces.md`); L14-16, L23 derivable inventory; L64-68 (Codespaces opt-out mirror → one bullet "created by `scripts/install-dotfiles.sh`") | Keep L17-20 and L41-49. L49 "two keys" → three keys incl. `includeCoAuthoredBy`. § Verify: `details` = first install; `plugin list` = update. L43 gains "(not verified)" for the Claude-web load path — the hedge moves here from the skills README. |
| `guides/copilot-agent-setup.md` | GUT → ~60 | everything not listed under keep; "formerly `mode:`"; L65-70 (restates § Cross-tool compatibility) | Keep: L1-5 minus the "2,500+ repositories" appositive; the layer table L11-18; precedence L20-25; the when-to-add table L35-41; § Cross-tool compatibility L43-57; L71-72 applyTo/excludeAgent; the Locations table L84-91; L97-102 (second symlink for Copilot CLI); L119-125 (.chatmode.md warning, naming/description/30k constraints); L133-134 (IDE-only preview, not loaded by cloud agent or CLI); L117 (`.agent.md` reach); L140-142. Drop the `.github/copilot-instructions.md` row from the layer table (deleted in Phase 1). |
| `guides/dotfiles-codespaces.md` | TRIM | L5 (compulsive triple), L8, L30-31, L34-37 | Keep L10-14 (sourcing-order why) and L32-33 (accepted entrypoint names). |
| `guides/unattended-agents.md` | TRIM | L26; L42-46 → one line pointing at the global rule; L64-76 hook JSON → the pointer at L78 plus the read command at L79 | Keep the measurement table L32-40. |
| `.devcontainer/devcontainer.json` | TRIM | L15 "Pinned to major :1." sentence; L29 comment | — |
| `.gitignore` | TRIM | L1 parenthetical "(mirror of .git/info/exclude)" | — |

### Acceptance criteria

- [x] `guides/copilot-agent-setup.md` ≤ 70 lines and still contains "chatmode", "IDE-only", "~/.agents/skills".
- [x] `guides/claude-plugin.md` says "three keys", has one Verify command per scenario, and the string "Personal config is deliberately excluded" survives.
- [x] `guides/unattended-agents.md` has no `PermissionDenied` JSON block and keeps "67 idle stretches".
- [x] `scripts/check-repo.sh links` and `prose` clean for the phase's files.

---

## Phase 4: Server-ops guides

**Depends on**: none.

### What to build

| File | Action | Cut | Keep / change |
| --- | --- | --- | --- |
| `guides/provision-server.md` | GUT → ~90 | L5-9 prerequisites; L27-29 (cloud-init.yml carries the SECURITY note); L66-80 manual SSH pipe fence (mirrors `setup-server.sh` usage header); L128-146 sshd drop-in (byte-identical to the script); L152 stale ufw line; L165-175 dotfiles clone (mirrors `install-dotfiles.sh` header); L182-188 See also | Keep § Inputs (anchor used by bootstrap), L60-61 netcup fact, the hcloud create block, § Verify block and table, L159 alias→package mapping, L177-179 tmux sentence. FLAG debian-12 vs 13 untouched. |
| `guides/ipv6-only-vps.md` | GUT → ~60 | L10-25 host table (keep only the conclusion L26); L59-72 daemon.json (script writes it); L76-82 RFC 6724 argument (script comment owns it); L78, L82 slop; L123-127 See also | Keep step 1 DNS64 resolvers with the trust trade-off L47-51, L84-92 facts, § Limits, § Verify. |
| `guides/docker-setup.md` | DELETE | whole | Move the clause "Deleting a volume needs a human decision, never an agent's" into `guides/maintenance.md` § prune callout. Report inbound hits: README, `provision-server.md`, `ipv6-only-vps.md`, `docker-multi-stage-builds.md`, `.claude/rules/guides.md` naming example, `scripts/setup-server.sh` printed strings (FLAG). |
| `guides/letsencrypt-docker.md` | GUT → ~55 | Steps 1-2 (transcription of `scripts/prod-init.sh`); L75-80 Auto-Renewal (compose comments own it); L88-93 preamble; L118-123 See also; L8 ports prerequisite (provisioning opens them); Inputs rows that restate their placeholder | Keep § Inputs anchor with the `<project-name>` and `CERT_PING_URL` rows, L55-57 shared `-p` rule, § Automation pointer to `prod-init.sh`, § Verify L86-105, L110-112 expiry check. FLAG `curl -4` untouched. |
| `guides/nginx-reverse-proxy.md` | DELETE → new `templates/nginx-spa.conf` | whole guide | New template: header comment with the copy destination and the L5-6 why (the reverse-proxy template does not carry the SPA container's config), then the two config blocks verbatim. Report inbound hits: README, `letsencrypt-docker.md`, `bootstrap.md`. |
| `guides/maintenance.md` | TRIM | L133-145 tmpfs diagnosis → pointer to the `setup-server.sh` comment; L225-230 → one line; L232-240 See also | The prune callout (a link to `docker-setup.md` since `d1967d6`) is rebuilt as the canonical `--volumes` prohibition: carry `guides/docker-setup.md` § prune L16-19 (`fad62ea`) verbatim, including "needs a human decision, never an agent's"; L67-68, L175, L237 retarget "provision-server.md" attributions to `scripts/setup-server.sh`. |
| `guides/monitoring.md` | GUT → ~85 | L54-58 vendor sign-up; UI click paths L67-68, L89, L106, L136; steps 3-5 prose (fold period/grace values into the ping-URL table as a column); L167-182 troubleshooting; L184-191 See also | Keep L9-23 dead-man model, L25-34 table, L44-47, L59-61, L74-83 callout (FLAG, kept verbatim), L108-116 grace rationale, § Verify L146-165. L133 → "pings only when `report-health.sh`'s three conditions hold". |

### Acceptance criteria

- [x] `guides/docker-setup.md` and `guides/nginx-reverse-proxy.md` are deleted; `templates/nginx-spa.conf` exists with both blocks; `guides/maintenance.md` contains "never an agent's".
- [x] `guides/provision-server.md` ≤ 100 lines with `## Inputs` and `## Verify` intact; no `00-hardening.conf` heredoc.
- [x] `guides/ipv6-only-vps.md` ≤ 70 lines with no `"fixed-cidr-v6"` block; `guides/letsencrypt-docker.md` ≤ 65 lines with no `certonly` fence; `guides/monitoring.md` ≤ 95 lines with the L74-83 callout intact.
- [x] `scripts/check-repo.sh links` and `prose` clean for the phase's files; inbound hits outside the phase reported.

---

## Phase 5: Project-ops guides, CI template, postgres cheatsheet

**Depends on**: none.

### What to build

| File | Action | Cut | Keep / change |
| --- | --- | --- | --- |
| `guides/postgresql-operations.md` | TRIM | L3-4; L29-32 and L47-50 plain-SQL pair (tooling only produces `-Fc`); L84-86 (script header owns it); L92, L103, L107; L176-181; L205-209 command inventory; L217-229 migration template; § 6 Monitoring queries (moves to the cheatsheet); L264-266; L271-273 See also | Keep L108-109 disaster-path warning, § Verify (FLAG on the cwd gate, untouched), § Troubleshooting `pg_terminate_backend` and `migrate force` entries. |
| `cheatsheets/postgresql.md` | TRIM + absorb | L3-10 psql Connection | Absorb the cache-hit query with a `-- should be > 99%` comment. |
| `guides/verification-drill.md` | DELETE | whole | Report README:26 hit. |
| `guides/docker-multi-stage-builds.md` | GUT → ~55 | L3; stage banners L8, L18, L22, L36, L49; L29-31; L57-58; L61-73; L80-85 | Keep both Dockerfiles, L32 `-DskipTests` note, L59 `.dockerignore` line, L75-77 musl entry. Report `guides/new-project.md` Go two-stage claim as FLAG. |
| `guides/github-actions-cicd.md` | DELETE | whole | The `actionlint .github/workflows/ci.yml` line becomes one header comment in `templates/ci.yml`. Report inbound hits: README, `new-project.md`, `go.md`/`java-spring-boot.md`/`react.md` (Phase 6 merges them — they retarget to `templates/ci.yml`). |
| `guides/new-project.md` | GUT → ~95 | L3-6 preamble (keep L7 back-link); L10-13 prerequisites; L47; L57-59 Makefile bullet; L81-85; L100-104; L114-115, L118-120 (keep L116-117 anti-sycophancy link); L130-133; L146-154 See also; the `cp templates/copilot-instructions.md` line and its bullet | Keep § Inputs table with all rows, repo-create commands L34-43, stack matrix L66-72, every `cp` block, § Verify. Step 5 link to `copilot-agent-setup.md` stays. |
| `templates/ci.yml` | TRIM | L24 "Only run jobs whose files actually changed" | Add header comment: `# Validate locally before pushing: actionlint .github/workflows/ci.yml`. |

### Acceptance criteria

- [x] `guides/verification-drill.md` and `guides/github-actions-cicd.md` deleted; `templates/ci.yml` header names `actionlint`.
- [x] `cheatsheets/postgresql.md` contains "99%" and no `psql -h`; `guides/postgresql-operations.md` has no "Monitoring Queries" section and keeps "restore into the production database".
- [x] `guides/new-project.md` ≤ 105 lines with `## Inputs`, the stack matrix and `## Verify` intact; `guides/docker-multi-stage-builds.md` ≤ 60 lines with both `FROM` chains.
- [x] `scripts/check-repo.sh links` and `prose` clean for the phase's files; inbound hits reported.

---

## Phase 6: Stack conventions merge and cheatsheet trims

**Depends on**: none.

### What to build

| File | Action | Content |
| --- | --- | --- |
| `guides/stack-conventions.md` | NEW (~80 lines) from `go.md`, `java-spring-boot.md`, `react.md` | One H1, one scope line, three `##` sections. **Go**: the domain-not-layer tree, the `domain/` import ban, the one-build-tag-per-file rule with the `unit`/`integration` tags `templates/ci.yml` depends on, `database/migrations/` + sqlc directory paths, "`t.Fatalf` for setup failures, `t.Errorf` for assertions". **Java**: the start.spring.io selection list, the four-layer table, `./mvnw verify` as the single gate stated once, "Spotless (google-java-format, AOSP) + Checkstyle" as one line, Flyway never-modify-existing-migrations, the test-tool-per-layer table, "constructor injection is what makes unit tests work without Spring". **React**: the feature-not-type tree, explicit return types on non-trivial functions, Zod at the API boundary stated once, shadcn/ui + `cn()`, Vitest + testing-library + `src/test/`, feature components next to their page / promote to `components/` when shared, co-locate helpers, the resolved fetch rule (hooks orchestrate service calls; no raw `fetch` in components or hooks). Dropped: L3 openers, version pins, linter tables and tool lists (templates own them), `---` separators, sqlc workflow prose, generic testing rules. |
| `guides/go.md`, `guides/java-spring-boot.md`, `guides/react.md` | DELETE | after the merge; report inbound hits (README ×3, `new-project.md` matrix, `docker-multi-stage-builds.md`). |
| `cheatsheets/unix-commands.md` | GUT | keep the `find -prune -o -print` line, the `[n]ginx` trick, the jq sort-then-diff recipe with their headings; cut the rest. |
| `cheatsheets/tmux.md` | TRIM | cut Sessions block L11-16, L35 mouse line, L44-46; keep the lingering block L18-31, the copy-mode table, L47 `tmux source-file`. |
| `cheatsheets/docker-compose.md` | TRIM | cut § Common Commands L15-28; keep Port Binding and Project Name. |
| `cheatsheets/makefile.md` | TRIM | cut § Syntax L3-10 and L18; keep the `$$` recipe rule and the `VAR := $$(cmd)` trap. |

### Acceptance criteria

- [x] `guides/stack-conventions.md` exists (≤ 90 lines) with `## Go`, `## Java`, `## React` and contains "constructor injection", "-tags", "cn()", and exactly one fetch rule; the three source guides are deleted.
- [x] Each cheatsheet is shorter than at `fad62ea` and still contains its keeper (`-prune`, `enable-linger`, `127.0.0.1`, `$$(`).
- [x] `scripts/check-repo.sh links` and `prose` clean; inbound hits reported.

---

## Phase 7: Template comments

**Depends on**: none. Comment lines only.

### What to build

| File | Cut | Keep / change |
| --- | --- | --- |
| `templates/.bash_aliases` | L60 history summary comment; L76 "Skipped when no git prompt helper" sentence | everything else |
| `templates/.tmux.conf` | L20 title gloss | L3, L13 stay |
| `templates/.editorconfig` | L17 "Java, Python – 4-space convention" | — |
| `templates/devcontainer.json` | L2 template-instance sentence; L25 first sentence; L30 | — |
| `templates/docker-compose.prod.yml` | L4-7 prerequisites; L111-112 (restates the dead-man note) | L9-10 usage gains `-p <project>` |
| `templates/docker-compose.initial-cert.yml` | L8-11 usage steps | keep L2-3, L5-6, L12 pointer |
| `templates/nginx-initial-cert.conf` | L2 copy line; second sentence of L4 | keep the `default_server` why |
| `templates/nginx-tls.conf` | L8, L21, L64 narrating comments | L4-6 and the server-block banners stay |
| `templates/cloud-init.yml` | L5-8 (guide owns the two paths) | keep L4, L10-12, L16-17 |
| `templates/setup-dev-tools.sh` | L5 | — |
| `templates/.env.example` | L1; first clause of L20 | keep L2, L4, L19-24 |

### Acceptance criteria

- [x] `git diff --stat` for the phase shows comment lines only; `docker compose -f templates/docker-compose.prod.yml --env-file templates/.env.example config -q` still passes; `make compose` green.
- [x] `templates/docker-compose.prod.yml` usage line contains `-p`.
- [x] `make lint` green.

---

## Phase 8: Script comments

**Depends on**: none. Comment lines only; program output strings are code.

### What to build

| File | Cut | Keep / change |
| --- | --- | --- |
| `scripts/prod-init.sh` | L63 banner | L35 comment scoped "in this script" |
| `scripts/backup-postgres.sh` | L30 Colors banner; the "3." in L79; the cron parentheticals at L8 and L12 | L40 copy stays |
| `scripts/install-dotfiles.sh` | L106; L128; L84-86 → the citation plus the ordering fact | — |
| `scripts/agent-bus.sh` | L14-19; L160 | L4-13 is program output — never touch |
| `scripts/check-repo.sh` | "focused" in L18; L49; the trailing comments on PARA_ALLOW entries L37-42 | L18 keeps "marks the run as failed" |
| `claude/statusline.sh` | L3-4 output map; L19, L25, L31; the "bold white" parenthetical in L37 | L52 stays |
| `Makefile` | second sentence of L1; the file-glob parenthetical in L13 | — |
| `scripts/md-to-epub.sh` | L27 separator; L48-49 | header stays; L108-109 untouched (FLAG) |
| `scripts/check-terms.sh` | L60, L67; second sentence of L31 | L28 untouched (FLAG, code string) |

### Acceptance criteria

- [x] `make lint`, `make test-agent-bus`, `make test-prune`, `make test-plan-run-guard` green.
- [x] `scripts/agent-bus.sh` with no arguments still prints the Usage block.
- [x] `git diff` shows no change outside comment lines.

---

## Phase 9: cleanup skill

**Depends on**: Phase 0.

### What to build

| File | Action | Cut | Keep / change |
| --- | --- | --- | --- |
| `cleanup/SKILL.md` | TRIM | L45-47; L95-98 → one line linking `../output-style.md#report-shape`; L119-120 | L86 table cell split into two sentences; L72-78 and L103-111 both stay. |
| `cleanup/readability.md` | TRIM | L6-7, L9, L59; bare tells L20-21, L24-25, L36-42, L52-54 | Keep calibration L22-23, L26-27, L29-30, L43-44, L46-57 (Deep Nesting stays — anchor target). |
| `cleanup/readability-de.md` | TRIM | L3 one-entry TOC, L19, L21 (promote `###` to `##`); L5-17 → two lines keeping the mixed-language rule | Keep L48-51, L105-106, L192-195. |
| `cleanup/code-smells.md` | TRIM | L7-8, L10, L47, L145, L14-17 stub | Keep L113-143. |
| `cleanup/architecture.md` | TRIM | L3-5; near-tautological tells L13-14, L22-24, L47-49, L96-99; every other tell compressed to one line | Every "Do NOT flag when" block intact under its heading. |
| `cleanup/principles.md` | TRIM | L10, L18, L37, L48 separators | L3-5 → one sentence keeping all nine principle names; L14 → Rule of Three. |
| `cleanup/cross-layer.md` | TRIM | L8, L22; L26 | L3 names both consumers; L30-35 reworded per the resolved conflict. |

### Acceptance criteria

- [x] `cleanup/SKILL.md` has no "Never manufacture findings" line and links `../output-style.md#report-shape`; `readability.md` keeps `### Deep Nesting`; `code-smells.md` keeps "Over-Engineered Error Messages"; `architecture.md` keeps every "Do NOT flag".
- [x] `readability-de.md` has more than one `##` heading and no lone TOC line.
- [x] `scripts/check-repo.sh links` and `prose` clean for the phase's files.

---

## Phase 10: distill and verify-docs skills

**Depends on**: none.

### What to build

| File | Action | Cut | Keep / change |
| --- | --- | --- | --- |
| `distill/SKILL.md` | TRIM | L40-42; trailing rationale sentence of L164; L183 folded up; L271-277 → four bullets (keep 271, 272, 275, 276) | Keep L249-250. `audience-sensitive` → `audience_sensitive` at L90, L146, L170. |
| `distill/criteria.md` | TRIM | L89-92; the enumeration after the link in L107-109; L21 merged into L20; the ranking in L128 | Keep L133. |
| `distill/restructure.md` | TRIM | first clause of L18; L20-22; L100 | Keep L23 and all three table rows. |
| `distill/parallelism.md` | TRIM → ~85 | L46, L50, L55 (restate dispatching); L72-76; L86-87 → cite dispatching's cap; L91-95 Workflow mechanics; L104 folded; L38-39 and L52-54 (restate SKILL.md) | Keep the § Model routing lead-in (links dispatching since `d1967d6`), the per-stage table, and every `##` heading (foreign anchors). Return block gains `read_in_full: true|false`; `audience_sensitive` spelling. Drop TOC if under 100 lines. |
| `verify-docs/SKILL.md` | TRIM | L140-141; L213-214 → link | Keep L33-35, L133-139. |
| `verify-docs/sources.md` | TRIM | L77-78 → one bullet | — |

### Acceptance criteria

- [x] `grep -rn "audience-sensitive" .claude/skills/distill` returns nothing; `parallelism.md` contains `read_in_full` and all six original `##` headings.
- [x] `distill/SKILL.md` keeps "cannot audit its own output" and "Surviving exactly as stated".
- [x] `scripts/check-repo.sh links` and `prose` clean for the phase's files.

---

## Phase 11: plan skills

**Depends on**: none.

### What to build

| File | Action | Cut | Keep / change |
| --- | --- | --- | --- |
| `implement-plan/SKILL.md` | TRIM | L17; L71-72; L82-83; L84-85; L90; L113-119 → link `../output-style.md#report-shape`; L123-124; L195-196; L197-199 | Step 2 strips `origin/`. Keep L73-76 and L182-193. |
| `implement-plan/orchestration.md` | GUT → ~115 | L38-42; L94-99 tier table; L113-116; L122-125; L144-151; L162-169 table (the link to dispatching above it, added by `d1967d6`, stays); L176-228 and L239-245 (the bundled `workflow-authoring` skill is canonical) | Keep L34-37, L44-75, L77-87, L91, L101-103, L107-108, L127-143, L230-237, L246-247; fix TOC and in-file links. |
| `implement-plan/integration.md` | TRIM | L69 | FLAGs untouched. |
| `implement-plan/recovery.md` | TRIM | L58-60; L110 | — |
| `create-plan/SKILL.md` | TRIM | L21, L22, L29-30, L48-51, L102, L126; L93-98 → one line linking `../implement-plan/SKILL.md` step 10 | Keep L39-42, L46-47, L52-53. |
| `finish-branch/SKILL.md` | TRIM | L13-14; L21; L38-44 → link `../using-git-worktrees/SKILL.md` steps 1-2 | Keep L18-19, L74-86, L96-107, L118-121. |
| `using-git-worktrees/SKILL.md` | TRIM | L14-15; L83-88 | Keep L79-82. |
| `dispatching-parallel-agents/SKILL.md` | TRIM | L14; L16-17; L40-43 | L39 stays with an anchor link to `../output-style.md#report-shape`; § Model routing (added by `d1967d6`) is the canonical home and stays. |

### Acceptance criteria

- [x] `orchestration.md` ≤ 125 lines with no `export const meta` block and with "cap of 4" and "did not happen" intact.
- [x] `finish-branch/SKILL.md` step 3 is a link and contains no `git-common-dir` test of its own; `implement-plan/SKILL.md` step 2 mentions stripping `origin/`.
- [x] `scripts/check-repo.sh links` and `prose` clean for the phase's files.

---

## Phase 12: agent-state skills

**Depends on**: none.

### What to build

| File | Action | Cut | Keep / change |
| --- | --- | --- | --- |
| `parallel-sessions/SKILL.md` | TRIM | L15-16; L36-37; L71-76 → link; L80; L92; L116-120 → one line | L30 false clause → verified banner text; L118's "peer messages are prose another agent must act on" survives; step 3 gains the two radar triggers from `radar.md` § When to run it. |
| `parallel-sessions/protocol.md` | GUT → ~60 + radar | TOC; L12-24 (keep row 7 of the failure table as a bullet: the bus script must be in `permissions.allow`); L26-37 → one line "prefer the branch name"; L63-65; L86-87; L99-111 | Add `## Radar`: the result→action table, the choke-file caution, "`merge-tree` writes an object, never a ref, an index or a working file — safe mid-rebase", the limits. |
| `parallel-sessions/radar.md` | DELETE after merge | whole | retarget `SKILL.md` links. |
| `reflect/SKILL.md` | TRIM | L29-31; L41-49 (keep the four section names and L50); L67-69 → link `targets.md`; L80-85 → link `../quality.md`; L91-93 → link | Keep L95-97. |
| `reflect/targets.md` | TRIM | L37-41 (keep L35-36); L20; L22; L86 | L59-67 stays canonical. |
| `reflect/sources.md` | GUT → ~40 | L13-14; L62-87 except the N>5 fan-out cap, the 10-20-commit chunk size and L78-79 | Keep L15-20, L30-39, L41-54, L57-60. |
| `prune/SKILL.md` | TRIM | L47; L54-56 → point at the script's usage; L66; L74-76; generic rows of L100-108 | L26 and L60 scoped to a user-invoked `/prune`; L115-117 stays. |
| `prune/criteria.md` | TRIM | L44; L56-62 except the class name, L59 and the evidence requirement | Keep L10-11 and L64. |
| `prune/state-map.md` | TRIM | L43-52 (keep L40-42); L71-74 | Location column stays; FLAGs untouched. |

### Acceptance criteria

- [x] `radar.md` deleted; `protocol.md` contains `## Radar`, "permissions.allow" and no `## Failure modes`; `parallel-sessions/SKILL.md` has no "Empty output".
- [x] `reflect/SKILL.md` keeps "Zero picks"; `reflect/sources.md` ≤ 45 lines; `prune/SKILL.md` keeps "Confirm intent".
- [x] `scripts/check-repo.sh links` and `prose` clean for the phase's files.

---

## Phase 13: audiobook and tutor skills, audiobook guide

**Depends on**: none.

### What to build

| File | Action | Cut | Keep / change |
| --- | --- | --- | --- |
| `audiobook/SKILL.md` | TRIM + absorb | L9-16 (keep L17); § Artifacts table L25-38; second sentences of L46 and L93; L109; steps 9-12 reduced to round name, scope and the `review-rounds.md` link (keep the `check-terms.sh` invocation); L121 | Step 4 absorbs from `the-checkpoint.md`: the placement why (L17-19), the three prior-knowledge levels (L35-36), the never-ask table (L43-49), how-to-ask (L53-57), BRIEF.md fields (L63-66), L68-69, L73-77 — deduplicated against the existing step-4 text. Where the terms.yml format is stated, it reads `term: chapter-file.md`. |
| `audiobook/review-rounds.md` | TRIM | L3-8 TOC; L60 | — |
| `audiobook/the-checkpoint.md` | DELETE after merge | whole | — |
| `audiobook/german-narration.md` | TRIM | L3-8; four surplus gloss rows in L31-36 (keep one plain noun and the chunking row); L51-52; L57; L59; L71-73 → one bullet | — |
| `audiobook/listenability.md` | TRIM | L3-7; L10-11; L20-22; L37-39; L56-57; L63-64 | Keep L58 ("Never trim, summarise, or merge chapters"). |
| `guides/audiobook-pipeline.md` | GUT → ~70 | everything not listed | Keep L12-19, L21-36, L40, L115-119, L126, L130-135, L137-143, L153-160, L170, L182; the Verify filter path points at `templates/strip-visuals.lua` via the handbook checkout. The link to `the-checkpoint.md` added by `d1967d6` dies with the GUT (the file is merged away in this phase). |
| `tutor/SKILL.md` | TRIM | L17-18; L20; L21-23; L24-26 → one link `../output-style.md#named-prose-exceptions`; L144-145 | Constraints L120-126 stay. |
| `tutor/session-state.md` | TRIM | L3; L84-86; L99-101 → link `question-design.md` | L106 keeps "rephrased (same concept, new surface)". |
| `tutor/question-design.md` | TRIM | L4-5; L49; meaning column of L64-70; L72-74 | L12/L18 untouched (FLAG). |

### Acceptance criteria

- [x] `the-checkpoint.md` deleted; `audiobook/SKILL.md` step 4 contains "new to the domain" and "Never write chapters before step 7"; `grep -c "chapter-file.md" .claude/skills/audiobook/SKILL.md` ≥ 1.
- [x] `guides/audiobook-pipeline.md` ≤ 80 lines and keeps "hand-written", "jgm/pandoc/releases", "-t plain /dev/null".
- [x] `scripts/check-repo.sh links` and `prose` clean for the phase's files.

---

## Phase 14: dev-practice skills

**Depends on**: Phase 0.

### What to build

| File | Action | Cut | Keep / change |
| --- | --- | --- | --- |
| `tdd/SKILL.md` | GUT | the red-green-refactor narrative, the ASCII block L24-34, the refactoring table L73-82, L66-67, L89-91, L102 | Keep frontmatter, links L11-12, "Confirm it fails for the EXPECTED reason", "passes AND all other tests still pass, with clean output", L50-52, Constraints L87-96; L44-46 → one link to `../write-prd/SKILL.md` step 5. |
| `tdd/mocking.md` | KEEP (FLAG) | — | — |
| `test-quality/SKILL.md` | TRIM | L32; L50-51; L52 → link `../output-style.md#report-shape`; L84; L97 | L67 boundary list → prefer a real test DB; L85-86 → call-count wording. |
| `test-quality/anti-patterns.md` | absorb `evaluation-criteria.md` | — | First section: the ordered decision tree and the Coverage Loss Protocol; each row keeps Signal/Why/Fix; numbering runs 1-8 in reading order; row 2 adopts the test-DB wording; L51 emoji → bold keyword. |
| `test-quality/evaluation-criteria.md` | DELETE after merge | whole | retarget `test-quality/SKILL.md`, `guided-implementation/SKILL.md`, `tdd/SKILL.md`. |
| `systematic-debugging/SKILL.md` | GUT | steps 1-10 | Keep frontmatter, L12 attribution, the parallel-agents link L56, Constraints L76-93 plus two bullets folded in: the won't-reproduce method (L26) and the boundary definition (L35); L97 → bare link. |
| `receiving-feedback/SKILL.md` | TRIM | L15-16; L44; L48; L53 → link; L63 | L36 untouched (FLAG); L52 stays. |
| `understand/SKILL.md` | GUT | steps 1-5 except the listed keepers; L13-15; L79-80 → link `../output-style.md#named-prose-exceptions`; L115-116 Quality section | Keep the ask gate L19-21, ADR paths L60-61, the cross-layer bullet L50-51, the outline L85-91, L93-95 stated directly ("Anchor explanations with code snippets; use Mermaid for relationships"), Constraints L99-111, the output-style link. |
| `guided-implementation/SKILL.md` | TRIM | L14-16; step 2 L37-45; L53-54, L57; L95-98 → link `../write-prd/SKILL.md`; L100 → link `../cleanup/code-smells.md#redundant-abstractions`; L109-111 → bare link; L159 | L25 → gate wording; keep L51-52, L55-56, L58-61, the briefing table, stop-and-wait, 5a/5b heading/5c, the gate, L122-124, L133-140. |
| `write-prd/SKILL.md` | TRIM | L45-50 → link the gate; L70; L147 | Keep L55-59 (canonical), L138-141. |
| `ux-review/SKILL.md` | TRIM | L11; L18-20; L52; L54-56; L66-68; L53 → link | — |
| `ubiquitous-language/SKILL.md` | GUT | L15-19 steps; table L29-36; L21-22 (keep L27); L88 | Keep frontmatter, the output path, the worked example L38-72, Constraints L76-83, the output-style link. |
| `research/SKILL.md` | DELETE (and the directory) | whole | `.claude/skills/README.md` row goes in Phase 15. |

### Acceptance criteria

- [x] `evaluation-criteria.md` and `research/` deleted; `anti-patterns.md` contains "Coverage Loss" and a decision tree; no skill in the phase still contains "manufacture" (all link the report shape).
- [x] `tdd/SKILL.md` ≤ 45 lines, `systematic-debugging/SKILL.md` ≤ 40, `understand/SKILL.md` ≤ 60, `ubiquitous-language/SKILL.md` ≤ 60; each keeps its Constraints.
- [x] Exactly one file states the deep-module checklist (`write-prd/SKILL.md`); `tdd` and `guided-implementation` link it.
- [x] `scripts/check-repo.sh links` and `prose` clean for the phase's files.

---

## Phase 15: Indexes, registry, link sweep, gate

**Depends on**: Phases 1-14.

### What to build

- `README.md`: remove rows for every deleted file; add `guides/stack-conventions.md` (Stack conventions table) and `templates/nginx-spa.conf`; drop the "Using this handbook (start here)" row (L3 keeps the entry point); move the anti-sycophancy row into Agent Setup; drop the Agent Setup rows that restate `AGENTS.md`'s surface table (Canonical instructions, Claude Code entrypoint, Copilot instructions, Repo devcontainer); drop the `(links, shellcheck, …)` parenthetical in the check-repo row.
- `.claude/skills/README.md`: GUT to the H1, one bullet (vendoring skills into `.github/skills/` is deliberately avoided), the When-to-Use table minus the Research row, and the final "Adding a new skill" line.
- `guides/bootstrap.md`: L5; L58-59 and L81-83 → bare anchor links; New project section → two lines; remove rows for deleted guides; plugin verify row follows the resolved decision.
- `guides/anti-sycophancy.md`: L3 → registry, not a stack-convention guide; L5, L6, L27-34; re-point every row whose home moved (report shape → `output-style.md`; per-skill zero-findings variants now links; deleted skills removed).
- Every hit reported by Phases 1-14 under "inbound links" is retargeted or removed; `grep -rn` for each deleted filename returns nothing outside `docs/plans/`.
- `make check` green.

### Acceptance criteria

- [ ] `make check` exits 0.
- [ ] `grep -rln -e docker-setup.md -e nginx-reverse-proxy.md -e verification-drill.md -e github-actions-cicd.md -e copilot-instructions.md -e evaluation-criteria.md -e the-checkpoint.md -e radar.md -e 'guides/go.md' -e java-spring-boot.md -e 'guides/react.md' -e research/SKILL.md . --exclude-dir=.git --exclude-dir=docs` returns only `scripts/setup-server.sh` (FLAG).
- [ ] `git ls-files '*.md' | xargs wc -l | tail -1` reports ≤ 7,500 total lines.
- [ ] `guides/anti-sycophancy.md` names no deleted file and points the report-shape rules at `.claude/skills/output-style.md`.

## Run state

| Field | Value |
| --- | --- |
| Base | main 3408ffb88e12b3e20819eebecadb7a019bc560c5 |
| Run branch | plan/distill-handbook |
| Worktrees | /home/nico/r/handbook/.worktrees/plan-distill-handbook-p1 -> plan/distill-handbook-p1 -> phase 1 |
| Worktrees | /home/nico/r/handbook/.worktrees/plan-distill-handbook-p2 -> plan/distill-handbook-p2 -> phase 2 |
| Worktrees | /home/nico/r/handbook/.worktrees/plan-distill-handbook-p3 -> plan/distill-handbook-p3 -> phase 3 |
| Worktrees | /home/nico/r/handbook/.worktrees/plan-distill-handbook-p4 -> plan/distill-handbook-p4 -> phase 4 |
| Worktrees | /home/nico/r/handbook/.worktrees/plan-distill-handbook-p5 -> plan/distill-handbook-p5 -> phase 5 |
| Worktrees | /home/nico/r/handbook/.worktrees/plan-distill-handbook-p6 -> plan/distill-handbook-p6 -> phase 6 |
| Worktrees | /home/nico/r/handbook/.worktrees/plan-distill-handbook-p7 -> plan/distill-handbook-p7 -> phase 7 |
| Worktrees | /home/nico/r/handbook/.worktrees/plan-distill-handbook-p8 -> plan/distill-handbook-p8 -> phase 8 |
| Worktrees | /home/nico/r/handbook/.worktrees/plan-distill-handbook-p9 -> plan/distill-handbook-p9 -> phase 9 |
| Worktrees | /home/nico/r/handbook/.worktrees/plan-distill-handbook-p10 -> plan/distill-handbook-p10 -> phase 10 |
| Worktrees | /home/nico/r/handbook/.worktrees/plan-distill-handbook-p11 -> plan/distill-handbook-p11 -> phase 11 |
| Worktrees | /home/nico/r/handbook/.worktrees/plan-distill-handbook-p12 -> plan/distill-handbook-p12 -> phase 12 |
| Worktrees | /home/nico/r/handbook/.worktrees/plan-distill-handbook-p13 -> plan/distill-handbook-p13 -> phase 13 |
| Worktrees | /home/nico/r/handbook/.worktrees/plan-distill-handbook-p14 -> plan/distill-handbook-p14 -> phase 14 |
| Worktrees | /home/nico/r/handbook/.worktrees/plan-distill-handbook -> plan/distill-handbook -> phase 15 |
| Next criterion | phase 1 criterion 1 |
| Verify | `bash /tmp/claude-1000/-home-nico-r-handbook/86c00fac-b80f-4d9c-b0b1-44051be02085/scratchpad/phase-gate.sh <worktree> 3408ffb88e12b3e20819eebecadb7a019bc560c5` per phase; `make check` at phase 15 |
| Workflow | scriptPath=/tmp/claude-1000/-home-nico-r-handbook/86c00fac-b80f-4d9c-b0b1-44051be02085/scratchpad/implement-plan-distill-group.js runId=wf_c3edbfa6-24b |
