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
  - Testability and test cost: suite time per module, duplicate and fan-out tests, own-module mocks, tests above the cheapest failing level
  - Readability and Understandability
  - SOLID Principles
  - Outdated, unused or deprecated fields, interfaces, functions, ...
  - Unification, best practices and consistency
- Reviewers apply these decision tests:
  - Deletion test: delete the module. Complexity that reappears in its callers means it earns its place.
  - One adapter is a hypothetical seam; two make it real.
  - The interface is the test surface.
- Thresholds come from the project's own gates: its linter config (ruff `max-complexity`, `max-statements`) and its structure tests.
  Structure tests hold the module line cap, the name length and thin `__init__` files.
  Where a project sets none: complexity ≤ 15, ≤ 50 statements per function, module ≤ 600 lines.
  Names have ≥ 3 characters; internals sit behind a package's `__init__`. Reviewers report each violation as a finding.
- Run as many Opus reviewers on as many areas of the codebase you think is suitable.
- Run Sonnet verifiers and refuters on the findings.
- Run Opus fixers and implementers.
- Keep the workflows lean and efficient.
  - Bundle reviews, tests and gates on the main branch or a common base branch.
  - You may even use just one branch or one worktree for all of this.
  - Chose the codebase split accordingly.

If you find any bugs or issues along the way, fix them directly as part of the workflow.
