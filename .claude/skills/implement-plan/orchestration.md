# Orchestration

How to decide whether to fan out across plan phases, and what a worker must be
told. The delegation contract itself is in
[../dispatching-parallel-agents/SKILL.md](../dispatching-parallel-agents/SKILL.md) —
follow it; this file covers only what is specific to executing a plan.

- [Execution modes](#execution-modes)
- [The concurrency test](#the-concurrency-test)
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

Never launch a workflow for a single agent. A workflow cannot take user input
mid-run, so the only human gates are between workflows — which is why folding
and landing stay with the lead.

## The concurrency test

Sequential is the default: create-plan emits deliberately dependent vertical
slices, so **one group — everything sequential — is the normal outcome**.
Parallelism carries the burden of proof. Phases *i* and *j* may run concurrently
only if **all** of these hold:

0. Neither phase's `**Depends on**` line names the other. If the plan has no
   `**Depends on**` lines, assume every phase depends on all earlier ones and
   run sequentially.
1. The union of paths named in *i*'s `### Context` and `### What to build` is
   disjoint from *j*'s. Compute the union; do not eyeball it.
2. Every symbol *j*'s context names already resolves at the pinned base:
   `git grep -n <symbol> $BASE`.
3. Neither writes a choke file: the plan file, `README.md` or another index,
   lockfiles, `go.mod` / `package.json`, migration-sequence files.
4. Proof, after both branches exist and again before folding:
   `git merge-tree --write-tree --messages "$BASE" <branch>` exits 0 with a
   40-hex tree oid on stdout line 1 for each branch, and the two branches merge
   into each other cleanly. Exit 1 alone does not prove conflict — a bad ref
   name also exits 1; require the hex oid.

Fewer than two phases passing ⇒ run sequentially. Group cap 4: the binding cost
is one checkout plus dependency install plus one fold per member, not the
runtime's `min(16, cores − 2)`.

## What a worker is told

Beyond the four-part contract: its absolute worktree path, its branch name, its
phase number, the plan file path **as a path to read, never as pasted text**,
the verification command, the commit trailer format, the plan-file write ban,
and "commit each criterion the moment it verifies; an uncommitted result does
not exist; return with a clean worktree".

Anti-pattern: pasting phase text into the prompt. It changes the workflow cache
key on the first tick and forces every later `agent()` call to re-run.

## Model routing

The rule is in
[../distill/parallelism.md](../distill/parallelism.md#model-routing). Set `model`
explicitly in every `agent()` opts — an agent that omits it inherits the session
model. Phase implementation and post-fold verification → `opus`. A fully
mechanical phase (rename, formatting, regenerate-and-check) → `sonnet`,
`effort: 'low'`. Ticking, folding and landing → the lead, no agent.

## Workflow script shape

Plain JavaScript, not TypeScript. Pure-literal `export const meta`. No
`Date.now()`, `Math.random()` or argless `new Date()` — they throw, so derive
every name from the phase number. `.filter(Boolean)` every return: `agent()`
returns `null` on a terminal API error or a user skip, and a throwing thunk
resolves to `null` without `parallel()` rejecting. Record the returned `runId`
and `scriptPath` in `## Run state` the moment the tool call returns.

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

A `null` is a phase that did not happen, not a phase that passed. Its branch
still holds every criterion it committed. Re-dispatch it with the instruction to
read `git log --oneline <its branch>` and continue from the last commit — never
to restart. Report the dropped count in the final report.

## Resume

Relaunch with `Workflow({ scriptPath, resumeFromRunId })`; the longest unchanged
prefix of `agent()` calls returns from cache. Cached results stop at the first
agent that did not finish, and **every agent that started after it re-runs even
if it completed** — which is why the durable record is the commits, not the
return values. Cross-session workflow resume is not promised by the docs; a new
session resumes from git, per [recovery.md](recovery.md).
