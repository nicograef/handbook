---
name: implement-plan
description: Executes a docs/plans plan end to end with no human turn between phases: run worktree, commit per criterion, verified ticks, fold, land. Two or more plans run as a programme of parallel lanes. Use to implement or resume whole plans.
argument-hint: "<plan path> [<plan path> ...]"
---

# Implement Plan

Progress is durable only once committed and ticked. The run owns the turn: no human turn between phases, folds and landing. Claim the run for the Stop hook with `${CLAUDE_PLUGIN_ROOT}/scripts/plan-run-guard.sh claim <slug>` once the run branch exists, and again on every pickup. An unclaimed run nudges every session in the repo.

Open [lead.md](lead.md) before the first dispatch, on a stop and before landing.

With two or more plan paths, follow [programme.md](programme.md) instead of the workflow below. It intersects the plans into waves and lanes, one agent and worktree per lane.

## Gotchas

- The plan copy on the base branch is stale during the run by design. Read it in the run worktree.
- Under `rebase`, `--ours` is the base side; under `merge` it is your branch. Read the conflict, do not assume.
- Pass the plan file to a Workflow agent as a path. Pasted phase text goes stale on the first tick and defeats resume.
- Pin the base once, `BASE=$(git rev-parse refs/heads/<base>)`, and target the sha in every dry run, rebase and merge.

## Workflow

1. Resume first, on every invocation: run the pickup sequence in [git.md](git.md). Finish or abort a half-open rebase or merge in its owning worktree. Redoing finished work is the most expensive failure.
2. Read the plan. Detect the base branch with `git symbolic-ref --short refs/remotes/origin/HEAD`, then `git ls-remote --symref origin HEAD`; ask if neither resolves. Pin it.
3. Review every unmet phase in one pass: ambiguous criteria, missing files, criteria no command verifies, shell commands the allowlist lacks.
4. Choose the shape. Run the concurrency test in [git.md](git.md) on every phase pair. Each pair that passes becomes a lane, up to the [writer cap](lead.md#dispatch); sequential is the fallback. Set each phase's [review tier](lead.md#verification-budget).
5. Present the run contract once: plan, base and sha, phases with grouping and tiers, worktrees and branches. Also the verify command, stop conditions, open questions and missing allowlist commands. This is the run's only planned human turn.
6. Create `../<repo>-wt/plan-<slug>` on branch `plan/<slug>` from `$BASE`. Confirm the verify command passes on unchanged code.
7. Execute phases in order. Sequential phases run in the run worktree; a concurrent group gets one worktree, branch and agent per phase. No two agents write one file; only the lead writes the plan file.
8. Commit per criterion that names its own change, then tick. Workers batch verification: one targeted test run per criterion, the full gate once per phase, scoped to the languages touched. No gate, build or review after a single edit. Tick a phase's criteria in one commit when it closes, and only what a tool result proves. Verification failing twice for one reason: debug root-cause first, then stop.
9. Fold each group into `plan/<slug>` in phase order with the fold sequence in [git.md](git.md). Re-verify after each fold.
10. Remove `## Run state` in its own commit, then land `plan/<slug>` as [lead.md](lead.md#landing) says. `git rm` the plan file after landing only when every criterion is ticked.
11. Report: `3 phases — 2 complete, 1 blocked; 9 criteria ticked; 11 commits landed`, then phases, dropped agents, unticked items and the plan file's fate.

## Stops

| Kind | Trigger | Action |
| --- | --- | --- |
| Forced | Any merge or rebase conflict | Abort in the owning worktree, report paths and classes, hand back |
| Forced | Verification fails repeatedly for one reason after debugging | Stop |
| Forced | A step needs a hazard command, or a branch, worktree or file the run did not create | Stop |
| Forced | A foreign dirty worktree or `index.lock` blocks the path | Stop as [git.md](git.md#hazards-in-a-multi-worktree-repo) says |
| Forced | Usage limit or terminal API error | Commit `## Run state` with the verbatim string; respond as [lead.md](lead.md#failures) says |
| Judgment | A criterion is ambiguous or unverifiable | One reading survives: implement it, say so in the commit body. Otherwise ask |
| Judgment | The plan would have to change | That is `plan`'s job: stop |
| Judgment | A shell command is not allowlisted | Use an allowlisted equivalent, or stop and name the exact command |

## Run state block

Written into the plan file on a stop, committed to `plan/<slug>`, deleted in its own commit before landing.

| Field | Value |
| --- | --- |
| `Base` | `<base-branch> <40-hex sha>` |
| `Run branch` | `plan/<slug>` |
| `Worktrees` | one row per member: `<path> -> <branch> -> phase <N>` |
| `Next criterion` | `phase <N> criterion <M>` |
| `Verify` | the verify command, verbatim |
| `Workflow` | `scriptPath=<path>` and `runId=<id>` |
| `Failure` | the verbatim failure string, only when the run died |

## Workers

- Commit subject Conventional Commit, trailer `Plan: <slug> phase <N> criterion <M>`.
- Give a worker: plan path (as a path), worktree path, branch, phase number, verify command, trailer format, plan-file write ban.
- Add: "commit each criterion as it verifies; run the full gate once, at phase end". Also: "at 30 minutes commit what verifies and return".
- A fully mechanical phase runs on `sonnet` with `effort: low`; the rest on `opus`.
