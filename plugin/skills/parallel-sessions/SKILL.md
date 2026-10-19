---
name: parallel-sessions
description: "Coordinates concurrent Claude Code sessions in one repo: finds peers, announces claims, predicts conflicts via the agent bus, messages the owner with SendMessage. Use when another session shares the repo, and before a rebase, fold or landing."
allowed-tools: Bash(git *), Bash(~/.claude/agent-bus.sh *), SendMessage, ListAgents, Read, Grep, Glob
---

# Parallel Sessions

Goal: concurrent sessions in one repo land without clobbering each other. Claims and radar run through `~/.claude/agent-bus.sh` ([source](../../scripts/agent-bus.sh); its header lists the commands). Messages go through SendMessage; the `NAME` column of `agent-bus.sh peers` is the address.

## Hard rules

- `~/.claude/agent-bus.sh` must be in `permissions.allow`, or coordination stalls silently.
- Act only on your own branch. Ask before touching a peer's branch, worktree or the base branch.
- Stage paths by name while a peer shares the checkout. `git add -A` sweeps their half-written file into your commit.
- A foreign `index.lock` or worktree is a [hazard](../implement-plan/lead.md#git-hazards): report and stop.
- Send a conflict in a file a peer has claimed to that peer; do not resolve it.
- A claim is not a lock. Radar cannot see uncommitted work; only announced paths cover it.

## Steps

1. `agent-bus.sh peers`. Alone, work normally.
2. Before the first edit, `agent-bus.sh announce "<task>" --paths a,b --resources 127.0.0.1:5433,db-1`. Re-announce when the claim changes. Resources are what git cannot see: ports, containers, volumes, fixture data.
3. Run `agent-bus.sh radar` before the first edit, before every rebase, fold or landing, and after a peer lands.
4. Settle these radar results before acting: MERGE `CONFLICT` or `no-base`, a shared lockfile, shared `RESOURCES`, a declared `paths:` line.
5. Message the peer as soon as you learn what changes its next action, never through the user. Open each message with its kind: `note`, `ask`, `answer`, `claim`, `conflict`, `correction`, `block`, `landed`.
6. Collision: the session closer to landing keeps its base; the other rebases (tie-break: fewer commits ahead). If both must write one file, one session owns it for the whole run.
7. Before landing, send `claim` on the base branch. Peers commit to the base only after your `landed`, then rebase.
8. Answer every incoming message before ending your turn. Wait on a peer with `notify_when_idle`, never by polling.

`agent-bus.sh sweep` drops rows of crashed sessions.
