# Git sequences

Verified at git 2.53.0.

## Pickup

```bash
git worktree list --porcelain
git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r w; do
  [ -d "$w" ] || { echo "$w MISSING"; continue; }
  gd=$(git -C "$w" rev-parse --path-format=absolute --git-dir) || continue
  s=""
  [ -d "$gd/rebase-merge" ] && s="$s rebase"; [ -d "$gd/rebase-apply" ] && s="$s rebase-apply"
  [ -f "$gd/MERGE_HEAD" ] && s="$s merge"; [ -f "$gd/CHERRY_PICK_HEAD" ] && s="$s cherry-pick"
  [ -f "$gd/index.lock" ] && s="$s INDEX_LOCK"
  printf '%s\tstate:%s\tdirty:%s\n' "$w" "${s:-clean}" "$(git -C "$w" status --porcelain | wc -l)"
done
awk '/^## Phase /{p=$0} /^- \[ \]/{print p" -> "$0; exit}' <plan>   # first unmet criterion
git log --oneline --all --grep='Plan: <slug> phase'                 # what was committed
```

- Read the plan inside the run worktree, including `## Run state`. If the worktree is gone, use `git branch --list 'plan/*'` plus the log grep; branches are the durable artifact.
- The log outranks the checkbox. A tick with no commit is unticked; a commit with no tick is re-verified and ticked. Only trailer-carrying commits are authoritative.
- Half-finished operations: read `$GD/rebase-merge/head-name`, `onto` and `orig-head`; continue or abort only from the owning worktree. `git worktree prune --dry-run --verbose` before `prune`; `git worktree repair <path>` after a move; `git fsck --no-progress` for ref damage.

## Locate yourself

```bash
git rev-parse --show-superproject-working-tree          # non-empty: submodule, treat as a plain checkout
git rev-parse --path-format=absolute --git-dir
git rev-parse --path-format=absolute --git-common-dir   # equal to git-dir: main checkout
MAIN=$(git worktree list --porcelain | awk 'NR==1{print $2}')   # first record is the main worktree
```

Inside a submodule git-dir and git-common-dir match, so run the submodule test first. If the first porcelain record contains `bare`, there is no main checkout; stop.

## Concurrency test

Phases i and j may run concurrently only if all hold:

1. Neither `**Depends on**` line names the other.
2. The paths named in their `### Context` and `### What to build` are disjoint (compute the union).
3. Every symbol j names already resolves at `$BASE` (`git grep -n <symbol> $BASE`).
4. Neither writes a choke file: the plan, `README.md` or another index, lockfiles, `go.mod` / `package.json`, migration-sequence files.
5. `git merge-tree --write-tree --messages "$BASE" <branch>` exits 0 for each, and the two branches merge into each other cleanly. Exit 1 is a conflict; read the exit code, not the oid.
6. The gate survives two concurrent runs: derived database names, ports and temp paths.

## Fold a phase branch into the run branch

```bash
git -C "$MAIN" merge-tree --write-tree --messages "$TRUNK_TIP" "$BR"                   # dry run
git -C "$WT" -c rerere.enabled=false rebase --onto "$TRUNK_TIP" "$(git merge-base "$TRUNK_TIP" "$BR")" "$BR"
git -C "$RUN_WT" -c rerere.enabled=false merge --ff-only "$BR"
```

## Land on the base branch

```bash
BEFORE=$(git -C "$MAIN" rev-parse refs/heads/<base>)
git -C "$MAIN" merge-tree --write-tree --messages "$BEFORE" plan/<slug>
git -C "$WT" -c rerere.enabled=false rebase --onto "$BEFORE" "$(git merge-base "$BEFORE" plan/<slug>)" plan/<slug>
git -C "$MAIN" -c rerere.enabled=false merge --ff-only plan/<slug>
```

`--ff-only` is the race detector: a human commit on the base mid-sequence fails it cleanly (exit 128, refs untouched). If the base moved, re-pin, redo the rebase, retry once; a second failure is a stop.

## Conflicts

List with `git diff --name-only --diff-filter=U`; classify by porcelain code. Abort with `git -C <wt> rebase --abort` from the owning worktree, report paths and classes, hand back. A declared `.gitattributes merge=` driver is the only automatic resolution. `git reflog show <branch>` is the undo ledger.

## Hazards in a multi-worktree repo

| Command | Effect | Use instead |
| --- | --- | --- |
| `gc --prune=now` | Corrupts refs and worktree HEADs under concurrent commits | plain `gc` |
| `update-ref refs/heads/<b>` | Desyncs a checked-out worktree silently | rebase and `merge --ff-only` |
| `rebase --update-refs` | Skips refs checked out elsewhere, exits 0 | land one branch at a time |
| `stash` | Repo-global | commit |
| `checkout -- .`, `restore .`, `clean -fd`, `reset --hard` | Unstaged and untracked work is gone | commit, then `git revert` |
| `branch -D` | Skips the merged check | `branch -d`; note the sha first |
| `worktree remove --force` | Removes a worktree holding staged work | plain form; read its refusal |
| Deleting a foreign `index.lock` | Staleness cannot be proven | report and stop |
| Force-push, `--no-verify` | Denied by settings | never |
| `push origin <base>` | Push, PR or discard is the user's call | never |
