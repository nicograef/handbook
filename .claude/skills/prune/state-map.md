# Agent State Map

What accumulates where, which classes `prune-state.sh` may delete, and what it
must never touch.

- **Verified against Claude Code CLI 2.1.258 (dev machine).**
- **Internal layout** — it drifts between CLI versions.
- **Drift rule** — a machine on another CLI version re-verifies by listing the directories.
- **Drift signs** — locations missing, renamed, or differently keyed.
- **After re-verifying** — update this file's pinned CLI version, then trust the allowlist again.
- **Absent locations** — skipped silently by the script.
- **Failure mode** — drift degrades to "nothing deleted", never to "wrong thing deleted".

The script reads its roots from two env-var defaults:

- `PRUNE_CLAUDE_DIR` — default `~/.claude`.
- `PRUNE_SCRATCH_DIR` — default `/tmp/claude-<uid>`, `<uid>` via `id -u`.
- **Fixture test** — redirects both to a throwaway tree.

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

- **Age** — mtime strictly older than `--days` days (required, minimum 1). The
  7-day default belongs to the skill's argument parsing (`prune/SKILL.md`), not the script.
- **Transcript units** — a top-level `<session-id>.jsonl` and its same-id session directory are
  deleted as one unit.
- **Unit mtime** — judged by the newer of the two mtimes.
- **Orphan** — a session directory without a transcript is judged by its own mtime.

## Never touched

Hard exclusions — outside the allowlist by construction, listed here so a
reader does not have to infer them:

- every `~/.claude/projects/<slug>/memory/` directory (agent memory)
- `settings.json`, `settings.local.json`, `.credentials.json`
- `plugins/`, `backups/`, `history.jsonl`, `sessions/`, `daemon*`, `ide/`,
  `cache/`, `downloads/`, `jobs/`, `stats-cache.json`
- any top-level file in a project directory that is not a `<session-id>.jsonl`
- anything else outside the allowlist table above

The harness's transcript cleanup (`cleanupPeriodDays`, 90 in `claude/settings.json`; harness
default 30) is untouched. Prune neither reads nor modifies that setting; it stays as the backstop.

## Cross-references

- Semantic prunability (memories, rules, repo leftovers) is a separate,
  always-gated layer — see [criteria.md](criteria.md).
