# Review Rounds

- [Why the order is fixed](#why-the-order-is-fixed)
- [Round A — correctness](#round-a--correctness)
- [Round B — structure and terms](#round-b--structure-and-terms)
- [Round C — language and flow](#round-c--language-and-flow)
- [Step 11 — re-check the C diff](#step-11--re-check-the-c-diff)
- [Drift guards](#drift-guards)

Three rounds, one dimension each. A round that edits outside its dimension is a
defect, not initiative.

## Why the order is fixed

Correctness first, because there is no point polishing a false sentence.
Language last, because it is the only round that may rewrite wording freely.
Step 11 exists because that freedom is exactly what breaks facts.

## Round A — correctness

Runs per chapter, chapters in parallel.

| May change | Must not change |
| --- | --- |
| A factually wrong statement | Chapter order |
| A claim with no entry in `sources.md` | Which chapter covers what |
| A code reference that no longer matches the repo | Sentence rhythm or register |

- Check every technical claim against `sources.md` and against the code.
- A claim with no source is either sourced now or deleted.
- Reading the code is required. `sources.md` covers theory, not this repo.
- Append new findings to `sources.md` with URL and as-of date.
- Label anything that stayed unverified. Do not quietly keep it.

## Round B — structure and terms

Runs once, over the whole book, after every chapter passed Round A.

- Verify the dependency order in `PLAN.md` still holds after Round A edits.
- Run `scripts/check-terms.sh <dir>`; every use-before-explained hit gets fixed.
- Two fixes are legitimate: move the explanation earlier, or move the chapter.
- Adding a second explanation of the same term is not a fix. It is drift.
- Update `terms.yml` when an explanation moves.

Structural moves change chapter numbering. Renumber files, then re-run the check.

## Round C — language and flow

Runs per chapter, chapters in parallel, after Round B settled the order.

| May change | Must not change |
| --- | --- |
| Sentence structure, rhythm, connectives | Any technical claim |
| Passive constructions, nominal style | Any term or its gloss |
| Transitions between sections | Chapter order or scope |

- Read every paragraph aloud. Rewrite what you would not say that way.
- **Never cut for length.** Repetition that serves the listener stays.
- Compression is the default failure here. Resist it.
- Leave the terminology alone. Round B owns it.

## Step 11 — re-check the C diff

Automatic. No approval, no user question.

1. Diff each chapter against its Round B state.
2. For every changed sentence carrying a claim, verify against `sources.md`.
3. A broken claim reverts to the Round B wording. Do not rewrite it a third time.

Only changed sentences are checked. A full re-read here wastes a pass and
invites new edits.

## Drift guards

| Symptom | Cause | Fix |
| --- | --- | --- |
| Round C undid a Round A correction | Round C touched facts | Revert, keep A wording |
| A term is explained twice | Round B added instead of moving | Delete the later gloss |
| Chapters got shorter each round | Reviewers compressing by habit | Revert; length is not a metric |
| A claim lost its source | Round A deleted the entry, not the claim | Re-source or delete the claim |
