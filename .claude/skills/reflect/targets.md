# Improvement Targets

Taxonomy and per-repo target resolution for reflect plan items.

## Categories and decision criteria

| Category | Choose when the learning is… |
| --- | --- |
| **memory** | a session-crossing fact about the user or project that is not derivable from the repo itself (code, git history, instructions files) |
| **rule** | a convention for how agents should behave — belongs in an instructions surface |
| **skill** | a repeatable multi-step workflow worth packaging for re-invocation |
| **documentation** | human-facing knowledge someone will look up: how-tos, commands, background |
| **tooling/process** | preventable by automation: a CI check, test, lint rule, Make target, script, or command |

**Most automatable wins.** A learning that fits several categories gets the most
automatable one: a CI check beats a rule, a rule beats a memory. Automation
changes future behavior without anyone having to remember anything.

## Memory directory resolution

The harness memory directory is `~/.claude/projects/<slug>/memory/`, where
`<slug>` is the absolute working directory with `/` replaced by `-`
(e.g. `/home/nico/r/handbook` → `-home-nico-r-handbook`). It exists only where
harness memory is enabled — if the directory is absent, the memory category has
no valid target (present such items as a handoff note, do not create the
directory).

### Memory file format

One file per fact, `<short-kebab-slug>.md`:

```markdown
---
name: <short-kebab-slug>
description: <one-line summary — used to decide relevance during recall>
metadata:
  type: user | feedback | project | reference
---

<the fact; for feedback/project, follow with **Why:** and **How to apply:** lines>
```

After writing the file, add one line to the directory's `MEMORY.md` index:
`- [Title](<file>.md) — <hook>`. `MEMORY.md` holds index lines only — never
memory content. Update an existing file instead of creating a near-duplicate.

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

Targets are **discovered, never assumed** — read what the repo actually has
before proposing any write. Discover:

- **Instructions surface** (rule items) — the first of `AGENTS.md`,
  `CLAUDE.md`, `.github/copilot-instructions.md` that exists in the repo root.
- **Docs layout** (documentation items) — `docs/` or another existing doc
  directory; `README.md` for small additions. Follow the repo's own structure
  and index conventions.
- **Skills location** (skill items) — `.claude/skills/` only if it already
  exists.
- **Memory directory** (memory items) — resolved via the working-directory
  slug (above); valid only if the directory exists.
- **Tooling surface** (tooling/process items) — the repo's own Makefile, CI
  workflows, or scripts; trivial edits inline, larger work → write-prd /
  create-plan handoff, same as in the handbook.

A category with **no valid target** in the current repo becomes a **handoff
note** inside the plan multi-select — the item is still presented with its
cited observation, but selecting it yields a recommendation of where such a
target could live, never a write to a guessed path.

**Dedup adapts too:** in a generic repo, check the discovered instructions
file, the discovered docs, and the memory directory (if present) instead of
the handbook-specific artifact list.
