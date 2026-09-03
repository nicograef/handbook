# Integration

Verified git sequences for folding, landing, conflicts and hazards. Commands
were verified at git 2.47.3.

Another Claude Code session may hold a branch in this repo. Run
`~/.claude/agent-bus.sh radar` before folding and before landing, and settle the
order over the bus — [../parallel-sessions/SKILL.md](../parallel-sessions/SKILL.md).

- [Locate yourself](#locate-yourself)
- [Fold a phase branch into the run branch](#fold-a-phase-branch-into-the-run-branch)
- [Land on the base branch](#land-on-the-base-branch)
- [When the base moves under you](#when-the-base-moves-under-you)
- [rerere may be enabled](#rerere-may-be-enabled)
- [Conflicts](#conflicts)
- [Hazards](#hazards)

## Locate yourself

```bash
git rev-parse --show-superproject-working-tree                  # non-empty => submodule, stop
git rev-parse --path-format=absolute --git-dir
git rev-parse --path-format=absolute --git-common-dir           # equal => main checkout
MAIN=$(git worktree list --porcelain | awk 'NR==1{print $2}')   # first record is always the main worktree
```

- Run the submodule test **first**: inside a submodule, git-dir and
  git-common-dir *match* (verified at git 2.47.3).
- The linked-worktree test alone then misreports a submodule as a main checkout.
- Never derive `MAIN` from `dirname` of the git-common-dir — that is wrong for a
  bare-hosted worktree.
- If the first porcelain record's block contains `bare`, there is no main
  checkout; stop.

## Fold a phase branch into the run branch

Per member, in ascending phase order:

```bash
git -C "$MAIN" merge-tree --write-tree --messages "$TRUNK_TIP" "$BR"   # dry run, touches nothing
git -C "$WT" -c rerere.enabled=false rebase --onto "$TRUNK_TIP" "$(git merge-base "$TRUNK_TIP" "$BR")" "$BR"
git -C "$RUN_WT" -c rerere.enabled=false merge --ff-only "$BR"
```

Re-run the verify command on the folded run branch before the next member.

## Land on the base branch

```bash
MAIN=$(git worktree list --porcelain | awk 'NR==1{print $2}')
BEFORE=$(git -C "$MAIN" rev-parse refs/heads/<base>)         # pin; never pass the moving name to rebase
git -C "$MAIN" merge-tree --write-tree --messages "$BEFORE" plan/<slug>
git -C "$WT" -c rerere.enabled=false rebase --onto "$BEFORE" "$(git merge-base "$BEFORE" plan/<slug>)" plan/<slug>
git -C "$MAIN" -c rerere.enabled=false merge --ff-only plan/<slug>
```

- `--ff-only` is the race detector: a human commit to the base branch
  mid-sequence makes it fail cleanly.
- Clean failure: exit 128, `fatal: Not possible to fast-forward, aborting.`, refs
  and working tree untouched.
- `--no-ff` succeeds on a diverged, unverified branch and therefore detects
  nothing.
- Landing must run in the main worktree.
- `git push . HEAD:<base>` is rejected by `receive.denyCurrentBranch`.

## When the base moves under you

- Re-pin `$BEFORE`, redo the `rebase --onto`, retry `--ff-only` once.
- A second failure is a stop, not a third attempt.

## rerere may be enabled

- `git config --show-origin --get rerere.enabled` returns `true` from
  `~/.gitconfig` on this dev machine.
- With it on, a repeat merge hands back a fully resolved working file with **no
  conflict markers**.
- `git status` still reports `UU`.
- An agent that reads "no markers" as "nothing to do" commits a resolution
  nobody reviewed.
- Every merge and rebase this skill runs therefore carries
  `-c rerere.enabled=false`.

## Conflicts

Enumerate with `git diff --name-only --diff-filter=U`; classify from the
porcelain v1 two-letter code:

| Code | Class |
| --- | --- |
| `AA` | add/add |
| `UU` | content |
| `UD` / `DU` | modify-delete |
| `DD` | both-deleted |

- **Sides flip between rebase and merge**: under `rebase <base>`, stage 2 /
  `--ours` is the *base* side; under `merge <base>` it is *your branch*.
- Never hardcode "ours = my work".
- Rule: abort in the owning worktree, report paths and classes, hand back.
- Abort with `git -C <wt> rebase --abort` — aborting from elsewhere exits 128.
- Nothing is auto-resolved by content.
- A declared `.gitattributes merge=` driver is the sole exception, because that
  is a human decision already recorded.
- After an abort, `git reflog show <branch>` is the undo ledger.

## Hazards

Never run these in a multi-worktree repo:

- `gc --prune=now` — corrupts refs and worktree HEADs when another worktree
  commits concurrently. Use plain `gc`.
- `update-ref refs/heads/<b>` — desyncs a checked-out worktree, exit 0, no
  warning.
- `rebase --update-refs` — silently skips refs checked out elsewhere and exits
  0. Land branches one at a time.
- `stash` — repo-global, not per-worktree. Commit instead.
- `checkout -- .` / `restore .` / `clean -fd` / `reset --hard` — unrecoverable;
  unstaged and untracked work was never an object (staged work survives as an
  unreachable blob).
- `branch -D` — skips the merged check; `-d` refuses an unmerged branch. Either
  form deletes the reflog, so note the sha first.
- `worktree remove --force` — removes a worktree holding staged work. Use the
  plain form and read its refusal.
- `push --force` / `-f` / `--force-with-lease`, `--no-verify`,
  `push origin <base>`.
- Deleting another worktree's `index.lock` — it is 0 bytes, holds no pid, and
  staleness cannot be proven. Report and stop.
