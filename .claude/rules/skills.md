---
description: "Conventions for skills in .claude/skills/."
paths: ".claude/skills/**"
---

# Skill conventions

- One directory per skill; `SKILL.md` is required. At most one level of reference files, each named for its content (`git.md`, `state.md`) and introduced with when to open it.
- Frontmatter: `name` matches the directory; `description` is third person, states what and when, key trigger first. It loads in every session, so ≤ 250 characters. Optional: `argument-hint`, `allowed-tools`, and `disable-model-invocation: true` for skills with side effects the model should not trigger on its own.
- `allowed-tools` pre-approves the listed tools only for the turn that invokes the skill; deny rules still win. Scope `Bash` to the commands the skill runs.
- Body ≤ 120 lines. Gotchas and hard constraints come first. Write only what the model would get wrong without the file; it knows general practice.
- State intent, hazards and local conventions. Leave harness paths and tool flags to the model and the harness; they drift with every release.
- Prefer positive instructions; reserve "never" for hazards.
- After adding or renaming a skill, update `.claude/skills/README.md`; `make skills` checks the index both ways.
