# Session State

- [Layout](#layout)
- [bank.json](#bankjson)
- [key.json](#keyjson)
- [progress.json](#progressjson)
- [Setup subagent brief](#setup-subagent-brief)

## Layout

- State lives outside any repo in `~/.claude/tutor/<slug>/`.
- `<slug>` is the kebab-case topic — prefix codebase topics with the project name
  (e.g. `jotti-event-sourcing`).

| File            | Content                              | Main-session access            |
| --------------- | ------------------------------------ | ------------------------------ |
| `bank.json`     | questions only, no answers           | read freely                    |
| `key.json`      | answers, rationales, provenance      | per-item `jq`, post-commit only; never written |
| `progress.json` | cross-session learning state         | read at start; append answer-free queue entries and errata mid-session; full update at wrap-up |

## bank.json

```json
{
  "topic": "go-concurrency", "created": "2026-07-23", "source": "model",
  "items": [
    {
      "id": "q1", "concept": "channel-directions", "difficulty": 2,
      "format": "single", "question": "…",
      "options": [{ "label": "…", "description": "…" }],
      "scaffold": ["easier sub-question 1", "easier sub-question 2"]
    }
  ]
}
```

- `options` is pre-shuffled and omitted for `format: "free"`.
- `format` is one of `single`, `multi`, `free`.

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
  "topic": "go-concurrency", "sessions": 3, "last_session": "2026-07-23",
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

`asked` lists every item id ever served. `status` runs `new` → `fragile` (guessed or
corrected) → `learned` (correct twice, spaced).

- Every queue entry carries the matching `reason`: `revealed`, `wrong`, or `guessed`.
- Review scheduling uses expanding intervals of 0, 3, 7, 21 days.
- `interval_days: 0` means due in **any later session**, same day included.
- A due entry is satisfied by whichever same-concept item served it.
- The entry itself advances one rung on success and resets to 0 on failure.
- It is removed after a success at 21 days; concept stats keep the history.

## Setup subagent brief

Inputs to pass:

- Topic, scope, and learner level.
- **Session length (item count)**.
- Source paths/URLs.
- The state directory.

The subagent must:

1. Digest the material. Grounding and provenance rules:
   [question-design.md](question-design.md).
2. Generate about **2× the session's item count**, following `question-design.md`:
   - **At least two items per concept**.
   - The spares serve re-asks and rephrased variants.
3. For an existing topic, read `progress.json` first, then:
   - Generate a keyed rephrased variant (same concept, new surface) for every queue entry.
   - Weight extra items toward `fragile` concepts.
   - Apply pending errata to `key.json`/`bank.json`.
   - Append "— applied <date>" to each applied erratum line.
4. Write the files:
   - Write `bank.json` and `key.json`.
   - Create `progress.json`, or preserve its `asked`, `concepts`, `queue`, and `errata`.
   - Append new items with fresh ids.
5. Return as its summary only the item count and concept list — **never answers or
   rationales**.
