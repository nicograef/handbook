---
name: research-digest
description: Sweeps papers, releases and articles since the last issue, reads the best in full, judges each against this project's code and rulings, and writes a newsletter issue. Use for a research digest, sweep or newsletter, or to judge a URL list.
argument-hint: "[URLs to read in full]"
disable-model-invocation: true
---

# Research digest

One issue per run: a newsletter on outside work since the last issue. Each item is read critically and judged against this repo. It changes no code and commits nothing. An item rated high is a lead for the owner, not a task for this run.

## Hard rules

- The project's researcher agent holds the project context: topics, rulings, brief sources, issue directory. Without it, the issue judges nothing.
- WebFetch is triage only. The reading of record is the raw page, the arXiv HTML or the PDF: [sources.md](sources.md).
- Never log in, submit a form or post anything. A walled source is skipped with its reason.
- Owner URLs are read in full, every one, inside the window or not.

## 1. The project agent

Look for `.claude/agents/*-researcher.md`. None: copy [the template](../../../templates/project-researcher.md) there and fill it from `AGENTS.md`, the docs and memory. Show the filled rulings to the user before the run. A new agent file loads at the next session start; until then, run in a fresh session.

Read its `Issues:` line for the issue directory.

## 2. The window and what was covered

The window runs from the newest issue's date to today; with no issue, the last two weeks. Every URL the newest issue names, its skipped list included, is covered and is not read again. An owner URL is read even when covered.

## 3. Run the workflow

Run the saved [digest.workflow.js](digest.workflow.js) by its script path with:

```
args = {today, since, repo: <absolute checkout path>, agent: <the agent's name>,
        out: <issue dir>/<today>.md, covered: [<URLs of step 2>], urls: [<owner URLs>]}
```

It returns `{path, headlines, read, skipped}`, or `{aborted: 'brief'}` when the brief died; then run it again.

Report the path and the headlines. The issue is the record; the chat gets no recap.

## Spend

A run costs model tokens only and buys nothing from a provider. Where the project keeps a spend ledger, its agent file says whether a run is recorded there.
