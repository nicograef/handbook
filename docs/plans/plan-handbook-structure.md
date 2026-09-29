# Plan: Handbook Structure

> Source PRD: `docs/prds/prd-handbook-structure.md`

## Goal

One document kind per folder, one entry page, and every live path contract checked by `make check` and `install.sh`.
Guards land first, so each later move runs under the anchor, folder-coverage and contract checks it could break.

## Architectural decisions

- **Folders**: `guides/` runbooks only · `reference/` reference pages · `templates/` copy-once files · `dotfiles/` files linked into `$HOME` outside `~/.claude` · `scripts/` server, repo and agent scripts · `claude/` global config · `.claude/` rules, Stop hook, skills, agents. Skills, agents and agent scripts stay in place.
- **Install table**: `scripts/install-dotfiles.sh` owns the one link table. Arguments are parsed before any side effect: none or `--check`; anything else prints usage and exits 2. `scripts/install-dotfiles.sh --check` is its pre-flight made callable: jq present, every origin exists, then one `<origin> <dest>` line per link (origin relative to the repo, dest relative to `$HOME`). It touches nothing and exits 1 on a failure. A plain run executes the same pre-flight before its first link.
- **Contracts stage**: `scripts/check-repo.sh contracts`, reached as `make contracts` and inside `make check`. Three checks:
  - Every handbook raw URL (raw GitHub content of `nicograef/handbook`, any ref) in a tracked file names a tracked path.
  - `install-dotfiles.sh --check` exits 0.
  - Every script path in `claude/settings.json` and `.claude/settings.json` exists. Candidates are every token ending in `.sh` in a hook command or `statusLine.command`, with shell quotes stripped, plus every `Bash(<path>:*)` allow entry. A candidate is checked when it starts with `~/.claude/`, `$HOME/.claude/` or `$CLAUDE_PROJECT_DIR/`. A `~/.claude/<rest>` or `$HOME/.claude/<rest>` path resolves through the install table: the dest `.claude/<rest>` itself, else the dest that is a directory prefix of it, then its origin plus the remainder. A `$CLAUDE_PROJECT_DIR/<path>` resolves in the repo. Any other candidate, such as the project-relative `scripts/agent-bus.sh`, names a path in whatever repo a session runs and is skipped. Non-script paths such as the `denials.log` write target are not candidates.
- **Anchors**: the links stage resolves `#anchor` for same-file links and links to a `.md` file, against GitHub heading slugs. Slug: heading text without inline code ticks, link URLs and `*`, lowercased, every character except letters, digits, space, `_` and `-` dropped, spaces turned to `-`. A repeated slug gets `-1`, `-2`. Headings inside code fences do not count.
- **Index coverage**: `INDEX_DIRS` ends as `guides reference templates dotfiles scripts claude`. Every other tracked top-level folder sits on an exclusion list, one reason per entry: `.claude` (the skills stage indexes skills; rules and agents are harness config), `docs` (PRDs, plans and their glossary are work files).
- **README**: a `## Journeys` section first, then the file index grouped by area: Dev machine, Project, Server, Agents, Handbook upkeep. Every indexed file appears in exactly one area.
- **AGENTS.md layout map**: the folder-kinds table, the payload folders `install.sh` links into `~/.claude`, and the two frozen paths `scripts/setup-server.sh` and `scripts/report-health.sh`.
- **Audiobook**: the pipeline guide becomes `.claude/skills/audiobook/pipeline.md`; `md-to-epub.sh`, `check-terms.sh` and `strip-visuals.lua` sit beside it. The skill calls them at `~/.claude/skills/audiobook/`, and `md-to-epub.sh` finds the filter beside itself.
- **Allowlist additions**: `~/.claude/check-agents.sh`, `~/.claude/plan-run-guard.sh`, and the two audiobook scripts at their installed paths. Nothing else in the allowlist changes; the agent-layer PRD owns the rest.
- **Stop hook**: the repo Stop hook command in `.claude/settings.json` exits 0 when the payload's `stop_hook_active` is true, else runs `scripts/check-repo.sh`. `check-repo.sh` stays unaware of hooks.
- **Landing**: `install.sh` never runs from a worktree. Phase 9 is the post-landing step: after implement-plan lands phases 1 to 8, the lead runs it in the main checkout before anything else. No worker runs phase 9. The lead ticks it on the base branch, then removes the plan file. The owner then updates `~/.claude/rules/machine.md` by hand (`templates/init.lua` becomes `dotfiles/init.lua`).

## Inventory

- `scripts/check-repo.sh — check_links()` — gains anchor resolution; same-file `#` links are skipped today
- `scripts/check-repo.sh — check_readme(), INDEX_DIRS` — gains folder coverage and the final folder list
- `scripts/check-repo.sh — check_shell()` — lint glob names `templates/.bash_aliases`
- `scripts/check-repo.sh — case "$STAGE"` — stage dispatch and usage string
- `scripts/install-dotfiles.sh — link()` — prints SKIP on a missing origin; the `templates/.bash_aliases` guard; jq used without a check; no argument parsing
- `install.sh` — wrapper that execs `scripts/install-dotfiles.sh` without arguments
- `Makefile` — one target per stage, `check` comment lists stages
- `claude/settings.json — permissions.allow` — no entry for `check-agents.sh` or `plan-run-guard.sh`
- `claude/settings.json — hooks, statusLine` — `$HOME/.claude/*.sh` paths the contracts stage resolves
- `.claude/settings.json — hooks.Stop` — runs `"$CLAUDE_PROJECT_DIR"/scripts/check-repo.sh` with no `stop_hook_active` release
- `agents` — redundant root symlink to `.claude/agents`
- `templates/cloud-init.yml`, `scripts/setup-server.sh` — the handbook raw URLs, pointing at the frozen paths
- `.claude/skills/programme/SKILL.md — Workflow step 6` — calls the handbook `scripts/check-agents.sh`
- `.claude/skills/implement-plan/SKILL.md`, `git.md` — call `~/.claude/plan-run-guard.sh claim`
- `.claude/skills/audiobook/SKILL.md` — links the pipeline guide, calls `scripts/check-terms.sh` and `scripts/md-to-epub.sh`
- `scripts/md-to-epub.sh — FILTER` — default resolves through `REPO_ROOT` to `templates/strip-visuals.lua`
- `.claude/rules/cheatsheets.md`, `.claude/rules/guides.md` — folder conventions; the rule-list convention sits in the guides rule
- `.claude/rules/scripts.md — paths` — scoped to `scripts/**` only
- `guides/bootstrap.md` — routing plus the dev-machine and first-deploy steps
- `README.md`, `AGENTS.md` — entry and index; inbound references to every moved file
- `~/.claude/rules/machine.md` — machine-local, names `templates/init.lua`; outside the repo

## Resolved decisions

- Clarification: zero questions; the PRD, the code and the owner decisions settle every fork.
- Guards before moves. Phases 1 to 3 have no Depends-on and run as parallel lanes with disjoint files.
- Choke files are shared only along the Depends-on chain: `scripts/check-repo.sh` (3, 4, 5, 6), `AGENTS.md` (4, 5, 6, 8), `README.md` (5 to 8), `.claude/rules/` (5 only).
- A moving phase owns every inbound reference to what it moves, choke files included.
- `--check` gives the contracts stage the install table without parsing the script, and makes the missing-origin and missing-jq paths verifiable without linking anything.
- `plan-run-guard.sh` and the audiobook scripts are allowlisted beside `check-agents.sh`: user story 8 covers every script a skill calls.
- `claude/` joins `INDEX_DIRS`: the README already links all three files, so the guard costs nothing.
- Negative probes are one-off acceptance criteria, not a permanent fixture test. One probe per contract; the settings probe breaks one candidate of each kind in a single edit. Restore a probed file by moving it back or with `git restore <path>`; `git checkout --` and `git restore .` are denied.
- The bootstrap content moves verbatim into the README and the two new runbooks; only headings change. The journeys plan rewrites it.
- The scripts rule widens to `.claude/skills/**/*.sh` in phase 5, the one phase owning `.claude/rules/`, so the audiobook scripts keep the script conventions after phase 7.
- The plan names no handbook raw URL literally and links no file, so the new stages never trip on it.
- Owner ruling 2026-09-29: `install-dotfiles.sh --check` stays, with its all-or-nothing pre-flight.
- `guides/dev-machine.md` and `guides/deploy.md` get `## Prerequisites` and `## Verify` now: the PRD defines `guides/` as runbooks.
- Anchor checking keeps GitHub's duplicate-slug suffixes: the PRD names GitHub heading slugs.

## Open questions / Risks

- Between landing and phase 9's first `install.sh` run, `~/.bash_aliases`, `~/.tmux.conf` and `~/.config/nvim/init.lua` dangle, and `~/.claude/check-agents.sh` is missing. Phase 9 runs first after landing, so that window is one command.
- `claude/settings.json` is live in every session. Its allowlist additions take effect at landing.
- A later PRD or plan that quotes a handbook raw URL with a placeholder path fails the contracts stage. Write such URLs without the host.

## Phase 1: Install contract

**User stories**: 6, 8
**Depends on**: none

### Context

- `scripts/install-dotfiles.sh — link()` — today prints SKIP and returns
- `claude/settings.json — permissions.allow`
- `.claude/skills/programme/SKILL.md — Workflow step 6`
- `scripts/check-agents.sh`, `scripts/plan-run-guard.sh` — read only
- Gotcha: today the script parses no arguments, so `--check` on it is a full install into the real `$HOME`, repointing `~/.claude` into the worktree. Argument parsing, as a `case` with a `--check)` arm, is the phase's first commit. Every criterion that invokes the script starts with the `grep -q -- '--check)'` guard; run none before that commit exists.

### What to build

`scripts/install-dotfiles.sh` parses its arguments first, holds its links in one table and gains `--check`, as the header decision describes. The plain run runs that pre-flight before its first link, so a missing origin or a missing jq exits 1 with nothing changed. The table gains `scripts/check-agents.sh` linked to `.claude/check-agents.sh`. The script header lists `--check` and the new link. The `templates/.bash_aliases` guard goes, since the pre-flight covers it. `claude/settings.json` allows `Bash(~/.claude/check-agents.sh:*)` and `Bash(~/.claude/plan-run-guard.sh:*)`. The programme skill calls `~/.claude/check-agents.sh`. Never run the plain install here.

### Acceptance criteria

- [ ] `grep -q -- '--check)' scripts/install-dotfiles.sh && scripts/install-dotfiles.sh --bogus; echo $?` prints the usage, then 2
- [ ] `grep -q -- '--check)' scripts/install-dotfiles.sh && scripts/install-dotfiles.sh --check` exits 0 and prints `scripts/check-agents.sh .claude/check-agents.sh` among its lines; `test ! -e ~/.claude/check-agents.sh` still holds afterwards
- [ ] Probe: with `scripts/check-agents.sh` moved aside, the guarded `--check` exits 1 naming it; moved back, it exits 0
- [ ] Probe: `grep -q -- '--check)' scripts/install-dotfiles.sh && { d=$(mktemp -d); ln -s "$(command -v dirname)" "$d/"; PATH="$d" "$(command -v bash)" scripts/install-dotfiles.sh --check; echo $?; }` prints a line naming jq, then 1
- [ ] `jq -r '.permissions.allow[]' claude/settings.json | grep -cE '^Bash\(~/\.claude/(check-agents|plan-run-guard)\.sh:\*\)$'` prints 2
- [ ] `grep -n '~/.claude/check-agents.sh' .claude/skills/programme/SKILL.md` hits, and `git grep -n 'scripts/check-agents.sh' .claude/skills` prints nothing
- [ ] `make check` passes

## Phase 2: Stop hook release and redundant symlink

**User stories**: 9
**Depends on**: none

### Context

- `.claude/settings.json — hooks.Stop`
- `agents` — root symlink

### What to build

The repo Stop hook releases a session that was already blocked once: with `stop_hook_active` true it exits 0, otherwise it runs `scripts/check-repo.sh` as today. The redundant root `agents` symlink is deleted.

### Acceptance criteria

- [ ] With a scratch history word in any tracked Markdown file, `printf '{"stop_hook_active":true}' | CLAUDE_PROJECT_DIR="$PWD" bash -c "$(jq -r '.hooks.Stop[0].hooks[0].command' .claude/settings.json)"` exits 0
- [ ] With the same scratch edit and `"stop_hook_active":false`, the same command exits 2; with the edit restored, it exits 0
- [ ] `git ls-files agents` prints nothing and `test ! -L agents` holds
- [ ] `make check` passes

## Phase 3: Anchor and folder-coverage checks

**User stories**: 7
**Depends on**: none

### Context

- `scripts/check-repo.sh — check_links(), check_readme(), INDEX_DIRS`
- `Makefile` — `links` and `readme` target comments

### What to build

The links stage resolves anchors as the header decision describes, and names the file, link and missing slug on a miss. The readme stage fails on a tracked top-level folder that is neither in `INDEX_DIRS` nor on the exclusion list. Top-level folders are the first path components of `git ls-files` entries that contain a `/`, so a tracked top-level symlink such as `agents` never counts. `INDEX_DIRS` gains `claude`; the exclusion list names `.claude` and `docs` with their reasons. The Makefile comments of `links` and `readme` say what the stages now check.

### Acceptance criteria

- [ ] `make links` passes on the current tree
- [ ] Probe: renaming the `### Roll back` heading in `guides/maintenance.md` makes `make links` fail naming `guides/maintenance.md` and `#roll-back`; restored, it passes
- [ ] Probe: a tracked scratch file in a new top-level folder (`git add`) makes `make readme` fail naming the folder; unstaged and removed, it passes
- [ ] `make readme` passes with `claude` in `INDEX_DIRS`
- [ ] `make check` passes

## Phase 4: Contracts stage

**User stories**: 6, 7
**Depends on**: 1, 2, 3

### Context

- `scripts/check-repo.sh — case "$STAGE"` — new `contracts` stage, also run by `all`
- `scripts/install-dotfiles.sh --check` — from phase 1
- `claude/settings.json`, `.claude/settings.json` — read only
- `templates/cloud-init.yml`, `scripts/setup-server.sh` — read only
- `Makefile`, `AGENTS.md` — the `make check` sentence
- Gotcha: the raw-URL scan covers `scripts/check-repo.sh` itself. Its source builds the host pattern with escaped dots. No comment, usage string, Makefile comment or `AGENTS.md` sentence quotes a literal handbook raw URL.

### What to build

`scripts/check-repo.sh contracts` runs the three checks of the header decision and names the file and path of every broken contract. `make contracts` reaches it, `make check` runs it, and the script header and usage string list it. The `make check` sentence in `AGENTS.md` names anchors, folder coverage and contracts.

### Acceptance criteria

- [ ] `make contracts` passes, and `make help` lists `contracts`
- [ ] Probe: pointing the raw URL in `templates/cloud-init.yml` at a missing script makes `make check` fail naming the file and path; restored, it passes
- [ ] Probe: with `claude/statusline.sh` moved aside, `make contracts` fails naming it; moved back, it passes
- [ ] Probe: renaming, to names nothing provides, the Stop hook script in `.claude/settings.json`, the `statusLine` script in `claude/settings.json` and the `Bash(~/.claude/agent-bus.sh:*)` allow entry makes `make contracts` fail naming all three; restored, it passes
- [ ] `grep -n contracts AGENTS.md` hits the `make check` sentence
- [ ] `make check` passes

## Phase 5: Reference shelf

**User stories**: 2, 3
**Depends on**: 4

### Context

- `cheatsheets/postgresql.md`, `cheatsheets/system-resources.md`, `cheatsheets/tmux.md`, `guides/stack-conventions.md` — move to `reference/`
- `.claude/rules/cheatsheets.md` — becomes `.claude/rules/reference.md`
- `.claude/rules/guides.md` — loses the convention-guide line
- `.claude/rules/scripts.md — paths, description` — widens to skill scripts
- `scripts/check-repo.sh — INDEX_DIRS` and the exclusion list
- `README.md`, `AGENTS.md`
- `guides/maintenance.md`, `guides/provision-server.md`, `guides/new-project.md` — inbound links

### What to build

The four reference pages live in `reference/` and `cheatsheets/` is gone. `.claude/rules/reference.md` scopes `reference/**` and holds both page shapes: command tables, and rule lists with one line of rationale. `.claude/rules/guides.md` states runbooks only and says "reference pages" where it said cheatsheets. `.claude/rules/scripts.md` scopes `scripts/**` and `.claude/skills/**/*.sh`, and its description names both. `INDEX_DIRS` swaps `cheatsheets` for `reference`. README, AGENTS.md and the three guides point at the new paths, anchors included.

### Acceptance criteria

- [ ] `git ls-files reference` lists the four pages; `git ls-files cheatsheets guides/stack-conventions.md .claude/rules/cheatsheets.md` prints nothing
- [ ] `git grep -n -i -e cheatsheet -e guides/stack-conventions -- ':!docs'` prints nothing
- [ ] `head -4 .claude/rules/reference.md` shows `paths: "reference/**"`, and `grep -n rationale .claude/rules/reference.md` hits
- [ ] `grep -n stack-conventions .claude/rules/guides.md` prints nothing
- [ ] `grep -nF '.claude/skills/**/*.sh' .claude/rules/scripts.md` hits the `paths` frontmatter
- [ ] `make links readme` passes
- [ ] `make check` passes

## Phase 6: Dotfiles folder

**User stories**: 5, 6
**Depends on**: 5

### Context

- `templates/.bash_aliases`, `templates/.tmux.conf`, `templates/init.lua` — move to `dotfiles/`
- `scripts/install-dotfiles.sh` — link table rows
- `scripts/check-repo.sh — INDEX_DIRS, check_shell()`
- `README.md`, `AGENTS.md` — index rows; the English-only exception names `init.lua`
- `guides/neovim.md`, `reference/tmux.md`, `guides/provision-server.md` — inbound links and the `readlink` expected output

### What to build

The three dotfiles live in `dotfiles/`, and the install table links them from there to the same dests. `INDEX_DIRS` gains `dotfiles`, and the lint glob covers `dotfiles/.bash_aliases`. README indexes the three files under their new paths. Every inbound reference names `dotfiles/`. Nothing runs `install.sh` during the run; phase 9 relinks the new origins after landing.

### Acceptance criteria

- [ ] `git ls-files dotfiles` lists the three files; `git ls-files templates/.bash_aliases templates/.tmux.conf templates/init.lua` prints nothing
- [ ] `scripts/install-dotfiles.sh --check` exits 0 and prints `dotfiles/.bash_aliases .bash_aliases`, `dotfiles/.tmux.conf .tmux.conf` and `dotfiles/init.lua .config/nvim/init.lua`
- [ ] `git grep -n -E 'templates/(\.bash_aliases|\.tmux\.conf|init\.lua)' -- ':!docs'` prints nothing
- [ ] `grep -n "dotfiles/.bash_aliases" scripts/check-repo.sh` hits the lint glob, and `make lint` passes
- [ ] `make check` passes

## Phase 7: Audiobook pipeline into its skill

**User stories**: 2, 8
**Depends on**: 6

### Context

- `guides/audiobook-pipeline.md` — becomes `.claude/skills/audiobook/pipeline.md`
- `scripts/md-to-epub.sh`, `scripts/check-terms.sh`, `templates/strip-visuals.lua` — move beside it
- `.claude/skills/audiobook/SKILL.md`, `.claude/skills/audiobook/writing.md`
- `claude/settings.json — permissions.allow`
- `README.md` — four rows leave the index

### What to build

The audiobook pipeline lives entirely in its skill directory. `SKILL.md` introduces `pipeline.md` as its reference file and calls both scripts at their installed paths. `md-to-epub.sh` defaults its filter to the file beside itself. Script headers, the filter header and `pipeline.md` name the new paths. `claude/settings.json` allows both scripts at their installed paths, and the contracts stage resolves them through the `.claude/skills` link.

### Acceptance criteria

- [ ] `git ls-files .claude/skills/audiobook` lists `SKILL.md`, `writing.md`, `pipeline.md`, `md-to-epub.sh`, `check-terms.sh` and `strip-visuals.lua`
- [ ] `git grep -n -E 'audiobook-pipeline|scripts/(md-to-epub|check-terms)\.sh|templates/strip-visuals' -- ':!docs'` prints nothing
- [ ] `grep -n 'FILTER=' .claude/skills/audiobook/md-to-epub.sh` shows a default relative to the script's own directory
- [ ] `.claude/skills/audiobook/check-terms.sh /nonexistent` exits 2 with "chapter directory not found"
- [ ] `jq -r '.permissions.allow[]' claude/settings.json | grep -c '~/.claude/skills/audiobook/'` prints 2, and `make contracts` passes
- [ ] `make check` passes

## Phase 8: Entry page and layout map

**User stories**: 1, 2, 4
**Depends on**: 7

### Context

- `guides/bootstrap.md` — dissolved
- `guides/dev-machine.md`, `guides/deploy.md` — new runbooks holding the moved steps
- `README.md` — `## Journeys` first, then the area index
- `AGENTS.md` — entry pointer, index sentence, layout map
- `guides/neovim.md`, `guides/new-project.md` — inbound links
- `scripts/install-dotfiles.sh --check` — read only, the payload source

### What to build

The bootstrap content moves verbatim; only headings change. Its routing becomes the README `## Journeys` section, with the gather-first lists and done-when lines as they stand. The New dev machine steps become `guides/dev-machine.md`. Its `## Prerequisites` names an Ubuntu machine with a `sudo` user; its `## Verify` holds the moved done-when check. The first-deploy step becomes `guides/deploy.md`. Its `## Prerequisites` holds the moved "point DNS at the VPS first" and links `provision-server.md#verify`. Its `## Verify` links `letsencrypt-docker.md#verify`, the moved verify pointer. The fresh-VPS journey links `deploy.md` at that step.

After Journeys, the README index groups every file by the five areas of the header decision; the folder-named sections go. `AGENTS.md` gains the layout map: the folder-kinds table, one line naming the payload folders `install.sh` links into `~/.claude`, and both frozen paths. Its entry pointer and index sentence match the new README. `guides/neovim.md` and `guides/new-project.md` point at the Journeys section or a new runbook file, never at a step heading: the journeys plan renames those.

### Acceptance criteria

- [ ] `git ls-files guides/bootstrap.md` prints nothing, and `git grep -n 'bootstrap\.md' -- ':!docs'` prints nothing
- [ ] `grep -cE '^## (Prerequisites|Verify)$' guides/dev-machine.md guides/deploy.md` prints 2 for each file
- [ ] `grep -n '^## ' README.md` lists Journeys, Dev machine, Project, Server, Agents, Handbook upkeep and License, in that order
- [ ] `awk '/^## Journeys/{j=1;next} /^## /{j=0} j' README.md | grep -oE 'guides/(dev-machine|deploy|provision-server|new-project)\.md' | sort -u | wc -l` prints 4
- [ ] `awk '/^## Journeys/{j=1;next} /^## /{j=0} !j' README.md | grep -oE '\]\([^)#]+' | sort | uniq -d` prints nothing
- [ ] `for d in guides reference templates dotfiles scripts claude .claude; do grep -qF "| \`$d/\`" AGENTS.md || echo "missing $d"; done` prints nothing
- [ ] `grep -n -e 'scripts/setup-server.sh' -e 'scripts/report-health.sh' AGENTS.md` hits both frozen paths
- [ ] `scripts/install-dotfiles.sh --check | awk '$2 ~ /^\.claude\// {print $1}'` lists origins under `claude/`, `scripts/`, `.claude/agents` and `.claude/skills` only
- [ ] `grep -i payload AGENTS.md | grep -E '(^|[^.])claude/' | grep -F 'scripts/' | grep -F '.claude/agents' | grep -F '.claude/skills'` hits
- [ ] `make links readme` passes
- [ ] `make check` passes

## Phase 9: Landing

**User stories**: 6
**Depends on**: 8

### Context

- Runs in the main checkout `~/r/handbook` after implement-plan lands phases 1 to 8, never in a worktree. The lead runs it first, before anything else, and ticks it on the base branch.
- `install.sh`, `scripts/install-dotfiles.sh` — run for real here only

### What to build

The live `$HOME` matches the landed install table. Two plain runs link every origin, and a missing origin stops the plain run before its first link.

### Acceptance criteria

- [ ] In `~/r/handbook`, `./install.sh 2>&1 | grep -c SKIP` prints 0 on two consecutive runs
- [ ] `scripts/install-dotfiles.sh --check | while read -r o d; do [ "$(readlink -f ~/"$d")" = "$(readlink -f "$o")" ] || echo "$d"; done` prints nothing
- [ ] Probe: with `scripts/check-agents.sh` moved aside, `./install.sh > /tmp/install.log 2>&1; echo $?` prints 1, `grep -c Linked /tmp/install.log` prints 0 and `grep -c check-agents /tmp/install.log` prints at least 1; moved back, `git status --short` prints nothing
- [ ] `make check` passes
