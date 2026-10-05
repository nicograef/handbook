# Plan: Research digest, rebuilt

> Source PRD: docs/prds/prd-research-digest.md

## Goal

Replace the workflow-driven research digest with one small skill. It reads a per-repo profile and runs up to four lane researchers in parallel. It writes a plain-English newsletter and publishes it through a fixed page template. Then remove every part and output of the old design.

## Architectural decisions

- **Skill**: `.claude/skills/research-digest/` holds `SKILL.md` and `page.html` only. Frontmatter has `disable-model-invocation: true` and `argument-hint: "[links or topic]"`.
- **Researchers**: the Agent tool with `subagent_type: general-purpose` and `model: opus`, one per lane, all started in one message. Each makes at most 40 web searches and returns three to six story drafts.
- **Draft fields**: headline, source link, date, plain summary, solidity, "for us" line.
- **Profile**: `.claude/research-digest.md` in the project repo, with three `##` sections in this order:
  - `## Project`: three to six lines.
  - `## Lanes`: one `### <lane name>` per lane, each with `Covers:`, `Feeds:` and `Queries:` lines.
  - `## Reports`: one folder path.
- **Profile template**: `templates/research-digest.md`, the profile's real file name.
- **Report**: markdown at `<reports folder>/<YYYY-MM-DD>.md`, then `-2`, `-3` on collision. Headings in order:
  - `# <Project> research digest, <date>`, then one line on what was swept.
  - `## In brief`, with five to eight bullets.
  - One `## <lane name>` per lane, each story a `### <headline>` with a source line, summary and `**For us:**` line.
  - `## Suggestions`, with zero to three paragraphs.
  - `## Learn`, with three to five links.
- **Link mode**: an argument of links or a topic runs one lane named after the topic, with no lookback.
- **Page**: `page.html` keeps the `{{TITLE}}` and `{{REPORT}}` placeholders and loads marked and DOMPurify from cdnjs. Its script renders, sanitises, sets heading ids and builds the contents rail from `h2`/`h3`. It does nothing else.
- **Page fill**: the existing python one-liner fills the template. The skill publishes the page with the Artifact tool, `icon: "news"`.
- **Storage**: gyva reports go to `data/research-digest/`, which `**/data` already ignores. jotti reports go to `~/Documents/research-digest/jotti/`.

## Inventory

- `.claude/skills/research-digest/SKILL.md` — rewritten
- `.claude/skills/research-digest/page.html` — rewritten from 258 to about 100 lines. The CDN script tags and the fill one-liner carry over.
- `.claude/skills/research-digest/digest.workflow.js`, `sources.md` — deleted
- `templates/project-researcher.md` — deleted, replaced by `templates/research-digest.md`
- `README.md`, `.claude/skills/README.md` — index rows for the template and the skill
- `~/r/jotti/.claude/agents/jotti-researcher.md`, `~/r/gyva/.claude/agents/gyva-researcher.md` — deleted. Their topics, feeds and queries seed the new profiles.
- `~/Documents/research-digest/jotti/` — `2026-10-05.md`, `2026-10-05-2.md`, `2026-10-05-3.md`: old reports, deleted
- Artifacts `DtPYSguCNz2BFFnvbQyHhj` (gyva) and `PB9u5pC8CooGHmWszYPHQ5`, `UQReUCawWhR9CRR1oYAmQw`, `3CeFqTtRtyjgrt6Za5DvPw` (jotti) — old pages, deleted
- `~/.claude/projects/-home-nico-r-gyva/memory/research-digest.md` — rewritten to current state

## Resolved decisions

- No agent file: `general-purpose` on `opus` carries web search, web fetch and Bash. This keeps to the PRD's one skill and two templates.
- `pdftotext` is installed: poppler-utils 26.01 is on the host.
- The owner approved deleting the old reports and pages, as the gyva memory note records.

## Open questions / Risks

- implement-plan runs Phases 1 and 2 in the handbook. It cannot touch another repo, `~/Documents` or memory.
- Phases 3 and 4 are cross-repo. Each runs in its own worktree: `make worktree` in gyva, `git worktree add ../jotti-wt/<branch>` in jotti.
- Each cross-repo phase rebases with `git fetch origin && git rebase origin/main` and runs its gate. It lands with `git push origin <branch>:main`.
- No session runs pull, merge, checkout or rebase in `~/r/gyva` or `~/r/jotti` themselves.
- Phases 5 and 6 are owner-run after Phases 1 to 4 land on `main`. `~/.claude/skills` links to the handbook's main checkout, so the skill is live then.
- Artifact deletion asks the owner once per page.
- A session has 200 web searches, and one run can use 160. Each Phase 6 run therefore gets its own session.

## Phase 1: Page template

**User stories**: 7
**Depends on**: none

### Context

- `.claude/skills/research-digest/page.html` — the current template; keep its placeholders, CDN tags and theme-token pattern

### What to build

Write a new `page.html` of about 100 lines. It has light and dark tokens on `:root` with the `data-theme` overrides and a sticky contents rail beside a wide reading column. Below 760 px it collapses to one column. The script renders the report markdown with marked, sanitises it with DOMPurify and gives each `h2`/`h3` an id. It fills the rail from those headings. A fixture report in the scratchpad, shaped like the report headings above, exercises it.

### Acceptance criteria

- [x] `wc -l .claude/skills/research-digest/page.html` reports 120 lines or fewer
- [x] At 375 px and 1440 px, in both themes, Playwright reads `scrollWidth <= clientWidth` on the filled fixture page
- [x] A fixture line `<img src=x onerror="document.title='pwned'">` leaves `document.title` unchanged
- [x] On the filled fixture page, Playwright reads `document.querySelectorAll('nav a').length === document.querySelectorAll('main h2, main h3').length`
- [x] `make check` passes

## Phase 2: Skill and profile template

**User stories**: 1, 2, 3, 4, 5, 6, 8, 9
**Depends on**: none

### Context

- `.claude/skills/research-digest/SKILL.md` — the current skill; its page-fill one-liner and its publish step carry over
- `.claude/rules/skills.md` — body ≤ 120 lines, description ≤ 250 characters
- `.claude/rules/templates.md` — real file name, `<placeholders>`
- `~/r/jotti/.claude/agents/jotti-researcher.md` — `## Topics`, a model for the lane fields

### What to build

Rewrite `SKILL.md` so that one invocation does the whole run:

1. Read the profile, or stop and point at the template when it is missing.
2. Start one researcher per lane, or one researcher on the argument in link mode.
3. Write the report from the drafts, fill `page.html` and publish it.
4. Print the URL and the report path.

The researcher prompt carries the project summary, the lane, the 40-search cap, the reading rules and the draft fields. The skill states the reader, the voice and the bans: no file paths, code names, version specifiers or verdicts. Every claim carries its source link. Write `templates/research-digest.md` with the profile sections and `<placeholders>`. Delete the workflow script, `sources.md` and `templates/project-researcher.md`, and update both index rows.

### Acceptance criteria

- [x] `ls .claude/skills/research-digest` lists only `SKILL.md` and `page.html`
- [x] `awk '/^---$/{n++; next} n>=2' .claude/skills/research-digest/SKILL.md | wc -l` reports 120 or fewer
- [x] `grep -rnE 'project-researcher|digest\.workflow|research-digest/sources' . --exclude-dir=.git --exclude-dir=docs` prints nothing
- [x] `grep -c '^## ' templates/research-digest.md` reports 3: Project, Lanes, Reports
- [x] `make check` passes, its skills and readme index checks included

## Phase 3: jotti profile

**User stories**: 8
**Depends on**: none

### Context

- `~/r/jotti/.claude/agents/jotti-researcher.md` — `## Topics`: the feeds and queries to keep
- `~/r/jotti/AGENTS.md` — the profile is agent instruction, so it is in English; German query terms stay German

### What to build

In `~/r/jotti`, write `.claude/research-digest.md` in the profile shape. It has four lanes: cash-register law, fiskaly and TSEs, POS market, engineering. `Reports:` is `~/Documents/research-digest/jotti/`. The Project section states what jotti is and what matters now, with no file paths. Write query terms in backticks: jotti's prose scan caps sentences at 20 words and strips code spans. Delete `.claude/agents/jotti-researcher.md`.

### Acceptance criteria

- [x] `grep -c '^### ' .claude/research-digest.md` reports 4
- [x] `grep -rn jotti-researcher . --exclude-dir=.git` prints nothing
- [x] After `git add .claude/research-digest.md`, `make check-repo` passes

## Phase 4: gyva profile

**User stories**: 8
**Depends on**: none

### Context

- `~/r/gyva/.claude/agents/gyva-researcher.md` — `## Topics`: the feeds and queries to keep

### What to build

In a gyva worktree, write `.claude/research-digest.md` in the profile shape. It has four lanes: retrieval research, AI progress, repair market, law and policy. Stack release notes are no lane. `Reports:` is `data/research-digest/`. Delete `.claude/agents/gyva-researcher.md`.

### Acceptance criteria

- [x] `grep -c '^### ' .claude/research-digest.md` reports 4
- [x] `grep -rn gyva-researcher . --exclude-dir=.git --exclude-dir=data` prints nothing
- [x] After `git add .claude/research-digest.md`, `make lint-docrefs` passes

## Phase 5: Remove old outputs

**Depends on**: 2, 3, 4

### Context

- `~/.claude/projects/-home-nico-r-gyva/memory/research-digest.md` and its line in that folder's `MEMORY.md`
- `~/.claude/projects/-home-nico-r-jotti/memory/MEMORY.md` — the index for the moved fact

### What to build

Owner-run, after Phases 1 to 4 land.

1. Delete the three old jotti reports and the four old Artifact pages; the owner confirms each delete.
2. Rewrite the gyva memory note and its index line to the residue. The digest is the handbook skill; profile and reports live where this plan's header says.
3. Move one fact into a new jotti project memory with its index line. The fact: jotti's `docs/rechtsquellen/` misses the AEAO letter of 2026-02-27, and no public BMF route was found.

### Acceptance criteria

- [ ] `grep -L '^## In brief' ~/Documents/research-digest/jotti/*.md` prints nothing
- [ ] `Artifact list` shows none of the four old page ids
- [ ] `grep -nE 'rebuil|old design|to be removed' ~/.claude/projects/-home-nico-r-gyva/memory/research-digest.md ~/.claude/projects/-home-nico-r-gyva/memory/MEMORY.md` prints nothing
- [ ] `grep -l AEAO ~/.claude/projects/-home-nico-r-jotti/memory/*.md` lists the new file, and jotti's `MEMORY.md` names it

## Phase 6: Acceptance runs

**User stories**: 1, 2, 3, 4, 5, 6, 7
**Depends on**: 1, 2, 3, 4, 5

### Context

- The PRD's Testing Decisions — the bar each report is read against

### What to build

Owner-run. Make three runs, each in its own session, one after another:

1. `/research-digest` in `~/r/jotti`.
2. `/research-digest` in `~/r/gyva`.
3. `/research-digest <two links>` in `~/r/jotti`.

Read each report as a newsletter. A defect is fixed in the skill or the template, not in the report.

### Acceptance criteria

- [ ] For each report, `grep '^## '` shows `In brief` first and `Learn` last, with `Suggestions` just before it
- [ ] For each report, `sed -E 's#https?://[^ )>]+##g' <report> | grep -nE '[[:alnum:]_.-]+/[[:alnum:]_.-]+\.(py|go|ts|js|md|ya?ml|json|toml)|[a-z_]+\(\)|[=~<>]=[0-9]'` prints nothing
- [ ] For each report, `awk '/^## /{if(h&&!l)print h; h=""} /^### /{if(h&&!l)print h; h=$0; l=0} /https?:\/\//{l=1} END{if(h&&!l)print h}' <report>` prints nothing
- [ ] Each run printed an Artifact URL, and `Artifact read` returns its page
- [ ] The gyva report, filled into `page.html` with the fill one-liner, passes Phase 1's scroll check at 375 px and 1440 px in both themes as a `file://` page
