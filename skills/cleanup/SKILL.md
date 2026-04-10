---
name: cleanup
description: >-
  Review code changes for clean code principles, design patterns, and
  anti-patterns. Use on recent changes (staged, unstaged, last commit) or a
  specific area (module, route, component, page). Reports findings with
  concrete suggestions, applies fixes after confirmation. Integrates AI slop
  detection, architecture boundary checks, and readability review.
  Triggers: "cleanup", "clean up", "review code quality", "check principles",
  "readability review", "code cleanup".
---

# Cleanup

Review code for clean code principles, design patterns, and anti-patterns.
Produce a structured report with concrete, minimal suggestions. Apply fixes
only after user confirmation.

This is a focused, incremental review — not a full codebase audit or an
architectural RFC. Work on recent changes or a user-specified area and suggest
small improvements that make the code cleaner and more readable.

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

## Workflow

### 1. Determine scope

Identify the files to review:

- If the user specifies files, a module, route, component, or page — use those.
- If not specified, check staged changes: `git diff --cached --name-only`.
- If nothing staged, check unstaged changes: `git diff --name-only`.
- Fall back to last commit: `git diff HEAD~1 --name-only`.
- If still empty, ask the user what to review.

Never scan the entire codebase unprompted. Ask the user to confirm scope if
ambiguous.

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
| Test readability | [principles.md](principles.md) + [code-smells.md](code-smells.md) | Test files only |

For each issue found, record:

- **What**: the principle violated or smell detected (reference the specific
  rule from the reference file)
- **Where**: file path + line range
- **Why**: one sentence explaining the impact on readability or maintainability
- **Suggestion**: a concrete, minimal change — not a rewrite
- **Effort**: S (< 5 min) / M (5–30 min) / L (30+ min)

### 4. Report

Present findings grouped by file, sorted by severity within each file:

1. **Correctness risks** — logic bugs, boundary violations, missing validation
   at system edges
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

End with a **prioritized summary**: the 3–5 most impactful changes across all
files.

Do not apply any changes yet. Ask: "Which of these should I apply?"

### 5. Apply

Work through confirmed findings one at a time:

- Make the minimal change described in the suggestion.
- Verify the file still compiles or passes lint after each change.
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
  restructuring, flag it as "consider the improve-architecture skill" and move
  on.
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
