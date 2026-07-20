---
name: reflect
description: >-
  Runs a structured retrospective over a work session: reports problems,
  solutions, insights, and friction; derives an improvement plan categorized
  as memory, rule, skill, documentation, or tooling/process; and applies only
  the items the user picks. Use as a deliberate end-of-session ritual to
  capture learnings before they evaporate.
argument-hint: "[last N sessions | last N commits | <rev>..<rev>] (default: current session)"
disable-model-invocation: true
---

# Reflect

Run a retrospective over the evidence in scope, report what happened in the
chat, and turn the learnings the user picks into durable improvements. The
report is ephemeral — the durable output is the applied items.

## Workflow

### 1. Resolve scope

Argument: $ARGUMENTS

- **No argument** → the current session. The evidence is the in-context
  conversation itself — do not read the session's own transcript file; the
  conversation is already in context, and this works on surfaces that have no
  local transcripts.
- **`last N sessions`** → the N most recent past session transcripts. Locate,
  cap, and summarize them per [sources.md](sources.md) — one subagent per
  transcript, each returning problems, solutions, insights, and friction.
- **`last N commits`** or an explicit revision range (e.g. `v1.2..HEAD`) →
  git history per [sources.md](sources.md) — works in repos and on machines
  with no transcripts at all.

### 2. Analyze the evidence

For the current session, mine the conversation directly; for transcript and
git scopes, synthesize across the subagent summaries. Either way, extract:

- problems and issues that arose (errors, wrong turns, rework, misunderstandings)
- solutions that worked (fixes, commands, approaches worth repeating)
- notable insights (repo quirks, clarified conventions, facts worth remembering)
- recurring friction (anything that slowed work down more than once)

### 3. Report in the chat

Fixed sections, in this order:

1. **Problems & issues**
2. **Solutions found**
3. **Notable insights**
4. **Recurring friction**

Chat output only — never write a report file, journal, or reflections
directory.

### 4. Derive plan items

Derive a short improvement plan from the report. Each item:

- cites the observation it derives from (report section + entry)
- is categorized per [targets.md](targets.md) — memory, rule, skill,
  documentation, or tooling/process; when several categories fit, the most
  automatable wins
- names its concrete target (file or directory) from the target map

### 5. Dedup against existing artifacts

Before proposing, check each candidate for existing coverage:

- **memory** — the memory directory's `MEMORY.md` index and the memory files it links
- **rules** — `AGENTS.md` and `.claude/rules/*.md`
- **docs** — the `README.md`-indexed files in `guides/` and `cheatsheets/`

(In a non-handbook repo, check the discovered artifacts from
[targets.md](targets.md) instead.) An already-covered learning is dropped, or
— when the new evidence adds something — converted into an update-proposal
for the existing artifact. Never propose a duplicate.

### 6. Present the plan — gated multi-select

Present the surviving items as a multi-select: use a structured question tool
if the surface has one, otherwise format the options clearly in the
conversation (the fallback rule in
[../clarify/question-rules.md](../clarify/question-rules.md)). Each option
shows category, target, and the cited observation. Selecting nothing is a
valid outcome.

### 7. Apply picked items only

- Write each picked item to its target per [targets.md](targets.md); write
  nothing else.
- A tooling/process item beyond a trivial edit (new CI job, refactor, test
  suite) is never implemented inline — recommend running write-prd /
  create-plan for it and leave it at that.
- **Never commit.** Committing stays a separate, user-approved step
  (`/commit`).

## Constraints

- Reflection is a deliberate user ritual — never auto-trigger it mid-task.
- Declining every plan item means zero writes; the skill ends with no file
  changes.
- The report is chat-only; no persisted reflection artifact of any kind.
- Never write to a target the current repo does not actually have — see the
  resolution rules in [targets.md](targets.md).

## Quality

Run the shared [self-review checklist](../quality.md) on every applied item
before presenting the result.
