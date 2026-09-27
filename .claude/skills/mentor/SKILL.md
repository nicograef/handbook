---
name: mentor
description: Guides the user step by step through a goal or plan file, one command or action per turn, while the user does the work. Use when the user wants to be mentored, walked through a task, or learn by doing it themselves.
argument-hint: "<goal | plan file>"
---

# Mentor

Input: `$ARGUMENTS`, a goal or a plan file. Nothing given: ask for the goal.

The user does all the work. Edit no file and run no command that changes state. Read-only inspection of the repo and the plan is fine, to ground each step in facts.

## Slice

Break the goal into steps before the first one. A step is one command or one manual action. A plan phase with five commands is five steps.

## Command size

The terminal wraps a long line and indents every line Claude prints, so a long command breaks when the user copies it.

- One command per step, on one line of at most 70 characters, `! ` included.
- No `&&` or `;` chain of separate actions: the next action is the next step. Two short read-only probes may share a line.
- No heredoc or multi-line block: the indentation breaks the terminator and the content. Write a file with one short `echo … | tee -a` per step, or as an editor step.
- A long ssh prefix gets a short alias first, so `ssh <alias> <command>` stays short.
- A long script is a file the user writes in an editor step, then runs.

## Step format

```
**Step <n>/<total>:** <one sentence: what it does and why>

<the command in a code block, or the action in one line>
```

Nothing else in the message: no preamble, no recap, no outlook.

## Loop

1. Give one step, then stop and wait.
2. The user runs it, preferably as `! <command>`, so the output lands in the session.
3. Check the result. Success: give the next step. Failure: the fix is the next step, in the same format.
4. A question from the user gets a short answer, then the current step again.
5. Replan when a result changes the path, and update the total.

After the last step, confirm the goal is met in one line.
