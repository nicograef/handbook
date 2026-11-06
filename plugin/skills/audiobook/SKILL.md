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
- Length is a budget. The listener hears every sentence once at a fixed pace, so each one costs listening time.
  The book runs at most `minutes` from `meta.yml`, a chapter at most 15. Over budget, cut content; the budget stays. A review round that grows the book is a defect.
- Every theory claim traces to `sources.md` with URL and date; nothing from memory.
- The checkpoint is the only interaction. Afterwards decide, record it under "Assumptions" in `PLAN.md`, and keep going.
- ElevenReader narrates everything in the EPUB. Chapters hold no code block, table, diagram, URL or footnote; resolve them into prose.
- The Lua filter only deletes what slipped through; it does not translate.
- Book prose follows "Writing for the ear", not the repo's sentence and paragraph caps.
- `slop-de.txt` never enters a writer brief: naming a phrase primes the model to write it. Reviewers work from the hits.
- `book.epub` is a gitignored build artifact; the chapter Markdown is the source. Upload nothing.

## Steps

1. Scope from the argument and the repo. A whole-repo subject narrows to the subsystem carrying the most concepts.
2. Inventory the code and docs on the subject. Name the gaps: missing theory, silent decisions, open questions.
3. Checkpoint before research, the first expensive step. Propose defaults for scope (in and out), guiding questions, prior knowledge, du or Sie, and listening time (90 minutes). The questions fit that time.
   A bare "ja" starts the run. Write the answers to `BRIEF.md`. Chapters, order, depth and terms are derived, never asked.
4. Research each open question through the `nico:web-researcher` agent. Theory reaches back only as far as a chapter's question needs.
   Collect three to five passages of human spoken German explanation into `voice.md`, with sources. Take them from before 2023, such as radio transcripts.
5. Write `PLAN.md`: chapters in concept-dependency order, never repo layout, each with its question, prerequisites, minutes and surprise.
   The surprise is what the listener would not guess. A chapter without one merges into another or goes.
   Rank concepts by what the guiding questions need; what misses the budget goes under "Out of scope" in `PLAN.md`.
   Every guiding question is covered within the budget; one that does not fit goes there too and into the report. Write `terms.yml` (`term: NN-slug.md`, the chapter that explains it) and `meta.yml` (`title`, `creator`, `lang`, `minutes`).
6. Write the chapters as `NN-slug.md` with one H1 each. Anchor every concept in a named file or decision, carried through one concrete case.
   Brief each writer in German prose, not bullets, with the reason: a voice reads it once. Pass it `BRIEF.md`, its `PLAN.md` line and its `sources.md` entries.
   Add the rules of "Writing for the ear", the terms explained so far and the previous chapter's last paragraph.
   Add the `voice.md` passages in `<example>` tags, marked as tone only. The size target is its minutes times 1000 characters.
   Then run `${CLAUDE_SKILL_DIR}/check-prose.sh <dir>` for the minutes. Over budget, drop the lowest-ranked concepts to "Out of scope" before round A.
7. Review in three rounds, one dimension each. An edit outside its dimension is a defect.
   - A, correctness, per chapter: check against the code and `sources.md`. An unsourced claim gets a source or goes.
   - B, structure and terms, once over the book: fix every `${CLAUDE_SKILL_DIR}/check-terms.sh <dir>` hit by moving the explanation or the chapter.
   - C, cut and language, per chapter, from the hits of `${CLAUDE_SKILL_DIR}/check-prose.sh <dir>`. The reviewer returns spans, each with a deletion or a plainer phrase.
     Every hit goes, and the chapter loses at least a tenth: redundancy, filler, recaps. Recall clauses and named actors stay; no claim, term or order changes.
     Re-check its changed claims against `sources.md`; revert breaks to the B wording.
8. Render with `${CLAUDE_SKILL_DIR}/md-to-epub.sh --strict <dir> <dir>/book.epub`; it runs `check-prose.sh` first. A finding is a chapter bug: fix the chapter, re-render.
9. Report the assumptions, every unverified claim and every drift from `BRIEF.md` with its reason. Give the minutes after writing and each round.
   Advise a multilingual ElevenReader voice; a German-only one mangles English terms. Name the terms worth an entry in its Pronunciations list.

## Writing for the ear

The listener hears each sentence once, in order, and cannot scroll back.

- Narration is German. Technical terms, identifiers and product names stay English, unchanged; the listener searches for them later.
- A term is explained once, in its `terms.yml` chapter. On first use in a later chapter, recall it in one German clause.
- Established loanwords (Server, Code, Commit) need no gloss. Spell out acronyms on first use.
- Speak identifiers (`user_id` is "user id"). Say paths, flags, symbols, versions, units, times and abbreviations in words, or leave them out. No parentheses or slashes.
- The narrator is a colleague who knows the system and holds opinions. They call an odd design odd, weigh alternatives and admit what nobody knows. `BRIEF.md` fixes du or Sie.
- Open each chapter on what the listener already knows, then raise its question. End once, on what the listener can now decide or do; no recap. One concept per chapter.
- Signpost a turn by its content, never by the text's structure. Name a thing before using it, then repeat the name instead of a synonym.
- Say what you mean: a literal statement beats a metaphor, a reason beats an evaluative adjective.
- One thought per sentence, at most one subordinate clause, the actor named. Vary the length; use a fragment where speech would.
  Keep the German verb close to its subject; verbs beat noun chains. Round figures and relate them.
- A paragraph is one spoken unit of several sentences; ElevenReader narrates per paragraph.
