---
name: dispatching-parallel-agents
description: >-
  Dispatches multiple independent subagents in parallel for tasks that share
  no state or sequential dependency. Use when facing 2+ failing tests,
  broken subsystems, or investigation targets that don't depend on each
  other's outcome.
---

# Dispatching Parallel Agents

Delegate independent problems to isolated subagents instead of investigating
them one by one. Each subagent gets exactly the context it needs — not your
full session history — so it stays focused and your own context stays free
for coordination.

## Workflow

1. **Check independence first.** Group the failures or tasks by root cause.
   Two items are independent only if neither shares a file/region with the
   other and fixing one has no chance of fixing the other. If they're
   related, investigate together instead — don't force a split.
2. **Write one focused prompt per domain.** Each prompt must include:
   - A specific scope (one file, one subsystem, one bug — not "fix
     everything")
   - Self-contained context: paste the actual error messages, test names,
     and stack traces, not a summary of them
   - Explicit constraints (e.g. "do not modify files outside `src/agents/`",
     "fix tests only, don't touch production code")
   - The exact expected return format (e.g. "return a summary of root cause
     and files changed")
3. **Dispatch all of them in the same response.** Multiple subagent calls
   issued in one response run in parallel; one dispatch per response runs
   sequentially and defeats the point.
4. **Read every summary when they return.** Don't skim — you need to know
   what each agent actually changed.
5. **Check for collisions.** Diff or grep to confirm no two agents touched
   the same file or region. If they did, resolve the overlap by hand before
   trusting either result.
6. **Integrate and verify as a whole.** Run the full test suite or build
   after merging all results — passing in isolation doesn't guarantee
   passing together.

## Constraints

- Never dispatch on a hunch that tasks are independent — verify no shared
  files/state and no "fixing one might fix the other" relationship first.
- Don't write vague prompts ("fix the tests," "investigate the bug"). A
  subagent with no file, no error text, and no constraint will wander.
- Don't let scope creep into a prompt — one subagent, one problem domain.
- Don't skip the collision check. Independent-looking problems can still
  land edits in the same file.
- If you're not sure a set of problems is actually independent, default to
  investigating together first — a wrong parallel split costs more time than
  it saves.

## Quality

- Before presenting results, run the shared [self-review checklist](../quality.md). Surface issues in the chat only if found.
