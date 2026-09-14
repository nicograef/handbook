---
name: distill
description: Radically shrinks a repo's prose (Markdown, READMEs, code and config comments) by re-deriving it from a blank slate, then splits survivors into small files. Plans first, applies only after approval. Triggers: distill, too much documentation.
argument-hint: "[path ...] [plan-only]"
disable-model-invocation: true
---

# Distill

Keep only what a reader cannot get anywhere else. Ask of every line: *if this repo had no docs, would I write this line today?* Keep is the exception that needs an argument.

## Hard rules

- Clean working tree before starting; git is the only undo. No archive directories, no `.old` copies.
- Nothing in the corpus changes before the user approves the plan. Silence is not approval.
- Rewrite freely, but never invent, alter or "correct" a claim. Every fact, command, flag, path and version survives exactly as stated, or is deleted, or is flagged. A doc that is wrong is deleted or flagged, never rewritten from memory.
- Deleting what you failed to understand is how this skill causes damage. A claim you cannot verify this session is FLAG, not DELETE.
- Agent instruction surfaces (`AGENTS.md`, `CLAUDE.md`, `.claude/rules/*`, `.claude/agents/*`) read as restating the obvious because that is their job. Delete from them only with per-file confirmation.
- Legal and compliance text stays. Generated docs are fixed at the generator. Code stays; only comments and docstrings are in scope.
- Sentence-level quality inside a diff is `/cleanup`; agent state is `/prune`.

## Workflow

1. Inventory: `git ls-files '*.md' '*.mdx' '*.rst' '*.txt' | xargs wc -l | sort -rn` plus comment-heavy sources in scope. Record per file the one-line question it answers; a purpose that takes more than one line is a finding. The total is the before-number.
2. Per-file pass, reading each file once in full. ≤ 10 files inline. 11–40: one `opus` agent per directory-sized group of 5–10 files, all dispatched at once. More, or on request: a Workflow. Workers are read-only and get the criteria by reading this file. They return per file: disposition, sections affected, the audience it serves, and a reason naming what supersedes or duplicates it. They also return every substantive claim with file and line. A disposition that would flip for another audience is marked `audience_sensitive`.

   | Disposition | Meaning |
   | --- | --- |
   | DELETE | The whole file fails the bar |
   | GUT | A small core survives |
   | TRIM | Some sections fail |
   | SPLIT | Earns its content but is too large or mixed to load as one unit |
   | MERGE | Belongs inside another file |
   | KEEP | Unchanged |
   | FLAG | Cannot be verified from this session |

3. Cross-file pass, yourself, after all workers return. Cluster identical and near-identical claims. Pick one canonical home per cluster, the file nearest the thing described; delete or link the rest. Two files that disagree are the highest-value finding; report both locations and let the user pick.
4. Ask three questions in one round, grounded in the files found. Who reads which files: present the inferred audience map for correction; the audience sets the keep-bar. What is off-limits: a multi-select seeded with the DELETE candidates and entry points; excluded paths leave the plan entirely. Plan-only, or plan-then-apply.
5. Plan: apply the confirmed keep-bar to every `audience_sensitive` disposition and drop exclusions. Design the target files for every SPLIT and MERGE (see below). List every index and inbound link each action invalidates. Plan-then-apply keeps the plan in memory. Plan-only writes `docs/plans/plan-distill-<scope>.md` with the plan skill's template and stops after committing it.
6. Present the budget (`3,180 → 1,240 lines (-61%)`, files deleted, split, merged) and the roughly ten major changes. Major: whole-file deletes, splits, merges, anything touching an entry point. Then every conflict and every FLAG. Ask for approval as a multi-select grouped by disposition; approving nothing is valid.
7. Apply in order: TRIM and GUT, `git rm` for DELETE, MERGE then SPLIT, indexes and inbound links last. Fan out stages 1–3 over a disjoint file partition. The lead owns indexes, entry points and any file receiving merged content.
8. Verify: `grep -r` every deleted or renamed name and fix each hit. Re-read every index against disk, run the repo's checks (`make check`), re-read the largest survivor end to end. A file that is only a list of links means the split went too far; merge back. Report real before/after counts from `wc -l`.
9. Commit as `docs: distill <scope>` with every FLAG in the body as `file:line`; the commit message is what the next session inherits. Name `/verify-docs` in a fresh session as the next step. This skill decided what to keep, not whether it is true, and a session cannot audit its own output.

## What dies

| Category | Examples |
| --- | --- |
| Historic residue | "previously", completed migration guides, dated status tables, rationale nobody will revisit. Keep only a note that is still operative: a compatibility constraint or a documented reason an obvious change is forbidden |
| Derivable | Directory listings, command inventories mirroring a Makefile or `--help`, config-option lists, API tables regenerable from signatures. Delete and link to the source |
| Common knowledge for the audience | What Docker or git is, `npm install`, essays on why tests matter |
| Aspirational | Roadmaps, docs for unbuilt features, placeholder sections |
| Ceremonial | Table of contents on a one-screen file, Introduction/Overview/Summary sections, a first sentence restating the heading, badge walls, boilerplate CONTRIBUTING text |
| Padding | Paragraphs introducing a code block, "as you can see", motivational framing, recaps of the previous section |
| Comments | Banner blocks and file preambles repeating the module docs; `@param userId The user ID` on a typed parameter. Keep contracts the type cannot express: units, ownership, nullability, side effects. When a comment and a doc explain one mechanism, the comment wins |

## What survives

Non-derivable why, especially where the obvious alternative fails. Facts that exist nowhere else: where credentials live, who owns the upstream. Sharp edges and ordering dependencies. Exact command sequences for irreversible operations. Constraints and prohibitions. One short entry point. One worked example beats three paragraphs; delete further examples that vary nothing.

## Splitting and merging

- Split after deleting, never instead. Cut on the reader's question (`deploy.md`, `rollback.md`), never on document parts (`part-1.md`, `overview.md`); a `misc.md` in the plan means the boundary is wrong.
- Leaf files 50–200 lines, hard ceiling ~500, floor ~30 (below it, merge into a sibling). A 600-line runbook of ordered commands stays one file. An index routes with one line per file and the question it answers; it holds nothing else.
- Each leaf opens with one line of scope under the H1 and links back to the index. It depends on no reading order.
- Deduplicate during the split by clustering claims first; a split that copies a duplicate turns one inconsistency into three.
- Merge tiny files that are always read together, and directories that exist for symmetry with one file each.
