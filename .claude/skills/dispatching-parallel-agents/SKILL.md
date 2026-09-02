---
name: dispatching-parallel-agents
description: >-
  Dispatches multiple subagents in parallel for 2+ confirmed-independent,
  each-substantial failures or investigation targets that share no state or
  sequential dependency. Use when the work splits cleanly and each part is big
  enough to justify a separate agent.
---

# Dispatching Parallel Agents

_Adapted from the MIT-licensed [superpowers](https://github.com/obra/superpowers) plugin._

- **Cost** — delegating to isolated subagents costs roughly 15× the tokens of a chat interaction, about 4× a single agent pass.
- **Reserve for** — genuinely independent, each-substantial work.
- **Do it yourself** — two small related fixes.

## Workflow

1. **Check independence first.** Group the failures or tasks by root cause.
   - Two items are independent only if neither shares a file/region with the other.
   - Independence also requires that fixing one has no chance of fixing the other.
   - Related items — investigate together instead; don't force a split.
2. **Write one focused prompt per domain** (the four-part delegation contract). Each prompt
   must include:
   - **Scope** — specific: one file, one subsystem, one bug; not "fix everything".
   - **Context** — self-contained: paste the actual error messages, test names and stack traces.
   - Never a summary of them.
   - **Tools and sources** — name the tools and source files each agent should use.
   - **Repo rules** — restate the rules that apply; anything they must obey has to be in the prompt.
   - Subagents see none of this session's history.
   - Explore/Plan-style agents don't load CLAUDE.md.
   - **Constraints** — explicit, including file ownership, so no two agents write the same file.
   - Examples: "only modify files under `src/agents/`", "fix tests only, don't touch production code".
   - **Return format** — state it exactly, per the
     [report shape](../output-style.md#report-shape).
3. **Dispatch all of them in the same response** so they run in parallel.
   - Then keep dispatching. Act on each result as it lands, not after the
     slowest one.
   - Waiting for the set before starting anything is a barrier you rarely need.
   - A barrier is earned only when the next step reads across *all* results.
   - That means dedup, a total count, or a comparison between findings.
   - Your own reading and thinking belongs inside someone else's runtime.
4. **Read every summary as it returns**, then **check for collisions.**
   - Diff or grep to confirm no two agents touched the same file or region.
   - Resolve any overlap by hand before trusting either result.
5. **Integrate and verify as a whole.** Run the full test suite or build after merging all
   results.
   - Passing in isolation doesn't guarantee passing together.

## Model routing

Decide the model per task. Never let a worker inherit the session model silently.

| Work | Model |
| --- | --- |
| Mechanical and fully specified — searches, renames, formatting, doc sweeps, scaffolding | `sonnet` |
| Judgment — implementation, review, verification, debugging, cross-cutting synthesis | `opus` |

- Set it explicitly: the `Agent` tool's `model`, or `model` in every `agent()` call's opts.
- Omitting it inherits the session model; a fork always inherits its parent's. Never fork for work `sonnet` could do.
- Use `effort: 'low'` for cheap mechanical stages.
- A skill refines this per stage — [distill](../distill/parallelism.md#model-routing),
  [implement-plan](../implement-plan/orchestration.md#model-routing).

## Constraints

- Dispatching to check another agent's work is budgeted by
  [verification-depth.md](../verification-depth.md).
- A stage costs its slowest member, so bound the long pole before cutting headcount.
  - Estimate each unit before dispatch; split anything past roughly 30 minutes.
  - Or tell it to commit what verifies and return at 30 minutes.
  - A stopped agent loses whatever it has not committed, so the bound has to be set up front.
- Cap only the agents that own a worktree. Read-only agents carry none of that
  cost, so cap them at the runtime's `min(16, cores − 2)` instead.
- Isolate writes when agents change code in the same repo.
- Give each a disjoint file-ownership partition, or run them in separate worktrees
  (`isolation: worktree`), so concurrent edits can't clobber each other.
- A returning agent needing a correction or follow-up — resume it with more context
  (`SendMessage`).
- Never dispatch a fresh agent to redo the whole task.
- Format every report per the [output style contract](../output-style.md).
