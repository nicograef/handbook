---
name: reflect
description: >-
  Runs a structured retrospective over a work session: reports problems,
  solutions, insights, and friction; derives an improvement plan categorized
  as memory, rule, skill, documentation, or tooling/process; and applies only
  the items the user picks. Use as a deliberate end-of-session ritual to
  capture learnings before they evaporate.
argument-hint: "[last N sessions | last N commits | <rev>..<rev>] (default: current session)"
---

# Reflect

## Workflow

### 1. Resolve scope

Argument: $ARGUMENTS

| Scope | Evidence | How |
| --- | --- | --- |
| No argument (default) | the current session — the in-context conversation itself | Never read the session's own transcript file — it is already in context. Works on surfaces with no local transcripts. |
| `last N sessions` | the N most recent past session transcripts | Locate, cap, and summarize them per [sources.md](sources.md). One subagent per transcript, each returning problems, solutions, insights, and friction. |
| `last N commits`, or an explicit revision range (e.g. `v1.2..HEAD`) | git history | Per [sources.md](sources.md). Works in repos and on machines with no transcripts at all. |

### 2. Analyze the evidence

- **Current session** — mine the conversation directly.
- **Transcript and git scopes** — synthesize across the subagent summaries.
- **Either way** — extract the four classes below.
- **Problems and issues that arose** — errors, wrong turns, rework, misunderstandings.
- **Solutions that worked** — fixes, commands, approaches worth repeating.
- **Notable insights** — repo quirks, clarified conventions, facts worth remembering.
- **Recurring friction** — anything that slowed work down more than once.

### 3. Report in the chat

One chat report, fixed sections in this order:

1. **Counts** — e.g. `6 items — 2 problems, 2 solutions, 1 insight, 1 friction`.
2. **Problems & issues** — one bullet per entry.
3. **Solutions found** — one bullet per entry.
4. **Notable insights** — one bullet per entry.
5. **Recurring friction** — one bullet per entry.

Rules, not sections:

- **Every bullet** opens with a bold keyword, then the fact.
- **Empty section** — one line, no padding.
- **Chat only** — never write a report file, journal, or reflections directory.

### 4. Derive plan items

Derive a short improvement plan from the report. Each item:

- **Citation** — the observation it derives from: report section plus entry.
- **Category** — memory, rule, skill, documentation, or tooling/process, per
  [targets.md](targets.md).
- **Tie-break** — when several categories fit, the most automatable wins.
- **Target** — its concrete file or directory, taken from the target map.

### 5. Dedup against existing artifacts

Before proposing, check each candidate for existing coverage:

- **memory** — the memory directory's `MEMORY.md` index and the memory files it links.
- **rules** — `AGENTS.md` and `.claude/rules/*.md`.
- **docs** — the `README.md`-indexed files in `guides/` and `cheatsheets/`.
- **Non-handbook repo** — check the discovered artifacts from [targets.md](targets.md) instead.
- **Already covered** — drop the learning.
- **Covered, but the new evidence adds something** — convert it into an update-proposal for the
  existing artifact.
- **Never** propose a duplicate.

### 6. Present the plan — gated multi-select

- Present the surviving items as a multi-select.
- **Tool** — a structured question tool if the surface has one.
- **Fallback** — otherwise format the options clearly in the conversation, per
  [../clarify/question-rules.md](../clarify/question-rules.md).
- **Each option** shows category, target, and the cited observation.
- **Zero picks** — selecting nothing is a valid outcome.

### 7. Apply picked items only

- Write each picked item to its target per [targets.md](targets.md); write nothing else.
- **Tooling/process beyond a trivial edit** — a new CI job, refactor, or test suite.
- Never implement those inline — recommend running write-prd / create-plan and leave it at that.
- **Commit what you applied** once every picked item is written.
- One commit, with nothing in it the user did not pick.

## Constraints

- Reflection is a deliberate user ritual — never auto-trigger it mid-task.
- Never write to a target the current repo does not actually have.
- See the resolution rules in [targets.md](targets.md).

## Quality

- Run the shared [self-review checklist](../quality.md) on every applied item before presenting
  the result.
- Format the report per the [output style contract](../output-style.md).
