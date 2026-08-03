---
name: test-quality
description: >-
  Reviews and refactors an existing test suite. Use when the user wants to reduce
  test count, remove implementation-detail tests, improve test readability, or
  clean up a test suite that has grown noisy or brittle.
---

# Test Quality Review

## Workflow

### Step 1 — Discover

- List the test files in a compact inventory table: file → test count → framework.
- Note any test helpers, fixtures, or shared setup files.
- Ask the user whether to limit scope to specific packages or files, before proceeding.

### Step 2 — Audit

- Evaluate every test file.
- Assign each test exactly one tag: **Keep**, **Refactor**, **Delete**, or **Merge**.
- Apply the decision rules in [evaluation-criteria.md](evaluation-criteria.md).
- [anti-patterns.md](anti-patterns.md) catalogs the patterns to recognise.
- Group findings by file.
- Do not make changes yet.

### Step 3 — Report

Present the summary to the user before touching any code.

- **Counts line first** — `20 tests — 4 keep, 5 refactor, 2 delete, 1 merge`.
- **Group** the tags by file, in this shape:

```
File: src/checkout/checkout.test.ts  (12 tests)
  Keep     4  — [list test names]
  Refactor 5  — [list test names + 1-line reason]
  Delete   2  — [list test names + 1-line reason]
  Merge    1  — [list test names + target]

File: src/cart/cart.test.ts  (8 tests)
  ...

Total: 20 tests → 17 tests after changes
```

- **Fields** — Keep and Merge list test names; Merge adds the target.
- **Fields** — Refactor and Delete add a one-line reason per test.
- **Mostly-Keep is a success** — a suite already testing behavior through the public API.
- **Report that outcome** in one line, with no padding.
- **Never manufacture** Delete or Merge tags to show activity.
- **Explain** the biggest quality wins after the report.
- **Ask** for explicit confirmation before proceeding.
- **Update** any tag the user disagrees with, before proceeding.
- **Gate** — do not start Step 4 until the user confirms.

### Step 4 — Refactor

Work through changes one file at a time.

- [ ] Apply **Merge** first (reduces total test count, simplifies subsequent work)
- [ ] Apply **Refactor** next (rewrite tests to use public interface only)
- [ ] Apply **Delete** last (already confirmed in the Step 3 report)
- [ ] Remove dead test helpers and fixtures that are no longer referenced
- [ ] Clean up imports left orphaned by deleted tests
- [ ] Preserve mocks at true system boundaries (HTTP, DB, email, time, randomness)

### Step 5 — Verify

- [ ] Run the full test suite
- [ ] If tests fail, diagnose which of the two causes applies
  - Regression — protected behavior was removed
  - False signal — the test was wrong before too
- [ ] For genuine regressions: restore the deleted test and re-evaluate
- [ ] Report the final before/after count and any regressions found

## Constraints

- **Never delete tests without user confirmation** — always show the report first
- **Never add new tests** — out of scope; redirect to TDD skill if coverage gaps exist
- **Never rewrite a test to make it pass** — broken behavior is fixed in the
  implementation, not the test
- **Never mock internal collaborators** — mocks belong at system boundaries only
- **Never keep tests that verify call counts or argument order** on internal
  methods — these are implementation-detail tests
- **Never bypass the public interface** to verify state (e.g. querying the DB
  directly after calling a service method)
- **Preserve integration-style tests** even if they are "slow" — they are the
  most valuable tests in the suite
- **Do not refactor implementation code** during this skill — test code only

## Quality

- Before presenting results, run the shared [self-review checklist](../quality.md).
- Reports follow the shared [output style contract](../output-style.md).
- Surface issues in the chat only if found.
