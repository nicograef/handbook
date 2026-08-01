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

Delegate independent problems to isolated subagents instead of investigating
them one by one. Each subagent gets exactly the context it needs — not your
full session history — so it stays focused and your own context stays free
for coordination. Parallel agents cost roughly 15× the tokens of a single
linear pass, so reserve this for genuinely independent, each-substantial work;
for two small related fixes, just do them yourself.

## Workflow

1. **Check independence first.** Group the failures or tasks by root cause.
   Two items are independent only if neither shares a file/region with the
   other and fixing one has no chance of fixing the other. If they're
   related, investigate together instead — don't force a split.
2. **Write one focused prompt per domain** (the four-part delegation
   contract). Each prompt must include:
   - A specific scope (one file, one subsystem, one bug — not "fix
     everything")
   - Self-contained context: paste the actual error messages, test names,
     and stack traces, not a summary of them; name the tools and source files
     each agent should use, and restate the repo rules that apply — subagents
     see none of this session's history, and Explore/Plan-style agents don't
     load CLAUDE.md, so anything they must obey has to be in the prompt
   - Explicit constraints, including file ownership (e.g. "only modify files
     under `src/agents/`", "fix tests only, don't touch production code") so no
     two agents can write the same file
   - The exact expected return format (e.g. "return a summary of root cause
     and files changed")
3. **Dispatch all of them in the same response** so they run in parallel.
4. **Read every summary when they return**, then **check for collisions:**
   diff or grep to confirm no two agents touched the same file or region, and
   resolve any overlap by hand before trusting either result.
5. **Integrate and verify as a whole.** Run the full test suite or build
   after merging all results — passing in isolation doesn't guarantee
   passing together.

## Constraints

- Isolate writes when agents change code in the same repo: give each a
  disjoint file-ownership partition, or run them in separate worktrees
  (`isolation: worktree`) so concurrent edits can't clobber each other.
- When a returning agent's work needs a correction or follow-up, resume it
  with more context (`SendMessage`) instead of dispatching a fresh agent to
  redo the whole task.
