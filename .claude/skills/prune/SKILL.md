---
name: prune
description: Deletes agent state. A mechanical sweep removes session state older than a threshold via an allowlist-only script; a gated review proposes stale memories, outdated rules and repo leftovers with cited evidence. Hard deletion, no trash.
argument-hint: "[all] [<N>d] [dry-run]"
disable-model-invocation: true
---

# Prune

Two layers. The mechanical sweep deletes without asking when the user invoked `/prune`; `dry-run` previews. The semantic review deletes nothing without a pick. Pruned transcripts are gone as `/reflect` evidence, so reflect first after a busy period.

## Arguments

| Argument | Meaning |
| --- | --- |
| none | Current project, 7-day threshold, delete |
| `all` | Every project slug plus the global classes |
| `<N>d` | Age threshold in days, minimum 1 |
| `dry-run` | Preview both layers; no deletion, no apply step |

## Mechanical sweep

Run the bundled script from the skill's directory with an explicit interpreter; the plugin cache may drop the execute bit. Pass `--delete` unless `dry-run`:

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

Never touched: every `memory/` directory, settings and credentials, `plugins/`, `backups/`, `history.jsonl`, `sessions/`, and anything outside the table. The live session and the newest transcript per project are excluded. If the layout on this CLI version differs from the table, re-verify by listing the directories first. Drift degrades to "nothing deleted".

## Semantic review

Content, not age. Every finding carries target, class, cited evidence and a proposed action (delete, or update with the new text).

| Class | Finding |
| --- | --- |
| Memory: orphaned-index, unindexed, duplicate, dead-reference | A `MEMORY.md` line without its file, a file without its line, two memories for one fact, `[[name]]` or paths that do not exist. No repo needed |
| Memory: stale-claim | The repo (slug reversed to a path; ambiguous slugs are matched against the parent directory) contradicts the memory. Partially stale becomes an update, not a deletion |
| Memory: expired-record | An event stored as a memory. Write its residue into a keeper first, then delete |
| Rule | A rule the current repo contradicts, references deleted files or tools, duplicates another surface, or pins a stale version. Current repo only; propose per-rule edits, never a rewrite of a surface |
| Repo leftover | Plan files with every box ticked, shipped PRDs, clean worktrees and local branches merged into the default branch, scratch files. Uncommitted work is never proposed |

With `all`, review other slugs that have a local repo through one `opus` subagent each. Slugs without a repo get the mechanical memory checks only.

Present all findings in one multi-select (batched by class when too many); apply only the picks. A memory deletion removes the file and its index line together. Repo-leftover deletions land in the working tree and are committed as one commit.

## Report

1. Mechanical: one row per class with files and bytes deleted, or would-be-deleted.
2. Kept: live session, entries under the threshold, memory directories.
3. Semantic: one bullet per finding, marked proposed, applied or skipped.
