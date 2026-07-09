---
description: "Conventions for editing or creating agent skills in the .claude/skills/ directory."
paths: ".claude/skills/**"
---

# Skill Conventions

## Directory Structure

Each skill lives in its own directory under `.claude/skills/`:

```
.claude/skills/<skill-name>/
├── SKILL.md           # required — main skill definition
├── REFERENCE.md       # optional — supplementary reference material
└── <topic>.md         # optional — additional reference files
```

## SKILL.md Format

Every `SKILL.md` includes:

1. **YAML frontmatter** — see the fields below.
2. **Workflow section** — numbered steps the agent follows.
3. **Constraints section** — guardrails, anti-patterns, or things to avoid.
4. **Quality section** (only for skills that produce code or documents) — a `../quality.md`
   relative link to the shared verification contract. Process-only and review-only skills omit it.

```yaml
---
name: skill-name
description: "Third-person summary of what the skill does and when to invoke it."
# allowed-tools:            # optional — restrict the skill to these tools
#   - Read
#   - Grep
---
```

## Frontmatter fields

- `name` — required; lowercase letters, numbers, and hyphens; ≤ 64 chars; matches the
  directory name.
- `description` — required; non-empty, ≤ 1024 chars; no XML tags. States the trigger
  ("Reviews…", "Guides…") in third person, never a step-by-step workflow summary.
- `allowed-tools` — optional; the tool-name allowlist for the skill. This is the skill field;
  `tools:` is subagent-only (see `.claude/agents/`), do not use it in a skill.
- `disable-model-invocation` — optional; `true` for side-effect flows the model should not
  auto-trigger (still reachable via its slash command).
- `user-invocable` — optional; `false` hides the skill from the slash-command menu.
- `argument-hint` — optional; a short hint shown for slash-command arguments.

## Content Rules

- Write actionable instructions, not explanations.
- Include anti-pattern warnings where common mistakes exist.
- Reference bundled files with relative links.
- Keep reference files short and focused; push detail out of `SKILL.md` into them so the main
  file stays scannable (progressive disclosure — load only what's needed).
- Every reference file over 100 lines opens with a short bullet TOC of its `##` headings,
  directly under the H1.

## File Naming

- Directory: `<verb-noun>` or `<topic>` — lowercase, hyphens. Example: `cleanup/`.
- Main file: always `SKILL.md`.
- Reference files: descriptive names. Example: `interface-design.md`, `mocking.md`.

## Deployment

- Skills deploy as the whole `.claude/skills/` directory, so the shared `quality.md` and each
  skill's reference files travel with the skill — reference them with relative links, not
  absolute paths.
- Copilot CLI pre-approves a skill's declared shell only for skills you trust; keep
  `allowed-tools` minimal so an untrusted skill cannot silently run destructive commands.

## After Creating or Renaming a Skill

1. Add or update the entry in `README.md` (Skills section).
2. Add or update the entry in `.claude/skills/README.md` (discovery index).
3. Search for references to the old name: `grep -r '<old-name>' .`
