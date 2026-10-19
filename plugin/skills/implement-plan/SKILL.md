---
name: implement-plan
description: "Executes a docs/plans plan end to end with no human turn between phases: run worktree, commit per criterion, verified ticks, fold, land. Two or more plans run as a programme of parallel lanes. Use to implement or resume whole plans."
argument-hint: "<plan path> [<plan path> ...]"
hooks:
  Stop:
    - hooks:
        - type: command
          command: 'g="${CLAUDE_PLUGIN_ROOT:-/home/nico/r/handbook/plugin}/scripts/plan-run-guard.sh"; [ -x "$g" ] || { echo "plan-run-guard: $g is missing; this plan run is unguarded" >&2; exit 1; }; exec "$g"'
---

# Implement Plan

Carry a plan from `docs/plans/` to landed commits on the base branch, with no human turn between phases. Progress is durable only once committed and ticked.

With two or more plan paths, follow [programme.md](programme.md) instead. Open [lead.md](lead.md) before the first dispatch, on a stop and before landing.

## Gotchas

- Invoking this skill arms a session-long Stop hook. It blocks a stop once per commit while `plan/<slug>` holds an unticked criterion. Commit `## Run state` before a genuine stop.
- The plan copy on the base branch is stale during the run by design. Read and tick it in the run worktree.
- Redoing finished work is the most expensive failure. Resume first, on every invocation.
- The log outranks the checkbox. A tick without a trailer commit is unticked; a trailer commit without a tick is re-verified, then ticked.
- Pass the plan to every agent as a path. Pasted phase text goes stale on the first tick.
- Pin the base once as a sha and target it in every dry run, rebase and merge.
- Only the lead writes the plan file. No two agents write one file.

## Steps

1. [Resume](#resume). Finish or abort a half-open rebase or merge only from its owning worktree.
2. Read the plan. Detect the base from `origin/HEAD`, else `git ls-remote --symref origin HEAD`; ask if neither resolves.
3. Review the unmet phases in one pass: ambiguous or unverifiable criteria, missing files, commands the allowlist lacks.
4. Phases passing the [concurrency test](#concurrency-test) run as parallel lanes, up to the writer cap in lead.md. Set each phase's review tier.
5. State the run contract once and start: base sha, phase grouping and tiers, worktrees, verify command. Only open forks and missing allowlist commands wait for the user.
6. Create `../<repo>-wt/plan/<slug>` on branch `plan/<slug>` from the pinned base. Confirm the verify command passes on unchanged code.
7. Run sequential phases in the run worktree. A concurrent phase gets its own worktree, branch and agent.
8. Commit per criterion with the trailer `Plan: <slug> phase <N> criterion <M>`. One targeted check per criterion; the full gate once per phase.
9. Tick a phase's criteria in one commit when it closes, only what a tool result proves.
10. Fold each lane into `plan/<slug>` in phase order: rebase onto the run tip, `merge --ff-only`, re-verify.
11. Delete `## Run state` in its own commit, then land as [lead.md](lead.md#landing) says. `git rm` the plan only when every criterion is ticked.
12. Report phases complete and blocked, criteria ticked, commits landed, dropped agents and the plan file's fate.

## Resume

- Inspect every worktree from `git worktree list --porcelain`: half-open rebase, merge or cherry-pick, `index.lock`, dirty files.
- `git log --oneline --all --grep='Plan: <slug> phase'` shows what was committed.
- Read the plan, `## Run state` included, inside the run worktree. Without that worktree, the `plan/*` branches are the durable record.

## Concurrency test

Two phases run concurrently only if all hold:

- Neither `**Depends on**` line names the other.
- The paths in their Context and What to build sections are disjoint.
- Every symbol either names already resolves at the pinned base.
- Neither writes a choke file: the plan, a README or other index, lockfiles, manifests, migration sequences.
- Their branches merge cleanly into the base and into each other. `git merge-tree --write-tree` signals a conflict by exit 1, not by its output.
- The gate survives two concurrent runs: separate database names, ports and temp paths.

## Stops

Forced: commit `## Run state`, report, hand back.

- Any merge or rebase conflict: abort in the owning worktree and report paths and classes. A declared `.gitattributes` merge driver is the only automatic resolution.
- Verification fails twice for one reason after root-cause debugging.
- A step needs a [hazard command](lead.md#git-hazards), or a branch, worktree or file the run did not create.
- A foreign dirty worktree or `index.lock` blocks the path.
- A usage limit or terminal API error: record it verbatim and respond as [lead.md](lead.md#failures) says.
- The plan would have to change: that is the plan skill's job.

Judgment:

- An ambiguous criterion with one surviving reading: implement it and say so in the commit body. Otherwise ask.
- A command missing from the allowlist: use an allowlisted equivalent, or stop and name the exact command.

## Run state

A `## Run state` section in the plan file, committed to `plan/<slug>` on a stop. It holds what git does not show: base branch and full sha, run branch, and one `<path> -> <branch> -> phase <N>` line per worktree. Add the next criterion, the verify command verbatim, the Workflow `scriptPath` and `runId`, and any failure string verbatim.

## Workers

- A brief names the plan path, worktree, branch, phase, verify command, trailer and the plan-file write ban.
- Workers commit each criterion as it verifies. At 30 minutes they commit what verifies and return.
- A fully mechanical phase runs on `sonnet` at low effort; the rest on `opus`.
