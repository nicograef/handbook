# Skills

Agent skills for Claude Code and GitHub Copilot. They live in this handbook repo and reach the agents through **two tiers** from this single source: local symlinks on the dev machine, and the public **`handbook@nicograef` Claude Code plugin** served from this repo (its own marketplace) for every other machine and Claude web session — see [guides/claude-plugin.md](../../guides/claude-plugin.md). Nothing is copied into project repos; adopted repos commit only enablement keys.

Namespacing differs per tier: symlink-tier skills invoke plain (`/commit`), plugin-tier skills namespaced (`/handbook:commit`, agent `handbook:web-researcher`). On the dev machine the plugin is disabled per repo via a gitignored `.claude/settings.local.json` so skills never load twice.

## Skill Consumption Matrix

Which surfaces load these personal skills, and from where:

| Surface | Tier / skills location | Loaded? |
| --- | --- | --- |
| Claude Code (CLI + IDE), dev machine | symlink: `~/.claude/skills` → this directory | Yes — verified 2026-07-10 (live-session skill enumeration from a neutral directory, loading only through the symlink) |
| VS Code Copilot, dev machine | symlink: `~/.claude/skills` → this directory | Yes — documented loading path, not smoke-tested ([guides/copilot-agent-setup.md](../../guides/copilot-agent-setup.md)) |
| Copilot CLI, dev machine | symlink: `~/.agents/skills` → this directory | Yes — documented loading path, not smoke-tested ([guides/copilot-agent-setup.md](../../guides/copilot-agent-setup.md)) |
| Codespaces on this repo (dotfiles install) | symlink tier via `install.sh` | Not verified — smoke test 1 pending ([guides/dotfiles-codespaces.md](../../guides/dotfiles-codespaces.md)) |
| Any other Claude Code machine | plugin: `claude plugin install handbook@nicograef` | Yes — smoke test 2, 2026-07-10 ([guides/claude-plugin.md](../../guides/claude-plugin.md)); in-session invocation proven with the symlink tier hidden |
| Claude web session on an adopted repo | plugin: committed `.claude/settings.json` enablement | Not verified — smoke test 3 pending ([guides/claude-plugin.md](../../guides/claude-plugin.md)); adoption committed in jotti, lexiban, website (2026-07-10) |
| Copilot cloud agent / server-side review | server-side, no `$HOME` access | Not verified — Copilot's cloud surfaces would require vendoring skills into each project repo (`.github/skills/`), which this handbook deliberately avoids |

`scripts/install-dotfiles.sh` creates the two symlink-tier links to this directory: `~/.claude/skills` (read by Claude Code and VS Code Copilot) and `~/.agents/skills` (read by the Copilot CLI — GitHub's CLI docs list `~/.copilot/skills` and `~/.agents/skills`, not `~/.claude/skills`, so the second symlink is what covers the CLI). Both tiers deploy the whole `.claude/skills/` directory, so the shared `quality.md` and each skill's reference files travel with them (plugin tier verified 2026-07-10: reference files present in the plugin cache copy).

## When to Use Which Skill

| Problem                                                       | Skill                           | Directory                                                    |
| ------------------------------------------------------------- | ------------------------------- | ------------------------------------------------------------ |
| Unclear requirements, need to ask questions                   | **Clarify**                     | [clarify/](clarify/)                                         |
| Planning a feature from PRD or task description               | **Create Plan**                 | [create-plan/](create-plan/)                                 |
| Writing a product requirements document                       | **Write a PRD**                 | [write-prd/](write-prd/)                                     |
| Developer-driven implementation with coaching                 | **Guided Implementation**       | [guided-implementation/](guided-implementation/)             |
| Executing an existing plan step by step                       | **Implement Plan**              | [implement-plan/](implement-plan/)                           |
| Building features test-first (red-green-refactor)             | **TDD**                         | [tdd/](tdd/)                                                 |
| Reviewing, reducing and refactoring an existing test suite    | **Test Quality**                | [test-quality/](test-quality/)                               |
| Mobile UX, UI consistency, workflow friction                  | **UX Review**                   | [ux-review/](ux-review/)                                     |
| Extracting DDD glossary terms                                 | **Ubiquitous Language**         | [ubiquitous-language/](ubiquitous-language/)                 |
| Incremental code review, readability, slop removal, or a repo-wide cross-layer audit | **Cleanup** | [cleanup/](cleanup/)                             |
| Understanding a part of the codebase holistically             | **Understand**                  | [understand/](understand/)                                   |
| Researching companies, jobs, or tools from live sources       | **Research**                    | [research/](research/)                                       |
| Debugging a failure root-cause-first                          | **Systematic Debugging**        | [systematic-debugging/](systematic-debugging/)               |
| Acting on code-review feedback                                | **Receiving Feedback**          | [receiving-feedback/](receiving-feedback/)                   |
| Isolating work in a git worktree                              | **Using Git Worktrees**         | [using-git-worktrees/](using-git-worktrees/)                 |
| Integrating a finished branch (merge/PR/keep/discard)         | **Finish Branch**               | [finish-branch/](finish-branch/)                             |
| Proposing a Conventional Commit message for staged changes    | **Commit**                      | [commit/](commit/)                                          |
| End-of-session retrospective; harvest learnings into memory, rules, skills, docs, tooling | **Reflect** | [reflect/](reflect/)                             |
| Running independent subagents in parallel                     | **Dispatching Parallel Agents** | [dispatching-parallel-agents/](dispatching-parallel-agents/) |

## Typical Workflow

1. **Clarify** → gather requirements
2. **Write a PRD** → formalise into a document
3. **Create Plan** → break PRD into vertical slices
4. **Implement Plan** → agent executes slices (with **TDD**)
   — OR **Guided Implementation** → developer writes all code, agent coaches
5. **Cleanup** → review the result (repo-wide scope mode for a cross-layer audit)
   — hit a bug along the way? **Systematic Debugging** → root-cause it before fixing
   — got review comments? **Receiving Feedback** → act on them deliberately

## Adding a New Skill

See [.claude/rules/skills.md](../rules/skills.md) for format requirements.

- Skills that produce code or documents carry a Quality section linking the shared [quality.md](quality.md) self-review checklist rather than restating it. Process-only and review-only skills omit it — their Constraints already carry the contract.
