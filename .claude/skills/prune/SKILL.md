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
disable-model-invocation: true
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

Retire agent state. The mechanical layer deletes aged session state without
asking (an explicit design decision — dry-run is the escape hatch); the
semantic layer proposes judgment-based deletions behind a multi-select gate.

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

- **Project slug** — the absolute working directory with `/` replaced by `-`
  (e.g. `/home/nico/r/handbook` → `-home-nico-r-handbook`).
- **Live session id** — `$CLAUDE_CODE_SESSION_ID` from the session
  environment. If unset, proceed without it: the script always keeps the
  newest-mtime transcript per project as the no-id fallback.

### 3. Mechanical sweep (ungated)

Run the bundled script via the skill's base directory with an explicit
interpreter — never an absolute handbook path, never relying on the execute
bit (the plugin cache may not preserve it):

```bash
bash <skill-base-dir>/prune-state.sh --days <N> --scope <slug-or-all> \
  --exclude-session "$CLAUDE_CODE_SESSION_ID" --delete
```

- With `dry-run`: omit `--delete` (the script's default is a dry run).
- Without `dry-run`: pass `--delete` directly — do not ask first; the
  mechanical classes are age-rule-decidable by design.
- What the script may touch, and everything it never touches, is documented
  in [state-map.md](state-map.md). If the machine's layout stops matching the
  state map, stop and re-verify per its drift rule before trusting the sweep.
- Never bypass the script with ad-hoc `rm` on harness state.

Parse the `MODE` / per-class / `total` lines for the report (step 7).

### 4. Semantic review — collect findings

Review three classes per [criteria.md](criteria.md), every finding carrying
its class, target, cited evidence, and proposed action (delete or update):

- **Memories** — mechanical checks everywhere; semantic verification against
  the project's repo where it exists locally. Current project inline; in
  `all` scope, one `opus` subagent per other project with a local repo
  (mechanical checks only where the repo is absent).
- **Instructions surfaces** — current repo only, in every scope. In the
  handbook: `AGENTS.md` and `.claude/rules/*.md`; elsewhere: surfaces
  discovered per [../reflect/targets.md](../reflect/targets.md), never
  assumed.
- **Repo leftovers** — current repo only, in every scope: completed plan
  files, merged worktrees and branches, stale scratch artifacts.

In **dry-run**, report the findings (step 7) and skip steps 5–6 entirely.

### 5. Gate — multi-select

Present all findings in one multi-select: a structured question tool if the
surface has one, otherwise the formatted-options fallback in
[../clarify/question-rules.md](../clarify/question-rules.md). Each option
shows class, target, evidence, and proposed action. When findings exceed the
tool's capacity, batch across several rounds grouped by class — selecting
nothing stays a valid outcome in every round.

### 6. Apply picked items only

- Memory deletion removes the file **and** its `MEMORY.md` index line
  together; a memory update edits the file in place.
- Rule updates/deletions edit the instructions surface; leftover deletions
  land in the working tree only.
- Unpicked findings are skipped and reported as such; picking nothing means
  zero semantic writes.

### 7. Report

One chat report, in this order:

- **Mechanical** — per class: files and bytes deleted (or would-be-deleted
  in dry-run); what was kept and why: live session (id or newest-mtime
  fallback), entries younger than the threshold, memory directories (never
  touched).
- **Semantic** — proposed findings, picked items (applied), skipped items
  and why (declined, dry-run, or ambiguous).
- Close with the reflect pairing reminder: **pruned transcripts are gone as
  reflection evidence — run `/reflect` before the first prune of a busy
  period.**

## Constraints

- Pruning is a deliberate, destructive user ritual — never auto-triggered
  (`disable-model-invocation`), never suggested mid-task.
- Deletion is hard: no archive, trash, or backup step; the chat report is the
  only record.
- Memory directories, configuration, credentials, plugins, and harness
  backups are never touched — enforced by the script's allowlist; do not work
  around it.
- Every semantic change is gated: nothing judgment-based is deleted or
  updated without being picked in the multi-select. Uncommitted work is never
  proposed for deletion.
- **Never commit.** Committing stays a separate, user-approved step
  (`/commit`).

## Quality

Run the shared [self-review checklist](../quality.md) on every applied item
before presenting the result.
