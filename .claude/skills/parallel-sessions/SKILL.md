---
name: parallel-sessions
description: >-
  Coordinates concurrent Claude Code sessions working in one repository.
  Discovers live peer sessions and their worktrees, publishes what this session
  claims, predicts merge conflicts and resource collisions, and exchanges
  messages with peers directly instead of through the user. Use when another
  session or worktree is active in the repo, before rebasing, folding or landing
  a branch, or when a phase depends on work another session owns.
allowed-tools: Bash, Read, Grep, Glob
---

# Parallel Sessions

Two sessions in one repo collide on files, on branches, and on things git cannot
see. This skill makes them talk to each other, not to the user.

The transport is [scripts/agent-bus.sh](../../../scripts/agent-bus.sh), reachable
as `~/.claude/agent-bus.sh`. Its details are in
[protocol.md](protocol.md); the detection commands are in [radar.md](radar.md).

## Workflow

1. **Discover before you plan.**

   ```bash
   ~/.claude/agent-bus.sh peers
   ```

   - Empty output means you are alone; stop here and work normally.
   - Any peer means every later step applies.

2. **Announce before your first edit.**

   - Declare the paths you will write and the resources you will hold.
   - Resources are ports, database clusters, containers — see
     [protocol.md](protocol.md#resources).

   ```bash
   ~/.claude/agent-bus.sh announce "phase 6: domain graph" \
     --paths "src/graph,docs/architecture.md" \
     --resources "127.0.0.1:5433,myproject-db-1" \
     --needs "phase-3" --provides "phase-6"
   ```

   - Re-announce whenever the claim changes. Omitted flags keep their old value.

3. **Read the radar before every integration point.**

   ```bash
   ~/.claude/agent-bus.sh radar
   ```

   - Run it before a rebase, before a fold, before landing, and after a peer lands.
   - How to read each column: [radar.md](radar.md).

4. **Message the peer that owns the problem.**

   - Send the moment you find something that changes their next action.
   - Do not wait for a checkpoint, and do not route through the user.

   ```bash
   ~/.claude/agent-bus.sh send <branch-or-id> "0012 is scope_device_id, not 0013." --kind correction
   ```

5. **Confirm delivery.**

   ```bash
   ~/.claude/agent-bus.sh sent
   ```

   - `UNREAD` means the peer has not seen it; an unread correction is not a
     correction.
   - A busy peer reads at the end of its current turn. An idle peer reads on its
     next prompt.

6. **Answer what arrives.** Messages appear in your context on their own.

   - Reply before you finish your turn, even if the reply is "no action needed".
   - Silence is what forced the user to relay messages by hand.

7. **Resolve, then land one at a time.**

   - Negotiate per [protocol.md](protocol.md#resolving-a-collision).
   - Landing order is agreed over the bus before anyone rebases.

## Constraints

- **Never propose or invent a coordination channel.** The bus path is derived
  from the repo, so both sides compute the same one.
  - Two sessions that each adopt the other's proposal have swapped channels, not
    converged. This has happened; see [protocol.md](protocol.md#failure-modes).
- **Act only on your own branch.** Free without asking: messaging, answering,
  rebasing your own branch, reordering your own remaining work, waiting.
- **Ask the user before touching a peer's branch, a peer's worktree, or the base
  branch.**
- **Never resolve a conflict in a file a peer has claimed** — send them the
  conflict instead.
- **Never clear another session's state**: its `index.lock`, its worktree, its
  `refs/agent-lock/*`. Report and stop.
- **A claim is not a lock.** It tells a peer where you will be, so they route
  around you.
- Hazardous git commands are listed in
  [../implement-plan/integration.md](../implement-plan/integration.md#hazards)
  and apply unchanged here.

## Output style

Messages to a peer are prose another agent must act on. They follow the
[output style contract](../output-style.md): lead with the action, one claim per
sentence, table before list before paragraph.
