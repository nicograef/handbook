# Handbook Overhaul — Implementation Plan

Status: proposed. Executed by parallel Opus agents. Every work package is self-contained: it
names the file, the change, and what to change it to. Shared edit patterns live once in
**Global conventions** — every WP references them by number. Findings are tracked by ID (e.g.
`IS-3`) in the **Finding coverage** table; source audit files are not required to execute a WP.

---

## 1. Goal

Rework the handbook's agentic-coding surface so it matches verified 2026 best practice
(`research/agentic-coding-insights.md`) and resolves all 139 audit findings. Make **AGENTS.md**
the single canonical instruction file, move `skills/`, `agents/`, and `commands/` into `.claude/`
so every Claude Code and Copilot surface discovers them, replace the 17× duplicated skill rituals
and duplicated cross-file rules with single-sourced content, de-escalate and de-scaffold every
skill for current models, add a real verification loop (`make check` + a `git push` guard hook),
and fix the concrete script/guide/cheatsheet bugs. Work lands on `main` in incremental
conventional commits (no AI-attribution trailers, no push). English only; `theory/*.md` German
content stays untouched.

---

## 2. Target architecture

### 2.1 Instruction surface (canonical AGENTS.md)

- **AGENTS.md = canonical rules** for every Copilot surface and (via import) Claude Code. It
  absorbs the ask-first / verify-before-claiming / web-search rules currently only in AGENTS.md,
  the Git rule, the plan-first workflow, and the repo-consistency rules — each stated **once**
  (kills the internal 3× README-rule / no-duplication repetition). *(research §1 AGENTS.md
  interop, §5 end-state 1; IS-1, IS-12, ST-3)*
- **CLAUDE.md** shrinks to first line `@AGENTS.md` plus only Claude-only deltas (the `grep`/`find`
  search block, a `/compact` steering line, and the always-on non-negotiables that must survive
  compaction: no-auto-commit, no `--force`/`--no-verify` push). Root-project CLAUDE.md content is
  re-injected on compaction, so these belong here, not in a path-scoped rule. *(research §1
  compaction survival, §5 end-state 2; IS-1)*
- **`.github/copilot-instructions.md`** shrinks to Copilot-only deltas: a pointer to
  `.github/prompts/` and `.github/instructions/`, and the note that AGENTS.md already carries the
  shared rules. No rule from AGENTS.md is restated (Copilot sends both files combined). *(research
  §5 instruction files; IS-5, CP-3)*
- **Per-directory conventions become path-scoped rules.** Create `.claude/rules/<dir>.md` with
  `paths:` frontmatter mirroring the existing `.github/instructions/*.instructions.md` `applyTo`
  globs — one canonical text per directory, loaded only when Claude touches matching files. Remove
  the per-directory "Content Conventions by Directory" block from CLAUDE.md and the Conventions
  bullets from AGENTS.md. *(research §1 path-scoped rules; IS-6)* We keep BOTH surfaces
  (`.claude/rules/` for Claude, `.github/instructions/` for Copilot) because neither tool reads the
  other's location; the two files per directory share identical body text.

### 2.2 Directory moves

- `skills/` → `.claude/skills/` and `agents/` → `.claude/agents/` via `git mv`. Top-level
  `skills/`/`agents/` are invisible to every Copilot surface and to Claude Code repo discovery;
  `.claude/` is read by Claude Code natively and by VS Code Copilot. *(research §5 end-state 4-5;
  ST-7, CP-4)*
- `commands/` is **merged into skills**, not moved: `commands/commit.md` →
  `.claude/skills/commit/SKILL.md` (add `disable-model-invocation: true` — side-effect flow, zero
  token cost, still `/commit`), `commands/research.md` → `.claude/skills/research/SKILL.md` (thin
  wrapper delegating to the `web-researcher` agent). Then delete `commands/`. *(research §1 skills:
  commands merged into skills; ST-8, IS-13, PF-3)*
- `research/agentic-coding-insights.md` and `theory/` stay in place.

### 2.3 Enforcement hooks + settings

- Add a **PreToolUse hook on Bash** in `claude/settings.json` that exits 2 (blocking) when the
  command contains `git push` together with `--force`, `-f`, `--force-with-lease`, or `--no-verify`
  anywhere in the string (regex, not prefix). Keep the existing `permissions.deny` prefix rules as
  defense in depth and add `--no-verify`/flag-last variants there too. *(research §1 hooks: convert
  must/never prose into PreToolUse hooks; IS-8)*
- Add `"$schema": "https://json.schemastore.org/claude-code-settings.json"` as the first key.
  *(research §1 settings; IS-14)*
- Commit the pending live `"model": "Fable"` diff (WP0). Change the hardcoded statusline command
  to `bash "$HOME/.claude/statusline.sh"`. *(ST-14)*

### 2.4 Repo self-check (verification loop)

- Add `scripts/check-repo.sh`: (a) markdown link check (every relative link resolves on disk),
  (b) `shellcheck` on `scripts/*.sh` and `install.sh`, (c) README-vs-filesystem index diff (every
  tracked doc file appears in the README index and vice-versa), (d) language check (no non-ASCII
  German prose outside `theory/` and the two allow-listed German-example files). **Silent on
  success (exit 0, no output); focused errors + exit 2 on failure.** *(research §4 docs repos need
  a synthetic check; success is silent; IS-11)*
- Add a root **`Makefile`** with `make check` running `scripts/check-repo.sh`, plus `make links`,
  `make lint`, `make readme` as the individual checks. Makefile-as-dev-interface. *(research §4
  standard commands are the agent interface)*
- Wire `scripts/check-repo.sh` as a **Stop hook** in a new committed project
  `.claude/settings.json`, so a session cannot end with broken links / failing shellcheck /
  README drift. *(research §4 wired as a Stop hook; IS-11)*

**Rejected — evals infrastructure.** Research §1 recommends per-skill `evals/evals.json` with
graded runs and should-trigger/should-not-trigger prompts. **Deferred/rejected for this repo:** a
personal handbook of ~17 skills does not justify standing eval infra; the cost/benefit is negative
versus the `make check` synthetic loop, which already gives a pass/fail gate. Revisit only if
skills start mis-triggering in practice (the trigger to do it later). *(PF-1 area, research §1
evals)*

**Rejected — devcontainer/sandbox hardening changes.** Research §1 sandbox/devcontainer guidance is
reference material; the repo's `templates/devcontainer.json` is out of audit scope (no finding).
No change.

### 2.5 Symlink strategy

`~/.claude/settings.json` and `~/.claude/skills` are live symlinks into this repo. After the moves:

- `install-dotfiles.sh` `CLAUDE_LINKS` source paths change: `agents`→`.claude/agents`,
  `skills`→`.claude/skills`, remove the `commands` entry, keep `claude/CLAUDE.md`,
  `claude/settings.json`, `claude/statusline.sh` targets.
- Add a **second skills symlink** `~/.agents/skills → <repo>/.claude/skills` (Copilot CLI reads
  `~/.agents/skills`, not `~/.claude/skills`), creating `~/.agents` first. *(research §5 personal
  skill locations; IS-10, ST-9, CS-6)*
- Add an `~/.claude/agents → <repo>/.claude/agents` link so the `web-researcher` agent is available
  in Claude Code (it currently only works via a manual symlink). *(IS-15)*
- The live `~/.claude/skills` symlink must be **retargeted** from `<repo>/skills` to
  `<repo>/.claude/skills` inside WP1 (the same work package that does the `git mv`), so the live
  environment does not break. Retarget the live `~/.claude/CLAUDE.md` German→English edit too
  (it is symlinked to `claude/CLAUDE.md`, so editing the repo file suffices). *(IS-2, ST-13)*

### 2.6 Skills portfolio end-state (merges / deletes / fixes)

- **Merge** `code-audit` into `cleanup` as an explicit repo-wide scope mode; keep its Step-1
  cross-layer trace as `cleanup/cross-layer.md`; delete `.claude/skills/code-audit/`. *(PF-6,
  RV-5)*
- **Trim, do not delete** `dispatching-parallel-agents`: cut the harness-native dispatch
  restatement (step 3), keep the independence check, four-part delegation contract, and collision
  check; mark `user-invocable: false`. *(PF-9, PR-7, PR-14 — overrides the brief's "delete
  dispatching-parallel-agents"; see §5 deviations)*
- **Fix** `using-git-worktrees` auto-commit → non-committing ignore via `info/exclude`. *(PR-1)*
- **Fix** `finish-branch` worktree failure (worktree-aware merge/delete path) and base-branch
  detection. *(PR-2, PR-5)*
- **Give `ux-review` a real Workflow** (scope → render at mobile viewport via Playwright MCP when
  available → walk flows → map to file:lines → report; static-only fallback). *(RV-2, SP-3)*
- Migrate `commit` and `research` commands into skills (§2.2).

---

## 3. Global conventions

These patterns are applied across many files. Each WP references them by number (**GC-n**). Apply
them exactly.

- **GC-1 — Slim `quality.md` to its contract.** Reduce `.claude/skills/quality.md` to two sections
  only: **Scope guard** (unchanged) and **Verify before claiming done**, the latter reworded to the
  official anti-fabrication phrasing: *"Before reporting work as complete, audit each claim against
  a tool result from this session; only report work you can point to evidence for. For code
  changes: name the exact test/build/lint command, run it fresh this turn, and cite its output. For
  document artifacts: re-read the final file and confirm every link and path it references exists."*
  Delete the **Principles** section and the 6-item self-review checklist (compensation scaffolding /
  self-grading skews positive). *(PR-3, PL-9, RV-6)*
- **GC-2 — Quality section only where files change.** A `## Quality` section linking `../quality.md`
  belongs ONLY in skills that produce code or documents (cleanup, tdd, create-plan, write-prd,
  implement-plan, guided-implementation, test-quality, ubiquitous-language, understand,
  systematic-debugging, receiving-feedback). REMOVE the Quality link from the process-only skills
  whose destructive-op Constraints are already the contract: `finish-branch`, `using-git-worktrees`,
  `dispatching-parallel-agents`. Run the checklist **once per result**, never per-step/per-briefing.
  *(PF-1, PR-4, PL-12, RV-13-analog)*
- **GC-3 — Commit epilogue lives once.** DELETE the sentence *"After task completion, propose a
  conventional commit message plus a short human-readable summary…"* from all 10 skill files that
  carry it (cleanup, create-plan, guided-implementation, implement-plan, receiving-feedback,
  systematic-debugging, tdd, test-quality, ubiquitous-language, write-prd). It is already covered
  by the canonical AGENTS.md Git rule and user-global CLAUDE.md; do not re-add it to `quality.md`.
  *(PL-10, PR-11)*
- **GC-4 — De-escalate emphasis.** Downgrade `CRITICAL`, `MUST`, `ALWAYS`, `DO NOT`, `IMPORTANT:`,
  and "never skip because it looks simple" to plain conditionals ("Use this when…", "If X, do Y").
  Replace blanket anti-laziness clauses with proportionality clauses. *(research §2 de-escalate;
  PR-9, GU/CP emphasis findings)*
- **GC-5 — Cut compensation scaffolding, keep contract scaffolding.** Remove micro-step
  decomposition, per-cycle self-verify checklists, "summarize after N tool calls", redundant
  negative-form constraints that restate workflow steps, and sycophancy-suppression bullets. KEEP
  output schemas, scope guards, idempotency rules, destructive-op gates, and evidence-before-claim
  rules. *(research §2; PL-6, PR-10, PR-13, RV-12, RV-13, CP-14)*
- **GC-6 — No reasoning-echo.** Remove any instruction to "show/transcribe your thinking". Ask for
  a rationale of the *result* instead. *(research §2 Fable 5 reasoning_extraction)*
- **GC-7 — Third-person description voice.** Skill `description:` first sentences use third-person
  verbs ("Reviews…", "Audits…", "Guides…", "Explores…"), never imperative or noun phrases, keeping
  the trigger keywords. *(research §1 descriptions; SP-7)*
- **GC-8 — Zero-findings is valid + adversarial self-check (review-shaped skills only).** Every
  review/report skill (cleanup, ux-review, test-quality, understand, and the merged code-audit
  mode) states: *"Zero findings is a valid outcome — if nothing survives the criteria, report that
  the code is clean and stop; do not manufacture findings."* and inserts a verification pass before
  reporting: *"Re-read each flagged location; drop any finding you cannot anchor to exact lines or
  that does not hold on re-read; mark remaining uncertainty as unverified."* Replace fixed finding
  quotas ("the 3–5 most impactful", "-40%") with "up to N". *(research §6 constrain reviewers; RV-1,
  RV-3, RV-7, RV-8)*
- **GC-9 — Single-source shared blocks (no duplication).** Extract each block duplicated across
  skills into ONE canonical file and replace copies with a one-line relative link:
  - Clarification question rules → `.claude/skills/clarify/question-rules.md` (canonical);
    create-plan and write-prd link it. *(PF-5, PL-2)*
  - Deep-module definition → `.claude/skills/tdd/interface-design.md` (add the definition there);
    write-prd and guided-implementation link it. *(PL-15)*
  - Testing doctrine (mock boundaries, behavior-vs-implementation) → `test-quality/evaluation-criteria.md`
    canonical; tdd, guided-implementation §5 link it. *(PF-7)*
  - Cross-layer consistency checklist → `cleanup/cross-layer.md` (from merged code-audit); the
    cleanup repo-wide mode links it. *(RV-5)*
  - Skill-consumption matrix → `.claude/skills/README.md` canonical; root README links it. *(ST-10,
    PF-8, SP-2)*
  - Within `cleanup/`, each rule (Deep Nesting, single-impl interface, pure-delegation wrapper)
    lives in exactly one reference file; duplicates become one-line cross-refs. *(RV-4)*
- **GC-10 — Reference-file TOC.** Every bundled skill reference file over 100 lines starts with a
  short bullet TOC of its `##` headings, directly under the H1. *(research §1 progressive
  disclosure; SP-4, PL-14)*
- **GC-11 — Concrete bars over qualitative ones.** Replace "important", "too small", "below the
  fold", "extensive", "LONG" with measurable definitions (e.g. touch targets < 44×44 CSS px or
  < 8px spacing; primary action not visible at 375×667 without scrolling). *(research §2 literal
  following; RV-8, PL-11)*
- **GC-12 — Tool-agnostic + one-term-per-concept.** No hardcoded tool parameter names
  (`allow_multiple: true` → "allow selecting multiple options when more than one applies"); use one
  consistent name for the structured-question tool across all skills. *(PL-8)*
- **GC-13 — Skill frontmatter field is `allowed-tools`, not `tools`.** `tools:` is subagent-only.
  Skill validation: `name` ≤64 chars, lowercase/numbers/hyphens, matches directory name;
  `description` non-empty ≤1024 chars, no XML tags. Document `disable-model-invocation` /
  `user-invocable` / `argument-hint` as the optional invocation-control fields. *(research §1
  skills; IS-4, ST-2, SP-1, SP-5, CP-1, PF-2)*
- **GC-14 — Markdown meta-comments use `<!-- -->`, never `#`.** In templates and prompts, guidance
  comments are HTML comments so they neither render as headings nor reach the model as content.
  *(CP-9)*
- **GC-15 — Version pins (grep-update all occurrences).** Canonical current versions to apply
  repo-wide (verified 2026-07-09): Go `1.26`; nginx `1.30-alpine`; certbot `certbot/certbot:v5.6.0`;
  GitHub Actions majors `actions/checkout@v7`, `actions/setup-java@v5`,
  `aws-actions/configure-aws-credentials@v6`, `golangci/golangci-lint-action@v9`,
  `pnpm/action-setup@v6`, `dorny/paths-filter@v3`→`@v4` (keep `setup-go@v6`, `setup-node@v6`);
  pnpm pin `pnpm@10`. *(GU-3, GU-5, GU-6, GU-7, GU-15)*
- **GC-16 — Language exception list.** The English-only rule's exception in AGENTS.md and the
  `.claude/rules`/`.github/instructions` files reads: *"Exception: `theory/` files, and the German
  example phrases in `.claude/skills/cleanup/readability-de.md` (its explanatory prose stays
  English)."* *(SP-6, RV-10)*

---

## 4. Work packages

Legend: **[sequential]** must run alone in order; **[parallel-safe]** may run concurrently with
other parallel-safe WPs (disjoint file sets guaranteed).

---

### WP0 — Housekeeping [sequential, runs first]

**Rationale:** Land the pending live settings diff and stop runtime artifacts from being committed
before any structural work begins.

**Files:** `claude/settings.json`, `.gitignore` (new), `scripts/.gitkeep` (delete).

**Steps:**
- [x] Commit the already-modified `claude/settings.json` (`"model": "Opus"`→`"Fable"`) exactly as
  it stands on disk — no other edits in this commit.
- [x] Create root `.gitignore` mirroring `.git/info/exclude` runtime patterns:
  `**/.claude/scheduled_tasks.lock`, `**/.claude/scheduled_tasks.json`, `**/.claude/routines/.state/`,
  `**/.claude/worktrees/`, `**/.claude/checkpoints/`, `**/.claude/mailbox/`,
  `**/.claude/agent-registry.json`, `**/.claude/agent-memory-local`, `**/.claude/first-run`,
  `**/.claude/assistant-daemon-state.json`, `**/.claude/settings.local.json`. *(ST-11)*
- [x] `git rm scripts/.gitkeep` (directory has three real scripts). *(ST-15, CS-10)*

**Acceptance:** `git status` clean after commits; `.gitignore` tracked; `.claude/scheduled_tasks.lock`
shows ignored via `git check-ignore`; `scripts/.gitkeep` gone.

**Commit(s):**
`chore: apply live model setting (fable)` / `chore: add .gitignore for claude runtime artifacts and drop stray .gitkeep`

---

### WP1 — Structural moves, cross-refs, README rebuild, symlinks [sequential, runs ALONE after WP0]

**Rationale:** All later WPs must edit files at their FINAL paths. This WP performs every `git mv`,
updates every reference to old paths, rebuilds the README index, retargets live symlinks, and
updates install scripts. Nothing else runs until this is committed.

**Files:** `git mv` of `skills/**`→`.claude/skills/**`, `agents/**`→`.claude/agents/**`; migrate
`commands/commit.md`,`commands/research.md`→`.claude/skills/commit/SKILL.md`,`.claude/skills/research/SKILL.md`,
delete `commands/`; `README.md`; `.claude/skills/README.md` (moved); `scripts/install-dotfiles.sh`;
`install.sh`; `.github/instructions/skills.instructions.md` (`applyTo` glob only); create
`.claude/rules/` skeleton dir is deferred to WP2 (this WP only moves existing files). Live symlinks:
`~/.claude/skills`, add `~/.agents/skills`, add `~/.claude/agents`.

**Steps:**
- [x] `git mv skills .claude/skills` and `git mv agents .claude/agents`. *(ST-7, CP-4)*
- [x] Create `.claude/skills/commit/SKILL.md` from `commands/commit.md`: same body, frontmatter
  gains `disable-model-invocation: true`; keep `allowed-tools`, `argument-hint`, `description`.
  *(IS-13, PF-3, ST-8)*
- [x] Create `.claude/skills/research/SKILL.md` from `commands/research.md`: reduce to a thin
  wrapper — a `## Workflow` that delegates the task to the `web-researcher` subagent
  (`.claude/agents/web-researcher.md`) and returns its findings; remove the inline verification
  policy (it now lives once in `web-researcher.md`). *(IS-9, PF-4)*
- [x] `git rm -r commands`. *(ST-8)*
- [x] Grep the whole repo for dead path references and update every one to the new locations:
  `grep -rn 'skills/' . --include=*.md`, same for `agents/`, `commands/`, `\.\./quality.md`,
  `~/.claude/commands`. Update `.claude/skills/README.md` internal links and root README links.
- [x] Update `.github/instructions/skills.instructions.md` frontmatter `applyTo: "skills/**"` →
  `applyTo: ".claude/skills/**"` and the "under `skills/`" body text → `.claude/skills/`. (Full
  content rewrite of this file is WP4; here change ONLY the path/glob so it is not left dangling.)
  *(CP-4)*
- [x] Rebuild `README.md` index completely:
  - Split the malformed line-82 Templates row into three rows (`ci.yml`, `.env.example`,
    `AGENTS.md`). *(ST-4)*
  - Add Theory row `theory/architecture.md` and Templates row `templates/vscode-settings.json`.
    *(ST-5)*
  - Add a new **"Agent Setup"** section indexing `.claude/skills/` (link to
    `.claude/skills/README.md`), `.claude/agents/web-researcher.md`, `.claude/rules/` (note: added
    in WP2), `claude/CLAUDE.md`, `claude/settings.json`, `claude/statusline.sh`, and root
    `install.sh`. *(ST-6)*
  - Update the Skills section: link to `.claude/skills/README.md`, and replace the inaccurate
    "Both agents consume them from the `~/.claude/skills` symlink" sentence with a link to the
    consumption matrix in `.claude/skills/README.md` (matrix authored in WP4). *(ST-10)*
- [x] Update `scripts/install-dotfiles.sh` `CLAUDE_LINKS`: source `agents`→`.claude/agents`,
  `skills`→`.claude/skills`; remove the `["commands"]` entry; add `mkdir -p "$HOME/.agents"` and a
  second link `ln -sfn "$DOTFILES_DIR/.claude/skills" "$HOME/.agents/skills"`. Update the block
  comment to drop "commands" and mention the `~/.agents/skills` mirror. *(IS-10, ST-9, CS-6)*
- [x] Retarget live symlinks so the running environment stays intact:
  `ln -sfn "$PWD/.claude/skills" ~/.claude/skills`; `mkdir -p ~/.agents && ln -sfn "$PWD/.claude/skills" ~/.agents/skills`;
  `ln -sfn "$PWD/.claude/agents" ~/.claude/agents`. *(IS-10, IS-15)*

**Acceptance:** `find .claude/skills -name SKILL.md` lists all skills incl. `commit/` and
`research/`; no top-level `skills/`,`agents/`,`commands/` remain; `grep -rn 'skills/\|agents/\|commands/' . --include=*.md`
returns only intended `.claude/skills`/`.claude/agents` paths; README has no three-in-one rows and
lists every tracked file; `ls -l ~/.claude/skills ~/.agents/skills ~/.claude/agents` all resolve
into the repo; `install-dotfiles.sh` passes `shellcheck`.

**Commit:** `refactor: move skills/agents/commands into .claude and rebuild README index`

---

### WP2 — Instruction surface (AGENTS.md canonical, CLAUDE.md, copilot-instructions, rules, hooks, check) [sequential, after WP1]

**Rationale:** Establishes the canonical instruction layer and verification loop that later WPs and
the whole repo depend on. Sequential because it creates `.claude/rules/` and the project
`.claude/settings.json` other files reference, and rewrites the top-level instruction files.

**Files:** `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `claude/CLAUDE.md`,
`claude/settings.json`, `claude/statusline.sh`, new `.claude/settings.json`, new `.claude/rules/guides.md`,
`.claude/rules/cheatsheets.md`, `.claude/rules/templates.md`, `.claude/rules/scripts.md`,
`.claude/rules/skills.md`, `.claude/rules/theory.md`; new `scripts/check-repo.sh`; new root `Makefile`.

**Steps:**
- [x] Rewrite `AGENTS.md` as the single canonical file. Merge Boundaries + Conventions + Keeping
  Docs in Sync into ONE deduplicated rules section; each rule stated once (README-index rule once,
  no-duplication once, no-dead-links once). Keep the ask-first/verify-before-claiming/web-search
  Boundaries. Move the per-directory conventions OUT (to `.claude/rules/` + `.github/instructions/`).
  Add `skills/` (`.claude/skills/`), `research/`, `.claude/agents/`, `claude/` to the Structure
  list. Reword the plan-first workflow to reference itself inline (create `plan.md` manually) and
  DELETE the `/plan` reference. Reword Git rule to *"Do not commit without explicit user approval —
  propose the message first (use /commit); no `--force`/`--no-verify` push."* Add the GC-16 language
  exception. Apply GC-4/GC-5 to any emphasis. *(IS-1, IS-3, IS-12, ST-1, ST-3, ST-12, IS-7)*
- [x] Rewrite `CLAUDE.md` to: line 1 `@AGENTS.md`; then only the `grep`/`find` Searching block, a
  `/compact` steering line (preserve modified-file list + test commands), and the always-on
  non-negotiables (no-auto-commit, no `--force`/`--no-verify` push) that must survive compaction.
  Remove the per-directory conventions block, the duplicated plan-first workflow, and the
  contradictory Git line. *(IS-1, IS-6, IS-7)*
- [x] Shrink `.github/copilot-instructions.md` to Copilot-only deltas: one line noting AGENTS.md
  carries the shared rules; pointers to `.github/prompts/` and `.github/instructions/`. Remove all
  9 duplicated rules and the dead `/plan` reference. *(IS-5, CP-3, ST-1)*
- [x] Edit `claude/CLAUDE.md` line 53: `(German)` → `(English; theory/ files in German)`. (This is
  the live user memory, symlinked — editing the repo file updates it.) *(IS-2, ST-13)*
- [x] Create six `.claude/rules/<dir>.md` files (`guides`,`cheatsheets`,`templates`,`scripts`,
  `skills`,`theory`) with `paths:` frontmatter matching the `.github/instructions/*.instructions.md`
  globs (post-move: `skills` → `.claude/skills/**`) and canonical convention body text copied from
  the corresponding instructions file. For `guides`, encode the two guide types (runbooks vs
  stack-convention guides) per GU-11. For `skills`, apply GC-13 (allowed-tools, validation limits,
  invocation-control fields) and GC-10 (TOC rule). *(IS-6, GU-11; feeds SP-5/CP-1)*
- [x] Edit `claude/settings.json`: add `"$schema"` as first key; add a `hooks.PreToolUse` entry on
  `Bash` whose command handler exits 2 when the input matches
  `git push` with `--force|-f|--force-with-lease|--no-verify` anywhere; extend `permissions.deny`
  with flag-last / `--no-verify` variants. Change `statusLine.command` to
  `bash "$HOME/.claude/statusline.sh"`. *(IS-8, IS-14, ST-14)*
- [x] Add a header comment to `claude/statusline.sh` stating it intentionally omits
  `set -euo pipefail` so the statusline degrades instead of crashing; switch `[ ]`→`[[ ]]`.
  *(CS-12)*
- [x] Create `scripts/check-repo.sh` (`#!/usr/bin/env bash`, description, usage, `set -euo pipefail`,
  `log()` helper): markdown link check, `shellcheck` on `scripts/*.sh`+`install.sh`, README-vs-disk
  index diff, language check (non-ASCII prose outside `theory/` and the two allow-listed German
  files). Silent on pass (exit 0), focused errors + exit 2 on fail. Idempotent. *(IS-11)*
- [x] Create root `Makefile`: `check` (runs `scripts/check-repo.sh`), `links`, `lint`, `readme`
  targets. *(IS-11, research §4)*
- [x] Create project `.claude/settings.json` with `"$schema"` and a `hooks.Stop` entry running
  `scripts/check-repo.sh`. *(IS-11)*

**Acceptance:** `head -1 CLAUDE.md` == `@AGENTS.md`; `grep -c` shows each canonical rule appears
once in AGENTS.md; no `/plan` reference anywhere (`grep -rn '/plan' .`); `copilot-instructions.md`
< 15 lines with no AGENTS.md rule restated; `.claude/rules/` has six files each with `paths:`
frontmatter; `bash -n scripts/check-repo.sh && shellcheck scripts/check-repo.sh` clean;
`make check` exits 0 on the clean tree; a test `git push --no-verify` dry string is blocked by the
PreToolUse hook logic; `claude/settings.json` valid JSON with `$schema` first.

**Commit:** `docs: make AGENTS.md canonical, add path-scoped rules, enforcement hook and repo check`

---

### WP3 — Skills group A: planning/authoring skills [parallel-safe, after WP2]

**Rationale:** De-duplicate and de-scaffold the planning/spec skills; single-source their shared
blocks.

**Files (disjoint):** `.claude/skills/quality.md`; `.claude/skills/clarify/SKILL.md`,
`.claude/skills/clarify/question-rules.md` (new); `.claude/skills/create-plan/SKILL.md`;
`.claude/skills/write-prd/SKILL.md`; `.claude/skills/implement-plan/SKILL.md`;
`.claude/skills/guided-implementation/SKILL.md`; `.claude/skills/tdd/SKILL.md`,
`.claude/skills/tdd/interface-design.md`, `.claude/skills/tdd/mocking.md`, `.claude/skills/tdd/tests.md`;
`.claude/skills/ubiquitous-language/SKILL.md`.

**Steps:**
- [x] Apply **GC-1** to `quality.md` (slim to Scope guard + Verify-before-claiming, official
  anti-fabrication phrasing). *(PR-3, PL-9, RV-6)*
- [x] Create `.claude/skills/clarify/question-rules.md` as the canonical clarification rules; make
  `clarify/SKILL.md` reference it. In `clarify/SKILL.md`: add explicit early-exit ("stop as soon as
  the decision tree is resolved, even after one round"), pick one question-count bound (max 5 per
  round), apply GC-12 (tool-agnostic, one term). *(PF-5, PL-2, PL-7, PL-8)*
- [x] `create-plan/SKILL.md`: replace the duplicated Rules block with a one-line link to
  `../clarify/question-rules.md`; drop the line-number mandate for plan artifacts — require file
  path + symbol name (`path/file.go — handleCheckout()`), keep line refs only for in-conversation
  citations; apply GC-2/GC-3. *(PF-5, PL-2, PL-5, PL-10)*
- [x] `write-prd/SKILL.md`: delete the blanket "You may skip steps" line (replace with scoped
  "skip a step only when its output already exists; never skip exploration"); link
  `../clarify/question-rules.md`; reduce the deep-module prose to a one-line def + link to
  `../tdd/interface-design.md`; replace "A LONG, extensive" user-stories bar with GC-11 concrete
  bar; apply GC-2/GC-3. *(PL-1, PL-2, PL-11, PL-15, PL-10)*
- [x] `implement-plan/SKILL.md`: reorder Workflow (find next open phase → read its Context → then
  critically review → implement); apply GC-2/GC-3. *(PL-4, PL-10)*
- [x] `guided-implementation/SKILL.md`: soften the intro absolute to "default + escape hatch"
  matching the Constraints; replace the inlined "from Code Audit"/"from Test Quality" copies (§5c
  etc.) with links to `../test-quality/evaluation-criteria.md` and (post-merge) `../cleanup/cross-layer.md`;
  link deep-module def to `../tdd/interface-design.md`; apply GC-2 (single once-per-result checklist,
  not per-briefing) and GC-3. *(PL-3, PF-7, PL-12, PL-15, PL-10)*
- [x] `tdd/SKILL.md`: keep the Anti-Pattern section + Constraints as the single canonical statement;
  delete the "Checklist Per Cycle" section and the redundant step-3 Rules list; de-escalate "DO
  NOT" (GC-4); narrow the frontmatter trigger (remove bare "wants integration tests"); apply GC-3.
  *(PL-6, PL-13, PL-10)*
- [x] `tdd/interface-design.md`: add the canonical deep-module definition (source for write-prd /
  guided-implementation links). *(PL-15)*
- [x] Add TOCs (GC-10) to `tdd/mocking.md` (158 lines) and `tdd/tests.md` (113 lines). *(PL-14,
  SP-4-subset)*
- [x] `ubiquitous-language/SKILL.md`: rename `## Process` → `## Workflow`; change output path to
  `docs/UBIQUITOUS_LANGUAGE.md` (frontmatter description, workflow step, Re-running section); apply
  GC-2/GC-3/GC-7. *(PF-11/RV-11, PF-12, PL-10, SP-7-subset)*
- [x] Apply GC-7 (third-person description) to each SKILL.md in this WP. *(SP-7 subset)*

**Acceptance:** `grep -rn 'quality.md' .claude/skills` shows Quality links only in the code/doc
skills of this WP; `question-rules.md` referenced by clarify/create-plan/write-prd, defined once;
no "propose a conventional commit message" line remains in these files; `tdd/mocking.md` and
`tests.md` open with a TOC; `ubiquitous-language` writes to `docs/`; all descriptions third-person;
`make check` passes.

**Commit:** `docs: de-duplicate and de-scaffold planning skills; single-source shared blocks`

---

### WP4 — Skills group B: review skills + cleanup/code-audit merge + skills docs [parallel-safe, after WP2]

**Rationale:** Merge code-audit into cleanup, de-scaffold review skills, add zero-findings +
verification, fix reference-file duplication and TOCs, and rewrite the skills convention doc.

**Files (disjoint):** `.claude/skills/cleanup/SKILL.md`, `.claude/skills/cleanup/architecture.md`,
`.claude/skills/cleanup/code-smells.md`, `.claude/skills/cleanup/readability.md`,
`.claude/skills/cleanup/readability-de.md`, `.claude/skills/cleanup/principles.md`,
`.claude/skills/cleanup/cross-layer.md` (new, from code-audit Step 1);
`.claude/skills/code-audit/` (delete dir); `.claude/skills/ux-review/SKILL.md`;
`.claude/skills/test-quality/SKILL.md`, `.claude/skills/test-quality/anti-patterns.md`,
`.claude/skills/test-quality/evaluation-criteria.md`; `.claude/skills/understand/SKILL.md`;
`.claude/skills/README.md`; `.github/instructions/skills.instructions.md`.

**Steps:**
- [x] **Merge code-audit → cleanup.** Add a repo-wide scope mode to `cleanup/SKILL.md` step 1
  (relax "never scan the entire codebase unprompted" for that mode); move code-audit Step-1
  cross-layer trace into `cleanup/cross-layer.md` (canonical, quantified "trace 3–5 representative
  flows per feature area"); `git rm -r .claude/skills/code-audit`; update both READMEs and the
  guided-implementation cross-ref (guided-implementation edit itself is in WP3 — this WP only
  ensures the target file/section exists). *(PF-6, RV-5, RV-11)*
- [x] `cleanup/SKILL.md`: apply GC-8 (zero-findings clause + pre-report verification pass, "up to
  5" not "3–5"); rename report category-1 to "Boundary & consistency risks" mapped to real checks +
  "general bug-hunting → /code-review"; change per-change compile check to once-per-file; add
  "report each issue once, under the most specific pass". Apply GC-2/GC-3. *(RV-1, RV-7, RV-13,
  RV-14, RV-4-directive, PL-10)*
- [x] De-duplicate cleanup reference files (GC-9): Deep Nesting only in `readability.md`;
  single-impl-interface + pure-delegation only in `code-smells.md`; duplicates → one-line
  cross-refs. Add TOCs (GC-10) to `code-smells.md`, `readability.md`, `readability-de.md`,
  `principles.md`, `architecture.md`. Translate the two German explanatory sentences in
  `readability-de.md` to English, keeping German example phrases (GC-16). *(RV-4, SP-4, RV-10,
  SP-6)*
- [x] `ux-review/SKILL.md`: add a numbered `## Workflow` (scope + how to run app → render key
  screens at 375×667 via Playwright MCP when available → walk top flows → map problems to
  file:lines → report; static-only fallback labeled when app can't run); apply GC-8 zero-findings +
  verification; apply GC-11 concrete thresholds (44×44 px, 8px spacing, fold at 375×667); add
  "if `docs/UBIQUITOUS_LANGUAGE.md` exists treat it as canonical term list" for the domain-language
  check; apply GC-2/GC-3/GC-7. *(RV-2, SP-3, PF-11/RV-11, RV-8, RV-15, PL-10)*
- [x] `test-quality/SKILL.md`: neutralize the "-40%" example to a small reduction; add "a mostly-Keep
  suite is a successful audit — do not manufacture Delete/Merge"; drop the redundant
  ">3 tests" re-confirmation (keep the single Step-3 gate); make `evaluation-criteria.md` the
  canonical testing-doctrine source (target of tdd/guided-implementation links from WP3); apply
  GC-2/GC-3/GC-7. *(RV-3, RV-12, PF-7, PL-10)*
- [x] `understand/SKILL.md`: relax "every claim needs file:line" to "anchor key claims to file:line;
  commit hashes for history; synthesis needs no citation if its sections are cited"; apply
  GC-2/GC-3/GC-7. *(RV-9, PL-10)*
- [x] `.claude/skills/README.md`: write the canonical **skill-consumption matrix** (Claude Code +
  VS Code Copilot via `~/.claude/skills`; Copilot CLI via `~/.agents/skills`; server-side Copilot
  surfaces presumably do not load personal skills — mark unverified). Update the "Quality section
  links…" note to GC-2's scope ("skills that produce code or documents"). Update the code-audit row
  (now a cleanup mode). *(ST-10, PF-8, SP-2, PF-4-note)*
- [x] Rewrite `.github/instructions/skills.instructions.md`: replace `tools` with `allowed-tools`
  in rule and YAML example (GC-13); add name/description validation limits and
  `disable-model-invocation`/`user-invocable`/`argument-hint`; add the GC-10 TOC rule to Content
  Rules; sharpen the Quality-section criterion to "skills that produce code or documents"; note
  skills deploy as the whole `.claude/skills/` directory so `quality.md` travels with them; note
  Copilot-CLI's "pre-approve shell only for trusted skills" caveat. *(SP-1, SP-5, SP-8, CP-1, PF-2)*

**Acceptance:** `.claude/skills/code-audit/` gone; `cleanup/cross-layer.md` exists and is linked;
`grep -rn 'Deep Nesting' .claude/skills/cleanup` shows one canonical definition; every cleanup
reference file >100 lines opens with a TOC; ux-review has a numbered `## Workflow`; no `tools:`
field prescribed anywhere (`grep -rn 'tools' .github/instructions/skills.instructions.md` shows
only `allowed-tools`); consumption matrix present once; `make check` passes.

**Commit:** `docs: merge code-audit into cleanup, de-scaffold review skills, fix skills convention doc`

---

### WP5 — Skills group C: process skills (git/debug/feedback/dispatch/agent) [parallel-safe, after WP2]

**Rationale:** Fix the destructive-op bugs and de-scaffold the superpowers-ported process skills.

**Files (disjoint):** `.claude/skills/using-git-worktrees/SKILL.md`,
`.claude/skills/finish-branch/SKILL.md`, `.claude/skills/systematic-debugging/SKILL.md`,
`.claude/skills/receiving-feedback/SKILL.md`, `.claude/skills/dispatching-parallel-agents/SKILL.md`,
`.claude/agents/web-researcher.md`.

**Steps:**
- [x] `using-git-worktrees/SKILL.md`: replace the auto-commit ignore (step 3) with a non-committing
  ignore: `echo ".worktrees/" >> "$(git rev-parse --git-common-dir)/info/exclude"`; replace step 5's
  "merge or push the branch" line with a cross-ref to the finish-branch skill. Apply GC-2 (remove
  Quality link — process-only skill), GC-4/GC-5. *(PR-1, PR-8)*
- [x] `finish-branch/SKILL.md`: add a worktree-aware merge/delete path (detect linked worktree via
  git-dir vs git-common-dir; run merge/pull from the main checkout with `git -C`; `git worktree
  remove` before `git branch -d/-D`); replace the `git merge-base HEAD main` base detection with
  default-branch detection (`git symbolic-ref --short refs/remotes/origin/HEAD` /
  `gh repo view --json defaultBranchRef`) and ask when other long-lived branches exist. Evaluate
  adding `disable-model-invocation: true` (side-effect flow) or keep the explicit 4-option gate as
  the cross-tool guard; apply GC-2 (remove Quality link). *(PR-2, PR-5)*
- [x] `systematic-debugging/SKILL.md`: compress the 10-step workflow — drop the pseudo-bash
  layer-logging block and micro-scaffolding (GC-5), keep the Constraints contract (root-cause-first,
  one change at a time, 3-attempt stop); add a competing-hypotheses escape hatch to step 7 (link
  `../dispatching-parallel-agents/SKILL.md`); replace "don't skip because it looks simple" with a
  proportionality clause (GC-4); qualify step 9's "write a failing test" with "where expressible as
  a test; otherwise re-run the original failing command"; apply GC-3 (drop commit epilogue). *(PF-10,
  PR-6, PR-9, PR-12, PR-11)*
- [x] `receiving-feedback/SKILL.md`: delete the three negative-form Constraints that restate
  workflow steps; collapse the "no performative agreement"/"no gratitude filler" pair into the one
  positive line already present; apply GC-3/GC-5. *(PR-10, PR-13, PR-11)*
- [x] `dispatching-parallel-agents/SKILL.md`: trim step 3's restatement of harness-native dispatch
  (and slim step 4), keep the independence check + four-part delegation contract + collision check;
  extend step 2 with tools/sources guidance and "restate repo rules (subagents see no history;
  Explore/Plan don't see CLAUDE.md)"; add constraints for write-isolation
  (`isolation: worktree` / partition file ownership) and "resume, don't redo via SendMessage";
  sharpen the description to "2+ confirmed-independent, each-substantial failures" + add the ~15×
  token-cost note; set `user-invocable: false`; apply GC-2 (remove Quality link). *(PF-9, PR-7,
  PR-14)*
- [x] `.claude/agents/web-researcher.md`: this is now the single owner of the research verification
  policy (research/commit skill and user CLAUDE.md just point here). Verify effective MCP server
  names with `claude mcp list` and correct the `tools:` grants to the exact `mcp__<server>` names
  (playwright/context7 are plugin-namespaced). Keep `tools:` (correct for subagents). *(IS-9, IS-15,
  PF-4)*

**Acceptance:** no `git commit` in `using-git-worktrees`; `finish-branch` has a worktree-aware
branch and default-branch detection; `systematic-debugging` has no pseudo-bash block and a
competing-hypotheses link; `dispatching-parallel-agents` is `user-invocable: false` with no Quality
link; `web-researcher.md` `tools:` names resolve against `claude mcp list`; `make check` passes.

**Commit:** `docs: fix destructive-op bugs and de-scaffold process skills`

---

### WP6 — Scripts + their guides [parallel-safe, after WP1] 

**Rationale:** Fix the shell bugs and the guide usage lines that drive them. Scripts and the two
guides that document them are grouped so the runbook and its script stay consistent.

**Files (disjoint):** `scripts/setup-server.sh`, `scripts/prod-init.sh`,
`scripts/install-dotfiles.sh`, `guides/provision-server.md`, `guides/postgresql-operations.md`,
`guides/dotfiles-codespaces.md`.

> Note: `install-dotfiles.sh` was already edited for the symlink moves in WP1. WP6 owns the
> remaining shell-quality fixes in it (curl|bash usage line, gh arch). WP1 and WP6 do not run
> concurrently (WP6 is after WP1), so this is safe.

**Steps:**
- [ ] `setup-server.sh`: move `. /etc/os-release` (and `REPO_URL`) above the Docker-keyring `if`
  block; use `$REPO_URL/gpg` in the curl (fixes `ID: unbound variable`). Wrap every mutating
  command in dry-run mode through the `run` wrapper (sudoers, authorized_keys/sshd edits +
  `systemctl restart sshd`, fail2ban jail.local, Docker keyring/apt writes) so `--dry-run` is truly
  side-effect free. Fix the header-comment usage line (inline env vars over SSH). *(CS-1, CS-2,
  GU-1)*
- [ ] `prod-init.sh`: require `DOMAIN` (drop the `example.com` default) like `EMAIL`; add
  `-p "$PROJECT"` to both `COMPOSE_CERT` and `COMPOSE_PROD`; replace
  `docker exec "${PROJECT}-reverse-proxy" nginx -t` with `$COMPOSE_CERT exec -T reverse-proxy nginx -t`;
  rewrite the certbot block as `if ! docker run … certonly …; then $COMPOSE_CERT down; error …; fi`
  (removes the dead `$?` check). *(CS-3, CS-4, CS-5)*
- [ ] `install-dotfiles.sh`: remove the `curl -sL <raw-url> | bash` usage line (document
  `git clone … && ./install.sh`); add a guard aborting if `$DOTFILES_DIR/templates/.bash_aliases`
  is missing; derive gh arch (`dpkg --print-architecture`→amd64/arm64) instead of hardcoding
  `linux_amd64`. *(CS-7, CS-14)*
- [ ] `guides/provision-server.md`: change the Usage `ssh` command to pass vars inline on the remote
  (`ssh root@<host> "SSH_PUBLIC_KEY='…' USERNAME=nico … bash -s" < scripts/setup-server.sh`); replace
  the copied fail2ban jail.local block and UFW list with pointers to the script's numbered steps
  (keep the sshd_config diff block); add/rename a `## Verify` section. *(GU-1, GU-14, GU-13)*
- [ ] `guides/postgresql-operations.md`: rewrite backups as
  `docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > …`
  (container holds env; `-T` avoids TTY corruption); add `set -a; . "$COMPOSE_DIR/.env"; set +a` to
  the cron example; document `migrate` over the compose network (`docker run --rm --network
  <project>_db-network …`), keeping the localhost form only as a published-port note. *(GU-2, GU-8)*
- [ ] `guides/dotfiles-codespaces.md`: replace the "create install.sh" instruction with "the wrapper
  already exists: [install.sh](../install.sh)"; drop the snippet with the mis-ordered shebang; add
  a `## Prerequisites` and `## Verify` section. *(GU-12, GU-13)*
- [ ] Add the `install.sh` description comment (`# install.sh — Codespaces dotfiles entrypoint;
  delegates to scripts/install-dotfiles.sh`). *(CS-13)*

**Acceptance:** `shellcheck scripts/*.sh install.sh` clean; `bash -n` on each; `setup-server.sh
--dry-run` performs no mutations (grep confirms every mutating line routes through `run`);
provision-server and dotfiles-codespaces guides have Prerequisites+Verify; no `curl|bash` usage
line; `make check` passes.

**Commit:** `fix: repair setup/prod/install scripts and align their guides`

---

### WP7 — Copilot files + templates [parallel-safe, after WP2]

**Rationale:** Bring the Copilot-facing guide, prompts, and templates to current spec; these files
are disjoint from the skills and other guides.

**Files (disjoint):** `guides/copilot-agent-setup.md`, `templates/copilot-instructions.md`,
`templates/AGENTS.md`, `.github/prompts/new-guide.prompt.md`, `.github/prompts/new-template.prompt.md`,
`.github/instructions/guides.instructions.md`.

**Steps:**
- [ ] `guides/copilot-agent-setup.md`: rewrite the custom-agents section to `NAME.agent.md` with
  `description` required, 30,000-char limit, `tools`/`mcp-servers`/`model`/`target` fields, and the
  `.chatmode.md`→`.agent.md` rename note; add a **skills** row/section (locations `.github/skills/`,
  `.claude/skills/`, `.agents/skills/`; GA across cloud agent, code review, CLI, VS Code/JetBrains);
  mark prompt files IDE-only preview with `agent:` frontmatter (not `mode:`); update AGENTS.md
  support claims (read by every Copilot surface, one agent file, nearest wins, root CLAUDE.md only a
  fallback); rewrite the "compact subset of AGENTS.md" pattern to "Copilot-only deltas or delete";
  fix the `applyTo`-required bullet (line 285) and add `excludeAgent` (`"code-review"`/`"cloud-agent"`)
  + `copilot-setup-steps.yml` constraints to the audit checklist; drop the `IMPORTANT:` emphasis
  (GC-4). *(CP-2, CP-6, CP-7, CP-8, CP-10, CP-11, CP-15)*
- [ ] `templates/copilot-instructions.md`: convert `#` meta-comments to `<!-- -->` (GC-14); make it
  a Copilot-only-deltas template (not an AGENTS.md restatement) per CP-8. *(CP-9, CP-8)*
- [ ] `templates/AGENTS.md`: add a top HTML comment — "create a sibling CLAUDE.md whose first line
  is `@AGENTS.md`, or `ln -s AGENTS.md CLAUDE.md`, so Claude Code loads the same rules"; trim the
  6-item silent self-review checklist and merge Change-presentation + Reviewer-summary into one
  short post-task rule (GC-5). *(CP-12, CP-14)*
- [ ] `.github/prompts/new-guide.prompt.md` and `new-template.prompt.md`: delete the `## Conventions`
  sections (supplied by the `applyTo` instructions); keep only Input + Steps. *(CP-13)*
- [ ] `.github/instructions/guides.instructions.md`: fix the link-depth example
  `../../templates/Makefile` → `../templates/Makefile`; add the two-guide-types distinction (GU-11,
  mirroring `.claude/rules/guides.md`). *(CP-5, GU-11)*

**Acceptance:** copilot-agent-setup mentions skills, `excludeAgent`, `copilot-setup-steps.yml`,
`NAME.agent.md`; `grep -n 'IMPORTANT:' guides/copilot-agent-setup.md` empty; templates use
`<!-- -->` comments and are functional as-is; prompt files carry no Conventions section;
guides.instructions link depth correct; `make check` passes.

**Commit:** `docs: update copilot guide, prompts and templates to current spec`

---

### WP8 — Remaining guides + cheatsheets [parallel-safe, after WP1]

**Rationale:** Version bumps, duplication removal, structure fixes, and cheatsheet fence bugs not
owned by WP6/WP7.

**Files (disjoint):** `guides/github-actions-cicd.md`, `guides/letsencrypt-docker.md`,
`guides/docker-multi-stage-builds.md`, `guides/nginx-reverse-proxy.md`, `guides/go.md`,
`guides/java-spring-boot.md`, `guides/react.md`, `templates/ci.yml`,
`templates/docker-compose.prod.yml`, `templates/Makefile`, `cheatsheets/unix-commands.md`,
`cheatsheets/postgresql.md`, `cheatsheets/vim.md`.

**Steps:**
- [ ] Apply GC-15 version bumps everywhere they occur: Go `1.26` (`github-actions-cicd.md`,
  `templates/ci.yml` ×3); nginx `1.30-alpine` (`docker-multi-stage-builds.md`, `letsencrypt-docker.md`,
  `templates/docker-compose.prod.yml`); certbot `v5.6.0` (`letsencrypt-docker.md` ×2,
  `templates/docker-compose.prod.yml`); action majors (`github-actions-cicd.md`, `templates/ci.yml`);
  pnpm `@10` (`docker-multi-stage-builds.md`). *(GU-3, GU-5, GU-6, GU-7, GU-15)*
- [ ] `github-actions-cicd.md`: reduce to pattern explanations (OIDC prereqs, path-filter concept,
  caching table, troubleshooting) + links to `templates/ci.yml` and `templates/Makefile`; delete
  the duplicated job/`prod-release` blocks; add `## Verify` and `## Prerequisites`. *(GU-9, GU-13)*
- [ ] `letsencrypt-docker.md`: fix the ufw prerequisite to `sudo ufw allow 80,443/tcp`; add a
  `## Verify` section (cert-issued + dry-run-renew). *(GU-4, GU-13)*
- [ ] `nginx-reverse-proxy.md`: keep only the two patterns NOT in `templates/nginx-tls.conf` (SPA
  try_files, static-asset caching) + one-line pointers; delete the five duplicated config blocks;
  rename `## Testing` → `## Verify`; add `## Prerequisites`. *(GU-10, GU-13)*
- [ ] `go.md`, `java-spring-boot.md`, `react.md`: these are stack-convention guides (heading-grouped
  rules, tables, short rationale) — the two-guide-types convention added in WP2/`.claude/rules/guides.md`
  and WP7/guides.instructions makes them compliant; verify each opens by naming itself a
  stack-convention guide and needs no runbook restructure. No content rewrite. *(GU-11)*
- [ ] `cheatsheets/unix-commands.md`: append the missing closing ``` after the final block; replace
  the project-specific `StructuralFormat` grep with a generic commented example. *(CS-8, CS-15)*
- [ ] `cheatsheets/postgresql.md`: move "Useful Shortcuts" SQL into a ` ```sql ` fence with `--`
  comments; split the reload section into a bash block (`systemctl reload`) and a sql block
  (`SELECT pg_reload_conf();`). *(CS-9)*
- [ ] `cheatsheets/vim.md`: split into `##` sections (Editing, Line Ranges, Search & Replace, Files
  & Splits); backtick every command cell; use `<before>`/`<after>` placeholders; rename title
  `# Vim Cheatsheet` → `# Vim`. *(CS-11)*

**Acceptance:** `grep -rn '1.24\|v2.11.0\|1.27-alpine\|checkout@v5\|pnpm@latest' guides templates`
empty; unix-commands has even fence count; postgresql cheatsheet SQL is in `sql` fences; vim.md has
`##` sections and backticked commands; nginx/github-actions guides have no duplicated template
blocks and carry Prerequisites+Verify; `make check` passes.

**Commit:** `docs: bump versions, de-duplicate guides, fix cheatsheet fences`

---

### Sequencing summary

```
WP0 (housekeeping)  ──►  WP1 (moves + README + symlinks)  ──►  WP2 (instruction surface + check)
                                                                  │
                        ┌─────────────────────────────────────────┼───────────────────────────┐
                        ▼            ▼            ▼            ▼    ▼            ▼                ▼
                      WP3          WP4          WP5          WP6  (after WP1)  WP7            WP8 (after WP1)
                   (skills A)   (skills B)   (skills C)   (scripts+guides) (copilot)    (guides+cheatsheets)
```

WP6 and WP8 depend only on WP1 (they touch scripts/guides/cheatsheets/templates, not the
instruction surface); running them after WP2 is also fine and keeps a single fan-out point.
WP3/WP4/WP5/WP7 depend on WP2 (rules + skills-convention doc). All of WP3–WP8 have disjoint file
sets and are mutually parallel-safe.

---

## 5. Finding coverage

All 139 findings mapped (IDs per audit file: IS=instruction-surface, ST=structure, SP=skills-spec,
PF=skills-portfolio, PL=skills-content-planning, PR=skills-content-process, RV=skills-content-review,
CS=cheatsheets-scripts, CP=copilot-files, GU=guides). Each appears exactly once.

| ID | Short title | WP / step |
|----|-------------|-----------|
| IS-1 | CLAUDE.md vs AGENTS.md canonical | WP2 (AGENTS/CLAUDE rewrite) |
| IS-2 | claude/CLAUDE.md "(German)" | WP2 (claude/CLAUDE.md edit) |
| IS-3 | dead `/plan` prompt | WP2 (AGENTS rewrite, delete /plan) |
| IS-4 | skills `tools`→`allowed-tools` | WP2 (.claude/rules/skills.md) + WP4 (instructions doc) via GC-13 |
| IS-5 | copilot-instructions duplicates AGENTS.md | WP2 (shrink copilot-instructions) |
| IS-6 | per-dir conventions triple-maintained | WP2 (.claude/rules/*) |
| IS-7 | Git rule contradicts /commit | WP2 (AGENTS Git rule reword) |
| IS-8 | `git push --force`/`--no-verify` not blocked | WP2 (PreToolUse hook) |
| IS-9 | research policy in 3 places | WP1 (research skill wrapper) + WP5 (web-researcher owns it) |
| IS-10 | skills symlink misses Copilot CLI | WP1 (install-dotfiles + live symlinks) |
| IS-11 | no verification loop | WP2 (check-repo.sh + Makefile + Stop hook + project settings) |
| IS-12 | AGENTS.md internal repetition | WP2 (AGENTS dedup) |
| IS-13 | commands not migrated / no disable-model-invocation | WP1 (commit skill) |
| IS-14 | missing `$schema` | WP2 (settings) |
| IS-15 | agents/ dir undiscoverable + MCP tool names | WP1 (symlink) + WP5 (web-researcher tools) |
| ST-1 | dead `/plan` (dup of IS-3) | WP2 |
| ST-2 | skills `tools` field (dup of IS-4) | WP2/WP4 GC-13 |
| ST-3 | three parallel instruction sets | WP2 (AGENTS canonical) |
| ST-4 | README line-82 malformed | WP1 (README rebuild) |
| ST-5 | README missing 2 files | WP1 |
| ST-6 | README missing agent-setup section | WP1 |
| ST-7 | skills/agents/commands top-level | WP1 (git mv) |
| ST-8 | commands/ legacy | WP1 (migrate + delete) |
| ST-9 | install-dotfiles missing ~/.agents/skills | WP1 |
| ST-10 | wrong+duplicated consumption sentence | WP1 (README link) + WP4 (matrix) |
| ST-11 | no .gitignore | WP0 |
| ST-12 | AGENTS Structure incomplete | WP2 |
| ST-13 | claude/CLAUDE.md "(German)" (dup of IS-2) | WP2 |
| ST-14 | statusLine hardcodes /home/nico | WP2 (settings command) |
| ST-15 | stray scripts/.gitkeep | WP0 |
| SP-1 | skills.instructions `tools` field | WP4 (instructions doc rewrite) |
| SP-2 | README.md line-3 consumption claim | WP4 (matrix) + WP1 (link) |
| SP-3 | ux-review no Workflow | WP4 |
| SP-4 | 9 reference files >100 lines no TOC | WP3 (tdd files) + WP4 (cleanup/test-quality files) via GC-10 |
| SP-5 | skills.instructions missing validation/invocation fields | WP4 |
| SP-6 | readability-de German vs English-only rule | WP2 (GC-16 exception) + WP4 (file) |
| SP-7 | 11/17 descriptions not third-person | WP3+WP4+WP5 (GC-7 across all SKILL.md) |
| SP-8 | quality.md out-of-bundle portability note | WP4 (instructions doc note) |
| PF-1 | 17× Quality ritual + quality.md | WP3 (GC-1 slim) + GC-2 across WP3/4/5 |
| PF-2 | skills.instructions `tools` (dup) | WP4 |
| PF-3 | commit command → skill + disable-model-invocation | WP1 |
| PF-4 | research policy triplicated | WP5 (web-researcher owner) + WP1 (wrapper) |
| PF-5 | clarification Rules duplicated | WP3 (question-rules.md) |
| PF-6 | code-audit duplicates cleanup | WP4 (merge) |
| PF-7 | guided-implementation inlines audit/test doctrine | WP3 (links) + WP4 (canonical file) |
| PF-8 | README consumption claim wrong | WP4 (matrix) |
| PF-9 | dispatching step 3 harness-native | WP5 (trim) |
| PF-10 | systematic-debugging over-prescriptive | WP5 (compress) |
| PF-11 | ux-review/ubiquitous-language/code-audit heading convention | WP4 (ux-review, code-audit) + WP3 (ubiquitous-language) |
| PF-12 | ubiquitous-language artifact path | WP3 (docs/ path) |
| PL-1 | write-prd skip-any-step contradiction | WP3 |
| PL-2 | create-plan Rules duplicated | WP3 |
| PL-3 | guided-implementation intro contradiction | WP3 |
| PL-4 | implement-plan step order | WP3 |
| PL-5 | create-plan line-number mandate stale | WP3 |
| PL-6 | tdd triple-stated rules | WP3 |
| PL-7 | clarify 3-rounds no early exit | WP3 |
| PL-8 | clarify hardcoded tool param | WP3 (GC-12) |
| PL-9 | quality.md test-command for docs | WP3 (GC-1) |
| PL-10 | commit epilogue in 10 skills | WP3+WP4+WP5 (GC-3) |
| PL-11 | write-prd "LONG extensive" bar | WP3 (GC-11) |
| PL-12 | guided-implementation per-briefing checklist | WP3 (GC-2) |
| PL-13 | tdd overtrigger "integration tests" | WP3 |
| PL-14 | tdd mocking/tests no TOC | WP3 (GC-10) |
| PL-15 | deep-module defined 3× | WP3 (tdd/interface-design canonical + links) |
| PR-1 | using-git-worktrees auto-commit | WP5 |
| PR-2 | finish-branch worktree failure | WP5 |
| PR-3 | quality.md Principles+checklist scaffolding | WP3 (GC-1) |
| PR-4 | quality.md always-linked in process skills | GC-2 (WP3/4/5) |
| PR-5 | finish-branch merge-base wrong | WP5 |
| PR-6 | systematic-debugging one-hypothesis | WP5 |
| PR-7 | dispatching stale subagent spec | WP5 |
| PR-8 | using-git-worktrees step-5 competes finish-branch | WP5 |
| PR-9 | systematic-debugging "looks simple" | WP5 (GC-4) |
| PR-10 | receiving-feedback negative-form constraints | WP5 (GC-5) |
| PR-11 | commit epilogue (dup of PL-10) | GC-3 (WP5) |
| PR-12 | systematic-debugging step-9 always-test | WP5 |
| PR-13 | receiving-feedback sycophancy bullets | WP5 (GC-5) |
| PR-14 | dispatching eager trigger + no cost note | WP5 |
| RV-1 | cleanup fixed 3–5 findings quota | WP4 (GC-8) |
| RV-2 | ux-review no Workflow (dup of SP-3) | WP4 |
| RV-3 | test-quality -40% anchor | WP4 (GC-8) |
| RV-4 | cleanup reference files duplicate rules | WP4 (GC-9) |
| RV-5 | code-audit Step-1 duplicates cleanup | WP4 (cross-layer.md canonical) |
| RV-6 | quality.md checklist code-shaped | WP3 (GC-1) |
| RV-7 | cleanup no verification pass | WP4 (GC-8) |
| RV-8 | ux-review qualitative bars | WP4 (GC-11) |
| RV-9 | understand every-claim-cited | WP4 |
| RV-10 | readability-de German prose | WP4 (translate) |
| RV-11 | code-audit/ubiquitous-language heading convention (dup of PF-11) | WP4 (code-audit) + WP3 (ubiquitous-language) |
| RV-12 | test-quality third confirmation gate | WP4 (GC-5) |
| RV-13 | cleanup per-change compile check | WP4 (GC-5) |
| RV-14 | cleanup category-1 "logic bugs" | WP4 |
| RV-15 | ux-review domain-language no source | WP4 |
| CS-1 | setup-server `${ID}` unbound | WP6 |
| CS-2 | setup-server --dry-run mutates | WP6 |
| CS-3 | prod-init dead `$?` check | WP6 |
| CS-4 | prod-init `-p` project name | WP6 |
| CS-5 | prod-init DOMAIN default | WP6 |
| CS-6 | install-dotfiles ~/.agents/skills (dup of IS-10/ST-9) | WP1 |
| CS-7 | install-dotfiles curl\|bash usage | WP6 |
| CS-8 | unix-commands unclosed fence | WP8 |
| CS-9 | postgresql cheatsheet SQL in bash fence | WP8 |
| CS-10 | scripts/.gitkeep (dup of ST-15) | WP0 |
| CS-11 | vim.md flat table | WP8 |
| CS-12 | statusline.sh no set -e note | WP2 |
| CS-13 | install.sh no description | WP6 |
| CS-14 | install-dotfiles gh arch hardcoded | WP6 |
| CS-15 | unix-commands StructuralFormat leftover | WP8 |
| CP-1 | skills.instructions `tools` field (dup of SP-1) | WP4 |
| CP-2 | copilot-agent-setup stale custom-agents | WP7 |
| CP-3 | copilot-instructions dead `/plan` | WP2 |
| CP-4 | skills.instructions applyTo skills/** | WP1 (glob) + WP4 (full rewrite) |
| CP-5 | guides.instructions link depth | WP7 |
| CP-6 | copilot-agent-setup prompt-files/skills gap | WP7 |
| CP-7 | copilot-agent-setup stale AGENTS.md claims | WP7 |
| CP-8 | copilot-instructions "compact subset" anti-pattern | WP7 (guide+template) |
| CP-9 | templates/copilot-instructions `#` comments | WP7 (GC-14) |
| CP-10 | copilot-agent-setup applyTo-optional wrong | WP7 |
| CP-11 | copilot-agent-setup missing excludeAgent/setup-steps | WP7 |
| CP-12 | templates/AGENTS.md no interop note | WP7 |
| CP-13 | prompt files duplicate conventions | WP7 |
| CP-14 | templates/AGENTS.md quality scaffolding | WP7 (GC-5) |
| CP-15 | copilot-agent-setup IMPORTANT: emphasis | WP7 (GC-4) |
| GU-1 | provision-server SSH env not propagated | WP6 |
| GU-2 | postgresql-operations backup env not sourced | WP6 |
| GU-3 | github-actions Go 1.24 | WP8 (GC-15) |
| GU-4 | letsencrypt ufw syntax | WP8 |
| GU-5 | letsencrypt certbot v2.11.0 | WP8 (GC-15) |
| GU-6 | docker-multi-stage nginx 1.27 | WP8 (GC-15) |
| GU-7 | github-actions stale action majors | WP8 (GC-15) |
| GU-8 | postgresql-operations migrate localhost | WP6 |
| GU-9 | github-actions duplicates templates | WP8 |
| GU-10 | nginx guide duplicates template | WP8 |
| GU-11 | go/react/java guides prose vs convention | WP2 (two-guide-types in rules) + WP7 (instructions) + WP8 (verify) |
| GU-12 | dotfiles-codespaces stale install.sh instruction | WP6 |
| GU-13 | 5 guides missing Verify/Prerequisites | WP6 (provision, dotfiles) + WP8 (letsencrypt, nginx, github-actions) |
| GU-14 | provision-server duplicates script | WP6 |
| GU-15 | docker-multi-stage pnpm@latest | WP8 (GC-15) |

**Rejected / Deferred (explicit):**

- **Per-skill evals infrastructure** (research §1; relates to PF-1 area, not a numbered finding) —
  **Rejected** as overkill for a 17-skill personal repo; the `make check` loop is the proportionate
  verification. Trigger to revisit: observed skill mis-triggering. *(No finding is left uncovered;
  this is a research recommendation, not an audit finding.)*
- No numbered finding is deferred — all 139 are assigned to a WP.

---

## 6. Verification plan

Run after all WPs (also wired as the `make check` Stop hook, so it runs continuously):

1. **Link check** — every relative Markdown link resolves to a file on disk (`scripts/check-repo.sh`
   link stage). Zero dead links.
2. **README-vs-filesystem diff** — every tracked doc/template/script/skill file appears in the
   README index and every README entry points at an existing file.
3. **Dead-path grep** — `grep -rn 'skills/\|agents/\|commands/' . --include=*.md` returns only
   intended `.claude/skills`/`.claude/agents` references (no top-level `skills/`, `agents/`,
   `commands/`, no `~/.claude/commands`); `grep -rn '/plan' .` empty.
4. **Skill frontmatter field grep** — `grep -rn '^tools:' .claude/skills` empty (skills use
   `allowed-tools`); `.github/instructions/skills.instructions.md` and `.claude/rules/skills.md`
   mention only `allowed-tools`.
5. **Language check** — no German prose outside `theory/` and the two allow-listed files
   (`.claude/skills/cleanup/readability-de.md` example phrases). `check-repo.sh` language stage.
6. **shellcheck** — `shellcheck scripts/*.sh install.sh` clean; `bash -n` on each.
7. **Skills frontmatter validation** — every `SKILL.md` `name` matches its directory, lowercase/
   hyphen, ≤64 chars; `description` non-empty ≤1024 chars, third-person, no XML tags.
8. **Version-consistency grep** — `grep -rn '1\.24\|v2\.11\.0\|1\.27-alpine\|@v5\b\|pnpm@latest' guides templates`
   returns nothing for the bumped pins (GC-15).
9. **Symlink resolution** — `ls -l ~/.claude/skills ~/.agents/skills ~/.claude/agents ~/.claude/settings.json`
   all resolve into the repo at the new paths.
10. **Hook smoke test** — the PreToolUse handler blocks a `git push --no-verify` and
    `git push origin main --force` string; `make check` exits 0 on the final clean tree.
11. **Finding re-scan** — confirm every ID in the §5 table has its acceptance criterion met.
