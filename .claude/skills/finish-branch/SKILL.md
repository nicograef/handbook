---
name: finish-branch
description: >-
  Decides how to integrate a finished branch — merge, pull request, keep, or
  discard — once tests pass. Use when implementation work on a branch is
  complete and you need to decide what happens to it next.
---

# Finish Branch

_Adapted from the MIT-licensed [superpowers](https://github.com/obra/superpowers) plugin._

## Workflow

1. **Run the project's test command.** Use `make test` if the repo has a Makefile.
   - Otherwise the language-appropriate default (`go test ./...`, `pnpm test`, `mvn test`).
   - **Tests fail** — stop. Report the failures and present no options.
   - **Tests pass** — continue.

2. **Determine the base branch.** Detect the repo's default branch rather than
   assuming `main`:

   ```bash
   git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null   # e.g. origin/main
   gh repo view --json defaultBranchRef -q .defaultBranchRef.name  # fallback
   ```

   - Strip the `origin/` prefix for the local branch name.
   - **Neither resolves** — try `git merge-base` against each long-lived branch
     in `git branch --list`; the nearest ancestor is the base.
   - Two candidates tie, or none is an ancestor: ask, per the
     [ask gate](../clarify/question-rules.md#the-ask-gate).

3. **Detect whether the branch lives in a linked worktree**, per
   [using-git-worktrees](../using-git-worktrees/SKILL.md) steps 1-2.

4. **Check for concurrent sessions before offering to integrate.**

   ```bash
   ~/.claude/agent-bus.sh radar
   ```

   - A peer session working in this repo makes landing a coordination step, not a
     local one — see [../parallel-sessions/SKILL.md](../parallel-sessions/SKILL.md).
   - Settle the landing order over the bus first, then continue.

5. **Present exactly these four options** — no open-ended "what next?":

   ```
   Tests pass. What would you like to do with this branch?

   1. Merge back to <base-branch> locally
   2. Push and open a Pull Request
   3. Keep the branch as-is
   4. Discard this work
   ```

6. **Execute the chosen option only:**

   - **Option 1, merge locally (plain checkout)** — checkout `<base-branch>`, `git pull`, merge
     the feature branch.
   - Re-run the test command on the merged result.
   - Delete the feature branch (`git branch -d <feature-branch>`) only after the merge and
     tests succeed.
   - **Option 1, merge locally (linked worktree)** — run the merge from the main checkout instead.
   - Derive it from the first `git worktree list --porcelain` record, always the main worktree.
   - Not from `dirname` of the git-common-dir: that resolves to a non-working-tree in a
     bare-hosted repo (verified at git 2.47.3).

     ```bash
     MAIN=$(git worktree list --porcelain | awk 'NR==1{print $2}')
     ```

   - **First record's block contains `bare`** — no main checkout to merge into, so stop and ask.
   - Otherwise run `git -C "$MAIN" checkout <base-branch> && git -C "$MAIN" pull && git -C "$MAIN" merge <feature-branch>`, then re-run tests there.
   - Then `git worktree remove <path>` before `git -C "$MAIN" branch -d <feature-branch>`.
   - Deleting a branch still checked out in a worktree fails.
   - **Option 2, push and open a PR** — push the branch (`git push -u origin <feature-branch>`)
     and open the PR (e.g. `gh pr create`).
   - Do not delete the branch — the user needs it to iterate on review feedback.
   - **Option 3, keep as-is** — do nothing. Confirm the branch name and that it's untouched.
   - **Option 4, discard** — confirm exactly what will be deleted (branch name, commit list).
   - Require explicit confirmation before discarding.
   - In a linked worktree, remove the worktree first (`git worktree remove <path>`).
   - Then delete the branch from the main checkout (`git -C "$MAIN" branch -D <feature-branch>`).

7. **Handle the plan file** — `docs/plans/plan-<slug>.md`, when the branch implemented one:

   | Option | Plan file |
   | --- | --- |
   | 1 merge | `git rm` in the main checkout after the merge, committed there |
   | 2 PR | Kept, and named as an open follow-up in the PR body |
   | 3 keep | Kept, untouched |
   | 4 discard | Kept, untouched |

   - Deletion requires every acceptance criterion ticked; one unticked box keeps the file.
   - Option 1 only, because only there is the merge complete in this session.
   - Rationale: the **Current state only** rule in `AGENTS.md`.

## Constraints

- Never skip test verification.
- A failing test suite means no options are offered, only the failure report.
- Never merge, push, or delete anything the user didn't explicitly pick from the four options.
- Exception, by design: a run of [implement-plan](../implement-plan/SKILL.md) lands its own
  `plan/*` branches and removes its own worktrees without this gate.
- The user approved that once, up front, in its run contract.
- Push, PR, discard, and any branch that run did not create still come here.
- Never force-push. A rejected push — report it and ask how to proceed.
- Never add `--force` on your own.
- Never delete a branch (`-d` or `-D`) without the user having chosen option 1 or option 4.
- Never run the discard without an explicit confirmation.
- Merge or test re-run fails — stop before deleting the branch and report the failure.
- Never leave the repo in a half-merged state silently.
- Format the options prompt and any failure report per the
  [output style contract](../output-style.md).
