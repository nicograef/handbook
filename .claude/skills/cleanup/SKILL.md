---
name: cleanup
description: >-
  Review code changes for clean code principles, design patterns, and
  anti-patterns. Use on recent changes (staged, unstaged, last commit) or a
  specific area (module, route, component, page). Reports findings with
  concrete suggestions, applies fixes after confirmation. Integrates AI slop
  detection, architecture boundary checks, and readability review.
  Triggers: "cleanup", "clean up", "review code quality", "check principles",
  "readability review", "code cleanup", "deslop", "remove slop",
  "clean up AI code", "review for slop", "remove AI writing".
---

# Cleanup

Review code for clean code principles, design patterns, and anti-patterns.
Produce a structured report with concrete, minimal suggestions. Apply fixes
only after user confirmation.

By default this is a focused, incremental review — recent changes or a
user-specified area — not a full codebase audit or an architectural RFC.
For a repo-wide audit, use the repo-wide scope mode in step 1.

Reference files for each review pass:

- [principles.md](principles.md) — SOLID, DRY, KISS, YAGNI, separation of
  concerns, composition over inheritance
- [code-smells.md](code-smells.md) — structural anti-patterns + AI slop
  patterns for code and config files
- [architecture.md](architecture.md) — dependency direction, IoC, deep modules,
  domain model, repository pattern, boundaries
- [readability.md](readability.md) — naming, clarity, clever code, nesting,
  prose/doc slop
- [readability-de.md](readability-de.md) — German prose/doc slop patterns
  (use instead of the prose section in readability.md when text is German)
- [cross-layer.md](cross-layer.md) — cross-layer consistency trace for the
  repo-wide scope mode

## Workflow

### 1. Determine scope

Identify the files to review:

- If the user specifies files, a module, route, component, or page — use those.
- If not specified, check staged changes: `git diff --cached --name-only`.
- If nothing staged, check unstaged changes: `git diff --name-only`.
- Fall back to last commit: `git diff HEAD~1 --name-only`.
- If still empty, ask the user what to review.

Ask the user to confirm scope if ambiguous. In the incremental default, do not
scan the entire codebase — stay within the determined scope.

**Repo-wide scope mode.** When the user asks for a repo-wide quality audit or a
cross-layer consistency check across the whole project, widen the scope to the
codebase. In this mode, run the [cross-layer.md](cross-layer.md) trace across
3–5 representative flows per feature area in addition to the per-file passes,
and report findings without applying fixes.

When reviewing a diff (staged/unstaged/commit), read both the diff and the full
files to understand context.

### 2. Understand conventions

Before flagging anything, read surrounding code that is NOT part of the changes.
Learn the codebase's native voice:

- Naming conventions (casing, prefixes, abbreviations)
- Error handling patterns (early returns, try/catch, result types)
- Comment style and density
- Architecture style (layered, hexagonal, flat, etc.)
- Test patterns (naming, structure, assertion style)
- Import organization
- Config annotation style

The codebase's existing conventions are the baseline. Flag deviations from
clean code principles, not deviations from personal preferences.

### 3. Multi-pass review

Run these passes on each file in scope. Not every pass applies to every file —
skip passes that are irrelevant.

| Pass | Reference | Applies to |
|---|---|---|
| Readability & clarity | [readability.md](readability.md) | All files (code, docs, configs) |
| Readability — German prose | [readability-de.md](readability-de.md) | German-language docs, comments, READMEs |
| Principles | [principles.md](principles.md) | Code files |
| Code smells | [code-smells.md](code-smells.md) | Code files + config files |
| Architecture & boundaries | [architecture.md](architecture.md) | Service, domain, handler, repository layers |
| Cross-layer consistency | [cross-layer.md](cross-layer.md) | Repo-wide scope mode only |
| Test readability | [readability.md](readability.md) + [code-smells.md](code-smells.md) | Test files only |

Slop detection is folded into the Readability and Code smells passes — there
is no separate slop pass. For a slop-focused trigger ("deslop", "remove
slop"), run those two passes with extra attention to their AI-slop sections.

For each issue found, record:

- **What**: the principle violated or smell detected (reference the specific
  rule from the reference file)
- **Where**: file path + line range
- **Why**: one sentence explaining the impact on readability or maintainability
- **Suggestion**: a concrete, minimal change — not a rewrite
- **Effort**: S (< 5 min) / M (5–30 min) / L (30+ min)

Report each issue once, under the most specific pass that catches it. If two
passes flag the same lines, keep the more precise one and drop the duplicate.

### 4. Report

Before reporting, run a verification pass: re-read each flagged location; drop
any finding you cannot anchor to exact lines or that does not hold on re-read;
mark remaining uncertainty as unverified.

Zero findings is a valid outcome — if nothing survives the criteria, report that
the code is clean and stop; do not manufacture findings.

Present findings grouped by file, sorted by severity within each file:

1. **Boundary & consistency risks** — logic at system edges: missing validation
   on external input (HTTP handlers, CLI, external APIs), broken dependency
   direction, cross-layer shape/validation mismatches (see
   [architecture.md](architecture.md) and [cross-layer.md](cross-layer.md)).
   For general bug-hunting inside a function, use `/code-review`.
2. **Readability wins** — naming, clarity, nesting, AI slop removal
3. **Principle violations** — SOLID, DRY, KISS, YAGNI
4. **Structural suggestions** — deeper modules, better boundaries, domain model
   improvements

Format per finding:

```
**[What]** ([principles.md](principles.md) → rule name)
File: path/to/file.ts:42-58
Why: <one sentence>
Suggestion: <concrete change>
Effort: S
```

End with a **prioritized summary**: up to 5 of the most impactful changes across
all files.

Do not apply any changes yet. Ask: "Which of these should I apply?"

### 5. Apply

Work through confirmed findings one at a time:

- Make the minimal change described in the suggestion.
- After finishing all changes to a file, verify that file still compiles or
  passes lint.
- Verify no functionality changed — the output, return values, side effects,
  and behavior must remain identical.

### 6. Verify

After all confirmed changes are applied:

- Run the project's build, lint, and test commands if available.
- Re-read each changed file — it should read more naturally than before.
- End with a 1–3 sentence summary of what changed and why the result is
  cleaner.

## Constraints

- **Never change functionality.** This is a readability and quality pass.
  The code must do exactly the same thing before and after.
- **Never suggest large refactors.** If an issue requires significant
  restructuring, flag it as a large refactor for the user to schedule
  separately and move on.
- **Never rewrite.** Subtract or simplify. Do not impose a different style.
- **Never impose foreign conventions.** The codebase's existing style is the
  baseline. Flag only genuine principle violations, not style preferences.
- **Never add comments, abstractions, or error handling** as part of cleanup.
  The goal is less noise, not more.
- **Never apply fixes without user confirmation.** Always present the report
  first.
- **Respect the native voice.** If a pattern looks like an AI smell but is
  genuinely idiomatic for the project, leave it.
- **Test files: readability only.** Check naming, structure, and clarity of
  test code. Do not retag, delete, or restructure tests — that is the
  test-quality skill's job.
- **Scope discipline.** Only touch files in the determined scope. Do not
  expand to "while we're here" changes in unrelated files.

## Quality

- Before presenting results, run the shared [self-review checklist](../quality.md). Surface issues in the chat only if found.
