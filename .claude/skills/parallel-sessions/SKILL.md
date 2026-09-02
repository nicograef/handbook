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

The transport is [scripts/agent-bus.sh](../../../scripts/agent-bus.sh), reachable
as `~/.claude/agent-bus.sh`. Its details are in
[protocol.md](protocol.md).

## Workflow

1. **Discover before you plan.**

   ```bash
   ~/.claude/agent-bus.sh peers
   ```

   - `agent-bus.sh peers` prints `No other live session is working in this
     repo.` when alone; stop here and work normally.
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

   - Run it before the first edit (after `announce`), before a rebase, fold,
     or landing, and after a peer lands.
   - Also after resolving a conflict, to confirm the prediction changed.
   - How to read each column: [protocol.md](protocol.md#radar).

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

   - `UNREAD` and delivery timing: [protocol.md](protocol.md#acknowledgement).

6. **Answer what arrives.** Messages appear in your context on their own.

   - Reply before you finish your turn, even if the reply is "no action needed".

7. **Resolve, then land one at a time.**

   - Negotiate per [protocol.md](protocol.md#resolving-a-collision).
   - Landing order is agreed over the bus before anyone rebases.

## Constraints

- **Never propose or invent a coordination channel.** The bus path is derived
  from the repo, so both sides compute the same one.
  - Two sessions that each adopt the other's proposal have swapped channels, not
    converged.
- **Act only on your own branch.** Free without asking: messaging, answering,
  rebasing your own branch, reordering your own remaining work, waiting.
- **Ask the user before touching a peer's branch, a peer's worktree, or the base
  branch.**
- **Never resolve a conflict in a file a peer has claimed** — send them the
  conflict instead.
- **Never `git add -A` or `git add .` while a peer shares the checkout.** Stage
  the paths you changed, by name.
  - A repo-wide add stages a peer's file mid-edit, and their half-written work
    lands under your commit message.
  - The index is per repository, not per session — a claim does not fence it.
  - It succeeds silently: no conflict, no warning, and the diff looks like yours.
  - Swept a peer's work already? Tell them what moved and under which sha.
  - Do not rewrite the commit to undo it: the content is safe, and only the
    message is wrong.
- **Never clear another session's state**: its `index.lock`, its worktree, its
  `refs/agent-lock/*`. Report and stop.
- **A claim is not a lock.** It tells a peer where you will be, so they route
  around you.
- Hazardous git commands are listed in
  [../implement-plan/integration.md](../implement-plan/integration.md#hazards)
  and apply unchanged here.
- Messages to a peer are prose another agent must act on.
  Follow the [output style contract](../output-style.md): lead with the
  action, one claim per sentence, table before list before paragraph.
