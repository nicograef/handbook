---
name: tdd
description: >-
  Drives development with a red-green-refactor loop, one test at a time. Use
  when the user wants to build a feature or fix a bug using TDD, mentions
  "red-green-refactor", or asks for test-first development.
---

# Test-Driven Development

## Philosophy

**Core principle**: Tests should verify behavior through public interfaces, not
implementation details. Code can change entirely; tests shouldn't.

**Good tests** are integration-style: they exercise real code paths through
public APIs. They describe _what_ the system does, not _how_ it does it. A good
test reads like a specification — "user can checkout with valid cart" tells you
exactly what capability exists. These tests survive refactors because they don't
care about internal structure.

**Bad tests** are coupled to implementation. They mock internal collaborators,
test private methods, or verify through external means (like querying a database
directly instead of using the interface). The warning sign: your test breaks
when you refactor, but behavior hasn't changed. If you rename an internal
function and tests fail, those tests were testing implementation, not behavior.

See [tests.md](tests.md) for examples and [mocking.md](mocking.md) for mocking
guidelines.

## Anti-Pattern: Horizontal Slices

Avoid writing all tests first, then all implementation. That is "horizontal
slicing" — treating RED as "write all tests" and GREEN as "write all code."

This produces **crap tests**:

- Tests written in bulk test _imagined_ behavior, not _actual_ behavior
- You end up testing the _shape_ of things (data structures, function
  signatures) rather than user-facing behavior
- Tests become insensitive to real changes — they pass when behavior breaks,
  fail when behavior is fine
- You outrun your headlights, committing to test structure before understanding
  the implementation

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
- [ ] Design interfaces for [testability](interface-design.md)
- [ ] List the behaviors to test (not implementation steps)
- [ ] Get user approval on the plan

Ask: "What should the public interface look like? Which behaviors are most
important to test?"

**You can't test everything.** Confirm with the user exactly which behaviors
matter most. Focus testing effort on critical paths and complex logic, not every
possible edge case.

**Deep modules** (from *A Philosophy of Software Design*): prefer a small
interface hiding substantial implementation over a shallow module whose
interface is nearly as complex as what it wraps.

```
┌─────────────────────┐
│   Small Interface   │  ← few methods, simple params
├─────────────────────┤
│  Deep Implementation│  ← complex logic hidden inside
└─────────────────────┘
```

When designing an interface, ask: can I reduce the number of methods, simplify
the parameters, or hide more complexity inside?

### 2. Tracer Bullet

Write ONE test that confirms ONE thing about the system:

```
RED:    Write test for first behavior → test fails
VERIFY: Confirm it fails for the EXPECTED reason (missing feature, not a
        typo or syntax error)
GREEN:  Write minimal code to pass → test passes
VERIFY: Confirm it passes AND all other tests still pass, with clean output
```

This is your tracer bullet — proves the path works end-to-end.

### 3. Incremental Loop

For each remaining behavior:

```
RED:    Write next test → fails
VERIFY: Confirm it fails for the EXPECTED reason (missing feature, not a
        typo or syntax error)
GREEN:  Minimal code to pass → passes
VERIFY: Confirm it passes AND all other tests still pass, with clean output
```

### 4. Refactor

After all tests pass, look for refactor candidates:

- **Duplication** → extract a function or class
- **Long methods** → break into private helpers (keep tests on the public interface)
- **Shallow modules** → combine or deepen them
- **Feature envy** → move logic to where the data lives
- **Primitive obsession** → introduce value objects
- **Existing code** the new code reveals as problematic
- Apply SOLID principles where natural

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
