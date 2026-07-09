---
name: finish-branch
description: >-
  Decides how to integrate a finished branch — merge, pull request, keep, or
  discard — once tests pass. Use when implementation work on a branch is
  complete and you need to decide what happens to it next.
---

# Finish Branch

Once work on a branch is done, decide how to integrate it. Verify tests first,
then present exactly four options and execute the one chosen.

## Workflow

1. **Run the project's test command.** Use `make test` if the repo has a
   Makefile, otherwise the language-appropriate default (`go test ./...`,
   `pnpm test`, `mvn test`).
   - If tests fail: stop. Report the failures and do not present any options.
     Nothing gets merged, pushed, or discarded until tests pass.
   - If tests pass: continue.

2. **Determine the base branch.** Try `git merge-base HEAD main` or
   `git merge-base HEAD master`. If neither resolves cleanly or the branch's
   origin is ambiguous, ask the user which branch this work is based on.

3. **Present exactly these four options** — no open-ended "what next?":

   ```
   Tests pass. What would you like to do with this branch?

   1. Merge back to <base-branch> locally
   2. Push and open a Pull Request
   3. Keep the branch as-is
   4. Discard this work
   ```

4. **Execute the chosen option only:**

   - **Merge locally:** checkout `<base-branch>`, `git pull`, merge the
     feature branch, re-run the test command on the merged result. Only after
     the merge and tests succeed, delete the feature branch
     (`git branch -d <feature-branch>`).
   - **Push and open a PR:** push the branch (`git push -u origin
     <feature-branch>`) and open the PR (e.g. `gh pr create`). Do not delete
     the branch — the user needs it to iterate on review feedback.
   - **Keep as-is:** do nothing. Confirm the branch name and that it's
     untouched.
   - **Discard:** confirm exactly what will be deleted (branch name, commit
     list) and require explicit confirmation before running
     `git branch -D <feature-branch>`.

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

## Quality

- Before presenting results, run the shared [self-review checklist](../quality.md). Surface issues in the chat only if found.
