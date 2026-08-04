# Improvement Targets

Taxonomy and per-repo target resolution for reflect plan items.

- [Categories and decision criteria](#categories-and-decision-criteria)
- [Memory directory resolution](#memory-directory-resolution)
- [Handbook target map](#handbook-target-map)
- [Generic repo resolution](#generic-repo-resolution-plugin-use-outside-the-handbook)

## Categories and decision criteria

| Category | Choose when the learning is… |
| --- | --- |
| **memory** | a session-crossing fact about the user or project that is not derivable from the repo itself (code, git history, instructions files) |
| **rule** | a convention for how agents should behave — belongs in an instructions surface |
| **skill** | a repeatable multi-step workflow worth packaging for re-invocation |
| **documentation** | human-facing knowledge someone will look up: how-tos, commands, background |
| **tooling/process** | preventable by automation: a CI check, test, lint rule, Make target, script, or command |

- **Most automatable wins** — a learning fitting several categories gets the most automatable one.
- **Precedence** — a CI check beats a rule; a rule beats a memory.
- **Why** — automation changes future behavior without anyone having to remember anything.

## Memory directory resolution

- **Path** — the harness memory directory `~/.claude/projects/<slug>/memory/`.
- **Slug** — the absolute working directory with `/` replaced by `-`
  (e.g. `/home/nico/r/handbook` → `-home-nico-r-handbook`).
- **Exists** only where harness memory is enabled.
- **Directory absent** — the memory category has no valid target.
- **Then** — present such items as a handoff note; never create the directory.

### Memory file format

- **File** — one per fact, named `<short-kebab-slug>.md`.
- **`name`** — the same short kebab slug.
- **`description`** — one line; it decides relevance during recall.
- **`metadata.type`** — one of `user`, `feedback`, `project`, `reference`.
- **Body** — the fact itself.
- **Body, `feedback` and `project` types** — follow the fact with **Why:** and
  **How to apply:** lines.

```markdown
---
name: <short-kebab-slug>
description: <one-line summary — used to decide relevance during recall>
metadata:
  type: user | feedback | project | reference
---

<the fact; for feedback/project, follow with **Why:** and **How to apply:** lines>
```

- **Index line** — after writing the file, add `- [Title](<file>.md) — <hook>` to the
  directory's `MEMORY.md`.
- **`MEMORY.md`** — index lines only, never memory content.
- **Near-duplicate** — update the existing file instead of creating one.

#### Memory holds current state, not events

The **Current state only** rule (`AGENTS.md`, Working rules) applied to the memory directory.

- **State, not events** — a memory says what is true, not what happened when.
- **Banned** — landed-plan and milestone records, run reports, completion and incident logs.
- **The lesson** from a run is a memory; the run itself is not.
- **Superseded** — rewrite it in place, or delete it with its `MEMORY.md` index line.
- **Dates** — only where the fact is itself a date.

#### Event to residue

An event record is rewritten as its residue, then deleted with its `MEMORY.md` line.

| Event record | Residue that survives |
| --- | --- |
| a landed plan | the constraints it settled, as a `project` memory |
| a run or session report | the lesson, as a `feedback` memory |
| a completed milestone | the state it left behind, in present tense |
| an incident log | the invariant that broke, and how to hold it |

- **Order** — write the residue first, delete the record second.
- **No residue** — delete the record outright.
- **No keeper fits** — write one, then fold the residue into it.

## Handbook target map

The richest target set — applies when reflecting inside the handbook repo:

| Category | Target |
| --- | --- |
| memory | memory directory (above) + `MEMORY.md` index line |
| rule | repo-wide → `AGENTS.md` (Working rules); path-scoped → `.claude/rules/<topic>.md` |
| skill | scaffold `.claude/skills/<name>/` per `.claude/rules/skills.md`, including its index entries |
| documentation | `guides/` (runbook-style) or `cheatsheets/` (quick reference) + `README.md` index row |
| tooling/process | trivial edit (a Make target, a line in `scripts/check-repo.sh`) → apply inline; anything larger → handoff: recommend running write-prd / create-plan |

## Generic repo resolution (plugin use outside the handbook)

Targets are **discovered, never assumed** — read what the repo actually has before proposing any
write. Discover:

- **Instructions surface** (rule items) — the first of `AGENTS.md`, `CLAUDE.md`,
  `.github/copilot-instructions.md` that exists in the repo root.
- **Docs layout** (documentation items) — `docs/` or another existing doc directory;
  `README.md` for small additions.
- **Docs conventions** — follow the repo's own structure and index conventions.
- **Skills location** (skill items) — `.claude/skills/` only if it already exists.
- **Memory directory** (memory items) — resolved via the working-directory slug (above); valid
  only if the directory exists.
- **Tooling surface** (tooling/process items) — the repo's own Makefile, CI workflows, or
  scripts.
- **Tooling size** — trivial edits inline; larger work → write-prd / create-plan handoff, same
  as in the handbook.
- **No valid target** in the current repo — that category becomes a handoff note inside the
  plan multi-select.
- **Handoff note** — the item is still presented with its cited observation.
- **Selecting it** yields a recommendation of where such a target could live.
- **Never** write to a guessed path.
- **Dedup adapts too** — in a generic repo, check the discovered instructions file and the
  discovered docs.
- **Memory dedup** — include the memory directory if it is present.
- **Skip** the handbook-specific artifact list.
