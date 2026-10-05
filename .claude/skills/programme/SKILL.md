---
name: programme
description: Runs several docs/plans plans as one programme: intersects them into waves and lanes, spawns one Opus agent per lane in its own worktree, reviews and lands each wave. Use when two or more plans share files and the user wants them run in parallel.
argument-hint: "<plan paths>"
---

# Programme

The orchestrating session plans, dispatches, reviews and lands; it writes no phase code. Lane agents write code and never land. `docs/plans/programme.md` is the design of record and the only status.

Open [lead.md](../implement-plan/lead.md) before step 5.

## Gotchas

- A limit or API failure is answered from [lead.md](../implement-plan/lead.md#failures).
- A lane agent stops where its plan's phases end unless the brief says the group is the unit. Say it, and resume a stopped agent by SendMessage with the same sentence.
- Lane agents are off the bus. The orchestrator reserves migration numbers in landing order, and names each in its lane's brief.
- A gate per lane on one host exhausts memory. Wrap every gate in one host-wide `flock` and cap the test workers.
- A committed append-only artefact can outgrow the git host's file-size cap. Shard it per key before the first landing.

## The programme file

One file, `docs/plans/programme.md`, with these sections and nothing about a phase's content:

| Section | Holds |
| --- | --- |
| Rule | interleave where files are disjoint; one owner per shared file per wave; the group is the unit of gate, review and landing; long work runs detached; the owner reads only spend rows and irreversible diffs; status lives here only |
| Waves and lanes | one row per lane: wave, phases in order, what it waits for, its store, its detached jobs, its landing slot |
| Ownership | one row per file two lanes of a wave would write: owner, and what the other lane adds at its rebase |
| Landing a group | the lanes' landing order; the protocol is [lead.md](../implement-plan/lead.md#landing) |
| Stores and lanes | how a lane's worktree, store and data are made |
| Migrations | number, phase, lane, what, status; reserved in landing order |
| Spend | leg, projection, who buys after the owner's yes, status |
| Status | one row per phase: lane, wave, status, landed sha |

Cut waves by file ownership: a phase waits only for phases it depends on. Lanes of one wave land smallest surface first so the largest rebase happens once.

## Workflow

1. Read every plan. List each phase's files from its Context and What to build. Group phases that share files into one lane; put lanes that share nothing in one wave. A phase two lanes would both touch belongs to the one that lands first; the other rebases.
2. Write the programme file and commit it. Put every open fork of the plans to the user in one batched round (`decide`). Record the rulings in the plans.
3. Create the wave's lanes from the base with the repo's worktree target. Each lane gets its own store, ports and env. It shares read-only data by symlink and owns what it writes. Seed each store the lane's criteria need. Run this detached and verify each store before dispatch.
4. Write the wave's `common.md` and one `brief.md` per lane, laid out as [Lane briefs](#lane-briefs) says. Keep lane logs, reports and reviews under the same directory for the user's read.
5. Arm the [lead jobs](../implement-plan/lead.md#lead-upkeep). Spawn one `general-purpose` agent per lane on `opus` in one message. The whole prompt is: read common.md, read the brief, do the work, return the report. Announce the lanes on the bus with paths and ports.
6. When a lane reports, review it as [lead.md](../implement-plan/lead.md#verification-budget) says. Confirmed findings go back to the lane's own agent, as [lead.md](../implement-plan/lead.md#dispatch) says.
7. Land in the wave's order as [lead.md](../implement-plan/lead.md#landing) says. The gate runs detached, against the lane's own store, under the host-wide lock. A rebase that brings a lower migration number re-initialises the lane's store. Flip the lane's status rows with the landed sha and the migration numbers taken, and stop its store. A lane that waits for another is created from the new base at that landing, with its own brief.
8. A spend leg is projected at list price in a commit body and put to the user. It is bought only on yes. A diff the owner must read stays in its own commit until read.
9. After the wave: every lane's worktree, branch and store gone. Delete both jobs after the last wave. Run `prog compact` before the next wave so the next session starts from a resume file.

## Lane briefs

Two files per wave under `../<repo>-wt/w<wave>/`: `common.md` for every lane and `<lane>/brief.md` per lane. The agent's prompt names both paths and nothing else; a pasted brief changes with every edit, a path does not.

### common.md

| Section | Says |
| --- | --- |
| Where you work | the worktree path and branch; every command runs there; a command run without the lane's ports and env reaches the main checkout's store; the data directory's symlinks and real directories; the repo's own rules bind, plus staging by path |
| Spend | nothing reaches a paid provider unless the brief names the row and the owner's yes; the paid targets by name; the free instruments that prove a criterion instead; a needed paid run goes under "for the owner" with its list-price projection |
| Long work | every job over a few minutes runs as a `systemd-run --user` unit with its log under the wave directory; the gate runs under the host-wide `flock` with capped workers; one gate per lane at a time |
| Commits | one per phase or coherent step; every figure the plan wants goes in the body verbatim; tick the plan's boxes in the commit that meets them; lint and targeted tests before each commit, the full gate once at the end |
| Migrations | the reserved numbers by phase; every registry the repo keeps beside the migration files; a number nobody reserved is taken as the next free one and reported |
| Ownership | the wave's ownership rows; a needed change in another lane's file goes in its own `<phase>: needs <file>` commit |
| What you do not do | no rebase, merge, landing or push; no questions to the user; no bus; no subagents unless the brief names an agent type; no stopping after one phase, the group is the unit |
| Report | the file path to write it to and the sections: commits, criteria with met or unmet and the evidence, gate tail with its log path, decisions taken, for the owner, left open |

### brief.md

- Lane path, branch, store and service ports, what the store carries and how it was verified.
- The phases in order, each in one sentence naming its deliverable, with the plan file as the source of criteria.
- The rulings the user gave that this lane carries, so the agent does not re-open them.
- What another lane of the wave will add on top of this lane's files, so interfaces stay where they are.
- The files the lane owns and the files it must not edit, both by path.
- Which criteria are proven with fakes and which paid row is projected instead of bought.

## Report

Per wave: lanes landed with shas, migrations taken, spend bought, owner items open, what the next wave waits for. Detail goes into the landing commits.
