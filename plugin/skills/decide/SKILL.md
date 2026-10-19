---
name: decide
description: Sweeps the session for open questions, unstated assumptions and pending decisions, orders them by dependency, and asks each through AskUserQuestion with context, trade-offs and consequences. Use when choices pile up or a skill routes one to the user.
---

# Decide

Everything the user needs lives inside the AskUserQuestion call. The chat gets no issue list or summary before it. Start without asking for permission.

1. Sweep the whole session for unanswered questions, assumptions stated or silent, deferred decisions, and ambiguous or conflicting instructions. Include blockers only the user can lift.
2. Drop items the session or a stated constraint already settles. Items with one clear winner: take it and record it. Nothing left: say so in one line and stop.
3. Order by dependency: an item whose answer changes another's options goes first. Dependents wait for a later round.
4. Ask one AskUserQuestion call per round, as many questions as it takes. Each question names where it came from and why it matters now. A reader who skipped the session must understand it alone. Give every option its consequences at equal depth, a recommendation first.
5. Follow up on answers that open new questions, round by round, until none remain.
6. Record every decision where the work is tracked: plan file, task, or memory across sessions. Continue the work.
