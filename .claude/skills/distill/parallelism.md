# Parallel Execution

How to fan out a distillation run, which model gets which stage, and what workers
must return.

- [Execution modes](#execution-modes)
- [Model routing](#model-routing)
- [The worker contract](#the-worker-contract)
- [Grouping files](#grouping-files)
- [Workflow mode](#workflow-mode)
- [Apply-stage partitioning](#apply-stage-partitioning)

The delegation contract itself — scope, self-contained context, constraints, return
format, collision checks — is in
[../dispatching-parallel-agents/SKILL.md](../dispatching-parallel-agents/SKILL.md).

- **Follow it** — this file only covers what is specific to distilling.

## Execution modes

Pick once, from the file count in step 2:

| Corpus | Mode |
| --- | --- |
| ≤ 10 files | **Inline.** Read them yourself. Fan-out overhead exceeds the work. |
| 11–40 files | **Parallel agents.** One `Agent` per group, all dispatched in a single response. |
| > 40 files, or the user asked for a workflow / ultracode | **Workflow.** A pipeline over groups. |

## Model routing

Per the global routing rules: `sonnet` for mechanical and fully-specified work,
`opus` for judgment. Never let a worker inherit the session model silently.

| Work | Model |
| --- | --- |
| Blank-slate disposition pass (step 3) | `opus` — deciding what dies is the skill's core judgment, and a wrong delete is the failure mode that matters |
| Restructure design (step 6) | `opus` — boundary choice is a design decision |
| Applying an approved, fully-specified action (step 8) | `sonnet` — the plan already names the file, sections, and reason |
| Link sweep and index-vs-disk check (step 9) | `sonnet` — mechanical |

- **Never route a step-3 worker to `sonnet`** to save tokens.
- **The plan it produces is what the user approves** — a cheap pass moves the cost to a bad deletion.

## The worker contract

Workers see none of this session. Every step-3 prompt must carry these fields.

| Field | Content |
| --- | --- |
| **File list it owns** | Absolute or repo-relative paths, and nothing else |
| **Criteria** | Instruct it to read [criteria.md](criteria.md) by path; never paraphrase the categories into the prompt |
| **Unsettled keep-bar** | Stated as such — the audience is not decided yet |
| **Provisional dispositions** | Every audience-dependent verdict must be marked |
| **Read-only constraint** | Stated explicitly — propose dispositions, edit nothing |
| **Return format** | Exactly the block below |

- **A worker told nothing about the keep-bar** will silently assume an audience.

```
For each file:
  path, line count, the one-line question it answers
  audience: the reader it appears to serve, and the evidence for that
  disposition: DELETE | GUT | TRIM | SPLIT | MERGE | KEEP | FLAG
  audience_sensitive: null, or "would be <disposition> for <audience>"
  affected sections or line ranges
  reason: names what supersedes it or what it duplicates — not "outdated"
Then, for the whole group:
  claims: every substantive fact, command, path, version, convention, or
  instruction, each with file and line
```

- **Two of these fields carry the run** — `claims` and `audience`.
- **`claims`** makes step 4 possible without a second read of every file.
- **One read, two outputs** — the biggest single saving in the run.
- **`audience`** lets step 5 present a real map to confirm, not an abstract question.
- **A worker that omits either has to be re-run**, which costs more than the fields ever save.
- **Use a `schema`** when the mode is a `Workflow`, so returns validate instead of being parsed.

## Grouping files

- **Group by directory** — it keeps related docs with one worker.
- **Why** — that is what makes intra-group duplication visible early.
- **Roughly 5–10 files per worker.** Balance line counts, not file counts.
- **One 900-line monolith** is a group of its own.
- **Never split one file** across two workers.
- **Cap concurrency** at what the run actually needs.
- **More workers on a small corpus** adds coordination cost, not speed.

## Workflow mode

For a corpus over ~40 files, a `Workflow` beats hand-dispatched agents. It holds
the pipeline deterministically and survives a long run. The shape:

1. **`phase('Analyze')`** — one `agent()` per group, `opus`, with the return schema above.
2. **A `parallel()` barrier** — step 4 needs all of it.
3. **Merge and cluster in plain script code.**
4. **No agent** — clustering a list you hold is not a reasoning task worth delegating.
5. **Return the merged evidence** — dispositions, the audience map, duplicate clusters, conflicts.
6. **The workflow ends here**, at step 4.

- **Two conversations a workflow cannot hold** — the three questions (step 5), the approval (step 7).
- **Both happen in the session**, between workflows.
- **After approval** — a second `Workflow`, or plain parallel agents, applies the partitioned actions.
- **With** `sonnet` and `effort: 'low'`.
- **Never carry the analysis workflow past step 4.**
- **A workflow that plans through the questions** has invented the answers; one that applies skipped the gate.

## Apply-stage partitioning

Concurrent edits to one file clobber each other. Partition strictly:

- **One worker owns a file completely**, for every action on that file.
- **The lead owns** index files, entry points, and any file receiving merged content — never a worker.
- **New files from a split** are created by the worker that owns their source.
- **After the workers return**, run the collision check from
  [../dispatching-parallel-agents/SKILL.md](../dispatching-parallel-agents/SKILL.md).
- **`git status` and `git diff --stat`** must show only the expected files.
- **Worktree isolation (`isolation: 'worktree'`) is the wrong tool here.**
- **Why** — the actions are already disjoint by file, and merging worktrees back costs more.
