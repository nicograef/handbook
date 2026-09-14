---
name: implement-plan
description: Executes a docs/plans plan end to end with no human turn between phases: run worktree, commit per acceptance criterion, verified ticks, fold, land. Also resumes a stopped run. Use when the user wants a whole plan implemented or picked back up.
argument-hint: "<path to plan file>"
disable-model-invocation: true
---

# Implement Plan

Progress is durable only once committed and ticked. The run owns the turn: no human turn between phases, folds and landing. The Stop hook `plan-run-guard.sh` blocks a stop while `plan/<slug>` still has an unticked criterion.

## Gotchas

- `rerere.enabled` is on in `~/.gitconfig`. A repeat conflict comes back fully resolved with no markers while `git status` still shows `UU`. Run every merge and rebase with `-c rerere.enabled=false`.
- `git stash` is repo-global across worktrees, so two agents pop each other's work. Commit instead.
- The plan copy on the base branch is stale during the run by design. Read it in the run worktree.
- Under `rebase`, `--ours` is the base side; under `merge` it is your branch. Read the conflict, do not assume.
- Pass the plan file to a Workflow agent as a path. Pasted phase text changes the cache key on the first tick and forces every later `agent()` call to rerun.
- Pin the base once, `BASE=$(git rev-parse refs/heads/<base>)`, and target the sha in every dry run, rebase and merge.

## Workflow

1. Resume first, on every invocation: run the pickup sequence in [git.md](git.md). Finish or abort a half-open rebase or merge in its owning worktree. Redoing finished work is the most expensive failure.
2. Read the plan. Detect the base branch with `git symbolic-ref --short refs/remotes/origin/HEAD`, then `git ls-remote --symref origin HEAD`; ask if neither resolves. Pin it.
3. Review every unmet phase in one pass: ambiguous criteria, missing files, criteria no command verifies, shell commands the allowlist lacks.
4. Choose the shape. Sequential is the default; the concurrency test is in [git.md](git.md). Set each phase's review tier. Gate only for redoable work; one probe where a rerun is paid or slow. Probes plus a human read before anything irreversible.
5. Present the run contract once: plan, base and sha, phases with grouping and tiers, worktrees and branches. Also the verify command, stop conditions, open questions and missing allowlist commands. This is the run's only planned human turn.
6. Create `.worktrees/plan-<slug>` on branch `plan/<slug>` from `$BASE`. Confirm the verify command passes on unchanged code.
7. Execute phases in order. Sequential phases run in the run worktree; a concurrent group gets one worktree, branch and agent per phase. No two agents write one file; only the lead writes the plan file.
8. Commit per criterion that names its own change, then tick. Workers run targeted tests per criterion and the full gate once per phase, scoped to the languages touched. Tick a phase's criteria in one commit when it closes, and only what a tool result proves. Verification failing twice for one reason: debug root-cause first, then stop.
9. Fold each group into `plan/<slug>` in phase order with the fold sequence in [git.md](git.md). Re-verify after each fold.
10. Land `plan/<slug>` on the base with the landing sequence, then re-verify in the main checkout. Remove `## Run state` in its own commit before landing. `git rm` the plan file after landing only when every criterion is ticked. Remove the run's worktrees and `-d` its merged branches. Push, PR or discard is the user's call.
11. Report: `3 phases — 2 complete, 1 blocked; 9 criteria ticked; 11 commits landed`, then phases, dropped agents, unticked items and the plan file's fate.

## Stops

| Kind | Trigger | Action |
| --- | --- | --- |
| Forced | Any merge or rebase conflict | Abort in the owning worktree, report paths and classes, hand back |
| Forced | Verification fails repeatedly for one reason after debugging | Stop |
| Forced | A step needs a hazard command, a push, or a branch, worktree or file the run did not create | Stop |
| Forced | A foreign dirty worktree or `index.lock` blocks the path | Report it; never clear another session's state |
| Forced | Usage limit or terminal API error | Commit `## Run state`, report the verbatim string and reset time |
| Judgment | A criterion is ambiguous or unverifiable | One reading survives: implement it, say so in the commit body. Otherwise ask |
| Judgment | The plan would have to change | That is `plan`'s job: stop |
| Judgment | A shell command is not allowlisted | Use an allowlisted equivalent, or stop and name the exact command |

## Dispatch

- Commit subject Conventional Commit, trailer `Plan: <slug> phase <N> criterion <M>`, no AI attribution.
- Give a worker: plan path (as a path), worktree path, branch, phase number, verify command, trailer format, plan-file write ban. Add: "commit each criterion as it verifies; at 30 minutes commit what verifies and return". A fully mechanical phase runs on `sonnet` with `effort: low`; the rest on `opus`.
- A returned `null` is a phase that did not happen; its branch keeps its commits. Re-dispatch it to continue from `git log <branch>`, never from scratch.
- A defect a review finds goes back to the phase's own worker via SendMessage. Carry the defect classes into the next phase's prompt.
- Cap writers at 4 (one checkout, install and fold each); read-only scouts and reviewers at the runtime's cap. While phase N's writer works, a read-only scout may prepare phase N+1.
