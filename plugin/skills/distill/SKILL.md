---
name: distill
description: "Shrinks a repo's prose (Markdown, comments) by re-deriving it from a blank slate and splitting survivors, then applies. \"verify\" fact-checks docs against code, commands and upstream. Triggers: distill, too much documentation, verify docs."
argument-hint: "[verify] [path ...] [plan-only] [since <ref>] [report-only]"
---

# Distill

Keep only what a reader cannot get anywhere else. Ask of every line: with no docs, would I write this today? With `verify` as the first argument, run the Verify section instead.

## Hard rules

- Start on a clean working tree; git is the only undo. No archive directories, no `.old` copies.
- Never invent, alter or "correct" a fact, command, flag, path or version from memory. Keep it, delete it, or flag it.
- A claim you cannot verify this session is FLAG, not DELETE. Deleting what you failed to understand is this skill's main damage.
- Agent instruction surfaces (`AGENTS.md`, `CLAUDE.md`, `.claude/rules/*`, `.claude/agents/*`) restate the obvious by design. Cut from them only what is false or duplicated.
- Legal and compliance text stays. Generated docs are fixed at the generator. Code stays; only comments and docstrings are in scope.
- Code quality is `/simplify`; agent state is `/nico:prog`.

## Distill

1. Inventory every prose file and comment-heavy source in scope; the line count is the before-number.
2. Read each file in full against the lenses below; fan out to read-only `opus` reviewers on a large corpus. Every cut names what supersedes or duplicates it.
3. Cross-file pass yourself: one canonical home per duplicated claim. Two docs that disagree are the top finding; the code decides, else FLAG both.
4. Infer who reads which files from the repo; the audience sets the keep-bar.
5. `plan-only` commits the plan as `docs/plans/plan-distill-<scope>.md` and stops.
6. Apply. Then `grep -r` every deleted or renamed name, fix each hit, and run `make check`.
7. Commit `docs: distill <scope>` with every FLAG as `file:line` in the body; the next session inherits it. Report before → after lines.
8. Name `/nico:distill verify` in a fresh session as the final phase. A session cannot audit its own output.

What dies:

- Historic residue: "previously", session records, finished migration guides, dated status. A still-operative constraint stays.
- Derivable: listings and inventories that mirror a Makefile, `--help`, config or signatures. Link the source instead.
- Common knowledge for the audience, docs for unbuilt features, ceremonial sections, padding.
- Comments that restate code or type. Contracts the type cannot express stay: units, ownership, side effects.

What survives: non-derivable why, facts that exist nowhere else, sharp edges, ordering, irreversible command sequences, constraints.

Split only after deleting, on the reader's question (`deploy.md`, `rollback.md`). A `misc.md` means the boundary is wrong. A file that is only links means the split went too far.

## Verify

Decide whether each claim is true, not whether it should stay; distill decisions stay closed. The default scope is the whole corpus. `since <ref>` narrows it; `report-only` edits and commits nothing.

- Nothing is settled without an artifact from this session: `path:line`, command stdout, or a fetched URL with its date. Training data is not a source.
- Read-only commands only: `--help`, `--version`, `--dry-run`, `make -n`, validators. A claim needing the real thing is UNREACHED.
- The dev machine is not the target host. A local version says nothing about a server or a CI image.
- A pinned older version is a decision, not staleness; check the lockfile or CI config.
- A claim about a template is checked against the template, not the repo's instance of it.

1. Run the repo's checks and record HEAD. Read the distill commit's FLAGs; report each by name.
2. Extract falsifiable claims and settle each on `opus`: TRUE, FALSE, STALE or UNREACHED.
3. About this repo, code wins. About a third-party tool, upstream wins via `nico:web-researcher`. A doc never verifies a doc.
4. Fix FALSE and STALE with the smallest edit to a verified value; with none, delete the claim. Code wrong while the doc is right is a repo finding.
5. If fixes plus deletions pass about a tenth of the claims, stop and ask. A wrong baseline (branch, host, submodule) is likelier than rot.
6. Report counts, each fix as `file:line` was → now with its artifact, and every UNREACHED with its reason.
7. Commit `docs: correct <scope> against verified sources`.
