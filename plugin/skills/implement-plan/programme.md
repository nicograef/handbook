# Programme

Two or more plans run as one programme. The orchestrator plans, dispatches, reviews and lands; it writes no phase code. Lane agents write code and never land. Open [lead.md](lead.md) before the first spawn.

## Gotchas

- The Stop hook reads the `## Status` table of `docs/plans/programme.md` at HEAD. It holds one row per phase, phase first.
- A Status cell of `waiting` or `running` blocks a stop; `landed` and `dropped` do not.
- A lane agent stops where its plan's phases end unless the brief says the group is the unit. Resume a stopped one by SendMessage with that sentence.
- Lane agents are off the bus. The orchestrator reserves migration numbers in landing order and names them in each brief.
- One gate per lane on one host exhausts memory. Wrap every gate in one host-wide `flock` and cap the test workers.
- A committed append-only artefact can outgrow the git host's file-size cap. Shard it per key before the first landing.
- Spend follows the [global irreversible-work rule](../../../claude/global.md#models-and-subagents). A diff the owner must read stays in its own commit until read.

## Steps

1. Read every plan and list each phase's files. Phases sharing files form one lane; lanes sharing nothing form one wave.
2. A file two lanes of a wave touch belongs to the lane that lands first; the other rebases.
3. Write and commit `docs/plans/programme.md`: waves and lanes, file ownership, landing order, stores, migrations, spend, Status. It is the only status.
4. Decide the plans' open forks; put only those with no clear winner to the user in one decide round. Record the rulings in the plans.
5. Create the wave's lanes from the base with the repo's worktree target. Each gets its own store, ports and env, seeded and verified before dispatch.
6. Write `common.md` and one `<lane>/brief.md` per lane under `../<repo>-wt/w<wave>/`. Lane logs and reports live there too.
7. Arm the [lead jobs](lead.md#upkeep). Spawn one `general-purpose` agent per lane on `opus` in one message. Its prompt names the two brief paths only.
8. Announce the lanes on the bus with paths and ports. Review each lane report as [lead.md](lead.md#dispatch-and-review) says.
9. Land in wave order, smallest surface first, as [lead.md](lead.md#landing) says. The gate runs detached, against the lane's store, under the lock.
10. A rebase bringing a lower migration number re-initialises the lane's store.
11. The landing commit flips the lane's Status rows with sha and migrations, and ticks the criteria the reviewed report proves.
12. A lane waiting for another starts from the new base with its own brief.
13. After each wave, remove every lane's worktree, branch and store, then run `prog compact`. Delete both jobs after the last wave.

## Briefs

`common.md` tells every lane:

- Every command runs in the lane worktree. One without the lane's ports and env reaches the main checkout's store.
- No paid provider call unless the brief names the spend row. A needed paid run goes to the owner with its list-price projection.
- Jobs over a few minutes run as `systemd-run --user` units, logged under the wave directory.
- The plan file stays untouched; the report carries each criterion with its evidence.
- A change in another lane's file goes in its own `<phase>: needs <file>` commit.
- No rebase, merge, landing, push, questions to the user, bus or unnamed subagents. The group is the unit.

`brief.md` names the lane's path, branch, store, ports and phases with deliverables. It names the rulings it carries and the files it owns or must not touch. It says what other lanes add on top.

Report per wave: lanes landed with shas, migrations taken, spend bought, open owner items, what the next wave waits for.
