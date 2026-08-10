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
5. **Output-style link** (only for skills that emit a report or an artifact) — an
   `../output-style.md` relative link beside `../quality.md`.

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
- Reference bundled files with relative links, not absolute paths.
- Give reference files descriptive names. Example: `mocking.md`.
- Keep reference files short and focused.
- Push detail out of `SKILL.md` into them so the main file stays scannable.
- Progressive disclosure — load only what's needed.
- Every reference file over 100 lines opens with a short bullet TOC of its `##` headings,
  directly under the H1.
- Output caps and format order: [`../skills/output-style.md`](../skills/output-style.md).

## Deployment

- Copilot CLI pre-approves a skill's declared shell only for skills you trust.
- Keep `allowed-tools` minimal so an untrusted skill cannot silently run destructive commands.

## After Creating or Renaming a Skill

Add or update the entry in `.claude/skills/README.md` (discovery index).
