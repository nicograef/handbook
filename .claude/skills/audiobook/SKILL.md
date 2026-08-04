---
name: audiobook
description: Plans, researches, structures, writes, and reviews an explanatory audiobook about a codebase or a topic, then renders it as an ElevenReader-ready EPUB. Use when the user wants to build deeper understanding of a system or a subject by listening instead of reading.
argument-hint: "<subject or project area> [→ output dir, default audiobook/]"
---

Audiobook subject: **$ARGUMENTS**

The deliverable is understanding, not narrated documentation. Generated docs
describe *what* a system does. This book explains *why it works that way*, in an
order a listener can follow from nothing.

Never write chapters before step 6 is approved. Research and structure first.

- Pipeline and rendering: [guides/audiobook-pipeline.md](../../../guides/audiobook-pipeline.md)
- Prose rules for the ear: [listenability.md](listenability.md)
- German prose, English terms: [german-narration.md](german-narration.md)
- Review contracts: [review-rounds.md](review-rounds.md)

## Artifacts

Everything lands in the output directory, default `audiobook/`. Each artifact is
the input of a later step, so the run survives an interruption.

| File | Written in step | Purpose |
| --- | --- | --- |
| `research-plan.md` | 4 | Open questions, prioritised, with what would answer them |
| `sources.md` | 5 | One entry per claim: statement, source URL, as-of date |
| `PLAN.md` | 6 | Chapter list, the question each answers, dependency order |
| `terms.yml` | 6 | `term: chapter-file` — where each term is first explained |
| `NN-slug.md` | 7 | One chapter per file, single H1 |
| `meta.yml` | 6 | `title`, `creator`, `lang` |

## Workflow

### Understand

1. **Scope.** Confirm subject and depth before anything else.
   - Ask which subsystem or which concepts when the subject is a whole repo.
   - Do not ask about length. There is no target length.
2. **Inventory.** Read the code and docs that touch the subject.
   - List every concept in play, each with the file where it lives.
   - Record decisions the code makes silently. They become chapter hooks.
3. **Name the gaps.** State what the docs assume but never explain.
   - This gap is the book. Anything already documented is filler.
   - Separate three kinds: missing theory, undocumented decision, open question.

### Research

4. **Write `research-plan.md`.** One entry per open question.
   - Give each question a priority and the kind of source that would settle it.
   - Cover the theory behind the code, not the code itself.
5. **Execute it.** Delegate to the **web-researcher** subagent
   (`../../agents/web-researcher.md`).
   - Never write theory from memory. Every claim traces to `sources.md`.
   - Record per-claim source URL and as-of date; label anything unverified.

### Structure

6. **Build the plan.** Turn concepts into a dependency-ordered chapter list.
   - A concept may only appear after everything it depends on.
   - Chapter order follows the concept graph, never the repository layout.
   - Write `PLAN.md`: per chapter the question it answers and its prerequisites.
   - Write `terms.yml`: every term mapped to the chapter that first explains it.
   - Write `meta.yml`: `title`, `creator`, `lang` (`de` for German narration).
   - **Present `PLAN.md` and stop. Do not write chapters without approval.**

### Write

7. **Write the chapters.** One file per chapter, `NN-slug.md`, single H1.
   - Follow [listenability.md](listenability.md) for every visual element.
   - Follow [german-narration.md](german-narration.md) for terms and glosses.
   - Resolve tables, diagrams, and code into prose here. This is the only step
     that can do it; the Lua filter deletes, it does not translate.
   - Anchor each concept in a named file or decision from step 2.
   - Write to completion. Length is whatever the subject needs.

### Review

Three rounds, one dimension each, in this order. Details and per-round contracts:
[review-rounds.md](review-rounds.md).

8. **Round A — correctness.** Per chapter, in parallel.
   - Check every claim against `sources.md` and against the code.
   - Fix the chapter directly. Add missing sources to `sources.md`.
9. **Round B — structure and terms.** Once, over the whole book.
   - Verify the dependency order still holds after Round A.
   - Run `scripts/check-terms.sh <dir>`; fix every use-before-explained hit.
10. **Round C — language and flow.** Per chapter, in parallel.
    - Read for the ear only. Do not touch facts, order, or terminology.
    - Never cut for length. Repetition that serves the listener stays.
11. **Re-check the Round C diff.** Automatic, no approval needed.
    - Language edits can silently break a factual claim.
    - Verify only what Round C changed, against `sources.md`.
    - A broken claim goes back to Round A wording, not to a new rewrite.

### Render

12. **Lint and render.** Run
    [scripts/md-to-epub.sh](../../../scripts/md-to-epub.sh) with `STRICT=1`.
    - A lint finding here is a bug in step 7, not something to strip.
    - Fix the chapter source and re-render.
    - Report chapters, total listening time, and the upload step.

## Constraints

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
