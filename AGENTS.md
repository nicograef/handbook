# Agents

This is a personal knowledge base for infrastructure, server setup and CLI workflows.
Target system: Debian / Ubuntu. It contains no runnable application — everything is
documentation, templates, scripts, and agent skills.

This file is the single canonical instruction set. Every Copilot surface reads it directly;
Claude Code loads it via `@AGENTS.md` from `CLAUDE.md`. `.claude/rules/*.md` is the only
path-scoped conventions surface (loaded by Claude Code when you touch matching files); Copilot
works through AGENTS.md.

## Structure

- `guides/` — step-by-step instructions (runbook-style) and stack-convention guides.
- `cheatsheets/` — quick-reference commands.
- `templates/` — copy-paste-ready config files (`.bashrc`, `Makefile`, `docker-compose.yml`, `nginx-tls.conf`).
- `scripts/` — reusable bash scripts.
- `.claude/skills/` — reusable agent skills (see `.claude/skills/README.md`).
- `.claude/agents/` — subagent definitions (`web-researcher`); the root `agents` symlink
  exposes it to the plugin's default agent scan (the manifest `agents` field does not load
  agents in Claude Code v2.1.197).
- `.claude/rules/` — path-scoped conventions for Claude Code.
- `.claude-plugin/` — plugin + marketplace manifests exposing the skills and agent as a public Claude Code plugin.
- `claude/` — dotfiles: global `CLAUDE.md`, `settings.json`, `statusline.sh`.

## Searching

| Command | Description |
|---------|-------------|
| `grep -r '<term>' .` | Search for references across all files |
| `find . -name '*.md'` | List all Markdown files |

## Working rules

Each rule is stated once and applies repo-wide.

- **Read `README.md` first** — it is the file index. Read the target directory to understand
  existing content and style before editing or creating a file.
- **Verify before claiming** — search the codebase before asserting anything about existing
  code, structure, or behaviour; read the actual source instead of guessing.
- **Ask instead of assuming** — when uncertain about requirements or intent, ask structured
  questions. Proceed on documented assumptions only if the user declines to answer.
- **Web search for external knowledge** — when working with external tools, libraries, or
  specs, consult authoritative sources (official docs, RFCs) rather than training data.
- **Single source of truth** — never duplicate content across files. Reference a template,
  script, or another doc with a relative link instead of copying it inline.
- **README is the index** — update it after every file add, remove, or rename so its table
  entries match the files on disk.
- **No dead links** — after renaming or deleting a file, `grep -r '<filename>' .` and update
  or remove every reference.
- **Delete, don't deprecate** — if a file becomes redundant, delete it and remove all
  references.
- **Version consistency** — when a tool version changes, `grep` the whole repo and update
  every occurrence.
- **Keep files concise** — no boilerplate prose; optimise for fast scanning.
- Ask before deleting or renaming a file (check for references first).

## Language

All content is written in English. Exception: the German example phrases in
`.claude/skills/cleanup/readability-de.md` (its explanatory prose stays English).

## Plan-first workflow

For multi-file changes:

1. **Research** — read affected files; understand existing style and cross-references.
2. **Plan** — create `plan.md` in the project root with the goal, affected files, and a
   step-by-step checklist. Do not make changes yet.
3. **Execute** — work through the checklist; tick off each step (`- [x]`) as you complete it.
4. **Verify** — check links, confirm `README.md` is up to date, re-read changed files.
5. **Clean up** — delete `plan.md` when done.

For trivial single-file changes (typo fix, adding one section), skip the plan and edit directly.

## Git

Do not commit without explicit user approval — propose the message first (use `/commit`);
no `--force` / `--no-verify` push.
