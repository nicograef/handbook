# Evidence Sources

Where to locate and read the evidence for each reflect scope beyond the current session. The
current-session default needs no lookup — the in-context conversation is the evidence, per
`SKILL.md` step 1.

## Past session transcripts (`last N sessions`)

### Locating transcripts

- **Directory** — `~/.claude/projects/<slug>/`, the same `<slug>` as the memory directory in
  [targets.md](targets.md).
- **Slug** — the absolute working directory with `/` replaced by `-`
  (e.g. `/home/nico/r/handbook` → `-home-nico-r-handbook`).
- **Sessions** — the top-level `*.jsonl` files, newest mtime first (`ls -t`).
- **Subdirectories** — ignore them; per-session working data, not transcripts.
- **Exclude the current session's own file** — its session id appears in harness-provided paths,
  e.g. the scratchpad directory name.
- **Id unknown** — exclude the newest-mtime file; it is the live transcript being appended to.
- **`last N sessions`** — the first N files after that exclusion.

### Cap or confirm

- Each transcript costs one subagent.
- **N > 5** — stop and confirm the fan-out with the user before launching.
- Never exceed the confirmed N.

### Subagent summarization

- **One subagent per transcript** — summarize each selected transcript in its own subagent.
- **Cheap model tier** — `sonnet` per the model-routing rules; the extraction is mechanical.
- **Contract** — the subagent reads the transcript file and returns exactly four parts:

1. problems and issues encountered
2. solutions found
3. notable insights
4. recurring friction

- **Synthesis** — the main agent synthesizes the summaries into the four-section report.

> **Anti-pattern:** never read a raw transcript JSONL whole into the main context.
> Session files reach hundreds of kilobytes. Only subagents read them, and only their
> four-part summaries come back.

### Defensive extraction (format drift)

Transcript JSONL is a harness-internal format that changes between CLI versions. Instruct the
summarizing subagent to:

- **Line by line** — process one line at a time; each is an independent JSON object.
- **Keep** known conversational content only: user messages and assistant text.
- **Skip** tool dumps, progress events, and other machinery.
- **Tolerate** unknown message types and unparseable lines silently.
- **Never fail** the summary over format drift.

### Copilot sessions

- GitHub Copilot keeps no locally readable session history on the dev machine.
- Transcript scope covers Claude Code sessions only.
- For work done in Copilot, use the git-history scope instead.

## Git history (`last N commits` | `<rev>..<rev>`)

- Works in any git repo on any machine.
- Touches only the repository — never `~/.claude/projects/` or other harness state.
- Needs no transcripts.

### Resolving the range

- **`last N commits`** → `HEAD~N..HEAD`.
- **Fewer than N commits** (`git rev-list --count HEAD`) — use the full history instead.
- **Explicit revision range** (e.g. `v1.2..HEAD`, `main..feature`) — passed to git verbatim.

### Gathering evidence

- **Overview** — `git log --stat <range>`: commit messages plus touched files.
- **Detail** — `git show <sha>` for commits the overview flags as interesting.
- **Interesting** — reverts, fixups, repeated touches of one file, "fix"/"actually"/"again"
  wording.

### Chunking large ranges

- Reuse the transcript summarization contract above.
- Split the range into chunks of roughly 10–20 commits.
- One subagent per chunk, cheap model tier, each returning the same four-part contract.
- Synthesize the returned summaries the same way.
- **Small ranges** (a handful of commits) — no subagents; read them directly.
