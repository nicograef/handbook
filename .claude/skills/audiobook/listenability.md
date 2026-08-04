# Listenability

- [The test](#the-test)
- [Element rules](#element-rules)
- [Writing for the ear](#writing-for-the-ear)
- [Chapter shape](#chapter-shape)
- [Anti-patterns](#anti-patterns)

Rules for prose that is heard once, in order, with no way to scroll back.
Reference doc conventions invert here: a written doc optimises for scanning,
a chapter optimises for a listener who cannot re-read.

## The test

Read the sentence aloud. If you would not say it that way to a colleague on a
walk, rewrite it.

## Element rules

Written docs carry meaning in layout. Speech has no layout, so every visual
element has to become prose or disappear.

| Element | Rule |
| --- | --- |
| Table | Linearise it. One sentence per row, column names as sentence parts |
| Bullet list | Write it out as ordinal prose, with connective sentences between items |
| Diagram (Mermaid, PlantUML) | Never the source. Narrate the flow as prose |
| Screenshot, chart | Describe the fact it shows, not the picture |
| Code block | Cut it. Say what the code does and why, in two or three sentences |
| Inline identifier | Spoken form: `user_id` becomes "user id" |
| Path, flag, env var | Name it in words, or leave it out |
| URL, citation | Drop it. Name the source in the sentence if it matters |
| Formula | Write it in words, or drop the formula and keep the consequence |
| Footnote | Fold it into the sentence, or delete it |
| Heading | One H1 per chapter file. H2 for sections. No deeper |

The lint in [scripts/md-to-epub.sh](../../../scripts/md-to-epub.sh) reports
violations by file and line. The Lua filter strips them at render time, but a
stripped table leaves a hole in the argument. Fix the source.

## Writing for the ear

| Rule | Why |
| --- | --- |
| Repeat the core claim at the start and the end of a chapter | A listener drifts |
| Signpost transitions in words ("more on that shortly") | No visual structure to navigate |
| One idea per sentence, but full sentences | Telegram style sounds rushed when spoken |
| Prefer active voice and concrete subjects | Passive chains are hard to follow by ear |
| Spell out numbers that matter, skip the rest | "Version 17" yes, "v2.1.197" almost never |
| Name a thing before you use it | The listener cannot jump to the definition |

Sentences may run longer than the handbook prose cap. Spoken sentences of 25 to
35 words read naturally. That cap governs repo docs, not chapter text.

## Chapter shape

- 1200 to 2500 words per chapter, roughly 8 to 15 minutes at 150 words a minute.
- Open with the question the chapter answers, in one sentence.
- Close with what the listener should now be able to decide or do.
- One concept per chapter. Two concepts means two chapters.

Order chapters so each one only needs what came before. A chapter that requires
a later one is misplaced.

## Anti-patterns

| Anti-pattern | Fix |
| --- | --- |
| Reading the existing doc aloud | Rewrite from the concept, not from the doc |
| Theory with no anchor in the project | Tie each concept to a named file or decision |
| Project tour with no theory | The listener already has the repo. Give the model behind it |
| API reference as narration | Reference material is for reading, not listening |
| A bare back-reference to an earlier chapter | Restate the point in one clause |
