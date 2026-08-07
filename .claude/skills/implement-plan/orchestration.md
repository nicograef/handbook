# Orchestration

How to decide whether to fan out across plan phases, and what a worker must be told.
This file covers only what is specific to executing a plan. Follow the delegation
contract in [../dispatching-parallel-agents/SKILL.md](../dispatching-parallel-agents/SKILL.md).

- [Execution modes](#execution-modes)
- [The concurrency test](#the-concurrency-test)
- [Review depth per phase](#review-depth-per-phase)
- [What a worker is told](#what-a-worker-is-told)
- [Model routing](#model-routing)
- [Workflow script shape](#workflow-script-shape)
- [When an agent returns nothing](#when-an-agent-returns-nothing)
- [Resume](#resume)

## Execution modes

| Shape | Mode |
| --- | --- |
| 1–2 phases total | **Inline** in the run worktree. Fan-out overhead exceeds the work. |
| 3+ sequential phases | **One `Agent` per phase**, dispatched one at a time; the lead verifies, ticks and commits between phases. A precaution to keep the lead's context bounded over a long plan, not a measured speedup. |
| A group of 2–4 concurrency-eligible phases | **`Workflow`**, one agent per phase. |

- Never launch a workflow for a single agent.
- A workflow cannot take user input mid-run, so the only human gates are between
  workflows.
- Folding and landing therefore stay with the lead.

## The concurrency test

- Sequential is the default: create-plan emits deliberately dependent vertical
  slices.
- **One group — everything sequential — is the normal outcome.**
- Parallelism carries the burden of proof.

Phases *i* and *j* may run concurrently only if **all** of these hold:

0. Neither phase's `**Depends on**` line names the other.
   - If the plan has no `**Depends on**` lines, assume every phase depends on
     all earlier ones and run sequentially.
1. The union of paths named in *i*'s `### Context` and `### What to build` is
   disjoint from *j*'s. Compute the union; do not eyeball it.
2. Every symbol *j*'s context names already resolves at the pinned base:
   `git grep -n <symbol> $BASE`.
3. Neither writes a choke file: the plan file, `README.md` or another index,
   lockfiles, `go.mod` / `package.json`, migration-sequence files.
4. Proof, after both branches exist and again before folding:
   - `git merge-tree --write-tree --messages "$BASE" <branch>` exits 0 for each
     branch.
   - It prints a 40-hex tree oid on stdout line 1.
   - The two branches also merge into each other cleanly.
   - Exit 1 alone does not prove conflict — a bad ref name also exits 1.
   - Require the hex oid.
5. The gate survives two concurrent runs of itself.
   - Probe and test database names, ports and temp paths are derived, not fixed.
   - A worktree under the repo root is excluded from every lint and type scan.
   - Either one unfixed turns both runs red, and the failure blames the wrong phase.
   - Report it as a one-off repo fix: it unlocks every group in the plan, not one.

- Fewer than two phases passing ⇒ run sequentially.
- Group cap 4: the binding cost is one checkout, one dependency install and one
  fold per member.
- Not the runtime's `min(16, cores − 2)`.

## Review depth per phase

The tier rule is [../verification-depth.md](../verification-depth.md). Read each
phase's tier off the plan, at step 4, before the run contract quotes it.

| The plan says this about the phase | Tier |
| --- | --- |
| Its output is rebuildable offline and free — a graph rebuild, a regeneration, a re-lint | Gate only |
| It rewrites shared state, or a later rerun costs a provider call or a human | Gate + one probe |
| It spends money, overwrites data with no copy, migrates production, or publishes | Gate + probes + a human read |
| An irreversible phase's `**Depends on**` names it | Inherits that phase's tier |

- Gate-only phases are reviewed **as one group**, once, over the group's whole diff.
- One probe over ten phases' diff, never ten probes. That batching is the saving.
- A plan whose phases are all gate-only gets one review unit at the end, not per phase.

### The probe stage

- Author the probe set **once per plan**, parameterised by phase number.
- The invariants do not change per phase, so a bespoke script per phase is lead time
  spent twice.
- One to two probes, `parallel()`, `model: 'opus'`, one structured findings schema.
- Each probe is a skeptic with a named target: a mutation probe, a criterion audit.
- Probes read only, so they may start before the phase ends.
  - Stream them behind the commit log: verify criterion 1 while criterion 7 is built.
  - Whole-phase probes — end-to-end behaviour, trim, teardown — still wait.
- Send findings to the worker as each probe lands, not after the slowest one.
- Mutations rank by blast radius and cap at roughly eight. State the cap in the report.
- A probe may edit only to measure, restores with `git restore`, and proves
  `git status --porcelain` empty.
- No probe commits, and no probe touches the plan file.

### No judge stage

- The lead adjudicates. It holds the plan, the diff and every probe report.
- A judge agent re-verifies from scratch and buys the review a second time.
- Reports too large for the lead's context: pass them to a judge that may run no tool.

## What a worker is told

Beyond the four-part contract, hand over the items below. **Anti-pattern** —
pasting phase text into the prompt. It changes the workflow cache key on the
first tick, forcing every later `agent()` call to re-run.

- its absolute worktree path
- its branch name
- its phase number
- the plan file path **as a path to read, never as pasted text**
- the verification command
- the commit trailer format
- the plan-file write ban
- "commit each criterion the moment it verifies; an uncommitted result does not
  exist; return with a clean worktree"

## Model routing

- The rule is in
  [../distill/parallelism.md](../distill/parallelism.md#model-routing).
- Set `model` explicitly in every `agent()` opts — an agent that omits it
  inherits the session model.

| Work | Route to |
| --- | --- |
| Phase implementation, post-fold verification | `opus` |
| A probe: which mutations matter, is this criterion met, is this test able to fail | `opus` |
| A fully mechanical phase (rename, formatting, regenerate-and-check) | `sonnet`, `effort: 'low'` |
| Plan-review readers: list a phase's write set, resolve its symbols | `sonnet` |
| A rule with a mechanical shape — counts, dead links, forbidden strings | a script, no agent |
| Ticking, folding, landing | the lead, no agent |

- A probe is tool-bound, not token-bound: its clock is the test runs it drives.
- A cheaper model therefore buys little there, and costs the judgment that ranks
  the probe's work.
- Cheapen a probe by mechanising its loop, never by demoting its reasoning.

## Workflow script shape

- Plain JavaScript, not TypeScript.
- Pure-literal `export const meta`.
- No `Date.now()`, `Math.random()` or argless `new Date()` — they throw.
- Derive every name from the phase number.
- `.filter(Boolean)` every return: `agent()` returns `null` on a terminal API
  error or a user skip.
- A throwing thunk resolves to `null` without `parallel()` rejecting.
- Record the returned `runId` and `scriptPath` in `## Run state` the moment the
  tool call returns.

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

## When an agent returns nothing

- A `null` is a phase that did not happen, not a phase that passed.
- Its branch still holds every criterion it committed.
- Re-dispatch it instructed to read `git log --oneline <its branch>` and
  continue from the last commit.
- Never restart it.
- Report the dropped count in the final report.

## Resume

- Relaunch with `Workflow({ scriptPath, resumeFromRunId })`.
- The longest unchanged prefix of `agent()` calls returns from cache.
- Cached results stop at the first agent that did not finish.
- **Every agent that started after it re-runs even if it completed.**
- The durable record is therefore the commits, not the return values.
- Cross-session workflow resume is not promised by the docs.
- A new session resumes from git, per [recovery.md](recovery.md).
