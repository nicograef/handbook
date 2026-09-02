---
name: reflect
description: >-
  Runs a structured retrospective over a work session: reports problems,
  solutions, insights, and friction; derives an improvement plan categorized
  as memory, rule, skill, documentation, or tooling/process; retires the
  artifacts those items supersede; and applies only the items the user picks.
  Use as a deliberate end-of-session ritual to capture learnings before they
  evaporate.
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

- **Problems and issues that arose** — errors, wrong turns, rework, misunderstandings.
- **Solutions that worked** — fixes, commands, approaches worth repeating.
- **Notable insights** — repo quirks, clarified conventions, facts worth remembering.
- **Recurring friction** — anything that slowed work down more than once.

### 3. Report in the chat

One chat report, fixed sections in this order: **Problems & issues**, **Solutions found**,
**Notable insights**, **Recurring friction**. Each section is one bullet per entry.

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

- **Per-category surfaces** — see the target map in [targets.md](targets.md#handbook-target-map).
- **Non-handbook repo** — check the discovered artifacts from [targets.md](targets.md) instead.
- **Already covered** — drop the learning.
- **Covered, but the new evidence adds something** — convert it into an update-proposal for the
  existing artifact.
- **Never** propose a duplicate.

### 6. Retire what the items supersede

Run the **Supersede check** from [../quality.md](../quality.md) over every surviving item.

- **Memory hits** — retire them per the event-to-residue pattern in [targets.md](targets.md).

### 7. Present the plan — gated multi-select

- Present the surviving items as a multi-select, per
  [../clarify/question-rules.md](../clarify/question-rules.md).
- **Each option** shows category, target, and the cited observation.
- **Each retirement** is its own option, listed under its item and pickable on its own.
- **Retirement option** shows the target, the verdict — delete or rewrite — and its citation.
- **Zero picks** — selecting nothing is a valid outcome.

### 8. Apply picked items and retirements only

- Write each picked item to its target per [targets.md](targets.md); write nothing unpicked.
- **Each picked retirement** — delete or rewrite the statement its citation names.
- **Tooling/process beyond a trivial edit** — a new CI job, refactor, or test suite.
- Never implement those inline — recommend running write-prd / create-plan and leave it at that.
- **Commit what you applied** once every picked item and retirement is written.
- One commit carrying both, with nothing in it the user did not pick.

## Constraints

- Reflection is a deliberate user ritual — never auto-trigger it mid-task.
- Never write to a target the current repo does not actually have.
- See the resolution rules in [targets.md](targets.md).

## Quality

- Run the shared [self-review checklist](../quality.md) on every applied item before presenting
  the result.
- Format the report per the [output style contract](../output-style.md).
