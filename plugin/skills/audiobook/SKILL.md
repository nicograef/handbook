---
name: audiobook
description: Researches, structures, writes and reviews an explanatory audiobook about a codebase or topic, then renders an ElevenReader-ready EPUB. One checkpoint, then it runs to completion. Use when the user wants to understand a system by listening.
argument-hint: "<subject or project area> [→ output dir, default audiobook/]"
disable-model-invocation: true
---

# Audiobook

Subject: **$ARGUMENTS**. All files live in the output dir, default `audiobook/`.

## Hard rules

- The book is the gap: what the docs assume but never explain. Rewrite from the concept; never restate a doc or tour the repo.
- No length target, and no trimming to hit one. Chapters that shrink each review round mean reviewers compress by habit; revert.
- Every theory claim traces to `sources.md` with URL and date; nothing from memory.
- The checkpoint is the only interaction. Afterwards decide, record it under "Assumptions" in `PLAN.md`, and keep going.
- ElevenReader narrates everything in the EPUB. Chapters hold no code block, table, diagram, URL or footnote; resolve them into prose.
- The Lua filter only deletes what slipped through; it does not translate.
- Book prose is exempt from the sentence and paragraph caps.
- `book.epub` is a gitignored build artifact; the chapter Markdown is the source. Upload nothing.

## Steps

1. Scope from the argument and the repo. A whole-repo subject narrows to the subsystem carrying the most concepts.
2. Inventory the code and docs on the subject. Name the gaps: missing theory, silent decisions, open questions.
3. Checkpoint before research, the first expensive step. Propose defaults for scope (in and out), guiding questions and prior knowledge.
   A bare "ja" starts the run. Write the answers to `BRIEF.md`. Chapters, order, depth, terms and length are derived, never asked.
4. Research each open question through the `nico:web-researcher` agent. Prior knowledge sets how far back the theory reaches.
5. Write `PLAN.md`: chapters in concept-dependency order, never repo layout, each with its question and prerequisites.
   Every guiding question is covered. Write `terms.yml` (`term: NN-slug.md`, the chapter that explains it) and `meta.yml` (`title`, `creator`, `lang`).
6. Write the chapters as `NN-slug.md` with one H1 each. Anchor every concept in a named file or decision.
7. Review in three rounds, one dimension each. An edit outside its dimension is a defect.
   - A, correctness, per chapter: check against the code and `sources.md`. An unsourced claim gets a source or goes.
   - B, structure and terms, once over the book: fix every `${CLAUDE_SKILL_DIR}/check-terms.sh <dir>` hit by moving the explanation or the chapter.
   - C, language and flow, per chapter: no claim, term, order or length changes. Re-check its changed claims against `sources.md`; revert breaks to the B wording.
8. Render with `${CLAUDE_SKILL_DIR}/md-to-epub.sh --strict <dir> <dir>/book.epub`. A finding is a chapter bug: fix the chapter, re-render.
9. Report the assumptions, every unverified claim, and every drift from `BRIEF.md` with its reason. Advise a multilingual ElevenReader voice; a German-only one mangles English terms.

## Writing for the ear

The listener hears each sentence once, in order, and cannot scroll back.

- Narration is German. Technical terms, identifiers and product names stay English, unchanged; the listener searches for them later.
- A term is explained once, in its `terms.yml` chapter. On first use in a later chapter, recall it in one German clause.
- Established loanwords (Server, Code, Commit) need no gloss. Spell out acronyms on first use.
- Speak identifiers (`user_id` is "user id"). Say paths, flags, symbols and versions in words, or leave them out.
- Open each chapter with its question; close with what the listener can now decide or do. One concept per chapter.
- Repeat the core claim at start and end. Signpost transitions in words. Name a thing before using it.
- Short full sentences in active voice. Round figures and relate them.
