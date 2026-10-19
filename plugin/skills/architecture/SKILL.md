---
name: architecture
description: "Improve code architecture"
---

# Architecture

- Enable ultracode and use workflows.
- Sweep the codebase and separate it into areas/modules to work at in parallel.
- Run a multi-expert review on code architecture considering clean code, modularity, readability
  - Clean Architecture: layer boundaries, domain code free of framework and infrastructure types
  - Cross-layer consistency: shapes, nullability, validation and enums agree from frontend to database
  - Clean Code
  - Modularity, Cohesion and Coupling
  - KISS, YAGNI, Overengineering and Simplifications
  - Testability, Test isolation, efficiency of tests and simplicity of tests
  - Readability and Understandability
  - SOLID Principles
  - Outdated, unused or deprecated fields, interfaces, functions, ...
- Run as many Opus reviewers on as many areas of the codebase you think is suitable.
- Run Sonnet verifiers and refuters on the findings.
- Run Sonnet fixers and implementers.
- Keep the workflows lean and efficient.
  - Bundle reviews, tests and gates on the main branch or a common base branch.
  - You may even use just one branch or one worktree for all of this.
  - Chose the codebase split accordingly.

If you find any bugs or issues along the way, fix them directly as part of the workflow.
