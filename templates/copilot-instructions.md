# <project-name> — Copilot Instructions

<!-- One-line project description. -->
<!-- Shared rules live in AGENTS.md — Copilot loads it on every surface (Chat, Inline,
     Agent, code review, cloud agent, CLI). Do NOT restate AGENTS.md rules here.
     This file holds only Copilot-only deltas. If there are none, delete this file. -->

Hard caps for every response:

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

## Copilot-only notes

<!-- Keep this list short — it is loaded on every Copilot request (token budget).
     Only put things here that are NOT already in AGENTS.md, for example:
       - Pointers to .github/prompts/ and .github/instructions/.
       - A rule that applies only in a specific Copilot surface (e.g. code review). -->

1. <First Copilot-only note — or delete this file if AGENTS.md covers everything.>
