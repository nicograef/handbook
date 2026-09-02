# Protocol

- The bus script (`agent-bus.sh`) must be in `permissions.allow`, or
  coordination stalls silently.
- Prefer the branch name when addressing a peer with `send`.

## Message kinds

Pass with `--kind`. The kind tells the peer how urgently to act.

| Kind | Meaning | Peer's expected response |
| --- | --- | --- |
| `note` | Context they should have | None required |
| `ask` | You need an answer to proceed | Answer, or say when you can |
| `answer` | Reply to an `ask` | None |
| `claim` | You are taking a path or resource | Route around it, or object |
| `conflict` | Your branches collide | Agree who rebases onto whom |
| `correction` | Something they believe is wrong | Confirm they have applied it |
| `block` | You are stopped until they act | Unblock, or say it will not happen |
| `landed` | You put something on the base branch | Rebase before your next commit |

## Resources

Path claims cover git. Resource claims cover what git cannot see.

- Database clusters and their ports — `127.0.0.1:5433`, `myproject-db-1`
- Dev servers and their ports
- Containers, volumes and fixture datasets
- Anything a test suite writes to outside the worktree

## Acknowledgement

- A message is delivered when the recipient drains it, which writes a receipt.
- `agent-bus.sh sent` shows `read` or `UNREAD` per message, with the read time.
- A read time far behind your send time means the peer acted on stale context.
- Treat `UNREAD` as undelivered. Do not assume a correction landed because you
  sent it.
- Acks are receipts, not messages: they never wake the sender.

## Delivery timing

| Peer state | When it sees your message |
| --- | --- |
| Busy in a turn | At the end of that turn, via the Stop hook |
| Idle at the prompt | On the user's next prompt |
| Starting or resuming | Immediately, via the SessionStart hook |

- Nothing polls. The hooks push.
- A session that would go idle with mail waiting keeps working instead.

## Resolving a collision

1. Whoever finds it sends `conflict` with the paths and the merge prediction.
2. The session **closer to landing** keeps its base; the other rebases onto it.
   - Tie-break: fewer commits ahead of base rebases.
   - This rule is objective, so it needs no negotiation round.
3. The rebasing session confirms with `landed` or `answer` when it is done.
4. Neither session edits a file the other has claimed. Send the diff instead.
5. If both must write one file, one session owns it for the whole run.

## Radar

What `agent-bus.sh radar` computes, and how to act on each result.

| Result | Action |
| --- | --- |
| `OVERLAP 0`, `MERGE clean` | Proceed |
| `OVERLAP > 0`, `MERGE clean` | Proceed, but re-run before landing — clean now is not clean later |
| `MERGE CONFLICT` | Send `conflict` and settle the rebase order before touching anything |
| A lockfile or index file in `SHARED PATHS` | Treat as a conflict even when `clean` |
| `RESOURCES` non-empty | Stop and settle ownership before running tests |
| `(no live peer branch to compare against)` | You are alone on git; declared claims may still collide |

Choke files deserve the extra caution: lockfiles, `go.mod`, `package.json`,
`README.md` and any index, plus migration-sequence files. Two clean auto-merges
of a lockfile still produce a broken tree.

`merge-tree` writes an object, never a ref, an index or a working file — safe
mid-rebase.

### Limits

| Limit | Consequence |
| --- | --- |
| A peer that never announced has no branch on record | It is invisible to the committed-collision table |
| Uncommitted work is invisible to git | Only the peer's declared `paths` cover it |
| `clean` is a prediction about the tips as they are now | Both tips move; re-run |
| Liveness comes from the process table | A crashed session lingers until `sweep` |

Run `agent-bus.sh sweep` when a peer row looks stale. It removes registry
entries whose process is gone, and their queues with them.
