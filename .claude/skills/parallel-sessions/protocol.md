# Protocol

- [Where the bus lives](#where-the-bus-lives)
- [Addressing a peer](#addressing-a-peer)
- [Message kinds](#message-kinds)
- [Resources](#resources)
- [Acknowledgement](#acknowledgement)
- [Delivery timing](#delivery-timing)
- [Resolving a collision](#resolving-a-collision)
- [Failure modes](#failure-modes)

## Where the bus lives

`$(git rev-parse --path-format=absolute --git-common-dir)/agent-bus`

| Property | Consequence |
| --- | --- |
| Every worktree of a repo resolves it identically | No session has to propose a path |
| It sits inside the git dir | Git never commits it, no branch carries it |
| It is not tied to a worktree layout | `.worktrees/`, `.claude/worktrees/` and sibling dirs all work |
| It is per-repo | Two repos never share a bus |

Derived, not negotiated. That single property removes the whole class of
channel-agreement failures.

## Addressing a peer

`send` accepts any of these, as long as it matches exactly one live peer:

| Form | Example |
| --- | --- |
| Branch name | `vermutungsdurchgang` |
| Session id prefix, 8 chars | `f2c8597d` |
| Full session id | `f2c8597d-04d2-…` |
| Worktree directory name | `plan-domain-graph` |

Ambiguous input is rejected with the candidate list. Prefer the branch name.

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

A shared database is the collision git will never warn you about. A test run that
falls through to a default port writes into a peer's cluster. Their measurements
are corrupted while both worktrees stay clean.

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
- The wake budget caps consecutive deliveries, so two sessions cannot ping-pong
  forever. It resets on every user prompt.

## Resolving a collision

1. Whoever finds it sends `conflict` with the paths and the merge prediction.
2. The session **closer to landing** keeps its base; the other rebases onto it.
   - Tie-break: fewer commits ahead of base rebases.
   - This rule is objective, so it needs no negotiation round.
3. The rebasing session confirms with `landed` or `answer` when it is done.
4. Neither session edits a file the other has claimed. Send the diff instead.
5. If both must write one file, one session owns it for the whole run.

## Failure modes

What this protocol exists to prevent, each observed in a real two-session run.

| Failure | Prevention |
| --- | --- |
| Two channels created independently, in different directories | The path is derived from the repo |
| Both sessions adopt the other's channel and swap instead of converging | Nothing to adopt |
| A tie-break invented under time pressure, on a false premise | No tie-break needed |
| A correction sent and never confirmed as read | Receipts, and `UNREAD` in `sent` |
| Polling, so the user has to prod both sides | Hooks push at turn end |
| A peer's test run writing into the other's database | Resource claims and the radar |
| Coordination stalling on an un-allowlisted command | The bus script is allowlisted |
