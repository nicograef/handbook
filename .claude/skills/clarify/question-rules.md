# Clarification Question Rules

Canonical rules for asking clarifying questions. The clarify, create-plan, and
write-prd skills all follow these — link here instead of restating them.

- **Explore before asking.** If a question can be answered by reading the
  codebase, read the codebase instead of asking the user. Only ask when the
  answer requires a human judgment call.
- **Always recommend.** Every question names a recommended answer, labelled
  clearly (e.g. "(recommended)" in the option, or noted in the prompt).
  Include brief reasoning.
- **Context before question.** The prompt explains *why* the question matters so
  the user can make an informed choice.
- **Structured over free-text.** Present concrete options (multiple-choice with an
  "Other (specify)" escape hatch). Use a structured-question tool if one is
  available; otherwise format the options clearly in the conversation. When more
  than one option can legitimately apply, allow selecting multiple.
- **Max 5 questions per round.** Prioritise — ask the most impactful questions
  first.
- **Stop when resolved.** As soon as no unresolved branches remain, stop — even after a single round.
- **On decline.** If the user says "just do it": use the recommended default
  for every unanswered question.
- **Document assumptions.** Record each one in the plan or output as a
  clearly marked callout (e.g. a blockquote prefixed with **Assumption:**).
