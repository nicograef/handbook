# PRD: Research digest, rebuilt

## Problem Statement

I want to keep up with my projects' fields: new papers, AI progress, products, markets and law. Reading it all by hand takes hours, and most of it does not matter to gyva or jotti.

The current research-digest skill does not give me that. It grew into a 590-line workflow with about 15 agents. It added a source catalogue, a hidden URL ledger and per-project agent files. Its reports judge every item against code paths. So field news drops out, and what remains reads like a code review: file paths, dependency pins, skeptic verdicts. The last gyva report covered ParadeDB and trafilatura releases instead of the field.

## Solution

One small skill produces a monthly-style newsletter on demand. I run `/research-digest` in a project. It reads the project's profile and sends one researcher per topic lane in parallel. Each returns the best stories of the last 30 days, read in full. The main session writes the newsletter and publishes it as a page.

The newsletter reads like a good industry digest written for me. An in-brief list opens it, then one section per lane. Each story is told in plain words with a short "for us" line. A few optional suggestions and the concepts worth learning close it. It has no file paths, no code verdicts, no ledger.

Given links or a topic, the same skill researches that material and what it connects to, in the same shape.

## User Stories

1. As the owner, I want one command per project, so that I get a newsletter on its field without setup.
2. As the owner, I want plain-worded stories with sources, so that I read it in ten minutes and follow up.
3. As the owner, I want a "for us" line per story, so that I see what it means for us.
4. As the owner, I want at most three closing suggestions, so that the report is no task list.
5. As the owner, I want a few concepts to learn with their best link, so that the report also teaches.
6. As the owner, I want to pass links or a topic, so that my own finds get the same report.
7. As the owner, I want the report as a well-designed page, so that it reads comfortably on desktop and phone.
8. As a maintainer, I want lanes and queries in one repo file, so that I edit them without the handbook.
9. As the handbook maintainer, I want one skill and two templates, so that there is little to keep current.

## Implementation Decisions

Reader and voice:

- The reader is the owner. The writing is technical-literate, plain English, short sentences.
- No file paths, function names, version specifiers or code verdicts anywhere in the report.
- Every claim links its source. Press is a lead; a paper, release or statute is the source of record.

Run shape:

- One skill in the handbook: `research-digest`, user-invoked only.
- A sweep covers the last 30 days. An older source is welcome when it still bears on the field. Runs are independent: no ledger, no dedup, no state between runs.
- The skill starts one researcher subagent per profile lane, in parallel, at most four.
- With links or a topic as argument, the skill starts one lane on that material instead, without a lookback.
- Researchers run on the most capable model with web search, web fetch and a shell for curl. Each one gets the project summary and its lane, and makes at most 40 web searches: a session has 200. Each returns three to six story drafts. A draft has a headline, source link, date, plain summary, solidity and "for us" line.
- The main session writes the report from the drafts. It picks the in-brief items, orders stories by importance and adds the suggestions and concepts. It publishes the page and prints the URL and the report path.

Report shape, in order:

1. Title with the date, and one line on what was swept.
2. In brief: five to eight bullets, most important first.
3. One section per lane, each story as headline, source line, summary and "For us".
4. Suggestions: zero to three, each one paragraph with its reason.
5. Learn: three to five concepts with their best link.

Profile, one markdown file per repo at `.claude/research-digest.md`:

- Project: three to six lines on what the project is and what matters to it now.
- Lanes: per lane its name, what it covers, its trusted feeds and its query terms.
- Reports: the folder reports go to.

Reading rules, a few lines in the skill:

- Read the full text, never an abstract or teaser alone.
- arXiv has an HTML view; PDFs go through `pdftotext`.
- Use curl for feeds and pages; WebFetch is for triage only.
- Never log in or submit a form; skip a walled source.

Page:

- A fixed HTML template of about a hundred lines, filled from the markdown report.
- It has light and dark themes, a contents rail, a wide reading column and a phone layout.
- It renders markdown and sanitises it, with no restructuring script.

Project lanes:

- gyva: retrieval research, AI progress, repair market, law and policy.
- jotti: cash-register law, fiskaly and TSEs, POS market, engineering.

Storage: reports stay outside git, in the folder the profile names. gyva uses `data/research-digest/`, jotti uses `~/Documents/research-digest/jotti/`.

Approaches weighed:

- Single agent: fewest parts, but one context reads everything, so a run gives few stories slowly.
- Workflow script: deterministic and resumable, but it is the complexity being removed.
- Parallel lanes plus a writing main session: breadth at small cost, no script. Chosen.

## Testing Decisions

- A run on gyva and a run on jotti, each read as a newsletter. The bar: no file paths or code names, every story linked, the in-brief list first and suggestions last.
- A run with two links as argument produces the same report shape.
- The page renders at 375 px and 1440 px in both themes without horizontal scroll.
- Handbook `make check` passes on the skill and templates; jotti `make check-repo` and gyva `lint-docrefs` pass on the profiles.

## Out of Scope

- Checking claims against the code, and code-level recommendations.
- Scheduled runs; a run starts only when I start it.
- Dedup across runs, and any ledger or state file.
- Stack release notes as a lane.

## Further Notes

Removed with the rebuild:

- The workflow script, the source catalogue and the old page template.
- The `gyva-researcher` and `jotti-researcher` agent files, and the old profile template.
- All earlier reports and pages: three jotti reports and pages, and the gyva sweep page.
- The memory note rewritten to the new design.
