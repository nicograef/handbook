# Clarification Question Rules

Canonical rules for asking clarifying questions. The clarify, create-plan, and
write-prd skills all follow these — link here instead of restating them.

## The ask gate

A question spends the user's turn. Earn it first. Run this before every
question, and before every `AskUserQuestion` call.

1. **Enumerate** the options, including the ones you would not have offered.
2. **Score** each against the constraints already on the table — repo
   conventions, `CLAUDE.md`, the PRD, the plan, the user's stated goal.
3. **Name the consequences** of each: effort, risk, reversibility, what it
   forecloses.
4. **Eliminate** every option a stated constraint already rules out.

Then count the survivors:

| Survivors | Action |
| --- | --- |
| 0 | The constraints conflict. That conflict is the question — ask it. |
| 1 | Take it. Record it as a **Decision** with its reasoning. Do not ask. |
| ≥ 2, one clearly better | Take it. Record it as a **Decision**. Do not ask. |
| ≥ 2, none clearly better | Ask. Steps 1–3 are the question's context. |

- The last row is the only one that earns a question.
- Applies to every skill and every subagent, `AskUserQuestion` included.
- "I am unsure" is not a survivor count — do the scoring, then count.
- Cannot name the surviving options? The question is not ready to ask.
- Never ask to hand back a call you are equipped to make.
- Never ask to confirm something you already verified.
- Asking costs a turn; a wrong reversible call costs a commit. Prefer the commit.

## Rules

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
