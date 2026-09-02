# Orchestration

How to fan out across plan phases and what a worker is told. Follow the delegation
contract in [../dispatching-parallel-agents/SKILL.md](../dispatching-parallel-agents/SKILL.md).

- [Execution modes](#execution-modes)
- [The concurrency test](#the-concurrency-test)
- [Review depth per phase](#review-depth-per-phase)
- [What a worker is told](#what-a-worker-is-told)
- [Model routing](#model-routing)
- [When an agent returns nothing](#when-an-agent-returns-nothing)

## Execution modes

| Shape | Mode |
| --- | --- |
| 1–2 phases total | **Inline** in the run worktree. Fan-out overhead exceeds the work. |
| 3+ sequential phases | **One `Agent` per phase**, dispatched one at a time; the lead verifies, ticks and commits between phases. A precaution to keep the lead's context bounded over a long plan, not a measured speedup. |
| A group of 2–4 concurrency-eligible phases | **`Workflow`**, one agent per phase. |

- Never launch a workflow for a single agent.
- A workflow cannot take user input mid-run, so human gates sit only between workflows. Folding and landing stay with the lead.

### Keep the pipeline full

A sequential plan runs one writer at a time, not one *agent* at a time.

- While phase *N*'s writer works, dispatch phase *N+1*'s **read-only** scout.
- A scout resolves symbols, maps the test surface and lists the files the phase will touch. It writes nothing, so it cannot conflict with the writer.
- Hand its result to the writer as context when the writer is dispatched.

## The concurrency test

- Sequential is the default: create-plan emits deliberately dependent vertical slices.
- **One group — everything sequential — is the normal outcome.**
- Parallelism carries the burden of proof.

Phases *i* and *j* may run concurrently only if **all** of these hold:

0. Neither phase's `**Depends on**` line names the other.
   - If the plan has no `**Depends on**` lines, assume every phase depends on all earlier ones and run sequentially.
1. The union of paths named in *i*'s `### Context` and `### What to build` is disjoint from *j*'s. Compute the union; do not eyeball it.
2. Every symbol *j*'s context names already resolves at the pinned base: `git grep -n <symbol> $BASE`.
3. Neither writes a choke file: the plan file, `README.md` or another index, lockfiles, `go.mod` / `package.json`, migration-sequence files.
4. Proof, after both branches exist and again before folding:
   - `git merge-tree --write-tree --messages "$BASE" <branch>`: exit 0 clean, exit 1
     conflict, anything else an error (a bad ref name exits 128).
   - Line 1 of stdout carries the tree oid in both the clean and the conflicted
     case. Read the exit code, not only the oid.
   - The two branches also merge into each other cleanly.
5. The gate survives two concurrent runs of itself.
   - Probe and test database names, ports and temp paths are derived, not fixed.
   - A worktree under the repo root is excluded from every lint and type scan.
   - Either one unfixed turns both runs red, and the failure blames the wrong phase.
   - Report it as a one-off repo fix: it unlocks every group in the plan, not one.

- Fewer than two phases passing ⇒ run sequentially.

### The cap is per writer, not per agent

| Agent kind | Cap | Why |
| --- | --- | --- |
| Writer — owns a worktree and a branch | 4 | One checkout, one dependency install and one fold each |
| Read-only — scout, reviewer, verifier | The runtime's `min(16, cores − 2)` | No checkout, no install, no fold |

- A read-only agent carries none of the cost that justifies the cap of 4.
- Capping scouts and reviewers at 4 buys nothing and costs wall clock.
- Read-only means it is told to write nothing, and owns no worktree.
- The runtime queues past its own cap; it never drops work.

## Review depth per phase

The tier rule is [../verification-depth.md](../verification-depth.md). Set each phase's tier at step 4, before the run contract quotes it.

- Gate-only phases are reviewed **as one group**, once, over the group's whole diff.
- One probe over ten phases' diff, never ten probes. That batching is the saving.
- A plan whose phases are all gate-only gets one review unit at the end, not per phase.

### The probe stage

- Author the probe set **once per plan**, parameterised by phase number.
- The invariants do not change per phase, so a bespoke script per phase is lead time spent twice.
- One to two probes, `parallel()`, `model: 'opus'`, one structured findings schema.
- Each probe is a skeptic with a named target: a mutation probe, a criterion audit.
- Probes read only, so they may start before the phase ends.
- A probe may edit only to measure, restores with `git restore`, and proves `git status --porcelain` empty.
- No probe commits, and no probe touches the plan file.

## What a worker is told

Beyond the four-part contract, hand over the items below. **Anti-pattern** — pasting
phase text into the prompt. It changes the workflow cache key on the first tick,
forcing every later `agent()` call to re-run.

- its absolute worktree path
- its branch name
- its phase number
- the plan file path **as a path to read, never as pasted text**
- the verification command
- the commit trailer format
- the plan-file write ban
- "commit each criterion the moment it verifies; an uncommitted result does not exist; return with a clean worktree"
- "at 30 minutes, commit what verifies and return what is left" (the long-pole bound: [../dispatching-parallel-agents/SKILL.md](../dispatching-parallel-agents/SKILL.md#constraints))

## Model routing

- The general rule is in [../dispatching-parallel-agents/SKILL.md](../dispatching-parallel-agents/SKILL.md#model-routing).
- Set `model` explicitly in every `agent()` opts — an agent that omits it inherits the session model.
- A fully mechanical phase (rename, formatting, regenerate-and-check): `sonnet`, `effort: 'low'`.
- Ticking, folding, landing: the lead, no agent.
- A probe is tool-bound, not token-bound, so a cheaper model buys little there. It costs the judgment that ranks its work.
- Cheapen a probe by mechanising its loop, never by demoting its reasoning.

## When an agent returns nothing

- A `null` is a phase that did not happen, not a phase that passed.
- Its branch still holds every criterion it committed.
- Re-dispatch it instructed to read `git log --oneline <its branch>` and continue from the last commit.
- Never restart it.
- Report the dropped count in the final report.
- Cross-session workflow resume is not promised by the docs.
- A new session resumes from git, per [recovery.md](recovery.md).
