# Skills

Agent skills for Claude Code and GitHub Copilot. They live in this handbook repo and both agents consume them from the `~/.claude/skills` symlink — they are not copied into project repos.

## When to Use Which Skill

| Problem                                                       | Skill                     | Directory                                        |
| ------------------------------------------------------------- | ------------------------- | ------------------------------------------------ |
| Unclear requirements, need to ask questions                   | **Clarify**               | [clarify/](clarify/)                             |
| Planning a feature from PRD or task description               | **Create Plan**           | [create-plan/](create-plan/)                     |
| Writing a product requirements document                       | **Write a PRD**           | [write-prd/](write-prd/)                         |
| Developer-driven implementation with coaching                 | **Guided Implementation** | [guided-implementation/](guided-implementation/) |
| Executing an existing plan step by step                       | **Implement Plan**        | [implement-plan/](implement-plan/)               |
| Building features test-first (red-green-refactor)             | **TDD**                   | [tdd/](tdd/)                                     |
| Reviewing, reducing and refactoring an existing test suite    | **Test Quality**          | [test-quality/](test-quality/)                   |
| Repo-wide cross-layer consistency audit                       | **Code Audit**            | [code-audit/](code-audit/)                       |
| Mobile UX, UI consistency, workflow friction                  | **UX Review**             | [ux-review/](ux-review/)                         |
| Extracting DDD glossary terms                                 | **Ubiquitous Language**   | [ubiquitous-language/](ubiquitous-language/)     |
| Incremental code quality review, readability, or slop removal | **Cleanup**               | [cleanup/](cleanup/)                             |
| Understanding a part of the codebase holistically             | **Understand**            | [understand/](understand/)                       |

## Typical Workflow

1. **Clarify** → gather requirements
2. **Write a PRD** → formalise into a document
3. **Create Plan** → break PRD into vertical slices
4. **Implement Plan** → agent executes slices (with **TDD**)
   — OR **Guided Implementation** → developer writes all code, agent coaches
5. **Code Audit** → review the result

## Adding a New Skill

See [.github/instructions/skills.instructions.md](../.github/instructions/skills.instructions.md) for format requirements.
