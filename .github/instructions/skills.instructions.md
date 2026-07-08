---
description: "Use when editing or creating agent skills in the skills/ directory."
applyTo: "skills/**"
---

# Skill Conventions

## Directory Structure

Each skill lives in its own directory under `skills/`:

```
skills/<skill-name>/
├── SKILL.md           # required — main skill definition
├── REFERENCE.md       # optional — supplementary reference material
└── <topic>.md         # optional — additional reference files
```

## SKILL.md Format

Every `SKILL.md` must include:

1. **YAML frontmatter** with `name`, `description`, and `tools` (if applicable).
2. **Workflow section** — numbered steps the agent follows.
3. **Constraints section** — guardrails, anti-patterns, or things to avoid.
4. **Quality section** (for skills that present results) — links to the shared self-review checklist at `skills/quality.md` via a `../quality.md` relative link.

```yaml
---
name: "skill-name"
description: "One-line summary of what the skill does and when to invoke it."
# tools:
#   - tool_name
---
```

## Content Rules

- Write actionable instructions, not explanations.
- Use imperative voice ("Search the codebase", not "The agent should search").
- Include anti-pattern warnings where common mistakes exist.
- Reference external files with relative links: `[REFERENCE.md](REFERENCE.md)`.
- `description` states the trigger ("Use when...") and what the skill does, in third person — never a step-by-step workflow summary; agents shortcut-follow a summarized workflow instead of reading the skill body.
- Keep reference files short and focused; push detail out of `SKILL.md` into them so the main file stays scannable (progressive disclosure — load only what's needed).

## File Naming

- Directory: `<verb-noun>` or `<topic>` — lowercase, hyphens. Example: `code-audit/`.
- Main file: always `SKILL.md`.
- Reference files: descriptive names. Example: `interface-design.md`, `mocking.md`.

## After Creating or Renaming a Skill

1. Add or update the entry in `README.md` (Skills table).
2. Add or update the entry in `skills/README.md` (discovery index).
3. Search for references to the old name: `grep -r '<old-name>' .`
