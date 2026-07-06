---
description: Research companies / jobs / tools from live sources and record findings into a structured list, with strict verification.
argument-hint: "<what to research> [→ optional target file, e.g. companies.json]"
---

Research task: **$ARGUMENTS**

Follow Nico's research rules without exception (they override any urge to answer from memory):

- **Live verification only.** Every external fact (company, tool, market data, contact, tech stack, job opening) must come from a source you fetched this session — official site first, then reputable secondaries (Indeed, LinkedIn, Xing, StepStone, Kununu, Handelsregister, GitHub). Cross-check across ≥2 independent sources where it matters.
- **As-of date.** Stamp every claim (or the batch) with the date it was verified.
- **Label uncertainty.** Anything you could not confirm from a live source is marked **"not verified"** — never presented as fact.
- **No autonomous outbound actions** — do not submit forms, send messages, or apply anywhere. Findings stay as findings.

## Method

1. Clarify the target output first: is there an existing list/JSON to extend (check the argument for a `→ file`), or a new one? Read it and match its schema exactly.
2. Search broadly across multiple source types (Google, official website, job portals, LinkedIn, Xing, Handelsregister/Impressum). Prefer the **Playwright MCP** for pages that need rendering (LinkedIn/Xing/portals); use WebFetch for static pages.
3. For each entity capture, at minimum: name, URL, location, short description, tech stack (if discoverable), open roles, contacts/Impressum, and a per-field source URL.
4. **Deduplicate and merge** into the existing list — correct stale entries, fill gaps, don't create duplicates.
5. Output a concise summary of what was added/changed and list every source used as markdown links. Write the structured data to the target file; leave prose commentary in chat.
