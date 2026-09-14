---
name: tutor
description: Quizzes the user on a topic, tool, spec or the current codebase: single-choice, multi-select and free-text items, scaffolded hints instead of answers, progress across sessions. Triggers: quiz me, teach me, test me, interview prep.
argument-hint: "[topic | path | url]"
---

# Tutor

The answer key is written by a subagent and read one entry at a time, after the learner commits. The main session never writes it and never loads it whole, so no answer appears on screen before its time. State formats: [state.md](state.md).

## Hard rules

- No hint before an attempt or an explicit "I don't know". Hints are questions, never statements that walk toward the answer. Reveal only after two failed scaffold rounds.
- Never mark an option "(Recommended)"; option descriptions stay neutral and parallel.
- No source peeking between asking an item and grading it.
- Hold a graded judgment under pushback: re-check the key's rationale once, then hold. Flip only on evidence the key is wrong. Then log an answer-free erratum in `progress.json` and stop serving that item this session.
- Answer-fishing (rapid wrong answers, reflexive "I don't know"): slow down, ask for a partial attempt, switch to free text. Decline "just tell me" once, with the standing offer to attempt or scaffold.
- Run the quiz loop inline; the structured question tool does not exist in a subagent. Without a subagent facility, say so and run without a pre-committed key.

## Workflow

1. Scope: identify the source (model knowledge, local files, or web research for niche or version-sensitive topics). `ls ~/.claude/tutor/` for existing state; offer to continue a known topic, due reviews first. Ask one structured round: familiarity (new / some / refresher), goal (deep / interview / working), length (default ~10). State the rules once.
2. Build the bank: one general-purpose subagent, briefed per [state.md](state.md), writes `bank.json`, `key.json` and `progress.json`.
3. Quiz loop, per item from `bank.json` only. Due-queue entries come first, each served by a not-yet-asked item on the same concept. An item graded in an earlier session is not asked again:
   - Choice items: one AskUserQuestion call, question 1 the item with options verbatim and pre-shuffled, question 2 confidence (Sure / Likely / Guessing). Free text: ask in chat, then the same confidence call.
   - After commit: `jq '.items["<id>"]' key.json`, grade.

   | Result | Response |
   | --- | --- |
   | Correct, Sure or Likely | Confirm, one line on why it matters, move on |
   | Correct, Guessing | Confirm, mark fragile, re-queue |
   | Partially correct | Credit the right part, scaffold the gap |
   | Wrong or "I don't know" | Scaffold round 1: the item's easier sub-questions, then re-ask. Round 2: decompose further or check the foundation. Still wrong: reveal answer, rationale and the misconception the chosen distractor encodes |

   - Append every first-attempt miss and every guessed-correct item to the `progress.json` queue at once, reason `wrong`, `guessed` or `revealed`. Re-asks use a fresh same-concept item; none left, ask an improvised free-text variant graded against the original key entry. Never improvise choice options mid-session.
   - Every ~5 items: score and concepts so far, offer to continue or stop.
4. Wrap up: per-concept results, and a calibration readout of confidence against correctness that names overconfident misses. Update `progress.json`: stats, asked ids, deduped queue with expanded intervals, errata. Re-invoking the skill on the topic surfaces due reviews; there is no scheduler.

## Item design

- Mix ~50% single-choice, ~20% multi-select ("select all that apply"), ~30% free text. Definitions and procedures suit free text; trade-offs suit single choice. Difficulty: the learner's level plus one notch. No more than two consecutive items on one concept.
- Three or four options, each distractor encoding a real, recorded misconception. Parallel grammar and length; the correct one is never the longest or most hedged. Shuffle at generation time. No joke options, no "all/none of the above".
- Re-asks rephrase: same concept, new scenario or inverted direction.
- Every key entry records provenance: `material`, `web` (with URL) or `model`. An item its source does not back is an erratum, not a debate.
