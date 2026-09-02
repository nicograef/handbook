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

## Workflow

1. **Rule out a submodule first.**

   ```bash
   git rev-parse --show-superproject-working-tree
   ```

   - A returned path means you're in a submodule.
   - Treat it as a normal checkout and skip to step 3.
   - Skip step 2's test — it cannot tell a submodule from a main checkout.

2. **Detect existing isolation.** Compare git-dir against git-common-dir:

   ```bash
   GIT_DIR=$(cd "$(git rev-parse --git-dir)" && pwd -P)
   GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
   ```

   - `GIT_DIR != GIT_COMMON` means you're already in a linked worktree — skip to step 4.
   - Inside a submodule the two *match* (verified at git 2.47.3).
   - Step 1 must run first — alone, this test reads a submodule as a normal checkout.

3. **In a normal checkout, confirm before creating.**

   - Ask whether an isolated worktree is wanted for this work.
   - If no, work in place and skip to step 4.
   - If yes, pick a directory:
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

4. **Work there.**

   - Install dependencies and confirm a clean baseline (tests pass) before making changes.
   - That way, any later failure is attributable to the new work, not pre-existing breakage.

5. **Remove it when finished.**

   - Decide what happens to the branch first — see [finish-branch](../finish-branch/SKILL.md)
     for the merge/PR/keep/discard choice.
   - Then, from the main checkout:

   ```bash
   git worktree remove .worktrees/<branch-name>
   ```

## Constraints

- A worktree isolates files, not the repo. Another session may be working in a
  sibling worktree right now.
  - Check with `~/.claude/agent-bus.sh peers`, then announce your claim.
  - Protocol: [../parallel-sessions/SKILL.md](../parallel-sessions/SKILL.md).
