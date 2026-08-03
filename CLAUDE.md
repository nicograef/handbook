@AGENTS.md

<!-- Claude-only deltas. The canonical rules live in AGENTS.md (imported above). -->

## On `/compact`

Preserve so verification resumes without re-deriving:

- The list of files modified this session.
- The exact test or check commands run (e.g. `make check`).

## Non-negotiables (survive compaction)

- Commit every completed task without asking, `main` included — no approval step.
- Never push to `main` / `master`; push feature branches only.
- Never `git push --force` / `-f` / `--force-with-lease` or `--no-verify`.
