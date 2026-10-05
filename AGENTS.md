# Agents

Rules for maintaining this repo. Setting up a machine, project or server starts at the [README Journeys](README.md#journeys). Communication and working rules: [claude/CLAUDE.md](claude/CLAUDE.md).

- Read the target directory before editing and match its style. Per-directory conventions live in `.claude/rules/`.
- Verify against the source before asserting anything about code, structure or behaviour.
- For external tools and specs, read the official docs, not memory.
- One source of truth: link to a template, script or doc instead of copying it.
- `README.md` indexes every guide, reference page, template, dotfile and script, grouped by area. Update it after every add, remove or rename.
- After renaming or deleting a file, `grep -r '<filename>' .` and fix every reference.
- When a tool version changes, grep the repo and update every occurrence.
- `make check` verifies links with their anchors, shellcheck, both indexes, top-level folder coverage, language and compose files. It checks the contracts: raw URLs, install origins and settings script paths. It also enforces the prose caps (sentence ≤ 20 words, paragraph ≤ 3 lines) and flags history words.
- English only. Exceptions: German phrases in `.claude/skills/audiobook/writing.md`, umlaut key names in `guides/neovim.md` and `dotfiles/init.lua`, the proper noun in `claude/CLAUDE.md` and `claude/settings.json`.
- A multi-file change starts with `docs/plans/plan-<slug>.md` (goal, files, checklist), ticked as you go and deleted when done. A single-file edit skips the plan.

## Layout

- One document kind per folder.
- `claude/` is the global Claude Code config. `.claude/` holds the repo rules and Stop hook, plus the shared skills and agents.
- `install.sh` links `dotfiles/` into `$HOME` and the `~/.claude` payload from `claude/`, `scripts/`, `.claude/agents` and `.claude/skills`. `scripts/install-dotfiles.sh --check` lists every link.
- Frozen paths: `scripts/setup-server.sh` and `scripts/report-health.sh`. Servers fetch them by raw URL, so they never move.
