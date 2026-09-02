---
name: audiobook
description: Plans, researches, structures, writes, and reviews an explanatory audiobook about a codebase or a topic, then renders it as an ElevenReader-ready EPUB. Confirms scope, focus, and prior knowledge once, then runs to completion. Use when the user wants to build deeper understanding of a system or a subject by listening instead of reading.
argument-hint: "<subject or project area> [→ output dir, default audiobook/]"
---

Audiobook subject: **$ARGUMENTS**

Never write chapters before step 7 is complete. Research and structure first.

- Pipeline and rendering: [guides/audiobook-pipeline.md](../../../guides/audiobook-pipeline.md)
- Prose rules for the ear: [listenability.md](listenability.md)
- German prose, English terms: [german-narration.md](german-narration.md)
- Review contracts: [review-rounds.md](review-rounds.md)

## Workflow

### Understand

1. **Draft the scope.** Derive it from the argument and the repository.
   - A whole-repo subject narrows to the subsystem carrying the most concepts.
   - Length is never a scoping input.
2. **Inventory.** Read the code and docs that touch the subject.
   - List every concept in play, each with the file where it lives.
   - Record decisions the code makes silently. They become chapter hooks.
3. **Name the gaps.** State what the docs assume but never explain.
   - This gap is the book. Anything already documented is filler.
   - Separate three kinds: missing theory, undocumented decision, open question.

### Confirm

4. **The one checkpoint.** Ask before the first expensive step, never after.
   - Earlier the proposal would be a guess, with no inventory behind it.
   - Later the research is already paid for, and a wrong scope wastes all of it.
   - Research is the first expensive step. The checkpoint guards exactly that line.
   - Three items only: scope boundary, guiding questions, prior knowledge.
   - Offer prior-knowledge levels the user can pick without thinking.
   - For example: new to the domain; working knowledge but no theory; solid
     theory, only this system is new.
   - Propose a concrete default for all three items. Never ask an open question.
   - A bare "ja" must be a complete, valid answer that starts the run.
   - Present the scope as in-scope and out-of-scope, both named explicitly.
   - List the guiding questions as the questions the book will answer.
   - Ask all three in one interaction. Never split them across turns.
   - Never ask about what is derived, not decided:

   | Never ask | Derived from |
   | --- | --- |
   | Chapter count, chapter titles | The concept graph in step 7 |
   | Chapter order | Concept dependencies, never the repo layout |
   | How much theory prelude | The prior-knowledge answer |
   | Terminology, glosses, language | [german-narration.md](german-narration.md) |
   | Length, minutes, word count | Nothing. There is no length target |

   - Write the answers to `BRIEF.md`, then run to the end without stopping.
   - `Scope` — what is in, what is out, in the user's own framing.
   - `Guiding questions` — the numbered list the book has to answer.
   - `Prior knowledge` — the chosen level, in one line.
   - `Changed by the user` — what the answer changed against the proposal.
   - `BRIEF.md` is read again in step 7 and in Round B. It is the contract for
     the run, not a transcript.
   - The run does not stop again, not even when research contradicts the brief.
   - A contradiction is recorded in `PLAN.md` under "Assumptions", not escalated.
   - The final report names every drift from `BRIEF.md` and the reason.
   - If research invalidates a guiding question, answer why it cannot be answered.

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
   - Write `terms.yml`: one `term: chapter-file.md` line per term, mapped to
     the chapter that first explains it.
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
   - Write to completion.

### Review

Three rounds, one dimension each, in this order. Details and per-round contracts:
[review-rounds.md](review-rounds.md).

9. **Round A — correctness.** Per chapter, in parallel.
10. **Round B — structure and terms.** Once, over the whole book.
    - Run `<handbook>/scripts/check-terms.sh <dir>`; fix every use-before-explained hit.
11. **Round C — language and flow.** Per chapter, in parallel.
12. **Re-check the Round C diff.**

### Render

13. **Lint and render.** Run
    [scripts/md-to-epub.sh](../../../scripts/md-to-epub.sh) with `STRICT=1`.
    - A lint finding here is a bug in step 8, not something to strip.
    - Fix the chapter source and re-render.
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
