@AGENTS.md

<!-- Claude-only deltas. The canonical rules live in AGENTS.md (imported above). -->

## Searching

```bash
grep -r '<term>' .          # search across all files
find . -name '*.md'         # list all Markdown files
```

## On `/compact`

When compacting, preserve the list of files modified this session and the exact test or check
commands run (e.g. `make check`), so verification can resume without re-deriving them.

## Non-negotiables (survive compaction)

- Commit every completed task without asking, `main` included — no approval step.
- Never push to `main` / `master`; push feature branches only.
- Never `git push --force` / `-f` / `--force-with-lease` or `--no-verify`.
