---
description: "Conventions for skills in plugin/skills/."
paths: "plugin/skills/**"
---

# Skill conventions

- One directory per skill; `SKILL.md` is required. At most one level of reference files, each named for its content (`git.md`, `pipeline.md`) and introduced with when to open it.
- Frontmatter: `name` matches the directory; `description` is third person, states what and when, key trigger first. It loads in every session, so ≤ 250 characters. Optional: `argument-hint`, `allowed-tools` and `hooks`. Every skill stays model-invocable, so agents can run it; only `audiobook` sets `disable-model-invocation: true`.
- `allowed-tools` pre-approves the listed tools only for the turn that invokes the skill; deny rules still win. Scope `Bash` to the commands the skill runs.
- `hooks` register when the skill is invoked and stay for the rest of the session. A plugin skill names its scripts under `${CLAUDE_PLUGIN_ROOT}`.
- Body ≤ 120 lines. Gotchas and hard constraints come first. Write only what the model would get wrong without the file; it knows general practice.
- State intent, hazards and local conventions.
- Prefer positive instructions; reserve "never" for hazards.
