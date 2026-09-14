---
name: audiobook
description: Researches, structures, writes and reviews an explanatory audiobook about a codebase or topic, then renders an ElevenReader-ready EPUB. One checkpoint, then it runs to completion. Use when the user wants to understand a system by listening.
argument-hint: "<subject or project area> [→ output dir, default audiobook/]"
disable-model-invocation: true
---

# Audiobook

Subject: **$ARGUMENTS**. Pipeline and rendering: [guides/audiobook-pipeline.md](../../../guides/audiobook-pipeline.md). Prose rules, German narration and review contracts: [writing.md](writing.md).

## Hard rules

- The book is the gap: what the docs assume but never explain. Anything already documented is filler. Rewrite from the concept, never restate a doc in longer sentences, never walk the repo file by file.
- No length target of any kind, and no trimming to hit one.
- Chapters contain no code block, table or diagram source. Resolve them into prose at writing time; the Lua filter deletes, it does not translate.
- Every theory claim traces to `sources.md` with URL and date; nothing from memory.
- Step 4 is the only interaction. Afterwards, decide, record under "Assumptions" in `PLAN.md`, and report; do not stop again.
- Exactly three review rounds. Chapter prose is exempt from the sentence and paragraph caps.
- The EPUB is a gitignored build artifact; chapter Markdown is the source. Upload nothing.

## Workflow

1. Scope from the argument and the repo; a whole-repo subject narrows to the subsystem carrying the most concepts.
2. Inventory the code and docs touching the subject: every concept with its file, every decision the code makes silently.
3. Name the gaps: missing theory, undocumented decisions, open questions.
4. Checkpoint, one interaction before research, the first expensive step. Propose concrete defaults for exactly three items, so a bare "ja" starts the run. Scope: in and out, both named. Guiding questions: numbered. Prior knowledge: offer levels like new to the domain, working knowledge without theory, solid theory but new here. Write the answers to `BRIEF.md` (`Scope`, `Guiding questions`, `Prior knowledge`, `Changed by the user`). Never ask about chapter count, titles, order, theory depth, terminology or length; those are derived.
5. Write `research-plan.md`: one entry per open question, with priority and the kind of source that settles it. Prior knowledge sets how far back the theory reaches.
6. Execute it through the web-researcher agent, recording every claim in `sources.md`.
7. Build `PLAN.md`: chapters in concept-dependency order (never repo layout), each with the question it answers and its prerequisites. Every guiding question is covered. Write `terms.yml` (`term: chapter-file.md`, the chapter that first explains it) and `meta.yml` (`title`, `creator`, `lang`, `de` for German). Record assumptions.
8. Write the chapters, `NN-slug.md`, single H1, per [writing.md](writing.md), anchoring each concept in a named file or decision.
9. Round A, correctness, per chapter in parallel. 10. Round B, structure and terms, once over the book, running `scripts/check-terms.sh <dir>`. 11. Round C, language and flow, per chapter in parallel. 12. Re-check only the Round C diff against `sources.md`, reverting broken claims to the Round B wording.
13. Render with `scripts/md-to-epub.sh` and `STRICT=1`. A lint finding is a bug in step 8: fix the chapter, re-render. Report the assumptions, every unverified claim, and every drift from `BRIEF.md` with its reason.
