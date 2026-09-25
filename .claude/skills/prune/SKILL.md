---
name: prune
description: Cleans up before a session closes. Removes stale memories, scratchpads and plans, merged branches, removable worktrees and dangling Docker artefacts, then gives a close verdict. Use when the user asks whether all is done, cleaned up or safe to close.
argument-hint: "[all] [dry-run]"
---

# Prune

A user asking "all cleaned up?", "all pruned?" or "can I close this session?" invokes this skill. Three steps: persist, sweep, review. The answer ends with a close verdict.

- Never delete uncommitted work, unpushed commits, stashes or a dirty worktree. Git's own refusals are the guard; never force them.
- Skip every branch and worktree that this session or a live peer holds. `~/.claude/agent-bus.sh peers` lists the peers.
- Aged harness state under `~/.claude` belongs to the harness: `cleanupPeriodDays` sweeps it at launch. Delete there only memory files the review picked.
- Hard deletion, no trash. `dry-run` lists what each step would remove and applies nothing.

Scope: the current project and repo by default; `all` covers every project's memory and every repo under `~/r`. Docker is machine-wide in both.

## 1. Persist

Run steps 1–3 of [prog](../prog/SKILL.md) first: every state file then holds the verified status quo. Open steps and decisions land in the plan file, durable facts in memory. The scratchpad does not survive the close, so nothing may live only there.

## 2. Sweep

Runs without asking. Everything here is a cache, regenerable or already dead:

- Docker: dangling images, dangling build cache, unused networks.
- Git: stale worktree entries, remote-tracking refs of deleted remote branches.
- Agent bus: registrations of dead sessions (`agent-bus.sh sweep`).
- This session: finished loops, monitors, background shells and agents.

## 3. Review

Content, not age. Every finding carries target, cited evidence and a proposed action: delete, or update with the new text.

| Class | Finding |
| --- | --- |
| Memory | Index and files out of sync, duplicates, dead references. Claims the repo contradicts: partly true becomes an update. Events stored as memories: keep the residue, drop the event |
| Rule | Contradicted by the repo, names deleted files or tools, duplicates another surface, pins a stale version. Current repo only; propose per-rule edits |
| Scratchpad | This session's files once the session ends; other sessions' leftovers |
| Plan, PRD | Every box ticked, or the PRD shipped. One commit for all |
| Branch | Merged into the default branch, or squash-merged with the merged PR as evidence. Remote copies too |
| Worktree | Clean, and its branch qualifies as a branch finding |
| Container | Stopped: name, image, compose project, exit age |
| Volume | Unused: name, compose project, size. Named volumes often hold databases; say so |
| Image | Tagged, used by no container, with size |
| Durable cron | A scheduled job whose work is done |

With `all`, review each other project that has a local repo through one `opus` subagent. Projects without a repo get the memory index checks only.

Present all findings in one multi-select, one option per class batch listing its targets. Apply only the picks. A memory deletion removes the file and its index line together.

## 4. Close verdict

The session may close when all of these hold:

- `repo-status` lists nothing, or only work the user chose to keep.
- No job of this session is still running.
- Plan files and memory hold every open step and durable fact.

## Report

1. Sweep: one row per target with items and space freed, or would-be-freed.
2. Review: one bullet per finding, marked applied, skipped or kept.
3. Verdict: "Safe to close", or "Not yet" with each blocking item.
