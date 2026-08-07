# handbook — Copilot Instructions

Copilot-only pointers. Shared rules live in [`AGENTS.md`](../AGENTS.md), read alongside this
file. The caps below are the one deliberate duplicate. They must survive a surface that
loads this file alone.

| Rule | Cap |
| --- | --- |
| Sentence | ≤ 20 words, one claim |
| Paragraph | ≤ 3 lines, ≤ 1 per section |
| Bullet | ≤ 2 lines |
| Table trigger | ≥ 3 items sharing ≥ 2 attributes |
| List trigger | any enumerable set of ≥ 2 items |
| Format order | table → list → paragraph |

- Banned: preamble, restating the task, closing recap, transition sentences.
- Banned: hedges that do not change the next action.
- Compression removes words, never a rule, condition, exception or caveat.
- Full contract: [`.claude/skills/output-style.md`](../.claude/skills/output-style.md).
