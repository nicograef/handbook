---
name: decide
description: Sweeps the session for open questions, unstated assumptions and pending decisions, orders them by dependency, and asks each through AskUserQuestion with context, trade-offs and consequences. Use when choices pile up or a skill routes one to the user.
---

# Decide

Everything the user needs lives inside the AskUserQuestion call. The chat gets no issue list, no options and no summary before the questions. Start without asking for permission.

## Sweep

1. Collect from the whole session, oldest to newest. Sources: questions the user left unanswered, assumptions you named, assumptions you made silently, deferred decisions. Also ambiguous requests, conflicting instructions, choices with no clear winner, and blockers only the user can lift.
2. Drop items the session settled later, and items a stated constraint settles on its own.
3. Order the rest. An item whose answer changes another item's options comes first. Group the remainder by topic.
4. Nothing left: say so in one line and stop.

## Ask

One AskUserQuestion call per round, as many questions as the tool takes. Dependents wait for a later round.

Per question:

- The question text states what is undecided and where it came from: the message, file or step. It says why it matters now and what happens if it stays open. A reader who skipped the session must understand it from this field alone.
- Each option's description gives what picking it means, its pros and cons, and its effect on other items. Same depth for every option.
- A recommendation, if you have one, goes first, marked as recommended, with the reason in its description.

Use multi-select only when the choices combine.

## Follow up

Each answer can open a new question. An "Other" needs detail; a pick makes its sub-choices live; a dependent item from the sweep is now askable. Ask those in the next round. Stop when no item remains.

Then record every decision where the work is tracked: the plan file, the task, or memory when it crosses sessions. Continue the work.
