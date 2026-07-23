# Session State

File layout, formats, and the setup-subagent brief for tutor sessions.

## Layout

State lives outside any repo in `~/.claude/tutor/<slug>/`, where `<slug>` is the
kebab-case topic — prefix codebase topics with the project name
(e.g. `jotti-event-sourcing`).

| File            | Content                              | Main-session access            |
| --------------- | ------------------------------------ | ------------------------------ |
| `bank.json`     | questions only, no answers           | read freely                    |
| `key.json`      | answers, rationales, provenance      | per-item `jq`, post-commit only; never written |
| `progress.json` | cross-session learning state         | read at start; append answer-free queue entries and errata mid-session; full update at wrap-up |

## bank.json

```json
{
  "topic": "go-concurrency",
  "created": "2026-07-23",
  "source": "model",
  "items": [
    {
      "id": "q1",
      "concept": "channel-directions",
      "difficulty": 2,
      "format": "single",
      "question": "…",
      "options": [{ "label": "…", "description": "…" }],
      "scaffold": ["easier sub-question 1", "easier sub-question 2"]
    }
  ]
}
```

`options` is pre-shuffled and omitted for `format: "free"`. `format` is one of
`single`, `multi`, `free`.

## key.json

```json
{
  "items": {
    "q1": {
      "answer": "the correct label (array for multi, null for free)",
      "rubric": "required elements for free-text answers",
      "rationale": "why the answer is right",
      "distractors": { "wrong label": "misconception it encodes" },
      "provenance": "material | web | model",
      "source": "path or URL when provenance is not model"
    }
  }
}
```

## progress.json

```json
{
  "topic": "go-concurrency",
  "sessions": 3,
  "last_session": "2026-07-23",
  "asked": ["q1", "q2", "q7"],
  "concepts": {
    "channel-directions": { "asked": 4, "correct": 3, "status": "fragile" }
  },
  "queue": [
    { "id": "q7", "reason": "revealed", "due": "2026-07-23", "interval_days": 0 }
  ],
  "errata": ["q3: key contradicted the Go spec on channel directions — pending"]
}
```

`asked` lists every item id ever served, so returning sessions never repeat a
graded item. `status`: `new` → `fragile` (guessed or corrected) → `learned`
(correct twice, spaced). Queue admission: every item that was revealed, answered
wrong on the first attempt (even if scaffolding recovered it), or answered
correctly while guessing — with the matching `reason`.

Review scheduling uses expanding intervals of 0, 3, 7, 21 days —
`interval_days: 0` means due in **any later session**, same day included. A due
entry is satisfied by whichever same-concept item served it; the entry itself
advances one rung on success, resets to 0 on failure, and is removed after a
success at 21 days (concept stats keep the history). Errata are **answer-free**
one-liners (never the corrected answer — `progress.json` is read at session
start, before items are re-asked); the fix itself is applied by the next
session's setup subagent.

## Setup subagent brief

Spawn one general-purpose subagent with: topic, scope, learner level, **session
length (item count)**, source paths/URLs, the state directory, and instructions
to first read this file and `question-design.md` from the skill directory. It
must:

1. Digest the material — read the given files, fetch web sources for niche or
   recent topics, or draw on model knowledge for established ones.
2. Generate about **2× the session's item count**, following
   `question-design.md`, with **at least two items per concept** — the spares
   are what re-asks and rephrased variants are served from.
3. For an existing topic: read `progress.json` first; generate a keyed rephrased
   variant (same concept, new surface) for every queue entry, weight extra items
   toward `fragile` concepts, and apply pending errata to `key.json`/`bank.json`
   (append "— applied <date>" to the erratum line).
4. Write `bank.json` and `key.json`; create `progress.json` or preserve its
   `asked`, `concepts`, `queue`, and `errata`, appending new items with fresh
   ids.
5. Return as its summary only the item count and concept list — **never answers
   or rationales**, which would render in the main conversation.
