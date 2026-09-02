# Listenability

Rules for prose that is heard once, in order, with no way to scroll back.

## The test

Read the sentence aloud. If you would not say it that way to a colleague on a
walk, rewrite it.

## Element rules

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

## Writing for the ear

| Rule | Why |
| --- | --- |
| Repeat the core claim at the start and the end of a chapter | A listener drifts |
| Signpost transitions in words ("more on that shortly") | No visual structure to navigate |
| One idea per sentence, but full sentences | Telegram style sounds rushed when spoken |
| Prefer active voice and concrete subjects | Passive chains are hard to follow by ear |
| Spell out numbers that matter, skip the rest | "Version 17" yes, "v2.1.197" almost never |
| Name a thing before you use it | The listener cannot jump to the definition |

Paragraphs may run longer than the handbook prose cap
([named exception](../output-style.md#named-prose-exceptions)). The ≤ 20-word
sentence cap still applies.

## Chapter shape

- Never trim, summarise, or merge chapters to hit a size.
- Open with the question the chapter answers, in one sentence.
- Close with what the listener should now be able to decide or do.
- One concept per chapter. Two concepts means two chapters.

## Anti-patterns

| Anti-pattern | Fix |
| --- | --- |
| Reading the existing doc aloud | Rewrite from the concept, not from the doc |
| Theory with no anchor in the project | Tie each concept to a named file or decision |
| Project tour with no theory | The listener already has the repo. Give the model behind it |
| API reference as narration | Reference material is for reading, not listening |
| A bare back-reference to an earlier chapter | Restate the point in one clause |
