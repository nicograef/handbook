# Question Design

Item-writing rules for tutor sessions. Both the main quiz loop and the setup
subagent follow these; they distill the MCQ item-writing and retrieval-practice
literature (Haladyna's rules, Rodriguez 2005, Dunlosky 2013).

## Formats and mix

- Target mix: ~50% single-choice, ~20% multiple-select, ~30% free-text recall.
  Recall beats recognition for retention; choice items are faster and let
  distractors encode misconceptions — the mix hedges both, and free-text weight
  can grow for advanced learners.
- Match format to how the knowledge will be used: definitions and APIs → recall;
  trade-offs and failure modes → single-choice; "which of these apply" facts →
  multiple-select; procedures and design reasoning → free-text.
- Difficulty 1–3 per item. Start at the learner's stated level plus one notch of
  desirable difficulty — hard enough to require thought, never beyond what the
  learner can plausibly execute.
- Interleave concepts: never more than two consecutive items on the same concept.

## Writing choice items

- 3–4 options. Three high-quality options beat four padded ones; never pad with a
  filler option to reach four.
- Every distractor must be plausible and encode a **real** misconception — record
  which one in the key entry. No joke options, no "all of the above" / "none of
  the above".
- Options grammatically parallel and of similar length and tone. The correct
  option must not be the longest or most hedged one.
- Shuffle the correct position at generation time; the bank stores options in
  final order so the quiz loop never reorders (or learns) anything.
- Multiple-select only when the concept genuinely has multiple correct facets;
  the question text must say "select all that apply".

## AskUserQuestion mechanics

- One call per item. Question 1 = the item: `header` ≤ 12 chars (e.g. "Q3 · Go"),
  option `label` = the answer choice, `description` = neutral elaboration or
  empty. Descriptions must be parallel — same tone, same depth — and must never
  hint at correctness.
- Question 2 in the same call = confidence: "Sure / Likely / Guessing".
- `format: "multi"` items set `multiSelect: true` on question 1 (the confidence
  question stays single-select); the answer returns as a list of labels — grade
  it against the key's answer array.
- **Never mark an option "(Recommended)".** That habit comes from clarification
  questions and is an instant answer leak here.
- The "Other" row is always available to the user: treat typed free text as
  their committed answer and grade it against the key entry — answer and
  rationale for choice items, rubric for free-text items.
- Free-text items are asked in chat, not through the tool, and always collect a
  confidence call alongside the answer.

## Scaffold sub-questions

- Each rung is an easier **question**, never a statement that walks toward the
  answer.
- Design a rung by isolating the single concept the wrong answer betrays (use the
  distractor's misconception note), then asking something the learner can answer
  that is a stepping stone back to the original item.
- A rung so obvious that it contains the answer is a reveal, not a hint.
- Re-asks of any graded item — revealed, wrong, or guessed-correct:
  **rephrase, don't repeat** — same concept, new surface (different scenario,
  inverted direction, applied context). Serve them from not-yet-asked
  same-concept bank items; a verbatim repeat tests memory of the transcript,
  not the concept.

## Grounding and provenance

- Niche, recent, or version-sensitive topics: build items from fetched
  authoritative sources (official docs, RFCs), not model memory. Codebase topics:
  from code actually read this session.
- Every key entry carries provenance: `material` (the user's files), `web`
  (fetched source, keep the URL), or `model` (trained knowledge). Free-text
  rubrics list required elements plus acceptable variants.
- An item whose source does not back its key answer is quiz poison: when a
  learner's challenge exposes one, treat it as an erratum, not a debate.
