# Parallel Execution

How to fan out a distillation run, which model gets which stage, and what workers
must return.

- [Execution modes](#execution-modes)
- [What parallelizes and what does not](#what-parallelizes-and-what-does-not)
- [Model routing](#model-routing)
- [The worker contract](#the-worker-contract)
- [Grouping files](#grouping-files)
- [Workflow mode](#workflow-mode)
- [Apply-stage partitioning](#apply-stage-partitioning)
- [Anti-patterns](#anti-patterns)

The delegation contract itself — scope, self-contained context, constraints,
return format, collision checks — is in
[../dispatching-parallel-agents/SKILL.md](../dispatching-parallel-agents/SKILL.md).
Follow it; this file only covers what is specific to distilling.

## Execution modes

Pick once, from the file count in step 2:

| Corpus | Mode |
| --- | --- |
| ≤ 10 files | **Inline.** Read them yourself. Fan-out overhead exceeds the work. |
| 11–40 files | **Parallel agents.** One `Agent` per group, all dispatched in a single response. |
| > 40 files, or the user asked for a workflow / ultracode | **Workflow.** A pipeline over groups. |

Corpus size, not enthusiasm, selects the mode. Parallel agents cost roughly 15×
the tokens of a linear pass — on a twelve-file docs directory that buys nothing.

## What parallelizes and what does not

| Step | Parallel? | Why |
| --- | --- | --- |
| 2 Inventory | No | Shell commands. `git ls-files`, `wc -l`. |
| 3 Blank-slate pass | **Yes** | Files are independent; this is the expensive step. |
| 4 Cross-file dedup | **No — barrier** | Needs every claim at once. A worker seeing one directory cannot detect duplication across two. |
| 5 The three questions | No | One conversation with the user. |
| 6 Plan (incl. restructure design) | Design fans out with ≥ 3 monoliths; finalizing does not | Each target file set is independent; merging is the lead's job. |
| 7 Approval | No | One conversation with the user. |
| 8 Apply | Yes, stages 1–3 only | Needs a disjoint partition; stage 4 touches shared indexes. |
| 9 Verify | Partly | Link sweep delegates; "did the split go too far" does not. |
| 10 Commit and hand off | No | One commit, one message. |

Step 4 is the one genuine barrier in the skill. Do not try to remove it — the
whole value of the dedup pass is global visibility.

## Model routing

Per the global routing rules: `sonnet` for mechanical and fully-specified work,
`opus` for judgment. Never let a worker inherit the session model silently.

| Work | Model |
| --- | --- |
| Blank-slate disposition pass (step 3) | `opus` — deciding what dies is the skill's core judgment, and a wrong delete is the failure mode that matters |
| Restructure design (step 6) | `opus` — boundary choice is a design decision |
| Applying an approved, fully-specified action (step 8) | `sonnet` — the plan already names the file, sections, and reason |
| Link sweep and index-vs-disk check (step 9) | `sonnet` — mechanical |

Never route a step-3 worker to `sonnet` to save tokens. The plan it produces is
what the user approves; a cheap disposition pass moves the cost to a bad deletion.

## The worker contract

Workers see none of this session. Every step-3 prompt must carry:

- **The file list it owns** — absolute or repo-relative paths, and nothing else.
- **The criteria** — instruct it to read [criteria.md](criteria.md) by path; do
  not paraphrase the categories into the prompt.
- **The unsettled keep-bar**, stated as such: the audience is not decided yet, so
  dispositions are provisional and every audience-dependent verdict must be
  marked. A worker told nothing about this will silently assume an audience.
- **Read-only constraint**, stated explicitly: propose dispositions, edit nothing.
- **The return format**, exactly:

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

Two of these fields carry the run. **`claims`** is what makes step 4 possible
without a second read of every file — one read, two outputs, and the biggest
single saving in the run. **`audience`** is what lets step 5 present a real map
to confirm instead of an abstract question. A worker that omits either has to be
re-run, which costs more than the fields ever save.

Use a `schema` when the mode is a `Workflow`, so returns validate instead of
needing to be parsed.

## Grouping files

- Group by directory — it keeps related docs with one worker, which is what makes
  intra-group duplication visible early.
- Roughly 5–10 files per worker. Aim for balanced line counts, not balanced file
  counts: one 900-line monolith is a group of its own.
- Never split one file across two workers.
- Cap concurrency at what the run actually needs; more workers on a small corpus
  adds coordination cost, not speed.

## Workflow mode

For a corpus over ~40 files, a `Workflow` beats hand-dispatched agents: it holds
the pipeline deterministically and survives a long run. The shape:

1. `phase('Analyze')` — one `agent()` per group, `opus`, with the return schema
   above. This is a `parallel()` **barrier** — step 4 needs all of it.
2. Merge and cluster in plain script code. No agent: clustering a list you hold is
   not a reasoning task worth delegating.
3. Return the merged evidence — dispositions, the audience map, duplicate
   clusters, conflicts. **The workflow ends here**, at step 4.

The run then has **two conversations a workflow cannot hold**: the three
questions (step 5) and the approval (step 7). Both happen in the session, between
workflows. After approval, a second `Workflow` — or plain parallel agents —
applies the partitioned actions with `sonnet` and `effort: 'low'`.

Never carry the analysis workflow past step 4. A workflow that plans through the
questions has invented the answers, and one that applies has skipped the gate.

## Apply-stage partitioning

Concurrent edits to one file clobber each other. Partition strictly:

- One worker owns a file completely, for every action on that file.
- Index files, entry points, and any file receiving merged content are owned by
  the lead, never by a worker.
- New files from a split are created by the worker that owns their source.
- After the workers return, run the collision check from
  [../dispatching-parallel-agents/SKILL.md](../dispatching-parallel-agents/SKILL.md)
  — `git status` and `git diff --stat` must show only the expected files.

Worktree isolation (`isolation: 'worktree'`) is the wrong tool here: the actions
are already disjoint by file, and merging worktrees back costs more than the
partition saves.

## Anti-patterns

**Fanning out a small corpus.** Twelve files read inline is faster end to end than
three workers plus prompt-writing plus merging.

**A worker per file.** Forty single-file agents means forty prompts, forty
returns, and no worker with enough context to spot a duplicate. Group.

**Delegating step 4.** A dedup worker with partial visibility reports no
duplicates and is confidently wrong.

**Skipping the claim list** to keep step-3 returns small, then re-reading the
corpus in step 4. That doubles the run's cost and is the most likely way this
design gets quietly broken.

**Letting an analysis worker edit.** A worker that "helpfully" deletes a section
bypasses the approval gate, which is the one thing this skill must not do.

**Applying inside the analysis workflow.** Same failure, structural version.
