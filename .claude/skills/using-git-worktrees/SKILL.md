---
name: using-git-worktrees
description: >-
  Creates or reuses an isolated git worktree for feature work, a risky
  refactor, or unattended agent runs. Use when starting work that shouldn't
  touch the current checkout, before executing a multi-step plan, or when
  running an agent unattended and it needs its own branch and directory.
---

# Using Git Worktrees

Give a piece of work its own checkout and branch so it can't collide with
whatever is currently checked out, without stashing or branch-juggling.

## Workflow

1. **Detect existing isolation first.** Compare git-dir against
   git-common-dir:

   ```bash
   GIT_DIR=$(cd "$(git rev-parse --git-dir)" && pwd -P)
   GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
   ```

   If `GIT_DIR != GIT_COMMON`, you are already in a linked worktree — skip
   creation and go straight to step 4.

2. **Guard against submodules.** The git-dir/git-common-dir mismatch is also
   true inside a submodule. Before treating a mismatch as "already isolated,"
   check:

   ```bash
   git rev-parse --show-superproject-working-tree
   ```

   If that returns a path, you're in a submodule, not a worktree — treat it
   as a normal checkout and continue to step 3.

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

- Check for existing isolation before creating a worktree — nesting a worktree
  inside a worktree is a mess to unwind.
- Confirm the worktree directory is ignored before creating it — an untracked
  worktree's contents should not end up staged.
- Run the clean-baseline check (dependency install + test run) after creating a
  worktree — it's the only way to tell new breakage from pre-existing breakage
  later.
- Prefer `.worktrees/` over ad hoc locations so worktrees stay predictable and
  easy to clean up in bulk (`git worktree list`, `git worktree prune`).
- Remove worktrees once their branch is merged or abandoned — stale worktrees
  accumulate and confuse `git worktree list`.
