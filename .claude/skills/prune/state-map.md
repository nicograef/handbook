# Agent State Map

What accumulates where, which classes `prune-state.sh` may delete, and what it
must never touch.

**As of 2026-08-01, Claude Code CLI 2.1.212 (dev machine).** The harness layout
is internal and drifts between CLI versions. **Drift rule:** when the layout on
a machine stops matching this map (locations missing, renamed, or differently
keyed), re-verify the layout by listing the directories, update this file and
its as-of line, and only then trust the allowlist again. Absent locations are
skipped silently by the script — drift degrades to "nothing deleted", never to
"wrong thing deleted".

The script reads its roots from two env-var defaults: `PRUNE_CLAUDE_DIR`
(default `~/.claude`) and `PRUNE_SCRATCH_DIR` (default `/tmp/claude-<uid>`,
`<uid>` via `id -u`). The fixture test redirects both to a throwaway tree.

## Mechanical classes (the allowlist)

Class names are stable — the script report, this map, and the skill report all
use them.

| Class | Location | Keyed by | Pruned in scope |
| --- | --- | --- | --- |
| `transcripts` | `~/.claude/projects/<slug>/<session-id>.jsonl` + `<session-id>/` | project + session | project scope (own slug) and `all` |
| `scratchpads` | `/tmp/claude-<uid>/<slug>/<session-id>/` | project + session | project scope (own slug) and `all` |
| `file-history` | `~/.claude/file-history/<session-id>/` | session | `all` only |
| `session-env` | `~/.claude/session-env/<session-id>/` | session | `all` only |
| `tasks` | `~/.claude/tasks/<session-id>/` | session | `all` only |
| `shell-snapshots` | `~/.claude/shell-snapshots/snapshot-*.sh` | age only | `all` only |
| `paste-cache` | `~/.claude/paste-cache/*.txt` | age only | `all` only |
| `debug-logs` | `~/.claude/debug/*.txt` | session (`<session-id>.txt`) | `all` only |

Rules the script applies on top of the allowlist:

- **Age** — mtime strictly older than `--days` days (default 7, minimum 1).
- **Transcript units** — a top-level `<session-id>.jsonl` and its same-id
  session directory are deleted as one unit, judged by the newer of the two
  mtimes. A session directory without a transcript (orphan) is judged by its
  own mtime. `<slug>` is the working directory with `/` replaced by `-`.
- **Session-id shape gate** — session entries are recognized only by UUID
  shape (`8-4-4-4-12` lowercase hex). Anything else in a walked directory —
  `memory/` above all — can never become a deletion candidate.
- **Live-session exclusion** — the session id passed via `--exclude-session`
  is skipped in every class; independently, the newest-mtime transcript in
  each project directory always survives (the no-id fallback).
- **Symlinks are never followed and never deleted** (e.g. `~/.claude/debug/latest`).

## Never touched

Hard exclusions — outside the allowlist by construction, listed here so a
reader does not have to infer them:

- every `~/.claude/projects/<slug>/memory/` directory (agent memory)
- `settings.json`, `settings.local.json`, `.credentials.json`
- `plugins/`, `backups/`, `history.jsonl`, `sessions/`, `daemon*`, `ide/`,
  `cache/`, `downloads/`, `jobs/`, `stats-cache.json`
- any top-level file in a project directory that is not a `<session-id>.jsonl`
- anything else outside the allowlist table above

The harness's built-in 90-day transcript cleanup is untouched — prune neither
reads nor modifies that setting; it stays as the backstop.

## Cross-references

- Transcript layout facts (top-level `*.jsonl` files are the transcripts,
  subdirectories are per-session working data, exclude the live session)
  agree with [../reflect/sources.md](../reflect/sources.md).
- Semantic prunability (memories, rules, repo leftovers) is a separate,
  always-gated layer — see [criteria.md](criteria.md).
