# Restructuring

Splitting monoliths, merging fragments, and shaping an index. Humans and agents
then load one small file instead of a large one.

- [Why size is a correctness problem](#why-size-is-a-correctness-problem)
- [When to split](#when-to-split)
- [Where to cut](#where-to-cut)
- [Sizing targets](#sizing-targets)
- [The leaf-file contract](#the-leaf-file-contract)
- [The index file](#the-index-file)
- [Deduplicate while splitting](#deduplicate-while-splitting)
- [Merging](#merging)
- [Naming](#naming)

## Why size is a correctness problem

Split for retrieval, not for tidiness.

- **The unit of value** — the smallest file that fully answers one question a reader arrives with.
- **Restructuring is not a substitute for deletion** — run the deletion pass first, then split what survives.
- **A 900-line file that should have been 200 lines** produces six files nobody needed.

## When to split

Split when any of these hold:

- The file exceeds the size targets below.
- **Readers arrive with clearly different questions**, each needing a different part.
- **Example** — the deploy question and the local-setup question share nothing.
- Sections have different lifetimes: a stable conventions section next to a
  volatile host list.
- Sections have different audiences: contributor-facing next to operator-facing.
- An agent loading it for one task wastes most of the file.

Do **not** split when:

- Every reader needs all of it (a 200-line runbook executed top to bottom is one
  file, always).
- The parts only make sense together and would need constant cross-referencing.

## Where to cut

**Cut on the question, not the taxonomy.** Boundaries that hold up name a task or
a decision. Boundaries that fail name a document part.

| Good | Bad |
| --- | --- |
| `deploy.md`, `rollback.md`, `incident-response.md` | `part-1.md`, `part-2.md` |
| `local-setup.md`, `ci.md`, `production.md` | `overview.md`, `details.md`, `appendix.md` |
| `postgres-backup.md`, `postgres-tuning.md` | `postgres-1.md`, `postgres-misc.md` |

- **Test each proposed boundary** — what question does a reader open this file with?
- **And** — does the file answer it without opening another?
- **A file whose answer always requires a second file** is cut in the wrong place.
- **A `misc.md` or `other.md` in your plan** means the boundary is wrong.
- **Its contents** belong to real files or belong nowhere.

## Sizing targets

Guidance, not a linter rule:

- **Leaf files: 50–200 lines.** Comfortable to read whole and cheap to load.
- **Hard ceiling: ~500 lines.** Beyond this, splitting almost always wins.
- **Floor: ~30 lines.** Below it, the file costs more in link-chasing and index
  entries than it saves — merge it into a sibling.
- **Index: as short as possible.** Rarely over 100 lines.
- **Precision beats the target.** A 600-line runbook of exact commands that must run in
  order stays one file.

## The leaf-file contract

A leaf will be reached by grep, by link, and by an agent that never saw the index.
Each one must therefore stand alone:

- **One line of scope directly under the H1** — what this file covers.
- **When the boundary is not obvious** — also what it does not cover.
- **That line is the only prose** in the file allowed to be about the file.
- **No dependence on reading order.** No "as described above", no "continuing from the previous file".
- **A link back to the index**, and forward links only where a reader genuinely continues elsewhere.

## The index file

The entry point earns its place by routing, not by summarizing.

- **One row or bullet per file** — the file, and **the question it answers**.
- **Not a précis** of its contents; a summary in the index is a duplicate that will drift.
- **Keep only the facts** true across every leaf and needed before choosing one.
- **Those facts** — prerequisites, the one-line "start here".
- **Every leaf reachable from it.** No orphans.
- **One level of nesting.** If the index needs subsections of subsections, the corpus is over-split.

## Deduplicate while splitting

Splitting a monolith reliably exposes the same claim stated in three sections.

- **Why** — the sections were written months apart and nobody read the whole file since.
- **Deduplicate *during* the split**, never after.
- **A split that copies duplicates** into separate files turns one inconsistency into three that disagree.
- **Order of operations** — extract claims → cluster → assign each cluster one home.
- **Never open a new file** and paste a section into it.

## Merging

The inverse case, and often the more valuable one. Merge when:

- Several tiny files each hold one paragraph and are always read together.
- A file's whole content is a section of another file's topic.
- Directories exist for structural symmetry with one file each.

Merging is subject to the same criteria pass — do not carry duplicates across.
After merging, delete the source files and fix every inbound link.

## Naming

- Lowercase, hyphenated, `.md`: `nginx-reverse-proxy.md`.
- Name the **subject**, not the document type: `postgres-backup.md`, not
  `postgres-backup-guide.md` or `how-to-backup-postgres.md`.
- Keep sibling names parallel so the directory listing reads as a menu.
