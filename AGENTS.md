# Agents

Rules for maintaining this repo. Setting up a machine, project or server starts at the [README Journeys](README.md#journeys). Communication and working rules: [claude/global.md](claude/global.md).

- Read the target directory before editing and match its style. Per-directory conventions live in `.claude/rules/`.
- Verify against the source before asserting anything about code, structure or behaviour.
- For external tools and specs, read the official docs, not memory.
- One source of truth: link to a template, script or doc instead of copying it.
- `README.md` indexes every guide, reference page, template, dotfile and script, grouped by area. Update it after every add, remove or rename.
- After renaming or deleting a file, `grep -r '<filename>' .` and fix every reference.
- When a tool version changes, grep the repo and update every occurrence.
- `make check` runs every repo self-check, the prose caps (sentence ≤ 20 words, paragraph ≤ 3 lines) and history words included; `make help` lists the stages.
- English only. Markdown exceptions are `LANG_ALLOW` in `scripts/check-repo.sh`; elsewhere, umlaut key names in `dotfiles/init.lua` and the owner's name in `claude/settings.json`.
- A multi-file change starts with `docs/plans/plan-<slug>.md` (goal, files, checklist), ticked as you go and deleted when done. A single-file edit skips the plan.

## Layout

- One document kind per folder.
- `claude/` is the global Claude Code config. `.claude/` holds the repo rules and Stop hook, and the shared skills and agents.
- `scripts/install-dotfiles.sh --check` lists every link `install.sh` creates in `$HOME`.
