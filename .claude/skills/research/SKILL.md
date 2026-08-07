---
name: research
description: Researches companies, jobs, or tools from live sources and records structured findings, with strict verification. Delegates to the web-researcher agent.
argument-hint: "<what to research> [→ optional target file, e.g. companies.json]"
---

Research task: **$ARGUMENTS**

## Workflow

1. Delegate the task to the **web-researcher** subagent (`../../agents/web-researcher.md`).
   - It owns the verification policy: live-only sourcing, cross-checking, as-of dates,
     uncertainty labels, no outbound actions.
   - Pass the full task, including any `→ target file` from the argument.
   - The target file lets the subagent read and match the existing schema.
2. Return the subagent's findings in the report shape of the
   [output style contract](../output-style.md).
   - Counts line first, e.g. `6 findings — 4 verified, 2 not verified`.
   - Findings as a table, or one bullet each: bold keyword first, then the fact.
   - Keep the summary skimmable, with per-claim source links and an as-of date.
   - Close with a "not verified / open questions" section; zero entries is one line.
   - If a target file was named, the subagent writes the structured data there.

## Constraints

These restate what [`../../agents/web-researcher.md`](../../agents/web-researcher.md) already
enforces; they add nothing.

- **No outbound actions** — never submit a form, send a message, or apply to anything.
- **Never answer from training memory** — an external fact needs a page fetched this session.
- **Never drop the as-of date or an uncertainty label** when relaying the subagent's findings.
