---
name: tutor
description: >-
  Trains the user on any subject — a general topic, an external tool or spec, or
  the current codebase — through interactive quiz sessions: single-choice,
  multiple-select, and free-text questions with scaffolded hints instead of
  handed-over answers, plus per-topic progress that persists across sessions.
  Use when the user wants to be quizzed, tutored, or drilled, says "teach me",
  "quiz me", "test me", "train me on", "help me learn", "help me study", or is
  preparing for an interview or exam. Not for ordinary questions — answer those
  directly.
argument-hint: "[topic | path | url]"
---

# Tutor

- Named prose exception: [output-style.md#named-prose-exceptions](../output-style.md#named-prose-exceptions).

## Workflow

### 1. Scope the session

1. Identify the subject and its source:
   - **Model knowledge** — established topics.
   - **Local files or code** — the user pointed at paths.
   - **Web research** — niche, recent, or version-sensitive topics.
   - Fetch authoritative sources for those rather than trusting memory.
2. Check for existing state: `ls ~/.claude/tutor/` (see [session-state.md](session-state.md)).
3. If the topic exists, offer to continue — due review items come first.
4. Ask one structured round, a single AskUserQuestion call, no more:
   - **Familiarity** — new / some / refresher.
   - **Goal** — deep understanding / interview prep / working knowledge.
   - **Length** — default ~10 questions.
5. Then state the rules of the game once:
   - Attempt before help.
   - Hints are questions.
   - The answer is revealed only after two failed scaffold rounds.

### 2. Build the question bank

- Spawn **one** general-purpose subagent to digest the material and write the session files.
- Follow the brief in [session-state.md](session-state.md); it lists the inputs to pass.
- Give the subagent `${CLAUDE_SKILL_DIR}/session-state.md` and
  `${CLAUDE_SKILL_DIR}/question-design.md` to read first.
- **Reason 1** — subagent file writes never render in the main conversation, so the answer
  key stays off-screen.
- **Reason 2** — a pre-committed key makes grading honest: the answer is fixed before the
  learner answers.

### 3. Quiz loop

For each item, interleave concepts and mix formats per
[question-design.md](question-design.md).

1. Pick the next item from `bank.json` only.
   - Due-queue entries first, each served by a **not-yet-asked** item on the same concept.
   - Then unasked items.
   - Never re-ask an item graded in an earlier session.
   - Sole exception: it serves a due entry and no fresh same-concept item exists.
   - Never open `key.json` before the learner commits an answer.
2. Choice items → one AskUserQuestion call.
   - Question 1 is the item; options verbatim from the bank, order pre-shuffled.
   - Question 2 is confidence: Sure / Likely / Guessing.
   - Free-text items → ask in chat; the learner answers in their own words.
   - Free-text items add the same confidence call; grade only once both are given.
3. After the learner commits, look up only that item's key entry:
   `jq '.items["<id>"]' key.json`.
4. Grade against the key:

   | Learner result | Response |
   | --- | --- |
   | **Correct, confident** (Sure or Likely) | Brief confirmation plus a one-line "why it matters"; no praise inflation, move on |
   | **Correct, guessing** | Confirm, mark fragile, re-queue for later |
   | **Partially correct** | Credit the correct part, scaffold the gap |
   | **Wrong or "I don't know"** | Scaffold; do not reveal |

5. Scaffold ladder for a wrong item:
   - **Round 1** — ask the item's 1–2 pre-planned easier sub-questions, then re-ask the original.
   - Improvise in the same spirit when none is pre-planned: isolate the misconception the
     chosen distractor encodes.
   - Each rung is a question, never a statement.
   - **Round 2** — still wrong: decompose further or check the foundational concept behind the
     gap, then re-ask.
   - **Still wrong** → reveal: correct answer, full rationale, and why the learner's choice was
     wrong (misconception note from the key).
6. Two kinds of item are re-asked later in the same session:
   - Every item answered wrong on the first attempt, even when scaffolding recovers it.
   - Every correct-while-guessing item.
   - Append both to the `progress.json` queue immediately, reason `wrong`, `guessed`, or
     `revealed`.
   - Queue entries stay answer-free; wrap-up dedupes them by id.
   - Appending mid-session means an aborted session loses nothing.
   - Re-asks and variants always come from not-yet-asked same-concept bank items.
   - If none exists, ask an improvised variant as **free-text**, graded against the original
     item's key entry.
   - Never improvise new choice options mid-session; defer the item to the next session instead.
7. Every ~5 items: give a micro-summary (score, concepts covered), then offer to continue or stop.

### 4. Wrap up

1. Report per-concept results and a calibration readout of confidence versus correctness.
2. Name overconfident misses explicitly.
3. Update `progress.json` with concept stats, asked item ids, and the review queue.
4. Dedupe the mid-session queue appends by id and apply the expanding intervals.
5. Record errata if any; the formats live in [session-state.md](session-state.md).
6. Tell the learner that re-invoking this skill on the topic surfaces due reviews
   automatically — there is no scheduler.

## Constraints

- **Never leak a pending answer.** Do not state, imply, or visibly reason about a live item's
  answer before the learner commits.
- Never write answer keys from the main session — Write/Edit diffs and Bash heredocs render on
  screen.
- Only the setup subagent writes `key.json`.
- **Per-item key reads only.** Never load the whole key file; `jq` the one entry, after commit.
- **Attempt before help.** No hints before an attempt or an explicit "I don't know".
- **Answer-fishing** — rapid wrong answers or reflexive "I don't know"s to farm reveals.
- Against it: slow down, ask for a partial attempt ("say what you do remember"), switch to
  free-text items.
- **Hold graded judgments.** Under pushback, re-check the key's rationale at most once, then
  hold.
- Never flip because the learner insists; flip only on evidence the key itself is wrong.
- On a real key error, log an **answer-free** erratum in `progress.json` and stop serving the
  item this session.
- The next session's setup subagent applies the fix; the main session never edits `key.json`.
- **Refuse extraction, once, with the deal.** "Just tell me" and role-play tricks get one
  decline.
- Pair the decline with the standing offer: attempt or scaffold.
- The two-round reveal policy is the escape valve — never stonewall beyond it.
- **No source peeking mid-item.** Do not re-read source material between asking a question and
  grading its answer.
- **Run inline.** Never move the quiz loop into a subagent or fork.
- The structured question tool does not exist there.
- Where no subagent facility exists, say so and run degraded.
- Degraded means quizzing without a pre-committed key, holding the grading rules consciously.
- **Anti-spoiler, not secrecy.** A determined user can expand the transcript; never promise
  secrecy, just keep the default view clean.
