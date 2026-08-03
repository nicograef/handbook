---
name: tdd
description: >-
  Drives development with a red-green-refactor loop, one test at a time. Use
  when the user wants to build a feature or fix a bug using TDD, mentions
  "red-green-refactor", or asks for test-first development.
---

# Test-Driven Development

See [anti-patterns.md](../test-quality/anti-patterns.md) for worked examples of
implementation-coupled tests and [mocking.md](mocking.md) for mocking guidelines.

## Anti-Pattern: Horizontal Slices

Avoid writing all tests first, then all implementation. That is "horizontal
slicing" — treating RED as "write all tests" and GREEN as "write all code." It
produces crap tests.

**Correct approach**: Vertical slices via tracer bullets. One test → one
implementation → repeat. Each test responds to what you learned from the
previous cycle.

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
  ...
```

## Workflow

### 1. Planning

Before writing any code:

- [ ] Confirm with user what interface changes are needed
- [ ] Confirm with user which behaviors to test (prioritize)
- [ ] Identify opportunities for deep modules (small interface, deep implementation)
- [ ] Design for testability: inject dependencies instead of constructing them, return values instead of mutating inputs
- [ ] Keep the interface surface small
- [ ] List the behaviors to test (not implementation steps)
- [ ] Get user approval on the plan

**You can't test everything.** Ask what the interface should look like, and
which behaviors matter most. Focus effort on critical paths and complex
logic, not every edge case.

### 2. Tracer Bullet

Write ONE test that confirms ONE thing about the system:

```
RED:    Write test for first behavior → test fails
VERIFY: Confirm it fails for the EXPECTED reason (missing feature, not a
        typo or syntax error)
GREEN:  Write minimal code to pass → test passes
VERIFY: Confirm it passes AND all other tests still pass, with clean output
```

This is your tracer bullet — proves the path works end-to-end. Repeat the same
loop for each remaining behavior.

### 3. Refactor

After all tests pass, look for refactor candidates:

| Smell | Fix |
| --- | --- |
| Duplication | Extract a function or class |
| Long methods | Break into private helpers (keep tests on the public interface) |
| Shallow modules | Combine or deepen them |
| Feature envy | Move logic to where the data lives |
| Primitive obsession | Introduce value objects |

- Also refactor existing code the new work reveals as problematic.
- Apply SOLID principles where natural.

Run tests after each refactor step. Never refactor while RED — get to GREEN
first.

## Constraints

- **Never write all tests first.** Vertical slices only — one test, one
  implementation, then repeat.
- **Never refactor while RED.** Get to GREEN first.
- One test at a time; write only enough code to pass the current test.
- Don't anticipate future tests or add speculative features.
- Test observable behavior through public interfaces — never private methods or
  internal collaborators.
- Get user approval on the behavior list before writing code.

## Quality

- Once the feature or fix is done, run the shared
  [self-review checklist](../quality.md) on it. Surface issues in the chat only
  if found.
