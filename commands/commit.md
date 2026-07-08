---
description: Propose a Conventional Commit message for the staged changes, then commit only after confirmation.
argument-hint: "[optional scope or hint, e.g. 'auth' or 'fix the flaky test']"
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*), Bash(git branch:*), Bash(git rev-parse:*)
---

You are preparing a git commit for Nico. Follow his rules strictly:

- **Never auto-commit.** Propose the message first, wait for an explicit "yes"/"go"/edit, then commit.
- **Conventional Commits** style: `type(scope): subject` — types: feat, fix, refactor, docs, test, chore, build, ci, perf, style. Imperative mood, lower-case subject, no trailing period, ~72 char subject cap.
- Keep the body only when it adds real information (why, not what). Wrap at ~72 cols.

## Steps

1. Run `git status` and `git diff --staged`. If **nothing is staged**, show `git diff` (unstaged) and ask whether to `git add -A` or which paths to stage — do not stage silently.
2. If the current branch is the default branch (`main`/`master`), warn and offer to create a feature branch first.
3. Analyze the diff. If it contains **unrelated changes**, suggest splitting into multiple commits and propose each message.
4. Present the proposed commit message(s) in a fenced block. Incorporate the user hint if given: $ARGUMENTS
5. **Stop and wait** for confirmation. Only after the user approves, run `git commit`. Never push.
