# Plan: rework the `implement-plan` skill

Durable handoff state. Any session — resumed, crashed-and-restarted, or woken by cron —
reads this file first and continues from the first unticked box. Delete this file when the
last box is ticked.

## Goal

Rewrite `.claude/skills/implement-plan/SKILL.md` so it executes a **whole** plan instead of
one phase, by orchestrating a Workflow (ultracode) run with parallel git worktrees, staying
aware of other agents/humans touching the repo, surviving failed subagents and API
incidents, checkpointing constantly (commits + plan checkboxes), and then autonomously
rebasing, verifying and merging its branches back into the main worktree.

## Ground truth already established this session

- Old skill: `.claude/skills/implement-plan/SKILL.md`, one-phase-at-a-time, 41 lines.
- Plans are consumed from `docs/plans/plan-<slug>.md`; anatomy is in
  `.claude/skills/create-plan/SKILL.md` (Plan Template section) — phases with
  `### Acceptance criteria` and `- [ ]` checkboxes.
- Skill format contract: `.claude/rules/skills.md`.
- Index to update after the rewrite: `.claude/skills/README.md` (row "Executing an existing
  plan step by step" → Implement Plan). It is currently the only file besides the skill
  itself that mentions `implement-plan`.
- Shared quality gate to link, not restate: `.claude/skills/quality.md`.
- Known tension to resolve, not ignore: `.claude/skills/finish-branch/SKILL.md` requires
  presenting the user four options before merging. An autonomous implement-plan contradicts
  it. Decide: supersede for its own worktrees, or hand off at that boundary.
- Known honesty constraint: a skill's instructions cannot outlast a hard usage-limit stop.
  "Self-repair" must be scoped to checkpointing + cheap resume, not invented mechanisms.
- CronCreate jobs are session-only (in-memory, die with the session, fire only when the
  REPL is idle). On-disk state is the only true durability.

## Research/design workflow

Script: `~/.claude/projects/-home-nico-handbook/930eeaa6-87d6-44db-904d-1bbab0f15393/workflows/scripts/rework-implement-plan-skill-wf_15d4b659-b32.js`
Run ID: `wf_15d4b659-b32`

Resume with `Workflow({scriptPath: "<above>", resumeFromRunId: "wf_15d4b659-b32"})`.
Completed agents return cached. **Check `<transcriptDir>/journal.jsonl` before assuming
anything is cached** — entries are `{"type":"result", ...}` (not `"completed"`), and after
the first stop the journal held only `started` entries, i.e. nothing. As of the second run it
holds 4 `result` entries (the research agents), so a resume replays those instantly and only
re-runs design + judge.

Run log:
- Run 1 stopped manually mid-research; nothing cached.
- Run 2 (2026-08-01 ~13:47–13:59 CEST): research 4/4 completed; all 3 design agents died on
  "session limit · resets 3pm (Europe/Berlin)". Judge never ran; the script returned
  `{error: 'all design proposals failed'}`. Limit reset confirmed at 15:00 CEST.
- The design agents are the expensive replay: they each receive the full ~62k-char dossier.

## Checklist

- [x] Research phase completes (4 agents) — captured to
      `docs/plans/plan-implement-plan-rework-research.md`, committed, replayable from cache
- [ ] Design phase completes (3 proposals + judge); capture the judge's outline into this
      file under "Design outcome" so the design survives without the workflow
- [ ] Write `.claude/skills/implement-plan/SKILL.md`
- [ ] Write the reference files the design calls for (names TBD by the design)
- [ ] Update the `.claude/skills/README.md` index row
- [ ] `grep -rn "implement-plan" --include='*.md' .` — no dead or stale references
- [ ] Reconcile the `finish-branch` contradiction in whichever file the design assigns it to
- [ ] Run the shared self-review checklist (`.claude/skills/quality.md`) on the result
- [ ] Commit (Conventional Commit, no AI attribution trailers)
- [ ] Delete this `plan.md`

## Design outcome

_(fill in from the workflow's synthesis so a fresh session needs no re-research)_
