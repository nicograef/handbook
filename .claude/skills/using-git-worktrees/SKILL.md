---
name: using-git-worktrees
description: >-
  Creates or reuses an isolated git worktree for feature work, a risky
  refactor, or unattended agent runs. Use when starting work that shouldn't
  touch the current checkout, before executing a multi-step plan, or when
  running an agent unattended and it needs its own branch and directory.
---

# Using Git Worktrees

_Adapted from the MIT-licensed [superpowers](https://github.com/obra/superpowers) plugin._

Give a piece of work its own checkout and branch so it can't collide with
whatever is currently checked out, without stashing or branch-juggling.

## Workflow

1. **Rule out a submodule first.**

   ```bash
   git rev-parse --show-superproject-working-tree
   ```

   If that returns a path, you're in a submodule. Treat it as a normal
   checkout and continue to step 3 — do not run the test in step 2, which
   cannot distinguish a submodule from a main checkout.

2. **Detect existing isolation.** Compare git-dir against git-common-dir:

   ```bash
   GIT_DIR=$(cd "$(git rev-parse --git-dir)" && pwd -P)
   GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
   ```

   If `GIT_DIR != GIT_COMMON`, you are already in a linked worktree — skip
   creation and go straight to step 4. Inside a submodule these two *match*
   (verified at git 2.47.3), which is why the submodule test has to run
   first: on its own, this test reports a submodule as a normal checkout.

3. **In a normal checkout, confirm before creating.** Ask whether an isolated
   worktree is wanted for this work. If the answer is no, work in place and
   skip to step 4.

   If yes, pick a directory:
   - Reuse `.worktrees/` if it already exists at the project root.
   - Otherwise create `.worktrees/` there (local-ignored, project-local).

   Ignore it without a commit, so an unattended run leaves no stray commit
   behind:

   ```bash
   git check-ignore -q .worktrees || echo ".worktrees/" >> "$(git rev-parse --git-common-dir)/info/exclude"
   ```

   Then create the worktree on a new branch:

   ```bash
   git worktree add .worktrees/<branch-name> -b <branch-name>
   cd .worktrees/<branch-name>
   ```

4. **Work there.** Install dependencies and confirm a clean baseline (tests
   pass) before making changes, so any later failure is attributable to the
   new work, not pre-existing breakage.

5. **Remove it when finished.** Decide what happens to the branch first —
   see the [finish-branch](../finish-branch/SKILL.md) skill for the
   merge/PR/keep/discard choice. Then, from the main checkout:

   ```bash
   git worktree remove .worktrees/<branch-name>
   ```

## Constraints

- Run the clean-baseline check after creating a worktree — it's the only way
  to tell new breakage from pre-existing breakage later.
- Prefer `.worktrees/` over ad hoc locations so worktrees stay predictable and
  easy to clean up in bulk (`git worktree list`, `git worktree prune`).
- Remove worktrees once their branch is merged or abandoned — stale worktrees
  accumulate and confuse `git worktree list`.
