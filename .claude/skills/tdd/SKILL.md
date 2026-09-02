---
name: tdd
description: >-
  Drives development with a red-green-refactor loop, one test at a time. Use
  when the user wants to build a feature or fix a bug using TDD, mentions
  "red-green-refactor", or asks for test-first development.
---

# Test-Driven Development

See [anti-patterns.md](../test-quality/anti-patterns.md) for worked examples of implementation-coupled tests and [mocking.md](mocking.md) for mocking guidelines.

## Workflow

### 1. Planning

Confirm the interface and the behaviors to test with the user. Apply the deep-module checklist ([write-prd/SKILL.md](../write-prd/SKILL.md) step 5). List behaviors, not implementation steps, and get approval before coding.

**You can't test everything.** Ask what the interface should look like, and which behaviors matter most. Focus on critical paths and complex logic, not every edge case.

### 2. Tracer Bullet

Write ONE test that confirms ONE thing about the system:

```
RED:    Write test for first behavior → test fails
VERIFY: Confirm it fails for the EXPECTED reason (missing feature, not a
        typo or syntax error)
GREEN:  Write minimal code to pass → test passes
VERIFY: Confirm it passes AND all other tests still pass, with clean output
```

### 3. Refactor

After all tests pass, look for refactor candidates and run tests after each refactor step. Never refactor while RED — get to GREEN first.

## Constraints

- One test at a time; write only enough code to pass the current test.
- Don't anticipate future tests or add speculative features.
- Test observable behavior through public interfaces — never private methods or internal collaborators.
- Get user approval on the behavior list before writing code.

## Quality

- Once the feature or fix is done, run the shared [self-review checklist](../quality.md) on it.
