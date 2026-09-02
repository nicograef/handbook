# Question Design

Item-writing rules for tutor sessions. Both the main quiz loop and the setup subagent follow
them.

## Formats and mix

Match format to how the knowledge will be used.

| Knowledge type | Format |
| --- | --- |
| Definitions and APIs | Free-text |
| Trade-offs and failure modes | Single-choice |
| "Which of these apply" facts | Multiple-select |
| Procedures and design reasoning | Free-text |

- Target mix: ~50% single-choice, ~20% multiple-select, ~30% free-text recall.
- The free-text share can grow for advanced learners.
- Difficulty 1–3 per item: the learner's stated level plus one notch of desirable difficulty.
- That notch is enough to require thought, never beyond reach.
- Interleave concepts: never more than two consecutive items on the same concept.

## Writing choice items

- 3–4 options — three high-quality options beat a padded fourth.
- Every distractor must be plausible and encode a **real** misconception.
- Record which misconception in the key entry.
- No joke options, no "all of the above" / "none of the above".
- Options stay grammatically parallel, similar in length and tone.
- The correct option must never be the longest or most hedged one.
- Shuffle the correct position at generation time.
- The bank stores options in final order, so the quiz loop never reorders or learns anything.
- Use multiple-select only when the concept genuinely has multiple correct facets.
- Then the question text must say "select all that apply".

## AskUserQuestion mechanics

- One call per item. Question 1 = the item.
- `header` ≤ 12 chars, e.g. "Q3 · Go".
- Option `label` = the answer choice.
- `description` = neutral elaboration or empty.
- `description` holds to the same parallel-tone rule as options and never hints at correctness.
- `format: "multi"` items set `multiSelect: true` on question 1.
- The confidence question stays single-select.
- A multi answer returns as a list of labels — grade it against the key's answer array.
- **Never mark an option "(Recommended)".** That habit comes from clarification questions and
  is an instant answer leak here.
- Treat typed free text as their committed answer and grade it against the key entry.

## Scaffold sub-questions

- Each rung is an easier **question** isolating the single concept the wrong answer betrays.
- Use the distractor's misconception note to find that concept.
- The rung gives the learner a stepping stone back to the original item.
- Never a statement that walks toward the answer.
- Never so obvious that it contains the answer.
- Re-asks of any graded item — revealed, wrong, or guessed-correct — **rephrase, don't repeat**.
- Same concept, new surface: different scenario, inverted direction, applied context.

## Grounding and provenance

Every key entry carries provenance: `material` (the user's files), `web`
(fetched source — keep the URL), or `model` (trained knowledge).

- Free-text rubrics list required elements plus acceptable variants.
- An item whose source does not back its key answer is quiz poison.
- When a learner's challenge exposes one, treat it as an erratum, not a debate.
