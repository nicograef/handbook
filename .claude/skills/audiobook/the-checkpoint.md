# The Checkpoint

- [Why here](#why-here)
- [What is asked](#what-is-asked)
- [What is never asked](#what-is-never-asked)
- [How to ask](#how-to-ask)
- [BRIEF.md](#briefmd)
- [After the checkpoint](#after-the-checkpoint)

Step 4 is the only place the run stops. One interaction, three items, then the
skill writes `BRIEF.md` and does not stop again.

## Why here

It sits after the gaps are named and before the research runs.

- Earlier the proposal would be a guess, with no inventory behind it.
- Later the research is already paid for, and a wrong scope wastes all of it.
- Research is the first expensive step. The checkpoint guards exactly that line.

## What is asked

Three items. Each one is something the user knows and the skill cannot derive.

| Item | Why the user decides |
| --- | --- |
| Scope boundary | Only the user knows which part they want to understand |
| Guiding questions | Their open questions, not the ones the repo happens to raise |
| Prior knowledge | Unmeasurable from the repo, and it drives every depth decision |

Prior knowledge is the highest-value item. It sets how far back the theory
reaches. Guessing it wrong means re-explaining the known, or assuming the
unknown, for the whole book.

Offer levels the user can pick without thinking. For example: new to the domain;
working knowledge but no theory; solid theory, only this system is new.

## What is never asked

These are derived, and asking about them turns one checkpoint back into a
conversation.

| Never ask | Derived from |
| --- | --- |
| Chapter count, chapter titles | The concept graph in step 7 |
| Chapter order | Concept dependencies, never the repo layout |
| How much theory prelude | The prior-knowledge answer |
| Terminology, glosses, language | [german-narration.md](german-narration.md) |
| Length, minutes, word count | Nothing. There is no length target |

## How to ask

- Propose a concrete default for all three items. Never ask an open question.
- A bare "ja" must be a complete, valid answer that starts the run.
- Present the scope as in-scope and out-of-scope, both named explicitly.
- List the guiding questions as the questions the book will answer.
- Ask all three in one interaction. Never split them across turns.

## BRIEF.md

Write the confirmed answers before step 5 starts.

- `Scope` — what is in, what is out, in the user's own framing.
- `Guiding questions` — the numbered list the book has to answer.
- `Prior knowledge` — the chosen level, in one line.
- `Changed by the user` — what the answer changed against the proposal.

`BRIEF.md` is read again in step 7 and in Round B. It is the contract for the
run, not a transcript.

## After the checkpoint

The run does not stop again, not even when research contradicts the brief.

- A contradiction is recorded in `PLAN.md` under "Assumptions", not escalated.
- The final report names every drift from `BRIEF.md` and the reason.
- If research invalidates a guiding question, answer why it cannot be answered.
