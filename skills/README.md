# Skills

Agent skills for GitHub Copilot — copy individual skill directories into project repos as needed.

## When to Use Which Skill

| Problem | Skill | Directory |
|---------|-------|-----------|
| Unclear requirements, need to ask questions | **Clarify** | [clarify/](clarify/) |
| Planning a feature from PRD or task description | **Create Plan** | [create-plan/](create-plan/) |
| Writing a product requirements document | **Write a PRD** | [write-prd/](write-prd/) |
| Developer-driven implementation with coaching | **Guided Implementation** | [guided-implementation/](guided-implementation/) |
| Executing an existing plan step by step | **Implement Plan** | [implement-plan/](implement-plan/) |
| Building features test-first (red-green-refactor) | **TDD** | [tdd/](tdd/) |
| Reviewing, reducing and refactoring an existing test suite | **Test Quality** | [test-quality/](test-quality/) |
| Code review, cross-layer consistency audit | **Code Audit** | [code-audit/](code-audit/) |
| Mobile UX, UI consistency, workflow friction | **UX Review** | [ux-review/](ux-review/) |
| Exploring multiple API / interface designs | **Design Interface** | [design-interface/](design-interface/) |
| Finding refactoring / deepening opportunities | **Improve Architecture** | [improve-architecture/](improve-architecture/) |
| Syncing a project with handbook best practices | **Handbook Sync** | [handbook-sync/](handbook-sync/) |
| Extracting DDD glossary terms | **Ubiquitous Language** | [ubiquitous-language/](ubiquitous-language/) |
| Cleaning up AI-generated code, docs, config | **Deslop** | [deslop/](deslop/) |
| Extracting content from PDF, Word, or Excel files | **Extract** | [extract/](extract/) |
| Understanding a part of the codebase holistically | **Understand** | [understand/](understand/) |

## Typical Workflow

1. **Clarify** → gather requirements
2. **Write a PRD** → formalise into a document
3. **Create Plan** → break PRD into vertical slices
4. **Implement Plan** → agent executes slices (with **TDD**)
   — OR **Guided Implementation** → developer writes all code, agent coaches
5. **Code Audit** → review the result
6. **Improve Architecture** → identify deepening opportunities

## Adding a New Skill

See [.github/instructions/skills.instructions.md](../.github/instructions/skills.instructions.md) for format requirements.
