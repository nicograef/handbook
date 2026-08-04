# Skills

- Agent skills for Claude Code and GitHub Copilot, reaching agents through two tiers from
  this single source.
- Tier 1 — local symlinks on the dev machine.
- Tier 2 — the public **`handbook@nicograef` Claude Code plugin**, served from this repo
  (its own marketplace).
- Reaches every other machine and Claude web sessions. See
  [guides/claude-plugin.md](../../guides/claude-plugin.md).
- Nothing is copied into project repos; adopted repos commit only enablement keys.
- Namespacing differs per tier: symlink-tier skills invoke plain (`/distill`); plugin-tier
  skills are namespaced (`/handbook:distill`, agent `handbook:web-researcher`).
- On the dev machine, the plugin is disabled per repo via a gitignored
  `.claude/settings.local.json`, so skills never load twice.

## Skill Consumption Matrix

| Surface | Tier / skills location | Loaded? |
| --- | --- | --- |
| Claude Code (CLI + IDE), dev machine | symlink: `~/.claude/skills` → this directory | Yes — verified |
| VS Code Copilot, dev machine | symlink: `~/.claude/skills` → this directory | Yes — documented loading path, not smoke-tested ([guides/copilot-agent-setup.md](../../guides/copilot-agent-setup.md)) |
| Copilot CLI, dev machine | symlink: `~/.agents/skills` → this directory | Yes — documented loading path, not smoke-tested ([guides/copilot-agent-setup.md](../../guides/copilot-agent-setup.md)) |
| Codespaces on this repo (dotfiles install) | symlink tier via `install.sh` | Not verified ([guides/dotfiles-codespaces.md](../../guides/dotfiles-codespaces.md)) |
| Any other Claude Code machine | plugin: `claude plugin install handbook@nicograef` | Yes — verified |
| Claude web session on an adopted repo | plugin: committed `.claude/settings.json` enablement | Not verified |
| Copilot cloud agent / server-side review | server-side, no `$HOME` access | Not verified — would require vendoring skills into each project repo (`.github/skills/`), which this handbook deliberately avoids |

`scripts/install-dotfiles.sh` creates both symlink-tier links; the Copilot CLI needs its own because GitHub's CLI docs list `~/.copilot/skills` and `~/.agents/skills`, not `~/.claude/skills`.

## When to Use Which Skill

| Problem                                                                                  | Skill                                                        |
| ---------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| Unclear requirements, need to ask questions                                              | [Clarify](clarify/)                                          |
| Planning a feature from PRD or task description                                          | [Create Plan](create-plan/)                                  |
| Writing a product requirements document                                                  | [Write a PRD](write-prd/)                                    |
| Developer-driven implementation with coaching                                            | [Guided Implementation](guided-implementation/)              |
| Executing an entire existing plan autonomously, or resuming a stopped plan run           | [Implement Plan](implement-plan/)                            |
| Building features test-first (red-green-refactor)                                        | [TDD](tdd/)                                                  |
| Reviewing, reducing and refactoring an existing test suite                               | [Test Quality](test-quality/)                                |
| Mobile UX, UI consistency, workflow friction                                             | [UX Review](ux-review/)                                      |
| Extracting DDD glossary terms                                                            | [Ubiquitous Language](ubiquitous-language/)                   |
| Incremental code review, readability, slop removal, or a repo-wide cross-layer audit     | [Cleanup](cleanup/)                                          |
| Radically minimizing and restructuring a repo's docs, prose, and comments                | [Distill](distill/)                                          |
| Fact-checking committed docs against code, commands, and upstream sources                | [Verify Docs](verify-docs/)                                  |
| Understanding a part of the codebase holistically                                        | [Understand](understand/)                                    |
| Learning a subject through quizzes with scaffolded hints                                 | [Tutor](tutor/)                                              |
| Learning a system by listening: audiobook chapters for ElevenReader                      | [Audiobook](audiobook/)                                      |
| Researching companies, jobs, or tools from live sources                                  | [Research](research/)                                        |
| Debugging a failure root-cause-first                                                     | [Systematic Debugging](systematic-debugging/)                |
| Acting on code-review feedback                                                           | [Receiving Feedback](receiving-feedback/)                    |
| Isolating work in a git worktree                                                         | [Using Git Worktrees](using-git-worktrees/)                  |
| Integrating a finished branch (merge/PR/keep/discard)                                    | [Finish Branch](finish-branch/)                              |
| End-of-session retrospective; harvest learnings into memory, rules, skills, docs, tooling | [Reflect](reflect/)                                          |
| Deleting stale agent state: old sessions, stale memories, outdated rules, repo leftovers | [Prune](prune/)                                              |
| Running independent subagents in parallel                                                | [Dispatching Parallel Agents](dispatching-parallel-agents/)  |

## Adding a New Skill

See [.claude/rules/skills.md](../rules/skills.md) for format requirements.
