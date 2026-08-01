# Evidence Sources

How to locate and read the evidence for each reflect scope beyond the current
session (the current-session default needs no lookup — the in-context
conversation is the evidence, per `SKILL.md` step 1).

## Past session transcripts (`last N sessions`)

### Locating transcripts

- Directory: `~/.claude/projects/<slug>/` — the same `<slug>` as the memory directory
  in [targets.md](targets.md): the absolute working directory with `/` replaced by `-`
  (e.g. `/home/nico/r/handbook` → `-home-nico-r-handbook`).
- Sessions are the **top-level `*.jsonl` files**, newest mtime first (`ls -t`).
  Ignore subdirectories — per-session working data, not transcripts.
- **Exclude the current session's own file.** Its session id appears in harness-provided
  paths (e.g. the scratchpad directory name); if the id is unknown, exclude the
  newest-mtime file — it is the live transcript being appended to.
- `last N sessions` = the first N files after that exclusion.

### Cap or confirm

Each transcript costs one subagent. For **N > 5**, stop and confirm the
fan-out with the user before launching; never exceed the confirmed N.

### Subagent summarization

Summarize each selected transcript in its own subagent on a cheap model tier
(mechanical extraction — `sonnet` per the model-routing rules). The subagent
reads the transcript file and returns exactly the four-part contract:

1. problems and issues encountered
2. solutions found
3. notable insights
4. recurring friction

The main agent synthesizes the returned summaries into the four-section report.

> **Anti-pattern:** never read a raw transcript JSONL whole into the main
> context. Session files reach hundreds of kilobytes; only subagents read them,
> and only their four-part summaries come back.

### Defensive extraction (format drift)

Transcript JSONL is a harness-internal format that changes between CLI versions.
Instruct the summarizing subagent to:

- process the file line by line; each line is an independent JSON object
- keep only known conversational content (user messages, assistant text); skip tool
  dumps, progress events, and other machinery
- silently tolerate unknown message types and unparseable lines — never fail the
  summary over format drift

### Copilot sessions

GitHub Copilot keeps no locally readable session history on the dev machine
(verified 2026-07-20). Transcript scope covers Claude Code sessions only; for
work done in Copilot, use the git-history scope instead.

## Git history (`last N commits` | `<rev>..<rev>`)

Works in any git repo on any machine — this path touches only the repository,
never `~/.claude/projects/` or other harness state, so it needs no transcripts.

### Resolving the range

- `last N commits` → `HEAD~N..HEAD`. If the repo has fewer than N commits
  (`git rev-list --count HEAD`), use the full history instead.
- An explicit revision range (e.g. `v1.2..HEAD`, `main..feature`) is passed to git
  verbatim.

### Gathering evidence

- Overview: `git log --stat <range>` — commit messages plus touched files.
- Detail: `git show <sha>` for commits the overview flags as interesting (reverts,
  fixups, repeated touches of the same file, "fix"/"actually"/"again" wording).

### Chunking large ranges

Reuse the transcript summarization contract above: split the range into chunks of
roughly 10–20 commits, one subagent per chunk (cheap model tier), each returning
the same four-part contract, synthesized the same way. Small ranges (a handful of
commits) need no subagents — read them directly.
