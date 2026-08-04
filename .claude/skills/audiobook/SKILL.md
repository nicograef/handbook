---
name: audiobook
description: Plans, researches, structures, writes, and reviews an explanatory audiobook about a codebase or a topic, then renders it as an ElevenReader-ready EPUB. Confirms scope, focus, and prior knowledge once, then runs to completion. Use when the user wants to build deeper understanding of a system or a subject by listening instead of reading.
argument-hint: "<subject or project area> [→ output dir, default audiobook/]"
---

Audiobook subject: **$ARGUMENTS**

The deliverable is understanding, not narrated documentation. Generated docs
describe *what* a system does. This book explains *why it works that way*, in an
order a listener can follow from nothing.

One checkpoint, at step 4. Everything after it runs to completion without
stopping. Every decision not covered by that checkpoint goes into `PLAN.md`
as a stated assumption, and into the final report.

Never write chapters before step 7 is complete. Research and structure first.

- Pipeline and rendering: [guides/audiobook-pipeline.md](../../../guides/audiobook-pipeline.md)
- The step 4 checkpoint: [the-checkpoint.md](the-checkpoint.md)
- Prose rules for the ear: [listenability.md](listenability.md)
- German prose, English terms: [german-narration.md](german-narration.md)
- Review contracts: [review-rounds.md](review-rounds.md)

## Artifacts

Everything lands in the output directory, default `audiobook/`. Each artifact is
the input of a later step, so the run survives an interruption.

| File | Written in step | Purpose |
| --- | --- | --- |
| `BRIEF.md` | 4 | Confirmed scope, guiding questions, prior-knowledge level |
| `research-plan.md` | 5 | Open questions, prioritised, with what would answer them |
| `sources.md` | 6 | One entry per claim: statement, source URL, as-of date |
| `PLAN.md` | 7 | Chapter list, the question each answers, dependency order |
| `terms.yml` | 7 | `term: chapter-file` — where each term is first explained |
| `NN-slug.md` | 8 | One chapter per file, single H1 |
| `meta.yml` | 7 | `title`, `creator`, `lang` |

## Workflow

### Understand

1. **Draft the scope.** Derive it from the argument and the repository.
   - A whole-repo subject narrows to the subsystem carrying the most concepts.
   - Length is never a scoping input. There is no target length.
2. **Inventory.** Read the code and docs that touch the subject.
   - List every concept in play, each with the file where it lives.
   - Record decisions the code makes silently. They become chapter hooks.
3. **Name the gaps.** State what the docs assume but never explain.
   - This gap is the book. Anything already documented is filler.
   - Separate three kinds: missing theory, undocumented decision, open question.

### Confirm

4. **The one checkpoint.** Ask before the first expensive step, never after.
   - Full contract: [the-checkpoint.md](the-checkpoint.md).
   - Three items only: scope boundary, guiding questions, prior knowledge.
   - Propose a concrete default for each. A bare "ja" must be a valid answer.
   - Write the answers to `BRIEF.md`, then run to the end without stopping.

### Research

5. **Write `research-plan.md`.** One entry per open question.
   - Prior knowledge from `BRIEF.md` sets how far back the theory reaches.
   - Give each question a priority and the kind of source that would settle it.
   - Cover the theory behind the code, not the code itself.
6. **Execute it.** Delegate to the **web-researcher** subagent
   (`../../agents/web-researcher.md`).
   - Never write theory from memory. Every claim traces to `sources.md`.
   - Record per-claim source URL and as-of date; label anything unverified.

### Structure

7. **Build the plan.** Turn concepts into a dependency-ordered chapter list.
   - Every guiding question from `BRIEF.md` is answered by some chapter.
   - A concept may only appear after everything it depends on.
   - Chapter order follows the concept graph, never the repository layout.
   - Write `PLAN.md`: per chapter the question it answers and its prerequisites.
   - Write `terms.yml`: every term mapped to the chapter that first explains it.
   - Write `meta.yml`: `title`, `creator`, `lang` (`de` for German narration).
   - Record every decision the checkpoint did not cover under "Assumptions".
   - Continue straight into step 8. `PLAN.md` is the record, not a request.

### Write

8. **Write the chapters.** One file per chapter, `NN-slug.md`, single H1.
   - Follow [listenability.md](listenability.md) for every visual element.
   - Follow [german-narration.md](german-narration.md) for terms and glosses.
   - Resolve tables, diagrams, and code into prose here. This is the only step
     that can do it; the Lua filter deletes, it does not translate.
   - Anchor each concept in a named file or decision from step 2.
   - Write to completion. Length is whatever the subject needs.

### Review

Three rounds, one dimension each, in this order. Details and per-round contracts:
[review-rounds.md](review-rounds.md).

9. **Round A — correctness.** Per chapter, in parallel.
   - Check every claim against `sources.md` and against the code.
   - Fix the chapter directly. Add missing sources to `sources.md`.
10. **Round B — structure and terms.** Once, over the whole book.
    - Verify the dependency order still holds after Round A.
    - Check every `BRIEF.md` guiding question is actually answered.
    - Run `scripts/check-terms.sh <dir>`; fix every use-before-explained hit.
11. **Round C — language and flow.** Per chapter, in parallel.
    - Read for the ear only. Do not touch facts, order, or terminology.
    - Never cut for length. Repetition that serves the listener stays.
12. **Re-check the Round C diff.**
    - Language edits can silently break a factual claim.
    - Verify only what Round C changed, against `sources.md`.
    - A broken claim goes back to Round A wording, not to a new rewrite.

### Render

13. **Lint and render.** Run
    [scripts/md-to-epub.sh](../../../scripts/md-to-epub.sh) with `STRICT=1`.
    - A lint finding here is a bug in step 8, not something to strip.
    - Fix the chapter source and re-render.
    - Report chapters, total listening time, and the upload step.
    - Report the `PLAN.md` assumptions and every claim left unverified.
    - Name anything that drifted from `BRIEF.md`, and why.

## Constraints

- Step 4 is the only interaction. After it, never stop for anything.
- Never ask about chapters, order, theory depth, terminology, or length.
- Anything the checkpoint did not cover is decided, recorded, and reported.
- No length target, no chapter count target, no minutes-per-chapter target.
- Never shorten, summarise, or trim a chapter to hit a size.
- Never paste a code block, table, or diagram source into a chapter.
- Never walk the repository file by file. That is a tour, not a chapter.
- Never restate an existing doc in longer sentences. Rewrite from the concept.
- Exactly three review rounds. No "until it is good" loop.
- Chapter prose is exempt from the handbook sentence and paragraph caps.
- The EPUB is a build artifact. Gitignore it; keep the chapter Markdown.
- Do not upload anything. The reader ingest step is the user's.

## Quality

- Verification contract: [../quality.md](../quality.md).
- Report style: [../output-style.md](../output-style.md). Applies to the chat
  report only, never to chapter prose.
