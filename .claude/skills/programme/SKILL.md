---
name: programme
description: Runs several docs/plans plans at once as one programme: intersects them into waves and lanes, writes lane briefs, spawns one Opus agent per lane in a worktree with its own store, checks in, reviews, lands each wave on the base and cleans up. Use when two or more plans share files and the user wants them run in parallel.
argument-hint: "<plan paths>"
---

# Programme

The orchestrating session plans, dispatches, reviews and lands; it writes no phase code. Lane agents write code and never land. `docs/plans/programme.md` is the design of record and the only status.

## Gotchas

- Every subagent dispatch sets `model: opus` (`sonnet` for mechanical work), reviewers included. A subagent never changes model on a limit.
- A limit is answered from [implement-plan's failure strings](../implement-plan/SKILL.md#failure-strings). Only the lead moves to Opus 5, and only through the user's `/model`.
- A session cannot switch its own model. A scheduled `/model` arrives as plain text, and `settings.json` is read once at start.
- A lane agent stops where its plan's phases end unless the brief says the group is the unit. Say it, and resume a stopped agent by SendMessage with the same sentence.
- Lane agents are off the bus. The orchestrator reserves migration numbers in landing order, names each in its lane's brief, and announces the lanes.
- Peers commit to the base mid-landing. Announce a `claim` on the base before a wave lands and ask peers to hold it until `landed`. Re-run radar before every rebase.
- A gate per lane on one host exhausts memory. Wrap every gate in one host-wide `flock` and cap the test workers.
- One committed artefact can outgrow the host's file cap (a 75 MB ledger). Shard append-only files per key before the first landing.
- The permission classifier refuses cleanup that looks destructive (`docker volume rm`, `git checkout --`). Leave those to the user and list them in the handoff.

## Lead upkeep

Arm both jobs before the first dispatch. Both are fixed-interval `CronCreate` jobs. They outlive a turn that a limit killed and come back on `claude --resume`; a self-paced `/loop` does neither.

| Job | Arm with | Each fire |
| --- | --- | --- |
| Check-in | `/loop 15m <prompt>` | Read agents, workflows, peers and host as step 6 lists. Act on what changes a lane's next step. Bring the scratchpad up to date |
| Recovery | `CronCreate` at `7 * * * *` | Assume the last turn died. Rebuild state from the scratchpad and verify it. Resume or re-dispatch each dead lane from its last commit. Re-arm a missing job |

- Both prompts name the scratchpad file and `docs/plans/programme.md` by path, so a fire needs no context.
- The scratchpad holds what git does not. Its first line is the resume action, `/model claude-opus-5` included. A Fable limit leaves no last turn, so the scratchpad is the handoff.
- Its rows: agent id per lane, the tasks directory, job ids, unit names, open owner items, the next step.
- Verify before trusting. Hold each row against its source: `git worktree list`, branch tips, `CronList`, `systemctl --user`, the tasks directory. Rewrite the row that lies.
- Memory changes when state changes, a landed wave or a ruling. Check that every path and flag it names still exists.
- A job expires seven days after creation; the recovery fire re-creates one older than six.
- A job fires only while the session is idle and cannot answer a permission prompt. A quiet fire ends in one line.

## The programme file

One file, `docs/plans/programme.md`, with these sections and nothing about a phase's content:

| Section | Holds |
| --- | --- |
| Rule | interleave where files are disjoint; one owner per shared file per wave; the group is the unit of gate, review and landing; long work runs detached; the owner reads only spend rows and irreversible diffs; status lives here only |
| Waves and lanes | one row per lane: wave, phases in order, what it waits for, its store, its detached jobs, its landing slot |
| Ownership | one row per file two lanes of a wave would write: owner, and what the other lane adds at its rebase |
| Landing a group | the protocol below |
| Stores and lanes | how a lane's worktree, cluster and data directory are made |
| Migrations | number, phase, lane, what, status; reserved in landing order |
| Spend | leg, projection, who buys after the owner's yes, status |
| Status | one row per phase: lane, wave, status, landed sha |

Cut waves by file ownership: a phase waits only for phases it depends on. Lanes of one wave land smallest surface first so the largest rebase happens once.

## Workflow

1. Read every plan. List each phase's files from its Context and What to build. Group phases that share files into one lane; put lanes that share nothing in one wave. A phase two lanes would both touch belongs to the one that lands first; the other rebases.
2. Write the programme file and commit it. Put every open fork of the plans to the user in one batched round (`decide`). Record the rulings in the plans.
3. Create the wave's lanes from the base with `make worktree NAME=w<wave>-<lane>` or the repo's equivalent. Each lane gets one cluster and one `.env`. Its `data/` is symlinks into the main checkout's read trees plus real directories for what it writes. Restore a dump where a lane measures on the corpus. Run this detached and verify each store before dispatch.
4. Write `<wt>/w<wave>/common.md` and one `brief.md` per lane from [lane-brief.md](lane-brief.md). Keep lane logs, reports and reviews under the same directory for the user's read.
5. Arm the lead jobs. Spawn one `general-purpose` agent per lane on `opus` in one message. The whole prompt is: read common.md, read the brief, do the work, return the report. Announce the lanes on the bus with paths and ports.
6. Check in every 15 minutes through the check-in job. Read the agents' last tool calls (`scripts/check-agents.sh`), workflow runs, the bus inbox and `peers`, `free -m`, the lane units and the base's log. Act on what changes a lane's next step; otherwise do nothing.
7. When a lane reports, review its whole diff once on `opus`. Verify each finding against the code. Send the confirmed ones back to the lane's own agent by SendMessage and re-review after the fix. One review per fix round.
8. Land in the wave's order with the protocol below. A lane that waits for another is created from the new base at that landing, with its own brief.
9. A spend leg is projected at list price in a commit body and put to the user. It is bought only on yes. A diff the owner must read (terms readings, manifests) stays in its own commit until read.
10. After the wave: status rows flipped, every lane's worktree, branch and cluster gone, the bus told, memory updated. Delete both jobs after the last wave. Run `prog compact` before the next wave so the next session starts from a resume file.

## Landing a group

1. `agent-bus.sh radar`; a conflict with a peer of the wave is settled by the landing order, the later lane rebasing.
2. Rebase the lane onto the base. A rebase that brings a lower migration number re-initialises the lane's store. A rebase that brings code means a full re-gate. Docs only means the lints plus the suites naming the changed directory.
3. The gate runs on the lane, detached under `systemd-run --user`, against the lane's own store, under the host-wide lock. Green means a complete run.
4. One review of the group's diff on `opus`; findings verified before any is applied.
5. `git merge --ff-only` on the base and `landed` on the bus. The same commit flips the status rows with the sha and the migration numbers taken.
6. `git worktree remove` the lane, `git branch -d` it, stop its cluster. A base that moved under a peer's commit means one more rebase; the ff-only refusal is the detector.

## Report

Per wave: lanes landed with shas, migrations taken, spend bought, owner items open, what the next wave waits for. Detail goes into the landing commits.
