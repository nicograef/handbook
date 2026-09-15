---
name: decide
description: Sweeps the session's state and history for open questions, unstated assumptions and pending decisions, orders them by dependency, and puts each to the user through AskUserQuestion with the context, trade-offs and consequences needed to decide.
disable-model-invocation: true
---

# Decide

Everything the user needs lives inside the AskUserQuestion call. The chat gets no issue list, no options and no summary before the questions. Start without asking for permission.

## Sweep

1. Collect from the whole session, oldest to newest: questions the user left unanswered, assumptions you named, assumptions you made silently, deferred decisions, ambiguous requests, conflicting instructions, choices with no clear winner, and blockers only the user can lift.
2. Drop items the session settled later, and items a stated constraint settles on its own.
3. Order the rest. An item whose answer changes another item's options comes first. Group the remainder by topic.
4. Nothing left: say so in one line and stop.

## Ask

One AskUserQuestion call per round, up to four questions per call. Dependents wait for a later round.

Per question:

- `header`: the topic, ≤ 12 characters.
- `question`: the issue in plain words. State what is undecided and where it came from: the message, file or step. State why it matters now and what happens if it stays open. A reader who skipped the session must understand it from this field alone.
- `options`: two to four distinct choices. `label`: the choice in ≤ 5 words. `description`: what picking it means, its pros, its cons, and the consequences for the work and for the other open items. Same depth for every option.
- A recommendation, if you have one, goes first with "(Recommended)" in its label and the reason in its description.
- The tool appends an "Other" option to every question. Do not add a second one.

Use multi-select only when the choices combine.

## Follow up

Each answer can open a new question: an "Other" that needs detail, a pick whose sub-choices are now live, or a dependent item from the sweep. Ask those in the next round. Stop when no item remains.

Then record every decision where the work is tracked: the plan file, the task, or memory when it crosses sessions. Continue the work.
