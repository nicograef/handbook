# Agents

Rules for maintaining this repo. Setting up a machine or project starts at [guides/bootstrap.md](guides/bootstrap.md). Communication and working rules: [claude/CLAUDE.md](claude/CLAUDE.md).

- Read the target directory before editing and match its style. Per-directory conventions live in `.claude/rules/`.
- Verify against the source before asserting anything about code, structure or behaviour.
- For external tools and specs, read the official docs, not memory.
- One source of truth: link to a template, script or doc instead of copying it.
- `README.md` indexes every guide, cheatsheet, template and script. Update it after every add, remove or rename.
- After renaming or deleting a file, `grep -r '<filename>' .` and fix every reference.
- When a tool version changes, grep the repo and update every occurrence.
- `make check` verifies links, shellcheck, both indexes, language, compose files and the plugin manifest. It also enforces the prose caps: sentence ≤ 20 words, paragraph ≤ 3 lines.
- English only. Exceptions: German phrases in `.claude/skills/audiobook/writing.md`, umlaut key names in `guides/neovim.md` and `templates/init.lua`, the proper noun in `claude/CLAUDE.md` and `claude/settings.json`.
- A multi-file change starts with `docs/plans/plan-<slug>.md` (goal, files, checklist), ticked as you go and deleted when done. A single-file edit skips the plan.
- Commit each completed task: Conventional Commit, bullet body for multi-file changes, no AI attribution. No force-push, no `--no-verify`.
