---
name: verify-docs
description: >-
  Fact-checks a repository's committed documentation against ground truth — the
  code, config, and scripts it describes, read-only command output, and official
  upstream sources — and against itself for contradictions, drifted duplicates,
  and dead references. Runs as an independent session over an already-committed
  corpus, typically the handoff at the end of /distill: it corrects what it can
  prove wrong, deletes what is false beyond repair, flags what no source can
  reach, and never settles a claim on anything but evidence gathered in the
  session.
argument-hint: "[path ...] [since <ref>] [report-only]"
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Edit
  - WebFetch
  - WebSearch
  - AskUserQuestion
  - Agent
---

# Verify Docs

Decide whether each documented claim is **true**, and fix the ones that are not.

**Scope boundary.** This skill judges truth, never value. A sentence that is
verbose, duplicated, badly placed, or inconsistently named is not its business —
corpus value and structure belong to `/distill`, sentence-level quality and
naming to `/cleanup`. A sentence that is elegant, well-placed, and *wrong* is the
only thing this skill targets. It never re-runs a distillation and never deletes
something for being unnecessary.

## Why this runs in its own session

The session that just rewrote the docs is the worst possible auditor of them. It
is anchored on its own dispositions, it spent its context deciding what to remove
rather than what is true, and it will read a surviving line as verified simply
because it chose to keep it.

So this skill starts from a commit, not from a conversation. Its inputs are the
files on disk, the sources they describe, and the handoff commit message —
nothing else. Anything it cannot re-derive from those does not exist for it,
which is the point.

Ground-truth classes, the evidence rule, lane precedence, and the anti-patterns
are in [sources.md](sources.md). Read it before step 2 — the lane taxonomy is
needed to extract claims, not just to verify them.

## Workflow

### 1. Scope and baseline

Arguments: `$ARGUMENTS`. Paths narrow the corpus; `since <ref>` limits it to docs
touched since that ref; `report-only` skips step 6 and the commit in step 7.

- Require a clean working tree — `git status --porcelain` must be empty. That
  both guarantees the corpus is committed and leaves the fixes as a diff of
  their own. If the tree is dirty, stop and say so.
- Record the HEAD sha. The report cites the exact state that was audited.
- **Run the repo's own checks now** — `make check`, a link linter, a docs build.
  They mechanize dead relative links and index-vs-disk comparison far better than
  a reading pass, and running them first means step 2 does not extract as claims
  what a passing script already settled. Keep the output; it is the artifact.
- **Read the handoff commit message.** A `/distill` run lists the claims it could
  not settle (its FLAGs) in the commit body. Those are the highest-priority
  claims in this run — a prior session already suspected them. They set priority,
  never scope. Carry the list to step 7: an inherited FLAG is always reported by
  name, whatever it resolves to.
- Enumerate the corpus (`git ls-files '*.md' '*.mdx' '*.rst'`, plus the
  comment-bearing sources and configs in scope) and its total line count.

Default scope is the **whole corpus**, not the diff. A distillation changes what
surrounds a surviving paragraph, so an untouched file can be wrong today for the
first time. `since` is an opt-in narrowing, never the default.

### 2. Extract claims

A claim is a statement that **can be false**. Extract, with `file:line`:

- Commands, flags, paths, filenames, make targets, script names
- Version numbers, version constraints, and pins
- Names of things in the repo: services, env vars, functions, types, config keys
- Links the step-1 checks do **not** cover — anchors and external URLs. Relative
  links already cleared by a passing link check are settled; do not re-extract
  them.
- Behaviour statements: "X does Y", "the default is Z", "this is idempotent"
- Ordering and prerequisites: "run A before B", "requires root"

Preferences, conventions, rationale, and tribal knowledge get lane `none` and are
handled per *Claims with no lane* in [sources.md](sources.md). They still enter
step 4: two conventions that contradict each other mislead a reader.

Each claim carries four fields, and the last is what makes step 3 cheap:

```
location:  file:line
claim:     one line, in falsifiable form
           ("`make check` exists as a target in Makefile")
lane:      repo | command | upstream | none   (see sources.md)
how:       the exact file, command, or URL that settles it
```

Fan out over file groups past the inline threshold, choosing the execution mode
and the group sizing from
[../distill/parallelism.md](../distill/parallelism.md#execution-modes) — the
corpus-size tiers and the [grouping rules](../distill/parallelism.md#grouping-files)
apply here unchanged. The delegation contract itself is in
[../dispatching-parallel-agents/SKILL.md](../dispatching-parallel-agents/SKILL.md).
Extraction workers are read-only and route to `sonnet` — spotting a version
string is mechanical.

### 3. Verify each claim

Work the lanes per [sources.md](sources.md). One verdict per claim:

| Verdict | Meaning |
| --- | --- |
| **TRUE** | Confirmed against its lane, with the artifact recorded. |
| **FALSE** | Contradicted by its lane. Record the correct value if the lane gives one. |
| **STALE** | Was true, has been superseded. Record what superseded it, if reachable. |
| **UNREACHED** | The claim has a lane, but the source could not be reached. Record why. |

Lane-`none` claims get no verdict here; nothing could refute them, so step 3
skips them.

Two outcomes fall outside the table and go straight to step 5: the lane shows the
**code is broken and the doc describes the intent correctly**, and **two lanes
disagree with each other**. Both are findings about the repo, not about the doc.

**Every verdict carries evidence from this session** — see *The evidence rule* in
[sources.md](sources.md). A verdict without an artifact is a guess wearing a
verdict's clothes, and it is the single way this skill does damage: it "corrects"
a right doc into a wrong one.

Verification routes to `opus` — deciding what an artifact actually proves is
judgment, and a cheap pass moves the cost to a wrong fix.

### 4. Cross-doc consistency — a barrier

Wait for every verifier, then reason over the merged claim table yourself. Do not
delegate: a worker seeing one directory cannot detect a contradiction spanning
two, which is the whole point of the pass.

- **Contradictions** — two docs asserting incompatible values for one thing.
  Lane-`none` claims count here, and only here.
- **Drifted duplicates** — the same claim in two wordings, one of them stale.
- **Anchors and external URLs** — the half a link checker skips: `#` fragments
  that no heading matches, and URLs that 404 or redirect somewhere unrelated.

Structural findings — orphan files, over-splitting, inconsistent naming — belong
to `/distill` and `/cleanup`. Note them in passing if they are glaring; do not
act on them.

### 5. Triage

The fix decision, and the guard against inventing content:

| Finding | Action |
| --- | --- |
| FALSE, and the lane gave the correct value | **Fix** — replace with the verified value |
| STALE, and the current value is verified | **Fix** |
| Dead internal link or anchor, correct target or heading found | **Fix the link or the fragment** |
| Dead internal link or anchor, no target exists | **Delete the link**, or the sentence carrying it |
| Dead external URL, current official URL verified | **Fix the URL** |
| Dead external URL, no replacement found | **Delete the link**, keep the surrounding claim if it still verifies |
| Two docs contradict, one side verified | **Fix the losing side**, report both locations |
| Two docs contradict, neither verified | **Report only** — never pick a winner |
| Drifted duplicate, one copy verified stale | **Fix or delete the stale copy**, never both copies |
| FALSE or STALE, and the correct value is unknown | **Delete the claim**, and report the deletion |
| UNREACHED | **Leave it. Report it.** Unreached is not false |
| The doc is right and the code is wrong | **Report only** — never edit code to fit a doc |
| Two lanes disagree about the same fact | **Report only** — a repo finding, never a doc edit |

**Tripwire.** If proposed fixes plus deletions exceed roughly a tenth of the
extracted claims, stop and ask before applying. At that rate the likelier
explanation is a wrong baseline — wrong branch, wrong host, a submodule not
checked out — not a corpus that rotted that far.

### 6. Fix

- **The smallest edit that makes the claim true.** Change the wrong value, not
  the paragraph around it.
- **Never grow a file.** A correction replaces; it does not elaborate. If a fix
  makes a file longer, you are writing, not correcting — and you are undoing the
  distillation that preceded you.
- **Keep the file's voice.** No restyling, no re-explaining, no added caveats.
- Fan out with `sonnet` — the triage table already names the file, the line, and
  the new value — under the partitioning rules in
  [../distill/parallelism.md](../distill/parallelism.md#apply-stage-partitioning).

### 7. Report and commit

Report, in this order:

1. **The numbers** — claims extracted, verified, fixed, deleted, unreached; the
   lane-`none` count as a single line; and the HEAD sha that was audited.
2. **Every fix** — `file:line`, was → now, and the artifact that settled it.
   Corrections are the deliverable; they never get aggregated away.
3. **Contradictions** left unresolved, and lane disagreements, both locations.
4. **UNREACHED claims**, each with the reason its lane could not be reached.
5. **Every FLAG inherited from the handoff commit**, by name, with what it
   resolved to — including `lane none — unfalsifiable`. The one-line lane-`none`
   count never absorbs an inherited FLAG: a prior session escalated it
   deliberately, and silently dropping it defeats the handoff.

Then commit — one commit, `docs: correct <scope> against verified sources`, body
listing the substantive corrections and every UNREACHED claim, so the next
session inherits them the way this one inherited distill's FLAGs. Push only if
HEAD is a feature branch; never push `main` / `master`.

**report-only** produces the report and stops. Nothing is edited, nothing is
committed.

## Constraints

- **Never assert a verdict without an artifact from this session.** Not a
  recollection, not a plausible inference, not "this is standard".
- **Never fabricate a replacement value.** If the lane did not yield the correct
  value, the claim gets deleted or reported — never rewritten into a guess.
- **Never run anything that changes state**, and **never treat the local machine
  as the target host** — the allowed and forbidden commands, and the host caveat,
  are in *Lane 2* of [sources.md](sources.md).
- **A doc never verifies a doc.** A second file repeating a claim is corroboration
  of nothing; it is usually the copy that drifted.
- **Never touch code to make a doc true.** Comments and docstrings are prose and
  in scope; the statements around them are not.
- **Never resolve an unverified contradiction.** Two docs disagreeing with no
  reachable source is a finding for the user, not a coin flip.
- **Unreached is not false.** Deleting what you failed to reach is how this skill
  loses the tribal knowledge that has no source of truth to link to.
- **Never re-open the distillation's decisions.** A deleted file stays deleted, a
  kept file is not re-argued, and content is never cut for being wordy. Only
  truth is on the table.
- **Never edit generated documentation.** Fix the generator or report it.
- **One commit, at the end.** Fixes are never committed incrementally — the whole
  sweep is one reviewable diff against the state it audited.

## Quality

- Before presenting results, run the shared [self-review checklist](../quality.md).
  Surface issues in the chat only if found.
