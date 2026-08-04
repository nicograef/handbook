---
name: prune
description: >-
  Cleans accumulated agent state in two layers: an ungated mechanical sweep
  that deletes session state older than a threshold (transcripts, session
  caches, scratchpads) via a bundled allowlist-only script, and a gated
  semantic review that proposes stale memories, outdated rules, and repo
  leftovers for deletion or update with cited evidence. Deletion is hard — no
  archive or trash; the chat report is the only record.
argument-hint: "[all] [<N>d] [dry-run]"
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - AskUserQuestion
  - Agent
---

# Prune

Retire agent state in two layers.

- **Mechanical** — deletes aged session state without asking, by explicit design. `dry-run` is
  the escape hatch.
- **Semantic** — proposes judgment-based deletions behind a multi-select gate.

## Workflow

### 1. Parse arguments

Argument: $ARGUMENTS — the parts combine freely:

| Argument | Meaning |
| --- | --- |
| (none) | current project, 7-day threshold, delete |
| `all` | every project slug plus the global session-state classes |
| `<N>d` (e.g. `30d`) | age-threshold override in days (minimum 1) |
| `dry-run` | preview only, both layers: mechanical report without deleting, semantic findings without the apply step |

### 2. Resolve context

- **Live session id** — `$CLAUDE_CODE_SESSION_ID` from the session environment.
- **If unset** — proceed without it.
- **No-id fallback** — the script always keeps the newest-mtime transcript per project.

### 3. Mechanical sweep (ungated)

Run the bundled script via the skill's base directory with an explicit interpreter:

```bash
bash <skill-base-dir>/prune-state.sh --days <N> --scope <slug-or-all> \
  --exclude-session "$CLAUDE_CODE_SESSION_ID" --delete
```

- Never use an absolute handbook path.
- Never rely on the execute bit — the plugin cache may not preserve it.
- Pass `--delete` unless `dry-run` was given — do not ask first.
- The mechanical classes are age-rule-decidable by design.
- What the script may touch, and everything it never touches, is in [state-map.md](state-map.md).
- If the machine's layout stops matching the state map, stop and re-verify per its drift rule
  before trusting the sweep.
- Never bypass the script with ad-hoc `rm` on harness state.
- Parse the `MODE` / per-class / `total` lines for the report (step 7).

### 4. Semantic review — collect findings

Review the three classes per [criteria.md](criteria.md). Every finding carries class, target,
cited evidence, and proposed action: delete or update.

- **`--days` governs the mechanical sweep only** — it never reaches memories, rules, or repo
  leftovers.
- **This layer judges content, not age** — a memory can be obsolete the day it is written.

### 5. Gate — multi-select

- Present all findings in one multi-select.
- **Tool** — a structured question tool if the surface has one.
- **Fallback** — the formatted options in
  [../clarify/question-rules.md](../clarify/question-rules.md).
- **Each option** shows class, target, evidence, and proposed action.
- **Overflow** — batch across rounds grouped by class when findings exceed the tool's capacity.
- **Zero picks** — selecting nothing stays a valid outcome in every round.

### 6. Apply picked items only

- **Memory deletion** — removes the file **and** its `MEMORY.md` index line together.
- **Memory update** — edits the file in place.
- **Rule updates/deletions** — edit the instructions surface.
- **Leftover deletions** — land in the working tree only.
- **Unpicked findings** — skipped and reported as such.
- **Zero picks** — no semantic writes.

### 7. Report

One chat report, in this order:

1. **Counts** — e.g. `3 findings — 1 applied, 2 skipped`.
2. **Mechanical** — a table, one row per class: files and bytes deleted, or would-be-deleted in
   dry-run.
3. **Kept and why** — live session (id or newest-mtime fallback), entries younger than the
   threshold, memory directories (never touched).
4. **Semantic** — one bullet per finding, bold keyword first: proposed, picked (applied), or
   skipped.
5. **Skip reason** — declined, dry-run, or ambiguous.
6. **Zero findings** — one line, no padding.
7. **Reflect pairing** — **pruned transcripts are gone as reflection evidence — run `/reflect`
   before the first prune of a busy period.**

## Constraints

- Pruning is a deliberate, destructive ritual — never suggested mid-task.
- The model may invoke this skill.
- **Confirm intent** before the mechanical sweep when the user did not explicitly ask to prune.
- That sweep deletes on its own.
- Pruned transcripts cannot be recovered.
- **Gated** — nothing judgment-based is deleted or updated without a pick in the multi-select.
- **Uncommitted work** — never proposed for deletion.
- **Commit the repo-leftover deletions** once applied — one commit, only the picked items.
- **Agent-state deletions** live outside version control and leave nothing to commit.

## Quality

- Run the shared [self-review checklist](../quality.md) on every applied item before presenting
  the result.
- Format the report per the [output style contract](../output-style.md).
