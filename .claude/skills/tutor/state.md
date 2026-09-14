# Tutor state

Lives in `~/.claude/tutor/<slug>/`; codebase topics are prefixed with the project name (`jotti-event-sourcing`).

| File | Content | Main-session access |
| --- | --- | --- |
| `bank.json` | Items without answers | Read freely |
| `key.json` | Answers, rationales, provenance | Per-item `jq` after commit; never written |
| `progress.json` | Cross-session learning state | Read at start; append queue entries and errata mid-session; full update at wrap-up |

```json
// bank.json
{ "topic": "go-concurrency", "created": "2026-07-23", "source": "model",
  "items": [ { "id": "q1", "concept": "channel-directions", "difficulty": 2,
    "format": "single | multi | free", "question": "…",
    "options": [ { "label": "…", "description": "…" } ],
    "scaffold": ["easier sub-question 1", "easier sub-question 2"] } ] }

// key.json
{ "items": { "q1": { "answer": "label | [labels] | null for free", "rubric": "required elements for free text",
    "rationale": "…", "distractors": { "wrong label": "misconception it encodes" },
    "provenance": "material | web | model", "source": "path or URL unless model" } } }

// progress.json
{ "topic": "go-concurrency", "sessions": 3, "last_session": "2026-07-23", "asked": ["q1", "q2"],
  "concepts": { "channel-directions": { "asked": 4, "correct": 3, "status": "new | fragile | learned" } },
  "queue": [ { "id": "q7", "reason": "revealed | wrong | guessed", "due": "2026-07-23", "interval_days": 0 } ],
  "errata": ["q3: key contradicted the Go spec — pending"] }
```

- `options` is pre-shuffled and omitted for free items. `status` runs new → fragile (guessed or corrected) → learned (correct twice, spaced).
- Review intervals expand 0, 3, 7, 21 days; `interval_days: 0` means due in any later session. A due entry is satisfied by any same-concept item. It advances one rung on success, resets on failure, and is removed after success at 21 days.

## Setup subagent brief

Pass: topic, scope, learner level, item count, source paths or URLs, the state directory. Have it read this file and `SKILL.md` first.

1. Digest the material; record provenance per item.
2. Generate about twice the session's item count, at least two per concept; spares serve re-asks.
3. For an existing topic, read `progress.json` first. Generate a keyed rephrased variant for every queue entry and weight extra items to fragile concepts. Apply pending errata to `key.json` and `bank.json`, appending "— applied <date>".
4. Write `bank.json` and `key.json`; create `progress.json` or preserve its `asked`, `concepts`, `queue` and `errata`; new items get fresh ids.
5. Return only the item count and concept list, never answers or rationales.
