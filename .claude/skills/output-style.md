# Output Style Contract

Shared output contract for the handbook. Skills that emit a report or an artifact link here
from their **Quality** section, beside [`quality.md`](quality.md).

Scope: chat responses, skill artifacts, repo docs, commit messages, PR bodies.

## Hard caps

| Rule | Cap |
| --- | --- |
| Sentence | ≤ 20 words, one claim |
| Paragraph | ≤ 3 lines, ≤ 1 per section |
| Bullet | ≤ 2 lines |
| Table trigger | ≥ 3 items sharing ≥ 2 attributes |
| List trigger | any enumerable set of ≥ 2 items |
| Format order | table → list → paragraph |

## Banned in output

- Preamble and scene-setting.
- Restating the question or the task.
- Closing recap of what was just said.
- Transition sentences between sections.
- Hedges that do not change the next action.

## Compression removes words, never content

- Never drop a rule, condition, exception, or caveat to hit a cap.
- Split into more bullets instead.
- A rewrite keeps the rule count; only the word count falls.

## Report shape

Applies to every review, audit, or findings report.

1. Counts line first: `3 findings — 1 high, 2 low`.
2. Findings as a table, or one bullet per finding with fixed fields.
3. Each bullet opens with a bold keyword, then the fact.
4. Zero findings: one line, no padding.

## Named prose exceptions

Prose paragraphs are allowed only here. The ≤ 20-word sentence cap still applies.

| Location | Why |
| --- | --- |
| [`tutor/SKILL.md`](tutor/SKILL.md) — hint ladders, post-answer explanations | Teaching needs connected reasoning |
| [`understand/SKILL.md`](understand/SKILL.md) — step 6 explanation | Holistic narrative is the deliverable |
| [`guided-implementation/SKILL.md`](guided-implementation/SKILL.md) — What/Why/How review text | Coaching is the deliverable |
| [`write-prd/SKILL.md`](write-prd/SKILL.md) — problem statement, user stories | PRD readers are non-technical |
| [`cleanup/readability.md`](cleanup/readability.md), [`readability-de.md`](cleanup/readability-de.md) — example phrases | Illustrative bad/good prose |

New exceptions require an edit here, never a local override.

## Enforcement

`make prose` flags paragraphs of ≥ 4 lines and sentences over 20 words across tracked Markdown.
