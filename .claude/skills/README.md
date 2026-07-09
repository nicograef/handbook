# Skills

Agent skills for Claude Code and GitHub Copilot. They live in this handbook repo and are exposed to the agents through symlinks — they are not copied into project repos.

## Skill Consumption Matrix

Which surfaces load these personal skills, and from where:

| Surface | Skills location | Loaded? |
| --- | --- | --- |
| Claude Code (CLI + IDE) | `~/.claude/skills` → this directory | Yes |
| VS Code Copilot | `~/.claude/skills` → this directory | Yes |
| Copilot CLI | `~/.agents/skills` → this directory | Yes |
| Copilot cloud agent / server-side review | n/a | Presumably no — not verified |

Both `~/.claude/skills` and `~/.agents/skills` are symlinks to this directory, created by `scripts/install-dotfiles.sh`. Skills deploy as the whole `.claude/skills/` directory, so the shared `quality.md` and each skill's reference files travel with them.

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
| Debugging a failure root-cause-first                          | **Systematic Debugging**        | [systematic-debugging/](systematic-debugging/)               |
| Acting on code-review feedback                                | **Receiving Feedback**          | [receiving-feedback/](receiving-feedback/)                   |
| Isolating work in a git worktree                              | **Using Git Worktrees**         | [using-git-worktrees/](using-git-worktrees/)                 |
| Integrating a finished branch (merge/PR/keep/discard)         | **Finish Branch**               | [finish-branch/](finish-branch/)                             |
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
