# Agents

This is a personal knowledge base for infrastructure, server setup and CLI workflows.
Target system: Debian / Ubuntu.

## Structure

- `guides/` – step-by-step instructions (runbook-style)
- `cheatsheets/` – quick-reference commands
- `templates/` – copy-paste-ready config files (.bashrc, Makefile, docker-compose.yml, nginx.conf)
- `scripts/` – reusable bash scripts

## Language

All documentation is written in English. Keep it that way.

## Conventions

- Read `README.md` for a full index of all files before making changes.
- Before editing or creating a file, read the target directory to understand existing content and style.
- Keep files concise and practical – no boilerplate prose. Optimise for fast scanning.
- Guides use fenced code blocks with copy-paste-ready commands and `diff` blocks for config changes.
- Cheatsheets use tables or commented code blocks – no explanatory paragraphs.
- Templates must be functional as-is, with commented-out optional sections.
- Update `README.md` when adding, removing or renaming files.

## Keeping Docs in Sync

Every change must leave the knowledge base consistent. Follow these rules:

- **Single source of truth** – never duplicate content across files. If something is defined in a template or script, reference it from guides instead of copying it inline.
- **Cross-references over copies** – use relative links (`[docker-compose.prod.yml](../templates/docker-compose.prod.yml)`) instead of repeating config blocks.
- **Delete, don't deprecate** – if a file becomes redundant, delete it and remove all references.
- **Version consistency** – when a tool version changes (Docker image tag, Node version, action version), grep the whole repo and update every occurrence.
- **README is the index** – it must always reflect the exact files on disk. After any file add/remove/rename, verify the table entries match.
- **No dead links** – after renaming or deleting a file, search for all references (`grep -r '<filename>'`) and update or remove them.
- **English only** – all content, examples and placeholder data must be in English.
