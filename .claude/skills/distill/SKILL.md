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

Reduce a repository's prose to what a reader cannot get anywhere else. Shape what
survives into small files that load cheaply.

- **Scope** — the whole prose corpus; deletes by default.
- **Deletes** whole files, whole sections, whole comment blocks.
- **Not this skill** — sentence-level quality inside a diff or one area: use `/cleanup`.
- **`/cleanup` owns** the per-comment rules ([../cleanup/code-smells.md](../cleanup/code-smells.md)).
- **`/cleanup` owns** the prose-slop catalogue ([../cleanup/readability.md](../cleanup/readability.md)).
- **Agent state** — sessions, memories, rules: use `/prune`.

## The method: re-derive, do not edit

Editing docs is status-quo biased. Every line reads as if it earned its place.
So "can I cut this?" gets a defensive answer.

- **Invert it** — suspend the existing structure, decisions and file boundaries.
- **Ask the re-derivation question below** of each thing.
- **Keep is the exception** that needs an argument, not the default.
- **[criteria.md](criteria.md)** — the bar, what dies, what survives, the hard cases.
- **[restructure.md](restructure.md)** — splitting, merging, index design.
- **[parallelism.md](parallelism.md)** — fan-out design, model routing, the subagent return contract.

> **If this repository had no documentation, would I write this line from scratch today?**

## Workflow

### 1. Scope and safety

Arguments: `$ARGUMENTS`.

- **Paths** limit the corpus to those directories or files.
- **`plan-only`** pre-answers the mode question in step 5.
- **Require a clean working tree** — `git status --porcelain` must be empty.
- **Git is the only undo** for this skill. Dirty tree: stop and say so.
- **Ask nothing yet** — the step-5 questions are worth far more grounded in real files.
- **Asking twice** wastes the user's attention.

### 2. Inventory

Enumerate the corpus and record the baseline you will be measured against:

```bash
git ls-files '*.md' '*.mdx' '*.rst' '*.txt' | xargs wc -l | sort -rn
```

- **Add** comment-heavy sources and configs in scope.
- **Record per file** — path, line count, the one-line **question it answers**.
- **A purpose you cannot state in one line** is a finding — that file is several files or none.
- **Sum the lines** — that total is the before-number in the final report.
- **The file count selects the execution mode** — inline, parallel subagents, or a `Workflow`.
- **Per [parallelism.md](parallelism.md)** — decide here, state it in one line, never re-decide.

### 3. Blank-slate pass — per file

Run this pass in the execution mode chosen in step 2.

- **Fan out** over file groups per [parallelism.md](parallelism.md) when it is not inline.
- **Read each file once and in full** — never two passes, never a grep hit or headings alone.
- **Return** the disposition below, the audience it appears to serve, and step 4's claim list.
- **Workers are read-only** — they propose; they never edit or delete.
- **Dispositions are provisional** — the keep-bar is not settled until step 5.
- **Mark every disposition that would flip** under a different reader.
- **Marker** — `audience-sensitive: would be KEEP for external users`.
- **Audience-independent** — duplication, staleness, derivability.
- **Audience-dependent** — "too obvious to document".
- **Apply** the re-derivation question above and the categories in [criteria.md](criteria.md).
- **Assign exactly one** disposition.

| Disposition | Meaning |
| --- | --- |
| **DELETE** | The whole file fails the bar. |
| **GUT** | A small core survives; most of the file goes. |
| **TRIM** | Sound file, some sections fail. |
| **SPLIT** | Earns its content but is too large or mixed to load as one unit. |
| **MERGE** | Belongs inside another file. |
| **KEEP** | Survives unchanged. |
| **FLAG** | Cannot be verified from this session — needs the user, not a delete. |

- **Record per file** — disposition, the lines or sections affected, a one-line reason.
- **The reason** names what a reader will not miss.
- **Not a reason** — "redundant" or "outdated"; name what it duplicates or what superseded it.

### 4. Cross-file pass — deduplicate

Per-file review cannot see repetition. This pass is a barrier. Do not spawn agents here.

1. **Wait** for all step-3 workers, then reason over the merged list yourself.
2. **Merge** the **claims** returned by step 3, each with its file and line.
3. **A claim** is a fact, command, path, version, convention, or instruction.
4. **Cluster** identical and near-identical claims.
5. **Pick the canonical home** for every cluster of two or more.
6. **Canonical** — the file whose stated purpose it belongs to, nearest to the thing it describes.
7. **Everything else is deleted**, or replaced by a relative link.
8. **Link only** where the reader genuinely needs the pointer.
9. **Conflicting duplicates are the highest-value finding** in this pass.
10. **Two files that disagree** mean at least one is wrong, misleading readers today.
11. **Never silently pick a winner** — report every conflict with both locations.
12. **Let the user resolve** it.

### 5. Ask — the three questions

Analysis is done; nothing is decided. Ground every option in files you actually found.

- **Ask all three in one round**, using a structured question tool if the surface has one.
- **Fallback** — [../clarify/question-rules.md](../clarify/question-rules.md).

**1. Who reads this repo, and which files serve which audience?**

- **Never ask this abstractly.**
- **Present the audience map** you inferred in step 3; ask the user to correct it:

```
README.md, guides/install.md   → external users
guides/deploy.md, runbooks/    → operators (you and your agents)
AGENTS.md, .claude/rules/      → agents
docs/adr/                      → unclear — who reads these?
```

- **The audience sets the keep-bar** and decides every `audience-sensitive` marker from step 3.
- **Name the consequence** — install instructions survive for external users, die in a private knowledge base.
- **Anything left unclear stays FLAG** — never guess an audience into a deletion.

**2. What is off-limits?**

- **Offer a multi-select** of concrete exclusions.
- **State the contract plainly** — **anything selected will not be touched.**
- **Seed the options** with the files most worth protecting, plus a free-text path option.
- **Most worth protecting** — files proposed for DELETE, entry points, instruction surfaces.
- **Also** — anything hand-written recently, any directory the user may treat as an archive.
- **Excluded paths are dropped from the plan entirely**, not merely reported as skipped.

**3. Plan only, or plan then apply?**

| Answer | Effect |
| --- | --- |
| **Plan then apply** | Continue to step 6 with the plan in memory. State the changes; apply on approval. |
| **Plan only** | Write the plan to a file and stop. Nothing in the corpus changes this session. Pre-answered by the `plan-only` argument. It exists because a large distillation is worth reviewing away from the session that proposed it. |

### 6. Plan

Finalize first, then write the plan. Keep it short — an action list, not prose.

- **Apply the confirmed keep-bar** to every `audience-sensitive` disposition from step 3.
- **Drop** everything excluded in question 2.
- **Design the target file set** for every SPLIT and MERGE per [restructure.md](restructure.md).
- **Name** every new file, its source sections, and its projected line count.
- **Three or more monoliths** — design them in parallel per [parallelism.md](parallelism.md).
- **The plan holds, in apply order**, everything step 8 needs without re-deriving anything.
- **Every action** — file, disposition, exact sections or line ranges, one-line reason.
- **The new file tree** for every split and merge, with source sections mapped.
- **Every index and inbound link** that each action invalidates.
- **The conflicts and FLAGs** — kept out of the action list.
- **Where it lives** depends on the answer to question 3.
- **Plan then apply** — keep it **in memory**; write no file.
- **Why** — writing one would add a file to the corpus being distilled.
- **And** — the plan is consumed in the same turn.
- **A deliberate exception** to the repo's plan-first `plan.md` convention.
- **Plan only** — write it to `docs/plans/plan-distill-<scope>.md`.
- **Template** — [../create-plan/SKILL.md](../create-plan/SKILL.md), plus its placeholder-scan self-review.
- **One phase** per directory or disposition group, each with its file list.
- **Acceptance criteria** a later session can verify against — line counts, dead-link check, index matches disk.
- **Record the keep-bar and the off-limits list** in *Resolved decisions*.
- **Why** — a plan is worthless without the bar it was written against.

### 7. State the major changes and get approval

Do not dump the plan. State only what changes the user's answer, in this order.

| # | Field | Content |
| --- | --- | --- |
| 1 | **The budget** | One line: `3,180 → 1,240 lines (-61%)`, plus the file count deleted, split, and merged |
| 2 | **Major changes only** | Whole files deleted, splits, merges, and anything touching an entry point or instruction surface |
| 3 | **Conflicts** | Every pair of docs that disagree, both locations |
| 4 | **FLAGs** | What you could not verify and are therefore not proposing to touch |

- **One line per major change** — file, action, reason; each opens with a bold keyword.
- **Cap major changes at roughly ten** — aggregate the tail: `+14 TRIM edits across guides/`, listed on request.
- **Conflicts need the user** whatever they decide about the rest.
- **A field with nothing to report** — one line, no padding.
- **Plan only** — state those four, name the plan file, commit it per step 10, and stop.
- **Never ask for approval in plan-only** — asking invites yes to changes this mode will not make.
- **Plan then apply** — ask for approval explicitly.
- **Offer** approve everything, approve with named exclusions, or stop.
- **Many actions** — use a multi-select grouped by disposition.
- **Same question mechanism as step 5**, so exclusions are picked rather than typed.
- **Approving nothing is a valid outcome.**

### 8. Apply

Plan-only runs never reach this step. Execute the in-memory plan in this order.
Later stages depend on the file set the earlier ones produce.

1. **TRIM and GUT** — shrink in place.
2. **DELETE** — `git rm`, so the removal is staged as one reviewable diff.
3. **MERGE, then SPLIT** — create the new files, remove the source.
4. **Every index and every inbound link last**, when the file set is final.

- **Stages 1–3 can fan out** over a disjoint file partition per [parallelism.md](parallelism.md).
- **Stage 4 stays with the lead** — index and link edits converge on shared files.
- **Apply only what was approved**; report excluded items as excluded.

### 9. Verify

- **Grep** `grep -r '<filename>'` for every deleted or renamed file; fix every hit.
- **No dead links** — a repo rule, not an option.
- **Re-read each index file** — its entries must match the files on disk.
- **Run the repo's own checks** if they exist: `make check`, link linters, docs build.
- **Re-read the largest surviving file** end to end.
- **A list of links with no content of its own** means the split went too far — merge back.
- **Report actual before/after line counts** from `git diff --stat`, not the plan's projections.
- **Delegate the mechanical half** to one `sonnet` agent — link sweep, index-vs-disk comparison.
- **The judgment half stays with the lead** — did the split go too far.

### 10. Commit, then hand off

Commit the distillation as one commit — `docs: distill <scope>`.

- **List every FLAG in the commit body**, one line each with its `file:line`.
- **Why** — the commit message is the only thing that survives this session.
- **The next session** is expected to settle them; a FLAG stated only in chat is discarded.
- **End the run by naming the next step** — [/verify-docs](../verify-docs/SKILL.md), in a fresh session.
- **Why** — this skill decided what to keep, never whether what it kept is *true*.
- **And** — [a session cannot audit its own output](../verify-docs/SKILL.md#why-this-runs-in-its-own-session).
- **Do not run it here**, and do not pre-empt its findings.
- **Plan-only runs** commit the plan file and stop; there is nothing to verify yet.

## Constraints

- **Never apply anything without explicit approval.** Steps 1–7 write nothing to the corpus.
- **Silence is not approval** — never commit mid-apply.
- **Never delete outside version control** — clean tree before, `git diff` as the record after.
- **No archive directory, no `.old` copies** — that is deprecating.
- **Never accept a disposition from a worker** whose return does not show it read the file in full.
- **Never delete legal or compliance content** — licences, third-party notices, security
  policies, attribution requirements — regardless of how boilerplate it reads.
- **Never delete agent instruction surfaces** without per-file confirmation.
- **Surfaces** — `AGENTS.md`, `CLAUDE.md`, `.claude/rules/*`, `.github/copilot-instructions.md`.
- **They read as restating the obvious** because that is their job; they are load-bearing contracts.
- **Unverifiable is not false** — cannot check a claim from this session? FLAG it.
- **Deleting what you failed to understand** is the main way this skill causes damage.
- **Delete a line for looking wrong** only when it also fails the bar.
- **Never fabricate replacement content** — delete or flag a wrong section.
- **Never invent the corrected version.**
- **Rewrite freely; never invent or alter a claim.**
- **Allowed and usually the point** — restyling, condensing, merging, restructuring surviving prose.
- **A distilled file reads as one voice**, not as the seams of what was cut.
- **Never change what a sentence asserts**, and never add an assertion that was not there.
- **Surviving exactly as stated** — every fact, command, flag, path, version, name and constraint.
- **Why** — that is what keeps the later verification sweep able to do its job.
- **The prose around them is yours.**
- **Never trade precision for brevity.** A short doc that lost the exact command, flag,
  path, or version is worse than the long one it replaced.
- **Never edit generated documentation.** Fix the generator or leave it.
- **Never touch code** — comments and docstrings are in scope, the statements around them are not.
- **A comment wrong only because the code is** — flag it.

## Quality

- Before presenting results, run the shared [self-review checklist](../quality.md).
- Match the shared [output style contract](../output-style.md).
- Surface issues in the chat only if found.
