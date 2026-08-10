# GitHub Copilot Agent Mode — Project Setup

Configure a repository so GitHub Copilot understands the project, follows conventions, and
produces consistent code. Covered surfaces: Agent Mode, Chat, Inline.
Based in part on [How to write a great agents.md](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/) — an analysis of 2,500+ repositories.

## Overview

Six layers of context, loaded at different times:

| Layer                       | File                                     | Loaded when                                          | Token cost      |
| --------------------------- | ---------------------------------------- | ---------------------------------------------------- | --------------- |
| **Root instructions**       | `AGENTS.md`                              | Every Copilot surface — always                       | High (full)     |
| **Copilot instructions**    | `.github/copilot-instructions.md`        | Copilot Chat / Inline / Agent — always               | Low (compact)   |
| **Contextual instructions** | `.github/instructions/*.instructions.md` | Automatically, when editing files matching `applyTo` | Per-area        |
| **Skills**                  | `.github/skills/<name>/SKILL.md`         | Loaded on demand when a task matches the skill       | Zero until used |
| **Custom agents**           | `.github/agents/*.agent.md`              | When invoked by name (agent picker / `@name`)        | Zero until used |
| **Reusable prompts**        | `.github/prompts/*.prompt.md`            | On demand (`/prompt-name` in chat)                   | Zero until used |

- **Every Copilot surface reads `AGENTS.md`** — Chat, Inline, Agent Mode, code review, cloud
  agent, and Copilot CLI.
- **One agent file at the repo root** is the norm.
- **Nested `AGENTS.md`** files apply to their subtree.
- **The nearest file wins.**
- **A root `CLAUDE.md`** is only a fallback when no `AGENTS.md` is present.
- **Never maintain both** with different content.
- **Design principle** — layer context always → contextual → on-demand.
- **Payoff** — the agent gets the right information at the right time, without wasting token
  budget.

### When to add each layer

Not every project needs all six layers. Add them incrementally:

| Project shape                                         | Recommended layers                                            |
| ----------------------------------------------------- | ------------------------------------------------------------- |
| Small / single-area                                   | `AGENTS.md` only                                              |
| Multi-area (backend + frontend, library + docs site)  | + `.github/copilot-instructions.md` + contextual instructions |
| Reusable expertise across tools (a repeatable workflow)| + skills                                                      |
| Specialised roles (docs writer, test engineer)        | + custom agents                                               |
| Recurring multi-step tasks (scaffolding, migrations)  | + reusable prompts                                            |

### Cross-tool compatibility

- **Cursor** — if the repo also uses `.cursor/rules/` and `.cursor/commands/`, keep the
  conventions aligned.
- **Single source of truth** — `AGENTS.md`.
- **Cursor rules** should point to it, not duplicate it.
- **Path-scoped conventions: pick one surface.**
- **Two mechanisms, one idea** — Copilot's `.github/instructions/*.instructions.md` and Claude
  Code's `.claude/rules/*.md`.
- **Both are** per-directory rules loaded on a glob.
- **Maintaining both** with the same content is a duplication anti-pattern.
- **The two copies drift** — one says "expected", the other "mandatory".
- **They also diverge** — one grows a section the other lacks.
- **Keep exactly one** path-scoped surface, and let the other tool read `AGENTS.md`.
- **This repo** canonicalises on `.claude/rules/` and routes Copilot through `AGENTS.md`.

---

## .github/instructions/*.instructions.md

Contextual instructions loaded automatically when the agent edits files matching the `applyTo` glob pattern. Each file covers one area of the codebase.

- **Use this surface only if** Copilot is the repo's single path-scoped mechanism.
- **If the repo already carries `.claude/rules/*.md`**, do **not** add a parallel
  `.github/instructions/` copy.
- **Why** — that dual surface drifts (see [Cross-tool compatibility](#cross-tool-compatibility)).
- **`applyTo` is required** — every instructions file needs an `applyTo` glob (e.g. `backend/**`, `frontend/**`, `scripts/**`) that scopes where it loads. Use `applyTo: "**"` for repo-wide instructions.
- Use `excludeAgent: "code-review"` or `excludeAgent: "cloud-agent"` to hide a file from a specific Copilot agent; without it, every agent loads the file.

---

## .github/skills/<name>/SKILL.md

- **Shape** — reusable, self-contained workflows.
- **Location** — each is a `SKILL.md` file in a per-skill directory.
- **Bundled files** — optional `REFERENCE.md` and `<topic>.md`, loaded only when the skill runs.
- **Standard** — the cross-tool [Agent Skills](https://agentskills.io) open standard.
- **Portability** — the same skill works in Claude Code, Cursor, Codex CLI, and GitHub Copilot.

### Locations Copilot reads

| Location            | Scope                                  |
| ------------------- | -------------------------------------- |
| `.github/skills/`   | Repo skills (Copilot code review, cloud agent, VS Code, CLI) |
| `.claude/skills/`   | Personal + project skills (also read by VS Code Copilot) |
| `.agents/skills/`   | Personal skills for Copilot CLI (`~/.agents/skills`)   |

Agent Skills are generally available across these surfaces:

- Copilot cloud agent, Copilot code review, and Copilot CLI.
- Agent mode in VS Code and JetBrains.

Personal skill paths (in `$HOME`, not committed) differ per surface:

- **VS Code** reads `~/.copilot/skills`, `~/.claude/skills`, and `~/.agents/skills`.
- **Copilot CLI** reads only `~/.copilot/skills` and `~/.agents/skills` — not `~/.claude/skills`.
- **A `~/.claude/skills` symlink** covers Claude Code and VS Code, but not Copilot CLI.
- **Add a second `~/.agents/skills` symlink** to cover the CLI too.

### When to use a skill vs a custom agent

- **Skill** — for a portable, tool-agnostic *workflow* that should behave the same everywhere. Prefer this by default.
- **Custom agent** — for a Copilot-specific *persona/role* that a user invokes explicitly.

---

## .github/agents/*.agent.md

- **What** — custom Copilot agent personas, selected from the agent picker or by name.
- **Content** — each file defines a specialist with a specific role, constraints, and tools.
- **Unlike `AGENTS.md`**, which instructs the general agent, these create **focused specialists**.
- **Each specialist** excels at one job.
- **Reach** — the same `.agent.md` file works for the Copilot cloud agent and Copilot CLI.

> **`.chatmode.md` is not the format.** Copilot still loads `.chatmode.md` files from
> `.github/chatmodes/`, but agents belong in `.github/agents/` as `<name>.agent.md`.
> Move any `.chatmode.md` file you find.

- Name the file `<name>.agent.md`; the `<name>` part becomes the agent's identifier and may only contain `.`, `-`, `_`, and alphanumerics.
- `description` is **required**; `name` and the rest are optional.
- The Markdown body (the prompt) is limited to **30,000 characters**.

---

## .github/prompts/*.prompt.md

- **What** — reusable prompts invoked via `/prompt-name` in Copilot Chat.
- **Use for** recurring multi-step tasks.
- **Availability** — an **IDE-only preview** feature (VS Code / JetBrains).
- **Not loaded** by the cloud agent or Copilot CLI.
- **`agent:` frontmatter** (optional, formerly `mode:`) selects which agent runs the prompt.
- **Values** — `ask`, `agent`, `plan`, or a custom agent name.

---

See also:
- [templates/AGENTS.md](../templates/AGENTS.md) — agent instructions template
- [templates/copilot-instructions.md](../templates/copilot-instructions.md) — copilot instructions template
