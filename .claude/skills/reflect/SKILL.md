---
name: reflect
description: End-of-session retrospective. Reports problems, solutions, insights and friction, proposes improvements as memory, rule, skill, doc or tooling items with what they retire, and applies only the items the user picks.
argument-hint: "[last N sessions | last N commits | <rev>..<rev>]"
disable-model-invocation: true
---

# Reflect

A deliberate ritual the user starts; never run it mid-task. The report lives in the chat only.

## Evidence

| Scope | Source |
| --- | --- |
| none (default) | The current conversation, already in context. Do not read its transcript file |
| `last N sessions` | The project's past session transcripts, newest first, excluding the live session. One `sonnet` subagent per transcript returns the four sections below; more than 5 needs confirmation. Parse line by line, keep user and assistant text, tolerate unparseable lines. Never load a raw transcript into the main context |
| `last N commits`, `<rev>..<rev>` | `git log --stat`: reverts, fixups, repeated touches of one file, "fix"/"actually"/"again" wording. Chunks of 10–20 commits per subagent |

## Workflow

1. Report in four sections, one bullet per entry, one line when empty: **Problems & issues**, **Solutions found**, **Notable insights**, **Recurring friction**.
2. Derive plan items, each with its citation (section and entry), category and concrete target:

   | Category | When | Target |
   | --- | --- | --- |
   | memory | A session-crossing fact about the user or project not derivable from the repo | The project's auto-memory directory plus its index line; only if the directory exists |
   | rule | A convention for agent behaviour | `AGENTS.md` or `CLAUDE.md` (repo-wide), `.claude/rules/<topic>.md` (path-scoped) |
   | skill | A repeatable multi-step workflow | `.claude/skills/<name>/`, only where that directory already exists |
   | documentation | Human-facing knowledge someone will look up | The repo's docs layout, plus its index |
   | tooling | Preventable by a check, test, lint rule, Make target or script | The repo's Makefile, CI or scripts; anything beyond a trivial edit becomes a recommendation to run `plan` |

   A check beats a rule; a rule beats a memory. Targets are discovered in the repo at hand, never assumed from the handbook.
3. Dedup against the existing artifacts of each category. Already covered: drop it. Covered but the evidence adds something: propose an update instead.
4. For each surviving item, search docs, rules and memory for the statement it replaces. Propose that retirement beside the item. A memory that records an event is rewritten as its residue, in present tense. A landed plan becomes the constraints it settled. A run report becomes the lesson, a milestone the state it left.
5. Present items and retirements as one multi-select, each showing category, target and citation. Zero picks is valid.
6. Apply picked items and retirements only, then commit them in one commit.
