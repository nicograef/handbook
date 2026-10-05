---
name: parallel-sessions
description: Coordinates concurrent Claude Code sessions in one repo: finds peers, announces claims, predicts conflicts via the agent bus, messages the owner with SendMessage. Use when another session shares the repo, and before a rebase, fold or landing.
allowed-tools: Bash(git *), Bash(~/.claude/agent-bus.sh *), SendMessage, ListAgents, Read, Grep, Glob
---

# Parallel Sessions

Claims and radar: `~/.claude/agent-bus.sh` (source: `scripts/agent-bus.sh`; its usage header lists every command). It must be in `permissions.allow`, or coordination stalls silently. The bus path is derived from the repo's common git dir, so both sides compute the same one.

Messages: native SendMessage. ListAgents lists every session on the machine; `agent-bus.sh peers` narrows that to this repo. Its `NAME` column is the SendMessage address.

## Hard rules

- Act only on your own branch. Free without asking: messaging, rebasing your own branch, reordering your own work, waiting. Ask before touching a peer's branch, worktree or the base branch.
- Stage paths by name while a peer shares the checkout. `git add -A` sweeps their half-written file into your commit silently; the index is per worktree, not per session.
- Send a conflict in a file a peer has claimed to that peer; do not resolve it.
- Never clear another session's `index.lock` or worktree. Report and stop.
- Never ask a peer to run what your own permissions blocked. Route it to the user.
- A claim is not a lock; it tells the peer where you will be.
- Messages are prose another agent acts on: action first, one claim per sentence. The first line is the only preview, so it carries the kind and the action.
- The receiver reads text literally: an `@path` attaches nothing. Send the content itself.

## Workflow

1. `agent-bus.sh peers`. Alone you work normally.
2. `agent-bus.sh announce "<task>" --paths a,b --resources 127.0.0.1:5433,db-1 --needs phase-3 --provides phase-6` before the first edit. Re-announce when the claim changes; omitted flags keep their value. Resources are what git cannot see: ports, containers, volumes, fixture data.
3. `agent-bus.sh radar` before the first edit, before every rebase, fold or landing, after a peer lands, and after resolving a conflict.

   | Radar result | Action |
   | --- | --- |
   | `OVERLAP 0`, `MERGE clean` | Proceed |
   | `OVERLAP > 0`, `MERGE clean` | Proceed; re-run before landing |
   | `MERGE CONFLICT` | Send `conflict`, settle the order before touching anything |
   | A lockfile or index in `SHARED PATHS` | Treat as a conflict even when clean |
   | `RESOURCES` non-empty | Settle ownership before running tests |

4. SendMessage the peer by name as soon as you learn what changes its next action. Never route it through the user. Open the first line with the kind.

   | Kind | Peer's response |
   | --- | --- |
   | `note` | none |
   | `ask` / `answer` | answer, or say when |
   | `claim` | route around it or object |
   | `conflict` | agree who rebases onto whom |
   | `correction` | confirm it is applied |
   | `block` | unblock, or say it will not happen |
   | `landed` | rebase before the next commit |

5. A successful send reached the session, not its reader. A peer in another permission mode holds the message for its user. A `[Cross-session delivery notice]` reports a held or refused message; silence is never agreement.
6. To wait for a peer, send with `notify_when_idle: true`; omit `message` for a pure subscription. One idle notice arrives. Never poll ListAgents or ask "are you done?".
7. Answer what arrives before ending your turn, even with "no action needed". Reply to a `<cross-session-message>` by copying its `from` as your `to`.
8. Collision: the session closer to landing keeps its base, the other rebases (tie-break: fewer commits ahead). The rebasing session confirms with `landed`. If both must write one file, one session owns it for the whole run.
9. A session about to land a group sends `claim` on the base branch. A peer then commits to the base only after `landed`. A commit in between costs the lander a rebase and a re-gate.

A subagent's send goes out under its parent session's address, and replies reach the parent. `notify_when_idle` works from the main conversation only.

Liveness comes from the process table; `agent-bus.sh sweep` drops rows of crashed sessions. Uncommitted work is invisible to radar; only declared paths cover it.
