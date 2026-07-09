---
name: finish-branch
description: >-
  Decides how to integrate a finished branch — merge, pull request, keep, or
  discard — once tests pass. Use when implementation work on a branch is
  complete and you need to decide what happens to it next.
---

# Finish Branch

_Adapted from the MIT-licensed [superpowers](https://github.com/obra/superpowers) plugin._

Once work on a branch is done, decide how to integrate it. Verify tests first,
then present exactly four options and execute the one chosen.

## Workflow

1. **Run the project's test command.** Use `make test` if the repo has a
   Makefile, otherwise the language-appropriate default (`go test ./...`,
   `pnpm test`, `mvn test`).
   - If tests fail: stop. Report the failures and do not present any options.
     Nothing gets merged, pushed, or discarded until tests pass.
   - If tests pass: continue.

2. **Determine the base branch.** Detect the repo's default branch rather than
   assuming `main`:

   ```bash
   git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null   # e.g. origin/main
   gh repo view --json defaultBranchRef -q .defaultBranchRef.name  # fallback
   ```

   Strip the `origin/` prefix for the local branch name. If neither resolves,
   or if other long-lived branches exist that this work could belong to
   (`git branch --list`), ask the user which branch this work is based on.

3. **Detect whether the branch lives in a linked worktree.** Compare git-dir
   against git-common-dir:

   ```bash
   GIT_DIR=$(cd "$(git rev-parse --git-dir)" && pwd -P)
   GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
   ```

   If they differ, the feature branch is checked out in a linked worktree — the
   base branch cannot be checked out in the same directory, so merge/delete has
   to run against the main checkout (git-common-dir's parent) with `git -C`, and
   the worktree has to be removed before the branch can be deleted. Keep that in
   mind for the Merge and Discard paths below.

4. **Present exactly these four options** — no open-ended "what next?":

   ```
   Tests pass. What would you like to do with this branch?

   1. Merge back to <base-branch> locally
   2. Push and open a Pull Request
   3. Keep the branch as-is
   4. Discard this work
   ```

5. **Execute the chosen option only:**

   - **Merge locally:** in a plain checkout, checkout `<base-branch>`,
     `git pull`, merge the feature branch, and re-run the test command on the
     merged result. Only after the merge and tests succeed, delete the feature
     branch (`git branch -d <feature-branch>`). In a linked worktree, run the
     merge from the main checkout instead (`MAIN=$(dirname "$GIT_COMMON")`;
     `git -C "$MAIN" checkout <base-branch> && git -C "$MAIN" pull && git -C
     "$MAIN" merge <feature-branch>`), re-run tests there, then
     `git worktree remove <path>` before `git -C "$MAIN" branch -d
     <feature-branch>` (deleting a branch still checked out in a worktree
     fails).
   - **Push and open a PR:** push the branch (`git push -u origin
     <feature-branch>`) and open the PR (e.g. `gh pr create`). Do not delete
     the branch — the user needs it to iterate on review feedback.
   - **Keep as-is:** do nothing. Confirm the branch name and that it's
     untouched.
   - **Discard:** confirm exactly what will be deleted (branch name, commit
     list) and require explicit confirmation. In a linked worktree, remove the
     worktree first (`git worktree remove <path>`) before deleting the branch
     from the main checkout (`git -C "$MAIN" branch -D <feature-branch>`).

## Constraints

- Never skip test verification — a failing test suite means no options are
  offered, only the failure report.
- Never merge, push, or delete anything the user didn't explicitly pick from
  the four options.
- Never force-push. If a push is rejected, report it and ask how to proceed —
  don't add `--force` on your own.
- Never delete a branch (`-d` or `-D`) without the user having chosen option 1
  or option 4, and never run the discard without an explicit confirmation.
- If the merge or the re-run of tests fails, stop before deleting the branch
  and report the failure — don't leave the repo in a half-merged state
  silently.
