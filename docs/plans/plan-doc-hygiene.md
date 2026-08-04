# Plan: Current-state-only documentation across every agent surface

> Source PRD: n/a — derived from the diagnosis of why sessions accrete dated history.

## Goal

Every agent surface states what is true now. History lives in git, in `CHANGELOG.md`, and in
deliberate ADRs — nowhere else. Adding a fact obliges the agent to retire the fact it replaced.

Seven causes, all verified in this session:

| # | Cause | Evidence |
| --- | --- | --- |
| 1 | The always-loaded surface has no hygiene rule | `claude/CLAUDE.md` has no rule about docs, comments, or pruning |
| 2 | Anti-history rules exist only per project | handbook `AGENTS.md`, `rag/AGENTS.md`, `barista/AGENTS.md`, `jotti/AGENTS.md` — four wordings, no canon |
| 3 | The verification contract never asks what a change made false | `.claude/skills/quality.md` checks only new claims and links |
| 4 | Pruning is opt-in | `distill`, `prune`, `verify-docs`, `cleanup` are user-triggered; nothing runs by default |
| 5 | The memory contract mandates dated records and retires only *wrong* ones | An obsolete record is never wrong, so it survives |
| 6 | `reflect` is an accretion pump | It writes learnings each session with no counterpart retirement |
| 7 | Skill artifacts have no end of life | `create-plan` and `write-prd` create; nothing deletes |

## Architectural decisions

- **One canonical rule, four translations.** The rule text is authored once in Phase 1 and
  copied verbatim into every other instruction surface. `jotti/AGENTS.md` gets the German
  rendering; every other surface is English.
- **Rule name**: **Current state only**. Referred to by that name in every surface.
- **Sanctioned records in time** — the exception list, identical everywhere: `CHANGELOG.md`,
  ADR files (`jotti/docs/adrs/`), git history. ADRs are a deliberate, manual, explicit act.
- **Dates**: reports carry as-of dates, committed docs do not. Docs pin versions instead.
- **Retirement is a verification step**, not a separate ritual. It joins
  `.claude/skills/quality.md`, which every skill already links.
- **Memory holds state, not events.** The class of banned memory is the run report.
- **Execution**: Phases 1–7 and 11a are handbook-local and may share a worktree. Phases 8–10
  and 11b each run in a different repository. They cannot be worktrees of this checkout and
  run sequentially in their own clones.
- **jotti forbids auto-commit** (`jotti/AGENTS.md`, "Kein auto-commit"). Phases 10 and 11b
  post a copy-paste commit message and stop.
- **Handbook prose caps apply to every edit here.** `make check` enforces ≤ 20-word sentences
  and ≤ 3-line paragraphs on all tracked Markdown outside `docs/plans/`.
- **No cross-repo Markdown links in this plan.** `check_links` in `scripts/check-repo.sh`
  runs over `docs/plans/` too; a link to another repo would fail it. Foreign paths stay in
  backticks.

## Inventory

Handbook surfaces:

- `claude/CLAUDE.md` — the global file, symlinked to `~/.claude/CLAUDE.md`. Sections
  *Code Conventions* and *Agent Working Rules*. Its research bullet carries the as-of rule.
- `AGENTS.md` — *Working rules*, currently "Delete, don't deprecate"; *Plan-first workflow*
  step 5 deletes a root `plan.md` that no skill writes.
- `.claude/skills/quality.md` — the shared verification contract, linked by every skill.
- `.claude/skills/reflect/SKILL.md` — steps 5 (dedup), 6 (gate), 7 (apply).
- `.claude/skills/reflect/targets.md` — *Memory file format*, the memory contract.
- `.claude/skills/prune/SKILL.md` — step 4, semantic review.
- `.claude/skills/prune/criteria.md` — *Memory review*, its *Finding contract* table,
  *Repo-leftover review*.
- `.claude/skills/prune/state-map.md` — its as-of line anchors the drift rule.
- `.claude/skills/create-plan/SKILL.md` — step 6 writes `docs/plans/plan-<slug>.md`.
- `.claude/skills/implement-plan/SKILL.md` — step 10 lands the plan and deletes only the
  `## Run state` block.
- `.claude/skills/finish-branch/SKILL.md` — the four-option integration decision.
- `.claude/skills/write-prd/SKILL.md` — step writing `docs/prds/prd-<name>.md`.
- `.claude/agents/web-researcher.md` — as-of rules 3 and its output contract. Report surface,
  so it keeps its dates.
- `guides/monitoring.md` — a dated free-plan caveat.
- `templates/nginx-tls.conf` — Mozilla intermediate v6.0 plus a redundant date.

Foreign surfaces:

- `rag/AGENTS.md` — "Prune, don't archive"; the definition-of-done verification date; the
  boundary bullet "date every time-sensitive claim".
- `barista/AGENTS.md` — "Delete, don't deprecate".
- `jotti/AGENTS.md` — German; the completed-plan deletion rule; the ADR rule.
- Barista memory directory `~/.claude/projects/-home-nico-r-barista/memory/` — 30 files,
  7 of them event records, plus `MEMORY.md`.

## Resolved decisions

- **Scope**: all four repos — handbook, rag, barista, jotti.
- **Cleanup**: causes *and* existing pollution, in the same plan.
- **Dates**: reports keep them, committed docs drop them. Docs pin a version where the
  staleness signal matters.
- **No mechanical gate.** A regex for "previously / no longer / superseded" matched ~100 lines
  across the four repos and most were legitimate prose. Rules only.
- **Two claims from the diagnosis are corrected here**, both verified this session:
  - `jotti/docs/plans/review-v0.17.2.md` has 39 unticked boxes. Under jotti's own rule it
    legitimately stays. It is not a deletion candidate.
  - `jotti/docs/plans/guide-manuelle-qa-v1.0.0.md` is referenced from
    `backend/api/fiskal/tse_live/tse_live_ausfall_test.go`. Deleting it would break that
    reference.
  - Phase 11b therefore triages and proposes; it deletes nothing by default.
- **Barista memories are not blanket-deleted.** Each event record is mined for its live
  residue first — a lesson, an open item, a constraint that still binds.
- **Barista memories stay German.** The project's language convention governs its memory
  directory.

## Open questions / Risks

- **`claude/CLAUDE.md` is live for every session** through the `~/.claude/CLAUDE.md` symlink.
  A malformed edit degrades every project at once. Phase 1 re-reads the file after editing.
- **Rule inflation.** Four surfaces gain text. Every phase deletes the wording it replaces, so
  no surface ends up with two rules about the same thing.
- **The retirement step can overreach.** A statement that merely looks superseded must not be
  deleted on suspicion. The wording requires a citation before any retirement.

---

## Phase 1: Author the canonical rule and land it on the global surfaces

**Depends on**: none

### Context

- `claude/CLAUDE.md — Code Conventions` — the only file loaded in every project.
- `AGENTS.md — Working rules` — carries "Delete, don't deprecate", the nearest existing rule.
- `AGENTS.md — Plan-first workflow` — step 5 deletes a root `plan.md`.
- `.claude/skills/create-plan/SKILL.md` — writes to `docs/plans/`, not the root.

### What to build

The **Current state only** rule, authored once and added to `claude/CLAUDE.md` under
*Code Conventions*. It states: docs, comments and instructions describe what is true now; git
history is the archive; a change that makes a statement false rewrites or deletes it in the
same change; a superseded version never stands beside its replacement; banned in prose are
dated change entries, "previously / formerly / used to", and deprecation notes; the exceptions
are `CHANGELOG.md`, ADR files, and git history.

In `AGENTS.md`, "Delete, don't deprecate" becomes a sub-bullet of the new rule rather than a
sibling — one rule, not two. Fix the plan-first workflow's stale path while here: the file is
`docs/plans/plan-<slug>.md`, matching what `create-plan` actually writes.

### Acceptance criteria

- [x] `claude/CLAUDE.md` carries the **Current state only** rule under *Code Conventions*.
- [x] The rule names the exception list: `CHANGELOG.md`, ADR files, git history.
- [x] `AGENTS.md` states the same rule, with "Delete, don't deprecate" nested under it.
- [x] `AGENTS.md` *Plan-first workflow* names `docs/plans/plan-<slug>.md`, not `plan.md`.
- [x] No surface states the rule twice.
- [x] `make check` passes.

---

## Phase 2: Make retirement part of the default verification loop

**Depends on**: 1

### Context

- `.claude/skills/quality.md` — *Scope guard* and *Verify before claiming done*. Every skill
  links here instead of restating the contract.

### What to build

A third section, **Supersede check**, in `.claude/skills/quality.md`. Before reporting work
complete the agent searches for the statement its change replaced — in docs, comments,
instructions and memory — rewrites or deletes each hit, and reports what it retired next to
what it added. A retirement requires a citation; a suspicion is not one. Finding nothing to
retire is a valid result and is stated in one line.

This is the fix for cause 3 and the default-loop half of cause 4.

### Acceptance criteria

- [ ] `.claude/skills/quality.md` has a *Supersede check* section.
- [ ] It requires a cited hit before any deletion.
- [ ] It requires reporting retirements alongside additions.
- [ ] It states that "nothing to retire" is a valid one-line result.
- [ ] The section references the **Current state only** rule by name.
- [ ] `make check` passes.

---

## Phase 3: Give plan and PRD artifacts an end of life

**Depends on**: 1

### Context

- `.claude/skills/create-plan/SKILL.md — step 6` — creates the plan file.
- `.claude/skills/implement-plan/SKILL.md — step 10` — lands the branch, deletes the
  `## Run state` block, hands integration to finish-branch.
- `.claude/skills/finish-branch/SKILL.md` — options 1 merge, 2 PR, 3 keep, 4 discard.
- `.claude/skills/write-prd/SKILL.md` — writes `docs/prds/prd-<name>.md`.
- `.claude/skills/prune/criteria.md — Repo-leftover review` — already proposes fully-ticked
  plan files.

### What to build

A *Lifecycle* line in `create-plan`: the plan file is transient and dies when its last
criterion lands. `implement-plan` step 10 gains the deletion: once every criterion is ticked,
`git rm` the plan file and commit that removal in the main checkout after landing. Any unticked
criterion keeps the file, and the report names it as surviving.

`finish-branch` deletes the plan only on option 1, where the merge is complete in the session.
On option 2 it names the plan file as an open follow-up in the PR body; on options 3 and 4 it
leaves it. `write-prd` gains a *Lifecycle* line: a shipped PRD is superseded by the docs that
describe the built thing, and `prune` proposes it — no skill deletes a PRD automatically.

### Acceptance criteria

- [ ] `create-plan` states that the plan file is transient and names what ends its life.
- [ ] `implement-plan` step 10 deletes a fully-ticked plan file after landing and commits it.
- [ ] `implement-plan` keeps a plan with any unticked criterion and reports it as surviving.
- [ ] `finish-branch` deletes the plan on option 1 only, and names it as a follow-up on option 2.
- [ ] `write-prd` states that a shipped PRD is superseded and is prune's proposal, not a skill's.
- [ ] No skill deletes a PRD automatically.
- [ ] `make check` passes.

---

## Phase 4: Memory holds state, not events

**Depends on**: 1

### Context

- `claude/CLAUDE.md — Agent Working Rules` — the global rule list.
- `.claude/skills/reflect/targets.md — Memory file format` — the memory contract this
  ecosystem controls.
- The barista memory directory is the worked example: 7 of 30 files are run reports.

### What to build

A **Memory holds current state, not events** rule in `claude/CLAUDE.md` under *Agent Working
Rules*. A memory says what is true, never what happened when. Banned: landed-plan records,
milestone records, run reports, completion logs, incident logs written as events. The lesson
from a run is a memory; the run is not. A superseded memory is rewritten in place, or deleted
together with its `MEMORY.md` line. Dates appear only where the fact is itself a date.

The same contract lands in `reflect/targets.md` under *Memory file format*, since that file is
what agents read when writing a memory. Include the rewrite pattern: an event record becomes
its residue — the lesson, the open item, or the constraint that still binds.

### Acceptance criteria

- [ ] `claude/CLAUDE.md` carries the memory rule under *Agent Working Rules*.
- [ ] It bans landed-plan records, milestone records, run reports and completion logs by name.
- [ ] It requires deleting the `MEMORY.md` index line with the file.
- [ ] `reflect/targets.md` states the same contract in its *Memory file format* section.
- [ ] `reflect/targets.md` shows the event-to-residue rewrite pattern.
- [ ] `make check` passes.

---

## Phase 5: reflect retires what it supersedes

**Depends on**: 4

### Context

- `.claude/skills/reflect/SKILL.md — step 5` dedups candidates against existing artifacts.
- `.claude/skills/reflect/SKILL.md — step 6` presents the gated multi-select.
- `.claude/skills/reflect/SKILL.md — step 7` applies picked items and commits.

### What to build

A retirement pass in `reflect`, between dedup and the gate. For every surviving plan item the
agent names what the item makes false or obsolete, searching memory, instructions and docs.
Each retirement becomes its own multi-select option — delete or rewrite — carrying the citation
that proves it superseded. An item with no retirement says so; a fabricated one is worse than
none. Step 7's commit includes the picked retirements.

This closes cause 6: the skill that harvests learnings now also retires them.

### Acceptance criteria

- [ ] `reflect/SKILL.md` has a retirement step between dedup and the gate.
- [ ] Every retirement carries a citation of the superseding evidence.
- [ ] Retirements are separate multi-select options, individually pickable.
- [ ] An item with no retirement states that in one line.
- [ ] Step 7 commits picked retirements together with picked additions.
- [ ] The step is named in the skill's own description or workflow list.
- [ ] `make check` passes.

---

## Phase 6: prune finds records that expired without aging

**Depends on**: 4

### Context

- `.claude/skills/prune/SKILL.md — step 4` collects semantic findings.
- `.claude/skills/prune/criteria.md — Memory review` — mechanical checks, semantic
  verification, and the *Finding contract* class enum
  (`orphaned-index | unindexed | duplicate | dead-reference | stale-claim`).
- `.claude/skills/prune/state-map.md` — the `--days` threshold governs mechanical classes only.

### What to build

A sixth memory class, **`expired-record`**: a memory whose content is an event rather than a
state — a landed plan, a completed milestone, a run report, an incident log. It is not
deletable on sight. The finding first extracts the live residue; where residue exists the
proposal folds it into the relevant keeper memory and then deletes the record, and where none
exists the proposal is a plain deletion. Evidence is the git state or the later memory that
consumed it.

Make the age-independence explicit in both `SKILL.md` step 4 and `criteria.md`: the `--days`
threshold governs the mechanical sweep only, and never reaches memories, rules, or repo
leftovers. That is the barista case — records days old and already obsolete.

### Acceptance criteria

- [ ] `criteria.md` defines the `expired-record` class with its event examples.
- [ ] The class requires extracting live residue before proposing deletion.
- [ ] The *Finding contract* class enum includes `expired-record`.
- [ ] `criteria.md` and `prune/SKILL.md` both state that `--days` never governs the semantic layer.
- [ ] The class cites git state or a later memory as its evidence.
- [ ] `make check` passes.

---

## Phase 7: As-of dates in reports, not in committed docs

**Depends on**: 1

### Context

- `claude/CLAUDE.md — Agent Working Rules` — the research bullet requiring an as-of date.
- `.claude/agents/web-researcher.md` — rule 3 and the output contract. A report surface.
- `.claude/skills/research/SKILL.md` and `.claude/skills/verify-docs/sources.md` — report
  surfaces. Unchanged.
- `guides/monitoring.md` — a free-plan caveat carrying a date.
- `templates/nginx-tls.conf` — Mozilla intermediate v6.0 plus a date.
- `.claude/skills/prune/state-map.md` — its as-of line anchors the drift rule.

### What to build

Scope the global research rule: live verification and official sources stay; the as-of date is
required in the research output, and forbidden in committed docs and code comments. Docs pin a
version instead — the version is the staleness signal, the date is not.

Apply it to the three dated handbook artifacts. `guides/monitoring.md` keeps the
verification-status caveat and loses the date. `templates/nginx-tls.conf` keeps `v6.0` and the
source URL and loses the date. `prune/state-map.md` pins the CLI version its layout was
verified against and loses the date, keeping the drift rule anchored to the version.

`web-researcher`, `research` and `verify-docs` are report surfaces and keep their as-of dates
unchanged.

### Acceptance criteria

- [ ] `claude/CLAUDE.md` requires the as-of date in research output only.
- [ ] It forbids as-of dates in committed docs and code comments, and requires a version pin instead.
- [ ] `guides/monitoring.md` states the verification status without a date.
- [ ] `templates/nginx-tls.conf` cites `v6.0` and the URL without a date.
- [ ] `prune/state-map.md` anchors its drift rule to the CLI version, with no date.
- [ ] `web-researcher.md`, `research/SKILL.md` and `verify-docs/sources.md` are unchanged.
- [ ] `make check` passes.

---

## Phase 8: Align rag

**Depends on**: 1

### Context

Repository `~/r/rag`, file `AGENTS.md`. Three sites, all verified this session:

- The *Prune, don't archive* rule, whose closing clause preserves "dated verification stamps".
- Constraint 5, whose definition of done requires "updated README status with verification date".
- The boundary bullet ending "and date every time-sensitive claim".

Verification command: `make check` (ruff, ty, pytest).

### What to build

Replace *Prune, don't archive* with the canonical **Current state only** wording, keeping rag's
own sentence about the public playbook reading as what is true today. Drop the surviving
"dated verification stamps" clause — Phase 7 moved those dates into reports.

Drop "with verification date" from constraint 5's definition of done; the status stays, the
date goes. Drop "and date every time-sensitive claim" from the boundary bullet, keeping the
whole verify-trained-knowledge requirement that precedes it.

### Acceptance criteria

- [ ] `rag/AGENTS.md` carries the canonical **Current state only** rule.
- [ ] The "dated verification stamps" clause is gone.
- [ ] The definition of done requires an updated README status with no date.
- [ ] The boundary bullet keeps live verification and drops the dating requirement.
- [ ] No rule in the file contradicts another about dates.
- [ ] `make check` passes in `~/r/rag`.
- [ ] Committed on a feature branch in `~/r/rag`.

---

## Phase 9: Align barista

**Depends on**: 1

### Context

Repository `~/r/barista`, file `AGENTS.md`, the working-rules list carrying "Delete, don't
deprecate". Verification command: `make check`.

### What to build

Replace "Delete, don't deprecate" with the canonical **Current state only** rule, nesting the
delete-don't-deprecate sentence under it exactly as Phase 1 did in the handbook. Keep barista's
English. The exception list names `CHANGELOG.md`, ADR files and git history even though barista
has no ADRs today — the wording is canon, not inventory.

### Acceptance criteria

- [ ] `barista/AGENTS.md` carries the canonical rule with the nested delete sentence.
- [ ] No second rule in the file covers the same ground.
- [ ] `make check` passes in `~/r/barista`.
- [ ] Committed on a feature branch in `~/r/barista`.

---

## Phase 10: Align jotti, and make the ADR carve-out explicit

**Depends on**: 1

### Context

Repository `~/r/jotti`, file `AGENTS.md` — German. Relevant sites:

- The completed-plan deletion rule under the git section.
- The ADR rule: decisions of long-range consequence are recorded in `docs/adrs/`.
- "Kein auto-commit" — the agent proposes a commit message, the user commits.

Verification command: `make check`.

### What to build

The German rendering of **Current state only**, placed with the other working rules. Its
exception list names `CHANGELOG.md`, `docs/adrs/` and the git history.

State the ADR carve-out where the ADR rule already lives, so the two rules cannot be read as
contradicting: an ADR is a deliberate record in time, written as an explicit, separate act, and
it is never rewritten to the current state. The existing completed-plan deletion rule stays as
it is — it already encodes the right behaviour and is the precedent the handbook now follows.

Respect "Kein auto-commit": post the Conventional Commit message and stop.

### Acceptance criteria

- [ ] `jotti/AGENTS.md` carries the German **Current state only** rule.
- [ ] Its exception list names `CHANGELOG.md`, `docs/adrs/` and the git history.
- [ ] The ADR rule states that an ADR is a deliberate record in time and is never rewritten.
- [ ] The completed-plan deletion rule is unchanged.
- [ ] `make check` passes in `~/r/jotti`.
- [ ] Nothing is committed; a copy-paste Conventional Commit message is posted in the chat.

---

## Phase 11a: Retire the barista event memories

**Depends on**: 4, 6

### Context

Directory `~/.claude/projects/-home-nico-r-barista/memory/`, 30 files plus `MEMORY.md`. The
seven event records:

| File | Residue to preserve |
| --- | --- |
| `block-1-abriss-landed.md` | the open dead reference destined for Block 7 |
| `block-2-kontrakte-landed.md` | the three holes that stay open |
| `domain-graph-1-5-landed.md` | the three measurements that drive ordering |
| `domain-graph-6-7-landed.md` | the head-to-head loss, round caps, the green-gate lesson |
| `distill-landed-2026-08-01.md` | cite symbol names, never `file:line` |
| `plan-korpus-revised-2026-08-04.md` | Block 3 is planned, not started |
| `session-fork-collision-2026-07-23.md` | one working tree, one session |

Keeper memories that already exist: `prd-sequencing.md` carries roadmap state.

### What to build

Apply the new `expired-record` class by hand to these seven. Each residue lands in a keeper
memory as present-tense state or as a `feedback` lesson; each event record and its `MEMORY.md`
line then goes. Where no keeper fits, write one — a project memory holding where barista stands
now, and a feedback memory for the citation lesson. All new and edited text stays German.

Nothing is deleted before its residue is written. The result is verified by reading `MEMORY.md`
against the directory listing.

### Acceptance criteria

- [ ] Every residue in the table above survives in a keeper memory, in German.
- [ ] The seven event records are deleted.
- [ ] `MEMORY.md` has no line pointing at a deleted file.
- [ ] `MEMORY.md` has a line for every file in the directory.
- [ ] No surviving memory is titled or framed as an event.
- [ ] No `[[name]]` link in the directory points at a deleted memory.

---

## Phase 11b: Triage the jotti plan artifacts

**Depends on**: 4, 6

### Context

Repository `~/r/jotti`, directory `docs/plans/`, three files:

- `review-v0.17.2.md` — 39 unticked boxes.
- `guide-manuelle-qa-v1.0.0.md` — 25 unticked boxes; referenced from
  `backend/api/fiskal/tse_live/tse_live_ausfall_test.go`.
- `plan-bondruck-ursachenklaerung.md` — 9 unticked boxes.

jotti's own rule keeps any plan with an open checkbox. Its CHANGELOG is at 1.0.0, so the two
version-stamped files describe superseded releases.

### What to build

A triage, not a deletion. For each file, determine whether its open boxes describe work that
still matters or work the releases since have overtaken. Present the three verdicts to the user
as a pick-list with the evidence for each, including the Go test reference that would break.
Apply only what the user picks, and post a commit message rather than committing.

### Acceptance criteria

- [ ] Each of the three files has a verdict with cited evidence.
- [ ] The Go test reference is named in the verdict for `guide-manuelle-qa-v1.0.0.md`.
- [ ] Nothing is deleted without an explicit pick.
- [ ] Any deletion is preceded by a repo-wide grep for references to the file.
- [ ] Nothing is committed; a copy-paste Conventional Commit message is posted in the chat.
