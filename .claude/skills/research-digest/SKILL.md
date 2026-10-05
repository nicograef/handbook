---
name: research-digest
description: Deep-dives the project's research topics on arXiv, web search, Hacker News, GitHub and regulators, or expands from links and text the user gives. Reads the best finds in full, judges them against the code and publishes a report page.
argument-hint: "[links or text to expand from]"
disable-model-invocation: true
---

# Research digest

Every run is one deep dive with one report. Without input it sweeps the profile's topics for work of the last 30 days. Given links or text, it reads that material in full and expands from it. Each item is read critically and judged against this repo. The run changes no code and commits nothing.

The report opens with one to three reasoned recommendations. Each is a change, or the cheapest experiment when no change is due yet. It shows only items of medium or high relevance, plus every link the user gave. The rest of what was read or skipped sits in a closing HTML comment. The page hides it; the next run reads it as covered.

## Hard rules

- The project profile holds the project context: topics, rulings, brief sources, report directory. Without it, the report judges nothing.
- Discovery uses the platforms of [sources.md](sources.md), never a hand-kept link list. The user's links feed one run; nothing stores them as a source.
- Never log in, submit a form or post anything. A walled source is skipped with its reason.

## 1. The project profile

The profile is the project's researcher agent, `.claude/agents/<project>-researcher.md`. None: copy [the template](../../../templates/project-researcher.md) there and fill it from `AGENTS.md`, the docs and memory. Show the filled rulings to the user before the run.

The workflow reads the profile by path, so a new profile works without a session restart. Its `Reports:` line names the report directory.

## 2. Lookback, covered, carried and the report path

A sweep searches for work published in the 30 days before today; `since` is that start. No candidate is dropped for its age: an older paper or statute that still bears on the project is read. Runs never depend on each other's dates.

Every report closes with a ledger comment. Its URLs under `deferred:` are carried, each with its priority. An earlier run deferred them over its reading cap or after a reader died. Every other URL the reports name is covered and is not read again unless the user names it. A URL one report names outside `deferred:` is covered, even where another report deferred it.

The report path is `<report dir>/<today>.md`; when that exists, `<today>-2.md`, and so on.

## 3. Run the workflow

Copy [digest.workflow.js](digest.workflow.js) into the session scratchpad and run that copy by its script path. The Workflow tool takes a script path only under the working directory or the scratchpad. Args:

```
args = {today, since, repo: <absolute checkout path>, profile: <absolute profile path>,
        out: <absolute report path>, covered: [<URLs>], carried: [{url, priority}],
        seeds: [<the user's links>], notes: "<the user's text or topic>"}
```

`seeds` and `notes` are present only when the user gave material; pasted text without a link goes into `notes`.

The workflow returns `{recommendations, ledger, failedRoutes}`. Append `ledger` verbatim to the report file. On `{aborted}`, relaunch it with its run id as `resumeFromRunId`, so the finished agents replay from the journal.

## 4. Publish the page

Where the Artifact tool is available, publish the report as a private page. Fill [page.html](page.html) into the scratchpad:

```sh
python3 -c 'import sys, json, html; t, md, title = open(sys.argv[1]).read(), open(sys.argv[2]).read(), sys.argv[3]; print(t.replace("{{TITLE}}", html.escape(title)).replace("{{REPORT}}", json.dumps(md).replace("<", "\\u003c")), end="")' \
  ~/.claude/skills/research-digest/page.html <report path> "<Project> research <today>" > <scratchpad>/research-<project>-<today>.html
```

Publish that file with `icon: "news"` and a one-sentence description of what it covers. The design is fixed in the template; build no page of your own.

Report the page URL, the report path and the recommendation titles, plus one line naming any failed routes. The report is the record; the chat gets no recap.

## Spend

A run costs model tokens only and buys nothing from a provider. Where the project keeps a spend ledger, its profile says whether a run is recorded there.
