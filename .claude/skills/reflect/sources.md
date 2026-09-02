# Evidence Sources

Where to locate and read evidence for each reflect scope beyond the current session.
The current-session default needs no lookup, per `SKILL.md` step 1.

## Past session transcripts (`last N sessions`)

### Locating transcripts

- **Directory** — `~/.claude/projects/<slug>/`, the same `<slug>` as the memory directory in
  [targets.md](targets.md).
- **Sessions** — the top-level `*.jsonl` files, newest mtime first (`ls -t`); subdirectories are
  per-session working data.
- **Exclude the current session's own file** — its id appears in harness-provided paths, e.g.
  the scratchpad directory name. If the id is unknown, exclude the newest-mtime file instead —
  the live transcript being appended to.
- **`last N sessions`** — the first N files after that exclusion. Each transcript costs one
  subagent; **N > 5** stops for user confirmation before launching, and the confirmed N is never
  exceeded.

### Subagent summarization

- **One subagent per transcript**, `sonnet` per the model-routing rules.
  It reads the transcript and returns exactly four parts — problems and issues, solutions found,
  notable insights, recurring friction.
- **Synthesis** — the main agent synthesizes the summaries into the four-section report.

> **Anti-pattern:** never read a raw transcript JSONL whole into the main context.
> Session files reach hundreds of kilobytes; only subagents read them and return summaries.

### Defensive extraction (format drift)

Transcript JSONL is a harness-internal format that changes between CLI versions.
Process one line at a time; keep only user and assistant text, skip tool dumps.
Tolerate unparseable lines without failing the summary.

- GitHub Copilot keeps no locally readable session history; transcript scope covers Claude Code
  sessions only. For work done in Copilot, use the git-history scope instead.

## Git history (`last N commits` | `<rev>..<rev>`)

- **Look for** — reverts, fixups, repeated touches of one file, and "fix"/"actually"/"again"
  wording in `git log --stat <range>`.
- **Large ranges** — chunk into roughly 10–20 commits per subagent, same four-part contract as
  transcripts. More than 5 chunks needs the same fan-out confirmation as sessions.
