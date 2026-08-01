# Design outcome: implement-plan skill rework

Synthesis from workflow run `wf_15d4b659-b32` (3 independent proposals + judge).
Research inputs: `plan-implement-plan-rework-research.md`. Checklist: `../../plan.md`.
**Delete with `plan.md` when the rework lands.**

Claims here are the judge's, not yet independently verified. Two in particular are
flagged for verification before acting: the submodule git-dir/git-common-dir claim
against `using-git-worktrees`, and the `MAIN=$(dirname ...)` claim against
`finish-branch`.

---

## A. VERDICT TABLE

| # | Decision | Chosen position | From | Why the alternatives lose |
|---|---|---|---|---|
| a | Parallelism policy | **Sequential by default.** Two phases run concurrently only if all of: a `**Depends on**` line (new, optional) does not link them; their `### Context` + `### What to build` path sets are disjoint (computed, not eyeballed); every symbol the later phase names already resolves at `$BASE` (`git grep -n <sym> $BASE`); neither touches a choke file (plan file, README/index, lockfile, manifest, migration sequence); and `git merge-tree --write-tree --messages "$BASE" <branch>` exits 0 with a 40-hex tree oid on line 1 for each branch **and** for the pair, re-checked at fold time. Absent `**Depends on**` ⇒ assume dependence. Group cap 4. | P3 test + P1's `Depends on` field | P1's prose-only test is weaker than P3's computed union; P2's looser gate risks the one failure (`UU` conflict → forced human turn) that destroys the autonomy the ask wants. create-plan emits deliberately dependent vertical slices, so parallelism carries the burden of proof. |
| b | Worktree layout | **One long-lived run worktree** `.worktrees/plan-<slug>` on `plan/<slug>` cut from a pinned `$BASE`; sequential phases commit there. **One extra worktree per concurrent phase** `.worktrees/plan-<slug>-p<N>` on `plan/<slug>/phase-<N>`, forked from the current `plan/<slug>` tip, folded back before the next sequential phase. Lead creates all worktrees with explicit `git worktree add`. **Never `isolation: 'worktree'`.** | P3 (b), unanimous on rejecting `isolation` | Per-sequential-phase branches buy zero isolation and N−1 gratuitous rebases. `isolation: 'worktree'` has no documented branch naming or post-exit persistence, and the entire recovery story is "a fresh session finds the run via `git worktree list --porcelain` under the `.worktrees/` convention". |
| c | Plan-file writer | **Exactly one writer: the lead, in the run worktree, on `plan/<slug>`.** Subagents get the plan path to *read* and are told in the prompt never to edit it. Ticks never land on the base branch until the run branch lands. Sequential phases: tick per criterion. Parallel lanes: subagents commit per criterion, lead transcribes ticks at fold time. | P3 (c) | P2's bounded plan-file auto-merge is unverified by its own admission; any multi-writer scheme guarantees a `UU` on the one file whose conflict is unavoidable. Cost — coarser tick granularity in parallel lanes — is stated plainly, not hidden. |
| d | Checkpoint unit | **One commit per acceptance criterion**, made in the worktree that owns the phase, Conventional Commit subject + one trailer `Plan: <slug> phase <N> criterion <M>`. Tick is a separate commit `docs(plan): tick <slug> phase <N> criterion <M>`. A criterion that is not committed is not done; an agent returning with a dirty worktree is a failed unit. | P3 (d) trailer + P1's "uncommitted = not done" rule | Per-phase batching loses everything a killed agent finished. Branch-name attribution (P1) breaks once the branch is merged and deleted; `git log --all --grep='Plan: <slug> phase'` survives that. |
| e | Autonomy boundary vs finish-branch | **Scope around it, in both files.** Without asking, the skill creates its own worktrees/branches, implements, commits, ticks, runs the verify command, rebases its own branches onto a pinned base sha, merges them locally with `--ff-only`, removes its own worktrees, deletes its own merged branches with `-d`. Push / PR / discard / any branch it did not create → `[finish-branch](../finish-branch/SKILL.md)`, gate intact. Add one Constraints line to `finish-branch/SKILL.md` naming the exception. One up-front confirmation gate (the run contract) satisfies using-git-worktrees step 3 once for every worktree the run creates. | P3 (e) contract gate + P1's one-line finish-branch amendment | P1's "invoking the skill pre-answers everything" leaves the worktree-confirm rule silently violated and shows the user the phase partition — the riskiest inference — only after N worktrees exist. Superseding finish-branch outright would rewrite a stable skill to fix a documentation problem. |
| f | What "self-repair" means | **Five mechanisms, named, and an explicit does-not-exist list.** (1) Null-safe fan-in: `.filter(Boolean)`, report the dropped count, re-dispatch dropped phases told to read their own branch log and continue from the last commit. (2) Cache-hot workflow resume via `resumeFromRunId`, which requires prompts to embed stable identifiers (plan path, phase number) and never plan text. (3) Checkpoint density: one commit per criterion. (4) A committed `## Run state` handoff block. (5) Correct diagnosis + clean stop with the verbatim failure string. | P2 (f) five-item framing + P3's re-dispatch detail | P1's three-item list drops diagnosis and re-dispatch. Nothing in any proposal that promised retry, sleep-until-reset, or cron catch-up survives — those are cut in §D. |
| g | Fresh-session pickup | **Worktrees first, log outranks checkbox.** `git worktree list --porcelain` → per-worktree state scan → read the plan **inside the run worktree** incl. `## Run state` → `git log --oneline --all --grep='Plan: <slug> phase'` → reconcile (untick any `- [x]` with no matching commit; re-verify and tick any commit with no tick) → finish/abort half-open operations in their owning worktree → re-pin `$BASE` → continue. | P3 (g) | P1/P2 read the plan first; the plan file on the base branch is stale by design during a run, so the worktree is the index. |

## B. FINAL FILE MANIFEST

| Action | Absolute path | Purpose | Target lines |
|---|---|---|---|
| Rewrite | `/home/nico/handbook/.claude/skills/implement-plan/SKILL.md` | Whole-plan execution loop: resume-first, pin base, one contract gate, per-criterion commit+tick, fold, land, clean up, report | ~105 |
| Create | `/home/nico/handbook/.claude/skills/implement-plan/orchestration.md` | Execution-mode tiering, the concurrency test, worker prompt specifics, model routing, workflow script skeleton and null-safety | ~75 |
| Create | `/home/nico/handbook/.claude/skills/implement-plan/integration.md` | Verified fold/land sequences, rerere hazard, base-moved handling, conflict classification and abort rule, `#hazards` never-run list | ~95 |
| Create | `/home/nico/handbook/.claude/skills/implement-plan/recovery.md` | First commands of a resumed run, worktree state scan, tick-vs-commit reconciliation, `## Run state` block, failure taxonomy, what does not exist | ~85 |
| Modify | `/home/nico/handbook/.claude/skills/README.md` (line 29) | Index row no longer says "step by step" | 1 row |
| Modify | `/home/nico/handbook/.claude/skills/finish-branch/SKILL.md` | (a) one Constraints line scoping the four-option gate out of implement-plan's own `plan/*` branches; (b) fix `MAIN=$(dirname "$GIT_COMMON")` at line 62 → `MAIN=$(git worktree list --porcelain \| awk 'NR==1{print $2}')` (verified wrong for a bare-hosted worktree) | +1, ~2 changed |
| Modify | `/home/nico/handbook/.claude/skills/using-git-worktrees/SKILL.md` (step 2, lines 30–39) | Its claim "The git-dir/git-common-dir mismatch is also true inside a submodule" is **false at git 2.47.3** — inside a submodule they *match*, so step 1 misreports a submodule as a normal checkout. Reorder: run `git rev-parse --show-superproject-working-tree` first; non-empty ⇒ submodule, ask before creating a worktree there. implement-plan links here, so a false instruction at a link target is a defect | ~4 changed |
| Modify (recommended, separate commit) | `/home/nico/handbook/.claude/skills/create-plan/SKILL.md` (template ~line 153) | Add `**Depends on**: Phase <N>, or "none"` to the phase block + one line telling the planner to fill it. Converts implement-plan's riskiest inference into a declared fact; the skill degrades to "assume dependent" without it | +2 |

Nothing deleted. `/home/nico/handbook/plan.md` is **git-ignored** (verified: `git check-ignore -v plan.md` → `plan.md`; `git ls-files plan.md` → empty), so it is session scratch, not a repo artifact — delete it at the end per AGENTS.md, no manifest row needed.

Exact README row (keep the existing pipe padding):

```
| Executing a whole plan autonomously, with checkpoints and crash resume                   | [Implement Plan](implement-plan/)                            |
```

`scripts/check-repo.sh check_skills` indexes only directories containing a `SKILL.md` (verified, lines 143–158), so the three reference files need no index rows. `check_links` strips `#anchors` before resolving, so `integration.md#hazards` is safe.

## C. WRITE-READY OUTLINE

### C1. `SKILL.md` (~105 lines)

Frontmatter, verbatim:

```yaml
---
name: implement-plan
description: >-
  Executes an entire implementation plan end to end — phase by phase in
  dedicated git worktrees, committing and ticking each acceptance criterion as
  it is verified, then rebasing and merging its branches back onto the base
  branch. Use when the user wants a whole plan implemented autonomously, or
  wants to pick a plan run back up after a crash, a usage limit, or a stopped
  workflow.
disable-model-invocation: true
argument-hint: "<path to plan file>"
---
```

`disable-model-invocation: true` is load-bearing, not decorative: the Workflow tool may only be called when the user explicitly opted in, and "the model auto-triggered a skill" is not an opt-in. It also fits `.claude/rules/skills.md`'s side-effect-flow criterion. Still reachable as `/implement-plan`. No `allowed-tools` — the skill needs Bash, Read, Edit, Write, Agent and Workflow; an allowlist that broad documents nothing.

**H1 `# Implement Plan`**, then two framing lines, no more:

> Execute a whole plan without a human turn between phases. Work is durable only once it is committed and ticked, so that is the unit of progress — everything else happens between checkpoints.

**`## Workflow`** — numbered, bold lead phrase per step:

1. **Resume before you start** — every invocation, including the first. Run the pickup sequence in `[recovery.md](recovery.md)`: worktree list, state scan, `## Run state`, commit log, reconcile. Finish or abort any half-open rebase/merge **in its owning worktree** before anything else. Redoing finished work is the most expensive failure available.
2. **Read the plan; pin the base.** Collect every phase with unmet `- [ ]` (plan anatomy: `[create-plan](../create-plan/SKILL.md)`). Detect the base branch with `git symbolic-ref --short refs/remotes/origin/HEAD`; fall back to `git ls-remote --symref origin HEAD`; if neither resolves, ask — do not assume `main`. Then pin it: `BASE=$(git rev-parse refs/heads/<base>)`. Every dry run, rebase and merge in this run targets `$BASE`, never a moving branch name.
3. **Review every unmet phase in one pass** — ambiguous criteria, missing context files, conflicting instructions, criteria no command can verify.
4. **Choose the shape** — execution mode and the concurrency test, both in `[orchestration.md](orchestration.md)`. Sequential is the default.
5. **Present the run contract and get one go-ahead**: plan path, base branch + pinned sha, the phase list with its grouping, worktree paths and branch names, the verification command, the stop conditions, plus every question from step 3. This is the run's only planned human turn, and it is `[using-git-worktrees](../using-git-worktrees/SKILL.md)` step 3's confirm-before-creating asked once instead of N times. Pre-flight, in the same message: an unattended run stalls on a permission prompt, so name any shell command the agents will need that is not already allowlisted, and note that `CLAUDE_CODE_RETRY_WATCHDOG=1` in the environment is the user's lever for an unattended run.
6. **Create the run worktree** `.worktrees/plan-<slug>` on branch `plan/<slug>` from `$BASE`, per `[using-git-worktrees](../using-git-worktrees/SKILL.md)`. Confirm a clean baseline there — the verify command passes on unchanged code — before the first edit, so later failures are attributable.
7. **Execute each unit in order.** Sequential phases run in the run worktree. A concurrency-eligible group gets one worktree, one branch and one agent per phase; dispatch per `[orchestration.md](orchestration.md)` and the `[delegation contract](../dispatching-parallel-agents/SKILL.md)`. No two agents ever write one file, and no agent ever writes the plan file.
8. **Commit per acceptance criterion, then tick.** Run the project's verification command — `make test` (or `make check`) if the repo has a Makefile, otherwise the language-appropriate default (`go test ./...`, `pnpm test`, `mvn test`). Commit the change with the run trailer (Constraints). Then flip `- [ ]` → `- [x]` and commit that separately. Tick only what a tool result from this session proves. If verification fails twice on the same phase for the same reason, switch to `[systematic-debugging](../systematic-debugging/SKILL.md)`; if that does not resolve it, stop.
9. **Fold each parallel group** into `plan/<slug>` in ascending phase order using the fold sequence in `[integration.md](integration.md)`, transcribing that phase's ticks as you go, and re-running verification after each fold — passing in isolation does not mean passing together.
10. **Land** `plan/<slug>` on the base branch with the landing sequence in `[integration.md](integration.md)`, then re-verify in the main checkout. Delete the `## Run state` block and commit that removal **before** landing, so the base branch never receives it. Then `git worktree remove` each worktree the run created and `git branch -d` each merged branch. Push, PR, or discard is `[finish-branch](../finish-branch/SKILL.md)`'s decision, not yours.
11. **Report**: phases completed, criteria ticked, commits landed, agents that returned nothing and what happened to their work, and anything left unticked with the reason.

**`## Stop and ask`** — seven bullets, each a forced stop:

- Any merge or rebase conflict. Abort in the owning worktree, report the paths and their classes, hand back. Nothing is auto-resolved by content — see `[integration.md](integration.md)`.
- A phase's criteria are ambiguous, unverifiable, or depend on something that does not exist.
- Verification fails repeatedly for the same reason after a debugging pass.
- Proceeding would need anything on the `[hazard list](integration.md#hazards)`, a push, a force-push, `--no-verify`, or deleting a branch, worktree or file the run did not create.
- A worktree, branch, `index.lock` or `refs/agent-lock/*` the run does not own is dirty, held, or mid-operation and blocks the path. Report it; never clear another worktree's state.
- The plan would have to change — a new phase, a reworded criterion, a different design. That is `[create-plan](../create-plan/SKILL.md)`'s job; this skill executes.
- A usage limit or a terminal API error. Not a question, a forced stop: write and commit the `## Run state` block, then report the verbatim failure string and any reset time it printed. Taxonomy in `[recovery.md](recovery.md)`.

**`## Constraints`**:

- **Commit message**: Conventional Commit subject plus one trailer, `Plan: <slug> phase <N> criterion <M>`. That trailer is what makes a dead agent's work findable after its branch is gone. No AI attribution trailers.
- **One writer per file, always.** The lead is the sole writer of the plan file for the entire run; subagents receive its path to read. Index files, lockfiles and entry points are lead-owned, as in `[distill/parallelism.md](../distill/parallelism.md#apply-stage-partitioning)`.
- **Never `git stash`** — it is repo-global, not per-worktree, so two agents pop each other's work. Commit instead.
- **Never** `git gc --prune=now`, `git update-ref` on a branch, `git rebase --update-refs`, `git checkout -- .`, `git restore .`, `git clean -fd`, `git reset --hard`, `git branch -D`, or `git worktree remove --force`. Each is a verified silent destroyer in a multi-worktree repo; what it destroys and the safe substitute are in `[integration.md](integration.md#hazards)`.
- **Never push the base branch, never force-push, never `--no-verify`.**
- Set `model` explicitly on every delegated agent; routing in `[distill/parallelism.md](../distill/parallelism.md#model-routing)`.
- Prefer simple, clear, idiomatic solutions. No performance optimisation at the cost of readability; small local duplication is fine when it aids understanding.
- If the user wants to write the code themselves, that is `[guided-implementation](../guided-implementation/SKILL.md)`.

**`## Quality`** — one bullet: after each phase lands on `plan/<slug>`, run the shared `[self-review checklist](../quality.md)` on that phase's diff. Surface issues in the chat only if found.

### C2. `orchestration.md` (~75 lines)

H1 `# Orchestration`, then two lines: how to decide whether to fan out, and what a worker must be told. The delegation contract itself is in `[../dispatching-parallel-agents/SKILL.md](../dispatching-parallel-agents/SKILL.md)` — follow it; this file covers only what is specific to executing a plan.

**`## Execution modes`** — same tiering shape as `[../distill/parallelism.md](../distill/parallelism.md#execution-modes)`:

| Shape | Mode |
| --- | --- |
| 1–2 phases total | **Inline** in the run worktree. Fan-out overhead exceeds the work. |
| 3+ sequential phases | **One `Agent` per phase**, dispatched one at a time; the lead verifies, ticks and commits between phases. Keeps the lead's context bounded over a long plan. |
| A group of 2–4 concurrency-eligible phases | **`Workflow`**, one agent per phase. |

Never launch a workflow for a single agent. A workflow cannot take user input mid-run — the only human gates are between workflows, which is why landing stays with the lead.

**`## The concurrency test`** — sequential is the default because create-plan phases are deliberately dependent vertical slices. Phases *i* and *j* may run concurrently only if **all** hold:

0. Neither phase's `**Depends on**` line names the other. If the plan has no `**Depends on**` lines, assume every phase depends on all earlier ones and run sequentially.
1. The union of paths named in *i*'s `### Context` and `### What to build` is disjoint from *j*'s. Compute the union; do not eyeball it.
2. Every symbol *j*'s context names already resolves at the pinned base: `git grep -n <symbol> $BASE`.
3. Neither writes a choke file: the plan file, `README.md` or another index, lockfiles, `go.mod`/`package.json`, migration-sequence files.
4. Proof, after both branches exist and again before folding: `git merge-tree --write-tree --messages "$BASE" <branch>` exits 0 with a 40-hex tree oid on stdout line 1 for each branch, and the two branches merge into each other cleanly. Exit 1 alone does not prove conflict — a bad ref name also exits 1; require the hex oid.

Fewer than two phases passing ⇒ run sequentially. Group cap 4: the binding cost is one checkout plus dependency install plus one fold per member, not the runtime's `min(16, cores − 2)`.

**`## What a worker is told`** — beyond the four-part contract: its absolute worktree path, its branch name, its phase number, the plan file path **as a path to read, never as pasted text**, the verification command, the commit trailer format, the plan-file write ban, and "commit each criterion the moment it verifies; an uncommitted result does not exist; return with a clean worktree". Anti-pattern: pasting phase text into the prompt changes the workflow cache key on the first tick and forces every later `agent()` call to re-run.

**`## Model routing`** — the rule is in `[../distill/parallelism.md](../distill/parallelism.md#model-routing)`; set `model` explicitly in every `agent()` opts, because an agent that omits it inherits the session model. Phase implementation and post-fold verification → `opus`. A fully mechanical phase (rename, formatting, regenerate-and-check) → `sonnet`, `effort: 'low'`. Ticking, folding and landing → the lead, no agent.

**`## Workflow script shape`** — plain JavaScript, not TypeScript; pure-literal `export const meta`; top-level `await`; no `Date.now()`, `Math.random()` or argless `new Date()` (they throw), so derive every name from the phase number; `.filter(Boolean)` every return because `agent()` returns `null` on a terminal API error or a user skip and a throwing thunk resolves to `null` without `parallel()` rejecting; record the returned `runId` and `scriptPath` in `## Run state` the moment the tool call returns. Skeleton, verbatim:

```javascript
export const meta = {
  name: 'implement-plan-group',
  description: 'Implements one concurrency-eligible group of plan phases, one agent per phase.',
  phases: ['implement'],
}

phase('implement')

const results = await parallel(
  args.phases.map((p) => () =>
    agent(
      [
        `Implement phase ${p.n} of the plan at ${args.plan}. Read the plan file yourself; never edit it.`,
        `Work only inside the worktree ${p.worktree}, on branch ${p.branch}. Touch no other path.`,
        `Verify with: ${args.verify}`,
        `Commit each acceptance criterion the moment it verifies, with the trailer`,
        `"Plan: ${args.slug} phase ${p.n} criterion <M>". Return with a clean worktree.`,
        `If you cannot finish, commit what verifies and report what blocked you.`,
      ].join('\n'),
      {
        label: `phase-${p.n}`,
        phase: 'implement',
        model: 'opus',
        schema: {
          type: 'object',
          required: ['phase', 'criteriaCommitted', 'blocked'],
          properties: {
            phase: { type: 'number' },
            criteriaCommitted: { type: 'array', items: { type: 'number' } },
            blocked: { type: ['string', 'null'] },
          },
        },
      },
    ),
  ),
)

const done = results.filter(Boolean)
return { done, dropped: results.length - done.length }
```

**`## When an agent returns nothing`** — a `null` is a phase that did not happen, not a phase that passed. Its branch still holds every criterion it committed. Re-dispatch it with the instruction to read `git log --oneline <its branch>` and continue from the last commit, never to restart. Report the dropped count in step 11.

**`## Resume`** — relaunch with `Workflow({ scriptPath, resumeFromRunId })`; the longest unchanged prefix of `agent()` calls returns from cache. Cached results stop at the first agent that did not finish, and **every agent that started after it re-runs even if it completed** — which is why the durable record is the commits, not the return values. Cross-session workflow resume is not promised by the docs; a new session resumes from git, per `[recovery.md](recovery.md)`.

### C3. `integration.md` (~95 lines)

H1 `# Integration`, one line: verified git sequences for folding, landing, conflicts and hazards; all verified at git 2.47.3. Add the bullet TOC of `##` headings only if the finished file exceeds 100 lines (`.claude/rules/skills.md`).

**`## Locate yourself`**

```bash
git rev-parse --show-superproject-working-tree                  # non-empty => submodule, stop
git rev-parse --path-format=absolute --git-dir
git rev-parse --path-format=absolute --git-common-dir           # equal => main checkout
MAIN=$(git worktree list --porcelain | awk 'NR==1{print $2}')   # first record is always the main worktree
```

Check the submodule test **first**: inside a submodule git-dir and git-common-dir *match*, so the linked-worktree test misreports it as a main checkout. Never derive `MAIN` from `dirname` of the git-common-dir — wrong for a bare-hosted worktree. If the first record's block contains `bare`, there is no main checkout; stop.

**`## Fold a phase branch into the run branch`** — per member, ascending phase order:

```bash
git -C "$MAIN" merge-tree --write-tree --messages "$TRUNK_TIP" "$BR"   # dry run, touches nothing
git -C "$WT" -c rerere.enabled=false rebase --onto "$TRUNK_TIP" "$(git merge-base "$TRUNK_TIP" "$BR")" "$BR"
git -C "$RUN_WT" -c rerere.enabled=false merge --ff-only "$BR"
```

Re-run the verify command on the folded run branch before the next member.

**`## Land on the base branch`**

```bash
MAIN=$(git worktree list --porcelain | awk 'NR==1{print $2}')
LOCK=refs/agent-lock/integrate

git update-ref "$LOCK" "$(git rev-parse HEAD)" ""            # create-only mutex; exit 128 => another agent holds it, stop
BEFORE=$(git -C "$MAIN" rev-parse refs/heads/<base>)         # pin; never pass the moving name to rebase
git -C "$MAIN" merge-tree --write-tree --messages "$BEFORE" plan/<slug>
git -C "$WT" -c rerere.enabled=false rebase --onto "$BEFORE" "$(git merge-base "$BEFORE" plan/<slug>)" plan/<slug>
git -C "$MAIN" -c rerere.enabled=false merge --ff-only plan/<slug>
git update-ref -d "$LOCK"
```

`--ff-only` is the race detector: when a human commits to the base branch mid-sequence it fails cleanly (exit 128, `fatal: Not possible to fast-forward, aborting.`, refs and working tree untouched). `--no-ff` succeeds on a diverged, unverified branch and therefore detects nothing. Landing must run in the main worktree — `git push . HEAD:<base>` is rejected by `receive.denyCurrentBranch`, and `git update-ref` desyncs the main worktree silently.

**`## When the base moves under you`** — re-pin `$BEFORE`, redo the `rebase --onto`, retry `--ff-only` once. A second failure is a stop, not a third attempt. Release the lock on every exit path, including the stop.

**`## rerere is on in this environment`** — `git config --show-origin --get rerere.enabled` → `file:/home/nico/.gitconfig true` (verified). With it on, a repeat merge hands back a fully resolved working file with **no conflict markers** while `git status` still reports `UU`. An agent that reads "no markers" as "nothing to do" commits a resolution nobody reviewed. Every merge and rebase this skill runs carries `-c rerere.enabled=false`.

**`## Conflicts`** — enumerate `git diff --name-only --diff-filter=U`; classify from the porcelain v1 two-letter code: `AA` add/add, `UU` content, `UD`/`DU` modify-delete, `DD` both-deleted. **Sides flip between rebase and merge**: under `rebase <base>`, stage 2 / `--ours` is the *base* side; under `merge <base>` it is *your branch*. Never hardcode "ours = my work". Rule: abort in the owning worktree (`git -C <wt> rebase --abort` — aborting from elsewhere exits 128), report paths and classes, hand back. Nothing is auto-resolved by content; a declared `.gitattributes merge=` driver is the sole exception, because that is a human decision already recorded. `DD` is the only trivial case and is not worth a code path. After an abort, `git reflog show <branch>` is the undo ledger.

**`## Hazards`** — one clause each on what it destroys and the safe substitute: `gc --prune=now` (verified to corrupt refs and worktree HEADs when another worktree commits concurrently — use plain `gc`); `update-ref refs/heads/<b>` (desyncs a checked-out worktree, exit 0, no warning); `rebase --update-refs` (silently skips refs checked out elsewhere, exit 0 — land branches one at a time); `stash` (repo-global); `checkout -- .` / `restore .` / `clean -fd` / `reset --hard` (unrecoverable — uncommitted work was never an object); `branch -D` (deletes the branch's reflog too — use `-d`, which refuses an unmerged branch); `worktree remove --force` (removes a worktree holding staged work — use the plain form and read its refusal); `push --force` / `-f` / `--force-with-lease`, `--no-verify`, `push origin <base>`. Also: never delete another worktree's `index.lock` — it is 0 bytes, holds no pid, and staleness cannot be proven; report and stop.

### C4. `recovery.md` (~85 lines)

H1 `# Recovery`, one line: how a session picks a run back up, and what it must leave behind when it stops. TOC only if over 100 lines.

**`## Start here, every time`**

```bash
git worktree list --porcelain                                     # 1. find the run's worktrees
# 2. state-scan loop (below)
awk '/^## Phase /{p=$0} /^- \[ \]/{print p" -> "$0; exit}' <plan>  # 3. first unmet criterion (verified)
git log --oneline --all --grep='Plan: <slug> phase'               # 4. what was actually committed
```

Read the plan **inside the run worktree**, including its `## Run state` block — the copy on the base branch is stale by design during a run. If the run worktree is gone, fall back to `git branch --list 'plan/*'` plus the same `git log --grep`: branches, not worktrees, are the durable artifact.

**`## The worktree state scan`** — verbatim, runs from anywhere:

```bash
git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r w; do
  [ -d "$w" ] || { echo "$w MISSING"; continue; }
  gd=$(git -C "$w" rev-parse --path-format=absolute --git-dir) || continue
  s=""
  [ -d "$gd/rebase-merge" ]     && s="$s rebase"
  [ -d "$gd/rebase-apply" ]     && s="$s rebase-apply"
  [ -f "$gd/MERGE_HEAD" ]       && s="$s merge"
  [ -f "$gd/CHERRY_PICK_HEAD" ] && s="$s cherry-pick"
  [ -f "$gd/index.lock" ]       && s="$s INDEX_LOCK"
  printf '%s\tstate:%s\tdirty:%s\n' "$w" "${s:-clean}" "$(git -C "$w" status --porcelain | wc -l)"
done
```

**`## The log outranks the checkbox`** — a `- [x]` with no matching commit is wrong: untick it. A commit with no tick gets its criterion re-verified, then ticked. Never trust a tick you did not place this session (`[quality.md](../quality.md)`).

**`## Half-finished operations`** — before deciding anything, read `$GD/rebase-merge/head-name` (mid-rebase the branch name is *not* in HEAD; status reports detached), `onto`, `orig-head` (the undo point) and `msgnum`/`end`. Continue or abort only from the owning worktree. Stale or moved worktrees: `git worktree prune --dry-run --verbose` before `prune`; `git worktree repair <path>` when the directory moved; pruning does not delete the branch. Ref or object damage: `git fsck --no-progress`.

**`## The `## Run state` block`** — what a stop must leave behind, committed to `plan/<slug>`, and deleted in its own commit before landing: base branch and pinned sha; run branch; a worktree → branch → phase table; the next unticked criterion; the verify command; the workflow `scriptPath` and `runId`; the verbatim failure string if the run died. No wall-clock call is needed — `git log -1 --format=%cI` gives the time.

**`## Failure taxonomy`** — table of the verbatim string and the honest response:

| String | Response |
| --- | --- |
| `You've hit your session limit · resets <time>` / weekly limit | Stop, commit the handoff, name the reset time. Both windows are shared across models — switching model does not help. |
| `You've hit your Opus limit · resets <time>` | The one limit `/model` escapes; a `sonnet`-eligible mechanical phase may continue, an implementation phase may not. |
| `Agent terminated early due to an API error: …` | That `agent()` returned `null`. Its committed work survives on its branch. Re-dispatch it told to continue from its last commit. |
| `API Error: Server is temporarily limiting requests (not your usage limit)` / 529 overloaded | The harness already retried up to 10× with backoff before you saw this. Check `https://status.claude.com`, stop, hand off. |
| `API Error: Server error mid-response. The response above may be incomplete.` | Never retried by design. Re-run that phase from its last commit. |

One line for the user, labelled as a user action, not skill behaviour: set `CLAUDE_CODE_RETRY_WATCHDOG=1` in the environment before launching an unattended run.

**`## What does not exist`** — so nobody invents it: no sleep-until-reset (the reset epoch reaches only a status-line shell command, and workflow scripts cannot read a clock at all); scheduled tasks and `/loop` fire only while the session is running *and idle*, with no catch-up for missed fires; cross-session workflow resume is not promised by the docs; `StopFailure` fires only after retries are exhausted and cannot block; `/rewind` checkpoints do not restore subagent or Bash-made edits — git does.

## D. KILLED IDEAS

- **Any retry or backoff instruction** — the harness owns it (10 attempts default); by the time the agent observes a failure, retries are exhausted.
- **Wait-until-reset, `CronCreate`, `/loop`, `ScheduleWakeup`, cloud routines as unattended catch-up** — fire only while the session runs and is idle, no catch-up, no clock in workflow scripts.
- **`StopFailure` hook configuration in skill prose** — real lever, lives in `settings.json`, belongs to `/update-config`, and cannot block anything.
- **P2's bounded plan-file conflict auto-resolution** — its own author could not verify that a checkbox collision presents as a hunk confined to `- [ ]` lines. Single-writer makes it moot.
- **Any content-based auto-resolution beyond a declared `.gitattributes` merge driver** — `checkout --ours` was verified to silently discard the other side's real edit.
- **`isolation: 'worktree'` in `agent()` opts** — no documented branch naming or post-exit persistence; discoverability by a fresh session is the whole design.
- **`pipeline()` for phase groups** — no barrier between stages, which is exactly wrong when the group must fold before the next sequential phase branches.
- **`git rebase --update-refs` for stacked phase branches** — verified to silently skip refs checked out elsewhere and exit 0, which is precisely this skill's situation.
- **`git worktree lock`** — advisory metadata that blocks only `remove`/`prune`; the `refs/agent-lock/` create-only ref is the verified 1-of-8 mutex.
- **A stale-`index.lock` reaper or any age heuristic** — the lock holds no pid; staleness is unprovable. Report and stop.
- **Budget arithmetic / pre-flight cost sizing in the script** — `budget.remaining()` is readable, but any threshold policy is a guess; the documented throw is enough.
- **Session task list (`TaskCreate`/`TaskUpdate`) as handoff state** — not verified readable by another session or a human.
- **A `docs/plans/.progress/` journal file** — adds a file class to clean up and lags the plan file it duplicates.
- **Restating model routing, the delegation contract, worktree mechanics, the four integration options, or the plan template** — all exist; all linked.
- **Deleting the branch history-grouping `--no-ff` option** — kept out entirely rather than conditioned; `--ff-only` is the race detector and `--no-ff` is not.

## E. RESIDUAL RISKS — hedge or omit, do not assert

- **The parallel path may never fire.** create-plan emits dependent vertical slices; on the repo's own `plan-distill-handbook.md` the test would very likely return "all sequential". The writer should say so plainly in orchestration.md ("one group is the normal outcome") rather than implying parallelism is the default experience. No data exists on how often real plans have independent phases — do not claim a rate.
- **`parallel()` returning a promise is inferred**, from "parallel() never rejects" plus the docs' top-level-`await` example using `pipeline()`. Keep `await` in the skeleton; do not add a sentence asserting the return type.
- **`meta.phases`** appears in the tool schema but not in the docs' saved-script example. Keep it, do not document it as required.
- **Whether `merge-tree` is affected by rerere is untested.** The skeleton puts `-c rerere.enabled=false` only on `rebase` and `merge` (both verified affected). Do not write a claim either way about `merge-tree`.
- **Per-criterion trailers depend on subagent compliance.** A worker that skips the trailer produces durable but unattributable work, and the design has no detector. recovery.md should say the log is authoritative *when the trailer is present*, and that a commit range on the phase branch is the fallback — not that reconciliation is complete.
- **Reconciliation can be expensive.** "Commit with no tick → re-verify and tick" means re-running the verification the checkpoint was supposed to make unnecessary. State that cost; do not sell reconciliation as free.
- **The submodule fix rests on one probe at git 2.47.3.** Write it as "verified at git 2.47.3", not as a general git property.
- **Unallowlisted shell commands can prompt mid-workflow and stall an unattended run** (documented). The pre-flight bullet should ask the user to allowlist, not claim the run is prompt-free.
- **Whether the lead's context survives a long sequential plan is untested.** The 3+-phase tier delegates for that reason; present it as a bounded-context precaution, not a measured improvement.
- **`disable-model-invocation: true` means the model can never proactively resume a crashed run** — a human must type `/implement-plan`. State this as a deliberate trade in the rewrite's commit message; do not paper over it in the skill text.
