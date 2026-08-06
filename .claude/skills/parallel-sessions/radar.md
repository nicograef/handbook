# Radar

What `agent-bus.sh radar` computes, and how to act on each result.

## Committed collisions

One row per live peer branch.

| Column | Source | Meaning |
| --- | --- | --- |
| `PEER BRANCH` | peer's registry entry | The branch that session has checked out |
| `OVERLAP` | file-set intersection since the merge base | Files both branches already changed |
| `MERGE` | `git merge-tree --write-tree` | `clean` or `CONFLICT`, predicted now |
| `SHARED PATHS` | the intersection itself | Which files those are |

The underlying commands, all read-only:

```bash
MB=$(git merge-base "$MINE" "$THEIRS")
comm -12 <(git diff --name-only "$MB" "$MINE" | sort) \
         <(git diff --name-only "$MB" "$THEIRS" | sort)
git merge-tree --write-tree --messages "$MINE" "$THEIRS"
```

- `merge-tree` writes an object, never a ref, an index or a working file.
- It is safe to run at any time, including mid-rebase in another worktree.

## Declared collisions

One row per peer whose announced claim intersects yours.

| Row | Meaning |
| --- | --- |
| `paths:` | You both intend to write these files; nothing is committed yet |
| `RESOURCES:` | You both hold the same port, cluster or container |

- A `RESOURCES` hit is the urgent one. Git will never surface it.
- Declared collisions appear before committed ones, which is the point.

## Reading the result

| Result | Action |
| --- | --- |
| `OVERLAP 0`, `MERGE clean` | Proceed |
| `OVERLAP > 0`, `MERGE clean` | Proceed, but re-run before landing — clean now is not clean later |
| `MERGE CONFLICT` | Send `conflict` and settle the rebase order before touching anything |
| A lockfile or index file in `SHARED PATHS` | Treat as a conflict even when `clean` |
| `RESOURCES` non-empty | Stop and settle ownership before running tests |
| `(no live peer branch)` | You are alone on git; declared claims may still collide |

Choke files deserve the extra caution: lockfiles, `go.mod`, `package.json`,
`README.md` and any index, plus migration-sequence files. Two clean auto-merges
of a lockfile still produce a broken tree.

## When to run it

- Before the first edit of a session, after `announce`.
- Before any rebase, fold or land.
- After a peer sends `landed`.
- After resolving a conflict, to confirm the prediction changed.

## Limits

| Limit | Consequence |
| --- | --- |
| A peer that never announced has no branch on record | It is invisible to the committed-collision table |
| Uncommitted work is invisible to git | Only the peer's declared `paths` cover it |
| `clean` is a prediction about the tips as they are now | Both tips move; re-run |
| Liveness comes from the process table | A crashed session lingers until `sweep` |

Run `agent-bus.sh sweep` when a peer row looks stale. It removes registry entries
whose process is gone, and their queues with them.
