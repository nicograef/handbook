---
name: code-audit
description: >-
  Audit a codebase for cross-layer consistency and simplification opportunities.
  Use when the user wants a repo-wide quality audit or consistency check across
  all layers of a full-stack project. Not for incremental code review or
  readability passes — use the cleanup skill for those.
---

# Code Quality Audit

Audit the codebase in three steps. Run all three unless the user restricts
the focus.

## Step 1: Cross-Layer Consistency

Do the layers still agree?

- Frontend request bodies vs. backend handler request structs
- Frontend response parsing vs. backend response JSON shapes
- Frontend types and validation schemas vs. backend types and JSON payloads
- Database queries vs. schema (columns, nullability, defaults, status values)
- Generated query expectations vs. repository mapping
- Validation rules consistent on both sides

Trace representative flows end-to-end: frontend call → API client →
HTTP handler → application service → repository → SQL.

## Step 2: Simplification (Readability-First)

What is harder to read than necessary?

- Long, nested logic that can be simplified
- Interfaces with only one implementation that add indirection without value
- Wrapper functions that only forward calls
- Stale patterns from earlier architecture phases
- Unused code, dead exports, endpoints nothing calls
- Inconsistent coding style across similar modules
- Queries that are unnecessarily complex
- Repository methods that only forward generated queries without domain value

## Step 3: Repo Verification

Run the project's build, lint, and test suite.

If errors occur: report the step, type (lint/test/build), affected files,
root cause, and next debugging step.

## Output

Per finding: **What** → **Where** (file:lines) → **Impact** → **Suggestion**
→ **Effort** (S/M/L).

At the end: prioritised recommendations (correctness bugs > quick wins >
larger refactors).

## Constraints

- This is a repo-wide audit, not incremental code review — for a single
  change or diff, use the cleanup skill instead.
- Report findings; do not apply fixes. The audit produces recommendations,
  not code changes.
- Simplification suggestions must stay readability-first — do not propose
  rewrites or refactors that trade clarity for cleverness or brevity alone.
- Do not flag a single-implementation interface or wrapper as a problem
  unless it adds indirection without value — some abstractions are
  intentional.
- Skip Step 3 conclusions if the build/lint/test tooling itself is broken or
  unavailable — report that as a finding rather than guessing at results.

## Quality

- Before presenting results, run the shared [self-review checklist](../quality.md) — applied to the quality of the audit artifact. Surface issues in the chat only if found.
