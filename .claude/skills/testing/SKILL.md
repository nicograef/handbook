---
name: testing
description: Test-first development (red-green-refactor, one test at a time) and test-suite review that tags every test Keep, Refactor, Delete or Merge before touching it. Use for TDD, test-first work, or to shrink a noisy or brittle suite.
argument-hint: "[tdd <feature> | review <paths>]"
---

# Testing

## Preferences that differ from defaults

- Test observable behaviour through public interfaces. Tests of private methods, internal call counts, argument order, or mock invocations on our own code are implementation-detail tests.
- Mock only at true system boundaries: external APIs, email, time, randomness. Prefer a real test database over a mocked repository; mock the driver only when none is available.
- A hand-rolled mock implements the whole interface or is replaced by a real in-memory fake. Partial mocks hide integration gaps.
- No test-only methods on production classes; build state through test helpers.
- Assert on error type, code or sentinel, not on the full message string.
- Add an integration test only where a unit test cannot cover the boundary, and keep it fast.
- A test nobody has watched fail is not a test: confirm red for the expected reason before green.

## TDD

1. Agree the interface and the behaviours to test with the user before coding. List behaviours, not implementation steps; cover critical paths and complex logic, not every edge.
2. One test: write it, run it, confirm it fails for the expected reason (missing feature, not a typo). Write the minimal code to pass. Confirm the whole suite is green with clean output.
3. Refactor only while green, running tests after each step.

## Suite review

1. Inventory: file → test count → framework, plus shared helpers and fixtures. Confirm scope with the user.
2. Tag every test, applying in order:

   | Signal | Tag |
   | --- | --- |
   | No meaningful assertion, or asserts only on values the test itself set up | Delete |
   | Reaches private methods or fields | Delete; a public-API test replaces it if the behaviour matters |
   | Asserts internal call counts, argument order or mock invocations | Delete, or Refactor to assert on output |
   | Mocks internal collaborators, or verifies state by bypassing the public interface (raw SQL, file reads) | Refactor |
   | Named for how ("calls X", "sets flag") rather than what | Refactor |
   | Same behaviour as two or more other tests with trivially different inputs | Merge into one table-driven test |
   | Asserts exact error strings | Refactor |
   | Otherwise | Keep |

3. Report before changing anything, grouped by file: tag, test names, one-line reason for Refactor and Delete, Merge target. Add before/after totals. When a Delete removes the only coverage of a behaviour, say so and suggest adding a proper test afterwards. Wait for confirmation and update disputed tags.
4. Apply per file: Merge, then Refactor, then Delete; remove orphaned helpers and imports.
5. Run the full suite. A failure is either a regression (restore the test, re-evaluate) or a false signal the test gave before too. Report the final counts and any regressions.

Fix broken behaviour in the implementation, never by rewriting the test. The review adds no tests and changes no implementation code.
