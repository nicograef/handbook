# GitHub Copilot Agent Mode — Project Setup

Configure a repository so GitHub Copilot understands the project, follows conventions, and produces consistent code. Covered surfaces: Agent Mode, Chat, Inline. Based in part on [How to write a great agents.md](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/).

## Overview

| Layer                       | File                                      | Loaded when                                          | Token cost      |
| ---------------------------- | ------------------------------------------ | ----------------------------------------------------- | ---------------- |
| **Root instructions**       | `AGENTS.md`                               | Every Copilot surface — always                       | High (full)     |
| **Contextual instructions** | `.github/instructions/*.instructions.md`  | Automatically, when editing files matching `applyTo` | Per-area        |
| **Skills**                  | `.github/skills/<name>/SKILL.md`          | Loaded on demand when a task matches the skill        | Zero until used |
| **Custom agents**           | `.github/agents/*.agent.md`               | When invoked by name (agent picker / `@name`)         | Zero until used |
| **Reusable prompts**        | `.github/prompts/*.prompt.md`             | On demand (`/prompt-name` in chat)                    | Zero until used |

- **Every Copilot surface reads `AGENTS.md`** — Chat, Inline, Agent Mode, code review, cloud agent, and Copilot CLI. One agent file at the repo root is the norm.
- Nested `AGENTS.md` files apply to their subtree, and the nearest file wins.
- **A root `CLAUDE.md`** is only a fallback when no `AGENTS.md` is present.

### When to add each layer

| Project shape                                          | Recommended layers                    |
| -------------------------------------------------------- | -------------------------------------- |
| Small / single-area                                     | `AGENTS.md` only                      |
| Multi-area (backend + frontend, library + docs site)    | + contextual instructions             |
| Reusable expertise across tools (a repeatable workflow) | + skills                              |
| Specialised roles (docs writer, test engineer)          | + custom agents                       |
| Recurring multi-step tasks (scaffolding, migrations)    | + reusable prompts                    |

### Cross-tool compatibility

- **Cursor** — if the repo also uses `.cursor/rules/` and `.cursor/commands/`, keep the conventions aligned; Cursor rules should point to `AGENTS.md`, not duplicate it.
- **Path-scoped conventions: pick one surface.** Copilot's `.github/instructions/*.instructions.md` and Claude Code's `.claude/rules/*.md` are two mechanisms for one idea — both are per-directory rules loaded on a glob.
- **Maintaining both** with the same content is a duplication anti-pattern: the two copies drift.
- **Keep exactly one** path-scoped surface, and let the other tool read `AGENTS.md`. This repo canonicalises on `.claude/rules/` and routes Copilot through `AGENTS.md`.

## .github/instructions/*.instructions.md

- **`applyTo` is required** — every instructions file needs an `applyTo` glob (e.g. `backend/**`, `frontend/**`, `scripts/**`) that scopes where it loads. Use `applyTo: "**"` for repo-wide instructions.
- Use `excludeAgent: "code-review"` or `excludeAgent: "cloud-agent"` to hide a file from a specific Copilot agent; without it, every agent loads the file.

## .github/skills/<name>/SKILL.md — Locations Copilot reads

| Location            | Scope                                                          |
| -------------------- | ---------------------------------------------------------------- |
| `.github/skills/`   | Repo skills (Copilot code review, cloud agent, VS Code, CLI)   |
| `.claude/skills/`   | Personal + project skills (also read by VS Code Copilot)       |
| `.agents/skills/`   | Personal skills for Copilot CLI (`~/.agents/skills`)            |

Personal skill paths (in `$HOME`, not committed) differ per surface:

- **VS Code** reads `~/.copilot/skills`, `~/.claude/skills`, and `~/.agents/skills`.
- **Copilot CLI** reads only `~/.copilot/skills` and `~/.agents/skills` — the `~/.claude/skills` symlink doesn't reach it.
- **Add a second `~/.agents/skills` symlink** to cover the CLI too.

## .github/agents/*.agent.md

- **Reach** — the same `.agent.md` file works for the Copilot cloud agent and Copilot CLI.

> **`.chatmode.md` is not the format.** Copilot still loads `.chatmode.md` files from
> `.github/chatmodes/`, but agents belong in `.github/agents/` as `<name>.agent.md`.
> Move any `.chatmode.md` file you find.

- Name the file `<name>.agent.md`; the `<name>` part becomes the agent's identifier and may only contain `.`, `-`, `_`, and alphanumerics.
- `description` is **required**; `name` and the rest are optional. The Markdown body (the prompt) is limited to **30,000 characters**.
- **`.github/prompts/*.prompt.md`** — an **IDE-only preview** feature (VS Code / JetBrains); not loaded by the cloud agent or Copilot CLI.
  - **`agent:` frontmatter** (optional) selects which agent runs the prompt — `ask`, `agent`, `plan`, or a custom agent name.

See also:
- [templates/AGENTS.md](../templates/AGENTS.md) — agent instructions template
- [templates/copilot-instructions.md](../templates/copilot-instructions.md) — copilot instructions template
