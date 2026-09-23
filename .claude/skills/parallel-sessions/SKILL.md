---
name: parallel-sessions
description: Coordinates concurrent Claude Code sessions in one repo through the agent bus: discovers peers, announces claims, predicts conflicts, messages the owning session. Use when another session shares the repo, and before a rebase, fold or landing.
allowed-tools: Bash(git *), Bash(~/.claude/agent-bus.sh *), Read, Grep, Glob
---

# Parallel Sessions

Transport: `~/.claude/agent-bus.sh` (source: `scripts/agent-bus.sh`; its usage header lists every command). It must be in `permissions.allow`, or coordination stalls silently. The bus path is derived from the repo's common git dir, so both sides compute the same one. Never propose a channel.

## Hard rules

- Act only on your own branch. Free without asking: messaging, rebasing your own branch, reordering your own work, waiting. Ask before touching a peer's branch, worktree or the base branch.
- Stage paths by name while a peer shares the checkout. `git add -A` sweeps their half-written file into your commit silently; the index is per worktree, not per session.
- Send a conflict in a file a peer has claimed to that peer; do not resolve it.
- Never clear another session's `index.lock` or worktree. Report and stop.
- A claim is not a lock; it tells the peer where you will be.
- Messages are prose another agent acts on: action first, one claim per sentence.

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

4. `agent-bus.sh send <branch> "<text>" --kind <kind>` the moment you learn something that changes a peer's next action; never route it through the user.

   | Kind | Peer's response |
   | --- | --- |
   | `note` | none |
   | `ask` / `answer` | answer, or say when |
   | `claim` | route around it or object |
   | `conflict` | agree who rebases onto whom |
   | `correction` | confirm it is applied |
   | `block` | unblock, or say it will not happen |
   | `landed` | rebase before the next commit |

5. `agent-bus.sh sent` shows `read` or `UNREAD` per message. `UNREAD` is undelivered: do not assume a correction landed. Delivery happens at the peer's turn end (Stop hook), next prompt, or session start; nothing polls.
6. Answer what arrives before ending your turn, even with "no action needed".
7. Collision: the session closer to landing keeps its base, the other rebases (tie-break: fewer commits ahead). The rebasing session confirms with `landed`. If both must write one file, one session owns it for the whole run.
8. A session about to land a group sends `claim` on the base branch. A peer then commits to the base only after `landed`. A commit in between costs the lander a rebase and a re-gate.

Liveness comes from the process table; `agent-bus.sh sweep` drops rows of crashed sessions. Uncommitted work is invisible to radar; only declared paths cover it.
