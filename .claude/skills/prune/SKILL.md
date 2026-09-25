---
name: prune
description: Cleans up before a session closes. Sweeps aged session state, stale memories, scratchpads and plans, merged branches, removable worktrees and dangling Docker artefacts. Use when the user asks whether all is done, cleaned up or safe to close.
argument-hint: "[all] [<N>d] [dry-run]"
---

# Prune

A user asking "all cleaned up?", "all pruned?" or "can I close this session?" invokes this skill. Three steps: persist, sweep, review. The answer ends with a close verdict.

- Never delete uncommitted work, unpushed commits, stashes or a dirty worktree. Git's own refusals are the guard: no `--force` on `git worktree remove`.
- Skip every branch and worktree that this session or a live peer holds. `~/.claude/agent-bus.sh peers` lists the peers.
- Pruned transcripts are gone as `/reflect` evidence. Reflect first after a busy period.
- Hard deletion, no trash. `dry-run` previews every step and applies nothing.

## Arguments

| Argument | Meaning |
| --- | --- |
| none | Current project and repo, 7-day threshold |
| `all` | Every project slug, the global state classes, every repo under `~/r` |
| `<N>d` | Age threshold in days, minimum 1 |
| `dry-run` | Preview both layers; no deletion, no apply step |

Docker is machine-wide in every scope.

## 1. Persist

Run steps 1–3 of [prog](../prog/SKILL.md) first: every state file then holds the verified status quo. Open steps and decisions land in the plan file, durable facts in memory. The scratchpad does not survive the close, so nothing may live only there.

## 2. Sweep

Runs without asking. Everything here is a cache, regenerable or already dead.

| Target | Command | Preview for `dry-run` |
| --- | --- | --- |
| Session state | `prune-state.sh`, below | same script without `--delete` |
| Dangling images | `docker image prune -f` | `docker image ls -f dangling=true` |
| Dangling build cache | `docker builder prune -f` | `docker system df` |
| Unused networks | `docker network prune -f` | `docker network ls` |
| Stale worktree entries | `git worktree prune` | `git worktree prune --dry-run -v` |
| Deleted remote branches | `git fetch --prune` | `git fetch --prune --dry-run` |
| Dead bus registrations | `~/.claude/agent-bus.sh sweep` | `~/.claude/agent-bus.sh peers` |
| This session's jobs | stop finished loops, monitors, background shells and agents | `CronList`, task list |

Skip a row whose tool is absent. Run the session-state script from the skill's directory:

```bash
bash "${CLAUDE_SKILL_DIR}/prune-state.sh" --days <N> --scope <slug>|all [--exclude-session "$CLAUDE_CODE_SESSION_ID"] [--delete]
```

Never bypass it with ad-hoc `rm` on harness state. Its allowlist, verified against Claude Code 2.1.259:

| Class | Location | Scope |
| --- | --- | --- |
| `transcripts` | `~/.claude/projects/<slug>/<session-id>.jsonl` plus `<session-id>/`, deleted as one unit | project and `all` |
| `scratchpads` | `/tmp/claude-<uid>/<slug>/<session-id>/` | project and `all` |
| `file-history` | `~/.claude/file-history/<session-id>/` | `all` |
| `session-env` | `~/.claude/session-env/<session-id>/` | `all` |
| `tasks` | `~/.claude/tasks/<session-id>/` | `all` |
| `shell-snapshots` | `~/.claude/shell-snapshots/snapshot-*.sh` | `all` |
| `paste-cache` | `~/.claude/paste-cache/*.txt` | `all` |
| `debug-logs` | `~/.claude/debug/<session-id>.txt` | `all` |

Never touched: every `memory/` directory, settings and credentials, `plugins/`, `backups/`, `history.jsonl`, `sessions/`, and anything outside the table. The live session and the newest transcript per project are excluded. If the layout on this CLI version differs, list the directories and re-verify. Drift degrades to "nothing deleted".

## 3. Review

Content, not age. Every finding carries target, cited evidence and a proposed action: delete, or update with the new text.

| Class | Finding | Action |
| --- | --- | --- |
| Memory: orphaned-index, unindexed, duplicate, dead-reference | A `MEMORY.md` line without its file, a file without its line, two memories for one fact, a dead `[[name]]` or path | delete or merge |
| Memory: stale-claim | The repo contradicts the memory. The slug reversed is the repo path; match ambiguous slugs against the parent directory | update if partly true, else delete |
| Memory: expired-record | An event stored as a memory | write its residue into a keeper, then delete |
| Rule | Contradicted by the repo, names deleted files or tools, duplicates another surface, pins a stale version. Current repo only | per-rule edit |
| Scratchpad | This session's files, only when the session ends and step 1 is done | delete |
| Plan, PRD | Every box ticked, or the PRD shipped | delete, one commit |
| Branch | Merged into the default branch (`git branch --merged`), or squash-merged: a merged PR whose head is the branch tip | `git branch -d`; `-D` only with the PR as evidence |
| Remote branch | A merged branch still on `origin` | `git push origin --delete <branch>` |
| Worktree | Clean, and its branch qualifies as a branch finding | `git worktree remove <path>`, then the branch |
| Container | Stopped: name, image, compose project, exit age | `docker rm` |
| Volume | Unused: name, compose project label, size from `docker system df -v`. Named volumes often hold databases; say so | `docker volume rm` |
| Image | Tagged, no container uses it, with size | `docker image rm` |
| Durable cron | A `CronList` entry whose work is done | `CronDelete` |

With `all`, review other slugs that have a local repo through one `opus` subagent each. Slugs without a repo get the mechanical memory checks only.

Present all findings in one multi-select, one option per class batch listing its targets. Apply only the picks. A memory deletion removes the file and its index line together.

## 4. Close verdict

Run `repo-status` (`~/.local/bin/repo-status`). The session may close when all of these hold:

- `repo-status` lists nothing, or only work the user chose to keep.
- No job of this session is still running.
- Plan files and memory hold every open step and durable fact.

## Report

1. Sweep: one row per target with items and bytes freed, or would-be-freed.
2. Review: one bullet per finding, marked applied, skipped or kept.
3. Verdict: "Safe to close", or "Not yet" with each blocking item.
