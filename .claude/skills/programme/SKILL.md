---
name: programme
description: Runs several docs/plans plans as one programme: intersects them into waves and lanes, spawns one Opus agent per lane in its own worktree, reviews and lands each wave. Use when two or more plans share files and the user wants them run in parallel.
argument-hint: "<plan paths>"
---

# Programme

The orchestrating session plans, dispatches, reviews and lands; it writes no phase code. Lane agents write code and never land. `docs/plans/programme.md` is the design of record and the only status.

Open [lead.md](../implement-plan/lead.md) before step 5. It holds lead upkeep, failures, dispatch, the verification budget and the landing protocol.

## Gotchas

- A limit or API failure is answered from [lead.md](../implement-plan/lead.md#failures).
- A lane agent stops where its plan's phases end unless the brief says the group is the unit. Say it, and resume a stopped agent by SendMessage with the same sentence.
- Lane agents are off the bus. The orchestrator reserves migration numbers in landing order, names each in its lane's brief, and announces the lanes.
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
4. Write the wave's `common.md` and one `brief.md` per lane, laid out as [lane-brief.md](lane-brief.md) says. Keep lane logs, reports and reviews under the same directory for the user's read.
5. Arm the [lead jobs](../implement-plan/lead.md#lead-upkeep). Spawn one `general-purpose` agent per lane on `opus` in one message. The whole prompt is: read common.md, read the brief, do the work, return the report. Announce the lanes on the bus with paths and ports.
6. Check in through the check-in job, reading what [lead.md](../implement-plan/lead.md#lead-upkeep) lists.
7. When a lane reports, review it as [lead.md](../implement-plan/lead.md#verification-budget) says. Confirmed findings go back to the lane's own agent, as [lead.md](../implement-plan/lead.md#dispatch) says.
8. Land in the wave's order as [lead.md](../implement-plan/lead.md#landing) says. The gate runs detached, against the lane's own store, under the host-wide lock. A rebase that brings a lower migration number re-initialises the lane's store. Flip the lane's status rows with the landed sha and the migration numbers taken, and stop its store. A lane that waits for another is created from the new base at that landing, with its own brief.
9. A spend leg is projected at list price in a commit body and put to the user. It is bought only on yes. A diff the owner must read stays in its own commit until read.
10. After the wave: status rows flipped, every lane's worktree, branch and store gone, live peers sent `landed` by SendMessage, memory updated. Delete both jobs after the last wave. Run `prog compact` before the next wave so the next session starts from a resume file.

## Report

Per wave: lanes landed with shas, migrations taken, spend bought, owner items open, what the next wave waits for. Detail goes into the landing commits.
