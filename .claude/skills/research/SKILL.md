---
name: research
description: Researches companies, jobs, or tools from live sources and records structured findings, with strict verification. Delegates to the web-researcher agent.
argument-hint: "<what to research> [→ optional target file, e.g. companies.json]"
---

Research task: **$ARGUMENTS**

## Workflow

1. Delegate the task to the **web-researcher** subagent (`../../agents/web-researcher.md`), which
   owns the verification policy (live-only sourcing, cross-checking, as-of dates, uncertainty
   labels, no outbound actions). Pass the full task, including any `→ target file` from the
   argument so it can read and match the existing schema.
2. Return the subagent's findings: a skimmable summary with per-claim source links, an as-of date,
   and a "not verified / open questions" section. If a target file was named, the subagent writes
   the structured data there.
