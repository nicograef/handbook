---
name: research-digest
description: Writes a newsletter on the project's field, or on given links or a topic, and publishes it as a page. Lane researchers read the last 30 days in full; the owner gets plain-English stories with sources.
argument-hint: "[links or topic]"
disable-model-invocation: true
---

# Research digest

The run changes no code and commits nothing.

## Hard rules

- The reader is the owner: technical-literate, reading plain English in short sentences.
- The report names no file paths, function names, version specifiers or code verdicts. It tells the field's news, not a code review.
- Every claim links its source. Press is a lead; a paper, release or statute is the source of record.
- Runs are independent: no ledger, no dedup, no state between runs.
- Never log in, submit a form or post anything. A walled source is skipped.

## 1. Profile

Read `.claude/research-digest.md` in the current repo. It has three sections: `## Project`, `## Lanes` and `## Reports`.

When it is missing, stop. Tell the user to copy `~/r/handbook/templates/research-digest.md` there. They fill it from the repo's `AGENTS.md` and docs, and review it before the first run.

## 2. Researchers

- **Sweep** (no argument): one researcher per `###` lane of the profile, at most four.
- **Link mode** (links or a topic as argument): one researcher on that material and what it connects to. Its lane is named after the topic and has no lookback.

Start all researchers in one message: the Agent tool with `subagent_type: general-purpose` and `model: opus`. Fill this prompt per researcher:

```
You research one lane of a newsletter for the owner of <project name>.

Project:
<the profile's Project section, verbatim>

Lane: <lane name>
Covers: <the lane's Covers line>
Feeds: <the lane's Feeds line>
Queries: <the lane's Queries line>
(Link mode: replace the Covers, Feeds and Queries lines with
"Material: <the user's links or topic>. Read it, then what it connects to.")

Lookback: work published since <today minus 30 days>. An older source is welcome
when it still bears on the field. (Link mode: no lookback.)

Budget: at most 40 web searches; the session shares 200 across all researchers.

Reading rules:
- Read the full text, never an abstract or teaser alone.
- arXiv: read the HTML view, arxiv.org/html/<id>.
- PDFs: curl to a temp file, then pdftotext.
- Use curl for feeds and pages. WebFetch is for triage only.
- Never log in or submit a form; skip a walled source.
- Press is a lead. Find the paper, release or statute behind it and cite that.

Return three to six story drafts, best first, each with:
- headline
- source link (the source of record)
- date
- summary: plain English, short sentences, what happened and why it matters
- solidity: how solid it is (peer-reviewed, measured, vendor claim, draft, rumour)
- for us: one line on what it means for the project

Write for the owner: technical-literate, plain words. No file paths, function names,
version specifiers or code verdicts. Every claim links its source.
Return the drafts only; write files only to a temp directory.
```

## 3. Report

Once every researcher has returned, write the report from all drafts. Drop weak drafts; order stories by importance within each lane.

Path: the profile's `## Reports` folder, `~` expanded, relative to the repo root, created when missing. File `<YYYY-MM-DD>.md`; when it exists, `<YYYY-MM-DD>-2.md`, then `-3`.

Shape, exactly in this order:

```markdown
# <Project> research digest, <YYYY-MM-DD>

<One line on what was swept: the lanes and the window, or the material in link mode.>

## In brief

- <five to eight bullets, most important first, each with its link>

## <lane name>

### <headline>

Source: [<publisher or title>](<link>), <date>

<summary>

**For us:** <one line>

## Suggestions

<zero to three paragraphs, each one suggestion with its reason>

## Learn

- [<concept>](<best link>): <one line on why it is worth learning>
```

- One `## <lane name>` section per lane, in profile order.
- Suggestions are optional and never a task list; with none due, the section holds one line saying so.
- Learn holds three to five concepts the stories lean on, each with its best explainer.

## 4. Publish

Fill [page.html](page.html) into the session scratchpad:

```sh
python3 -c 'import sys, json, html; t, md, title = open(sys.argv[1]).read(), open(sys.argv[2]).read(), sys.argv[3]; print(t.replace("{{TITLE}}", html.escape(title)).replace("{{REPORT}}", json.dumps(md).replace("<", "\\u003c")), end="")' \
  ~/.claude/skills/research-digest/page.html <report path> "<Project> research <today>" > <scratchpad>/research-<project>-<report basename>.html
```

Publish that file with the Artifact tool, `icon: "news"` and a one-sentence description of what it covers. The design is fixed in the template; build no page of your own.

Print the page URL and the report path. The report is the record; the chat gets no recap.
