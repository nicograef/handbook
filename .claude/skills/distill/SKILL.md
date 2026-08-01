---
name: distill
description: >-
  Radically minimizes and restructures the prose of a whole repository —
  Markdown, docs, READMEs, code and config comments. Re-derives the docs from a
  blank slate instead of editing them: deletes what is historic, derivable,
  generic, aspirational, or duplicated, then splits surviving monoliths into
  small deduplicated files that humans and agents can load one at a time. Plans
  first and applies nothing without explicit approval — or stops at a written
  plan on request.
  Triggers: "distill", "minimize the docs", "shrink the documentation",
  "too much documentation", "split this doc up", "deduplicate the docs",
  "radically reduce prose".
argument-hint: "[path ...] [plan-only]"
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

# Distill

Reduce a repository's prose to what a reader cannot get anywhere else, then
shape what survives into small files that load cheaply.

**Scope boundary.** This skill works on the whole prose corpus and deletes by
default — whole files, whole sections, whole comment blocks. For sentence-level
quality inside a diff or one area, use `/cleanup`; it owns the per-comment rules
([../cleanup/code-smells.md](../cleanup/code-smells.md)) and the prose-slop
catalogue ([../cleanup/readability.md](../cleanup/readability.md)). For agent
state (sessions, memories, rules), use `/prune`.

## The method: re-derive, do not edit

Editing docs is status-quo biased: every line reads as if it earned its place
because someone wrote it, so "can I cut this?" gets a defensive answer. Invert
it — suspend the existing structure, decisions and file boundaries, then ask of
each thing:

> **If this repository had no documentation at all, and I were writing it from
> scratch today, would I write this line?**

Keep is the exception that needs an argument, not the default. The bar itself,
what dies, what survives and the hard cases are in [criteria.md](criteria.md);
splitting, merging and index design in [restructure.md](restructure.md);
fan-out design, model routing and the subagent return contract in
[parallelism.md](parallelism.md).

## Workflow

### 1. Scope and safety

Arguments: `$ARGUMENTS`. Paths limit the corpus to those directories or files;
`plan-only` pre-answers the mode question in step 5.

Require a clean working tree — `git status --porcelain` must be empty; git is
the only undo for this skill. If the tree is dirty, stop and say so.

Ask nothing yet: the step-5 questions are worth far more once grounded in real
files, and asking twice wastes the user's attention.

### 2. Inventory

Enumerate the corpus and record the baseline you will be measured against:

```bash
git ls-files '*.md' '*.mdx' '*.rst' '*.txt' | xargs wc -l | sort -rn
```

Add comment-heavy sources and configs in scope. For each file record path, line
count, and a one-line statement of the **question it answers** — a file whose
purpose you cannot state in one line is already a finding, being either several
files or none. Sum the lines: that total is the before-number in the final report.

The file count selects the execution mode for the analysis — inline, parallel
subagents, or a `Workflow` — per [parallelism.md](parallelism.md). Decide it here
and state it in one line; do not re-decide it later.

### 3. Blank-slate pass — per file

Run this pass in the execution mode chosen in step 2, fanning out over file
groups per [parallelism.md](parallelism.md) when it is not inline. Each file is
read **once** — never two passes — returning the disposition below, the audience
it appears to serve, and the claim list step 4 needs. Workers are read-only; they
propose, they never edit or delete.

Dispositions here are **provisional**: the keep-bar is not settled until step 5,
so mark every disposition that would flip under a different reader
(`audience-sensitive: would be KEEP for external users`). Duplication, staleness
and derivability are audience-independent; "too obvious to document" is not.

Read each file in full — never judge a file from a grep hit or its headings.
Apply the re-derivation question above and the categories in
[criteria.md](criteria.md), then assign exactly one disposition:

| Disposition | Meaning |
| --- | --- |
| **DELETE** | The whole file fails the bar. |
| **GUT** | A small core survives; most of the file goes. |
| **TRIM** | Sound file, some sections fail. |
| **SPLIT** | Earns its content but is too large or mixed to load as one unit. |
| **MERGE** | Belongs inside another file. |
| **KEEP** | Survives unchanged. |
| **FLAG** | Cannot be verified from this session — needs the user, not a delete. |

Record for each: disposition, the lines or sections affected, and the one-line
reason a reader will not miss them. "Redundant" or "outdated" is not a reason —
name what it duplicates or what superseded it.

### 4. Cross-file pass — deduplicate

Per-file review cannot see repetition. This pass is a barrier: wait for all
step-3 workers, merge their claim lists, then reason over the merged list
yourself. Do not spawn agents here.

1. Merge the **claims** returned by step 3 — each a fact, command, path, version,
   convention, or instruction, with its file and line.
2. Cluster identical and near-identical claims.
3. For each cluster of two or more, pick the canonical home: the file whose
   stated purpose the claim belongs to, nearest to the thing it describes.
   Everything else is deleted, or replaced by a relative link only where the
   reader genuinely needs the pointer.
4. **Conflicting duplicates are the highest-value finding in this pass.** Two
   files that disagree mean at least one is wrong and readers are being misled
   today. Never silently pick a winner — report every conflict with both
   locations and let the user resolve it.

### 5. Ask — the three questions

Analysis is done; nothing is decided. Ask all three in one round, using a
structured question tool if the surface has one and the
[../clarify/question-rules.md](../clarify/question-rules.md) fallback otherwise.
Ground every option in files you actually found.

**1. Who reads this repo, and which files serve which audience?**

Never ask this abstractly. Present the audience map you inferred in step 3 and
ask the user to correct it:

```
README.md, guides/install.md   → external users
guides/deploy.md, runbooks/    → operators (you and your agents)
AGENTS.md, .claude/rules/      → agents
docs/adr/                      → unclear — who reads these?
```

The audience sets the keep-bar and decides every `audience-sensitive` marker from
step 3, so name the consequence when you ask: install instructions survive for
external users and die in a private knowledge base. Anything left unclear stays
FLAG — never guess an audience into a deletion.

**2. What is off-limits?**

Offer a multi-select of concrete exclusions and state the contract plainly:
**anything selected will not be touched.** Seed the options with the files most
worth protecting — files proposed for DELETE, entry points, instruction
surfaces, anything hand-written recently, any directory the user may treat as an
archive — plus a free-text path option. Excluded paths are dropped from the plan
entirely, not merely reported as skipped.

**3. Plan only, or plan then apply?**

| Answer | Effect |
| --- | --- |
| **Plan then apply** | Continue to step 6 with the plan in memory, state the changes, apply on approval. |
| **Plan only** | Write the plan to a file and stop; nothing in the corpus changes this session. Pre-answered by the `plan-only` argument, it exists because a large distillation is worth reviewing away from the session that proposed it. |

### 6. Plan

First, finalize: apply the confirmed keep-bar to every `audience-sensitive`
disposition from step 3, drop everything excluded in question 2, and design the
target file set for every SPLIT and MERGE per [restructure.md](restructure.md).
Name every new file, its source sections, and its projected line count. With
three or more monoliths, design them in parallel per
[parallelism.md](parallelism.md).

The plan holds, in apply order, everything step 8 needs without re-deriving
anything: every action (file, disposition, exact sections or line ranges,
one-line reason), the new file tree for every split and merge with source
sections mapped, every index and inbound link that each action invalidates, and
the conflicts and FLAGs — kept out of the action list.

Where it lives depends on the answer to question 3:

- **Plan then apply** — keep it **in memory**; write no file. Writing one would
  add a file to the corpus being distilled, and the plan is consumed in the same
  turn: a deliberate exception to the repo's plan-first `plan.md` convention.
- **Plan only** — write it to `docs/plans/plan-distill-<scope>.md` using the
  [../create-plan/SKILL.md](../create-plan/SKILL.md) template and its
  placeholder-scan self-review. One phase per directory or disposition group,
  each with its file list and acceptance criteria a later session can verify
  against (line counts, dead-link check, index matches disk). Record the keep-bar
  and the off-limits list in *Resolved decisions* — a plan is worthless without
  the bar it was written against.

Keep it short either way — an action list, not prose.

### 7. State the major changes and get approval

Do not dump the plan. State only what changes the user's answer, in this order:

1. **The budget** — one line: `3,180 → 1,240 lines (-61%)` plus the file count
   deleted, split, and merged.
2. **Major changes only** — whole files deleted, splits, merges, and anything
   touching an entry point or instruction surface. One line each: file, action,
   reason. Cap at roughly ten; aggregate the tail (`+14 TRIM edits across
   guides/`, listed on request).
3. **Conflicts** — every pair of docs that disagree, both locations. These need
   the user whatever they decide about the rest.
4. **FLAGs** — what you could not verify and are therefore not proposing to touch.

**Plan only** — state those four, name the plan file, commit it per step 10, and
stop. Do not ask for approval: asking invites the user to say yes to changes this
mode will not make.

**Plan then apply** — ask for approval explicitly. Offer: approve everything,
approve with named exclusions, or stop. With many actions, use a multi-select
grouped by disposition, through the same question mechanism as step 5, so
exclusions are picked rather than typed. Approving nothing is a valid outcome.

### 8. Apply

Plan-only runs never reach this step. Execute the in-memory plan in this order —
later stages depend on the file set the earlier ones produce:

1. TRIM and GUT (shrink in place).
2. DELETE — `git rm` so the removal is staged as one reviewable diff.
3. MERGE, then SPLIT (create the new files, remove the source).
4. Update every index and every inbound link last, when the file set is final.

Stages 1–3 can fan out over a disjoint file partition per
[parallelism.md](parallelism.md); stage 4 stays with the lead — index and link
edits converge on shared files. Apply only what was approved; report excluded
items as excluded.

### 9. Verify

- `grep -r '<filename>'` for every deleted or renamed file; fix every hit. No
  dead links (a repo rule, not an option).
- Re-read each index file — its entries must match the files on disk.
- Run the repo's own checks if they exist (`make check`, link linters, docs build).
- Re-read the largest surviving file end to end. If it now reads as a list of
  links with no content of its own, the split went too far — merge back.
- Report actual before/after line counts from `git diff --stat`, not the
  projections the plan carried.

Delegate the mechanical half — link sweep, index-vs-disk comparison — to one
`sonnet` agent; the judgment half (did the split go too far) stays with the lead.

### 10. Commit, then hand off

Commit the distillation as one commit — `docs: distill <scope>`. **List every
FLAG in the commit body**, one line each with its `file:line`: the commit message
is the only thing that survives this session, the next one is expected to settle
them, and a FLAG stated only in chat is discarded.

Then end the run by naming the next step: **[/verify-docs](../verify-docs/SKILL.md),
in a fresh session.** This skill decided what to keep, never whether what it kept
is *true*, and [a session cannot audit its own
output](../verify-docs/SKILL.md#why-this-runs-in-its-own-session). Do not run it
here, and do not pre-empt its findings.

Plan-only runs commit the plan file and stop; there is nothing to verify yet.

## Constraints

- **Never apply anything without explicit approval.** Steps 1–7 write nothing to
  the corpus. Silence is not approval; never commit mid-apply.
- **Never delete outside version control.** Clean tree before, `git diff` as the
  record after. No archive directory, no `.old` copies — that is deprecating.
- **Never accept a disposition from a worker whose return does not show it read
  the file in full.**
- **Never delete legal or compliance content** — licences, third-party notices,
  security policies, attribution requirements — regardless of how boilerplate it
  reads.
- **Never delete agent instruction surfaces** (`AGENTS.md`, `CLAUDE.md`,
  `.claude/rules/*`, `.github/copilot-instructions.md`) without per-file
  confirmation. They read as restating the obvious because that is exactly their
  job; they are load-bearing contracts.
- **Unverifiable is not false.** If you cannot check a claim from this session,
  FLAG it — deleting what you failed to understand is the main way this skill
  causes damage. Delete a line for looking wrong only when it also fails the bar.
- **Never fabricate replacement content.** If a section is wrong, delete it or
  flag it — do not invent the corrected version.
- **Rewrite freely; never invent or alter a claim.** Restyling, condensing,
  merging and restructuring surviving prose is allowed and usually the point — a
  distilled file should read as one voice, not as the seams of what was cut.
  What you may not do is change what a sentence asserts, or add an assertion that
  was not there: every fact, command, flag, path, version, name and constraint
  survives exactly as stated — which is what keeps the later verification sweep
  able to do its job. The prose around them is yours.
- **Never trade precision for brevity.** A short doc that lost the exact command,
  flag, path, or version is worse than the long one it replaced.
- **Never edit generated documentation.** Fix the generator or leave it.
- **Never touch code.** Comments and docstrings are in scope; the statements
  around them are not. If a comment is only wrong because the code is, flag it.

## Quality

- Before presenting results, run the shared [self-review checklist](../quality.md).
  Surface issues in the chat only if found.
