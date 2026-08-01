---
name: implement-plan
description: >-
  Executes an entire implementation plan end to end — phase by phase in
  dedicated git worktrees, committing and ticking each acceptance criterion as
  it is verified, then rebasing and merging its branches back onto the base
  branch. Use when the user wants a whole plan implemented autonomously, or
  wants to pick a plan run back up after a crash, a usage limit, or a stopped
  workflow.
argument-hint: "<path to plan file>"
---

# Implement Plan

Execute a whole plan without a human turn between phases. Work is durable only
once it is committed and ticked, so that is the unit of progress — everything
else happens between checkpoints.

## Workflow

1. **Resume before you start** — every invocation, including the first. Run the
   pickup sequence in [recovery.md](recovery.md): worktree list, state scan,
   `## Run state`, commit log, reconcile. Finish or abort any half-open
   rebase/merge **in its owning worktree** first. Redoing finished work is the
   most expensive failure available.
2. **Read the plan; pin the base.** Collect every phase with unmet `- [ ]`
   (plan anatomy: [create-plan](../create-plan/SKILL.md)). Detect the base
   branch with `git symbolic-ref --short refs/remotes/origin/HEAD`, falling back
   to `git ls-remote --symref origin HEAD`; if neither resolves, ask — do not
   assume `main`. Then pin it: `BASE=$(git rev-parse refs/heads/<base>)`. Every
   dry run, rebase and merge targets `$BASE`, never a moving branch name.
3. **Review every unmet phase in one pass** — ambiguous criteria, missing
   context files, conflicting instructions, criteria no command can verify.
4. **Choose the shape** — execution mode and the concurrency test, both in
   [orchestration.md](orchestration.md). Sequential is the default.
5. **Present the run contract and get one go-ahead**: plan path, base branch and
   pinned sha, the phase list with its grouping, worktree paths and branch
   names, the verification command, the stop conditions, and every question from
   step 3. This is the run's only planned human turn — it is
   [using-git-worktrees](../using-git-worktrees/SKILL.md) step 3's
   confirm-before-creating, asked once instead of once per worktree. In the same
   message, name any shell command the agents will need that is not already
   allowlisted: an unattended run stalls on a permission prompt.
6. **Create the run worktree** `.worktrees/plan-<slug>` on branch `plan/<slug>`
   from `$BASE`, per [using-git-worktrees](../using-git-worktrees/SKILL.md).
   Confirm a clean baseline there — the verify command passes on unchanged
   code — before the first edit, so later failures are attributable.
7. **Execute each unit in order.** Sequential phases run in the run worktree. A
   concurrency-eligible group gets one worktree, one branch and one agent per
   phase; dispatch per [orchestration.md](orchestration.md) and the
   [delegation contract](../dispatching-parallel-agents/SKILL.md). No two agents
   ever write one file, and no agent ever writes the plan file.
8. **Commit per acceptance criterion, then tick.** Run the project's
   verification command — `make test` or `make check` if the repo has a
   Makefile, otherwise the language-appropriate default (`go test ./...`,
   `pnpm test`, `mvn test`). Commit the change with the run trailer
   (Constraints), then flip `- [ ]` → `- [x]` and commit that separately. Tick
   only what a tool result from this session proves. If verification fails twice
   on one phase for the same reason, switch to
   [systematic-debugging](../systematic-debugging/SKILL.md); if that does not
   resolve it, stop.
9. **Fold each parallel group** into `plan/<slug>` in ascending phase order
   using the fold sequence in [integration.md](integration.md), transcribing
   that phase's ticks as you go and re-running verification after each fold —
   passing in isolation does not mean passing together.
10. **Land** `plan/<slug>` on the base branch with the landing sequence in
    [integration.md](integration.md), then re-verify in the main checkout.
    Delete the `## Run state` block and commit that removal **before** landing,
    so the base branch never receives it. Then `git worktree remove` each
    worktree the run created and `git branch -d` each merged branch. Push, PR or
    discard is [finish-branch](../finish-branch/SKILL.md)'s decision, not yours.
11. **Report**: phases completed, criteria ticked, commits landed, agents that
    returned nothing and what happened to their work, and anything left unticked
    with the reason.

## Stop and ask

- Any merge or rebase conflict. Abort in the owning worktree, report the paths
  and their classes, hand back. Nothing is auto-resolved by content — see
  [integration.md](integration.md).
- A phase's criteria are ambiguous, unverifiable, or depend on something that
  does not exist.
- Verification fails repeatedly for the same reason after a debugging pass.
- Proceeding would need anything on the [hazard list](integration.md#hazards), a
  push, a force-push, `--no-verify`, or deleting a branch, worktree or file the
  run did not create.
- A worktree, branch, `index.lock` or `refs/agent-lock/*` the run does not own
  is dirty, held, or mid-operation and blocks the path. Report it; never clear
  another worktree's state.
- The plan would have to change — a new phase, a reworded criterion, a different
  design. That is [create-plan](../create-plan/SKILL.md)'s job; this skill
  executes.
- A usage limit or a terminal API error. Not a question, a forced stop: write
  and commit the `## Run state` block, then report the verbatim failure string
  and any reset time it printed. Taxonomy in [recovery.md](recovery.md).

## Constraints

- **Commit message**: Conventional Commit subject plus one trailer,
  `Plan: <slug> phase <N> criterion <M>`. That trailer is what makes a dead
  agent's work findable after its branch is gone. No AI attribution trailers.
- **One writer per file, always.** The lead is the sole writer of the plan file
  for the whole run; subagents receive its path to read. Index files, lockfiles
  and entry points are lead-owned, as in
  [distill/parallelism.md](../distill/parallelism.md#apply-stage-partitioning).
- **Never `git stash`** — it is repo-global, not per-worktree, so two agents pop
  each other's work. Commit instead.
- **Never** `git gc --prune=now`, `git update-ref` on a branch,
  `git rebase --update-refs`, `git checkout -- .`, `git restore .`,
  `git clean -fd`, `git reset --hard`, `git branch -D`, or
  `git worktree remove --force`. What each destroys and its safe substitute are
  in [integration.md](integration.md#hazards).
- **Never push the base branch, never force-push, never `--no-verify`.**
- Set `model` explicitly on every delegated agent; routing in
  [distill/parallelism.md](../distill/parallelism.md#model-routing).
- Prefer simple, clear, idiomatic solutions. No performance optimisation at the
  cost of readability; small local duplication is fine when it aids
  understanding.
- If the user wants to write the code themselves, that is
  [guided-implementation](../guided-implementation/SKILL.md).

## Quality

- After each phase lands on `plan/<slug>`, run the shared
  [self-review checklist](../quality.md) on that phase's diff. Surface issues in
  the chat only if found.
