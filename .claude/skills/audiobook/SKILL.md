---
name: audiobook
description: Turns a codebase, its Markdown docs, and fresh web research into listenable audiobook chapters and an ElevenReader-ready EPUB. Use when the user wants to build deeper understanding of a system or a topic by listening instead of reading.
argument-hint: "<subject or project area> [→ output dir, default audiobook/]"
---

Audiobook subject: **$ARGUMENTS**

The deliverable is understanding, not narrated documentation. Generated docs
describe *what* a system does. A chapter has to explain *why it works that way*,
using theory the docs never state.

Renders through [guides/audiobook-pipeline.md](../../../guides/audiobook-pipeline.md).
Prose rules: [listenability.md](listenability.md). Language rules:
[german-narration.md](german-narration.md).

## Workflow

1. **Scope.** Confirm subject, depth, and chapter count before writing anything.
   - Ask when the subject is a whole repo: which subsystem, which concepts.
   - Default output directory: `audiobook/`.
   - Default target: 5 to 8 chapters, 8 to 15 minutes each.
2. **Inventory the project.** Read the code and docs that touch the subject.
   - List the concepts actually in play, with the file where each one lives.
   - Record decisions the code makes silently — they become chapter hooks.
3. **Find the theory gap.** Name what the docs assume but never explain.
   - This gap is the book. Everything already documented is filler.
   - Delegate external grounding to the **web-researcher** subagent
     (`../../agents/web-researcher.md`).
   - Never write theory from memory. Cite what the research returned.
4. **Outline.** One concept per chapter, ordered so nothing needs a later chapter.
   - Present the outline and get approval before writing.
   - State for each chapter the question it answers.
5. **Write chapters.** One file per chapter, `NN-slug.md`, single H1.
   - Follow [listenability.md](listenability.md) for every visual element.
   - Follow [german-narration.md](german-narration.md) for terms and glosses.
   - Anchor each concept in a named file or decision from step 2.
6. **Write `meta.yml`** in the output directory: `title`, `creator`, `lang`.
7. **Render and fix.** Run
   [scripts/md-to-epub.sh](../../../scripts/md-to-epub.sh) on the directory.
   - Fix every lint finding in the chapter source, never in the output.
   - Check the reported per-chapter minutes against the target, then re-render.
8. **Hand off.** Report chapters, total listening time, and the upload step.

## Constraints

- Never paste a code block, table, or diagram source into a chapter.
- Never walk the repository file by file. That is a tour, not a chapter.
- Never restate an existing doc in longer sentences. Rewrite from the concept.
- Chapter prose is exempt from the handbook sentence and paragraph caps.
  Spoken sentences of 25 to 35 words are correct here.
- The EPUB is a build artifact. Gitignore it; keep the chapter Markdown.
- Do not upload anything. The reader ingest step is the user's.

## Quality

- Verification contract: [../quality.md](../quality.md).
- Report style: [../output-style.md](../output-style.md). Applies to the chat
  report only, never to chapter prose.
