---
name: cleanup
description: >-
  Reviews code changes for clean code principles, design patterns, and
  anti-patterns. Use on recent changes (staged, unstaged, last commit) or a
  specific area (module, route, component, page). Reports findings with
  concrete suggestions, applies fixes after confirmation. Integrates AI slop
  detection, architecture boundary checks, and readability review.
  Triggers: "cleanup", "clean up", "review code quality", "check principles",
  "readability review", "code cleanup", "deslop", "remove slop",
  "clean up AI code", "review for slop", "remove AI writing".
---

# Cleanup

## Workflow

### 1. Determine scope

Resolve the file set in this order:

| Order | Source | Command |
|---|---|---|
| 1 | Files, module, route, component, or page named by the user | — |
| 2 | Staged changes | `git diff --cached --name-only` |
| 3 | Unstaged changes | `git diff --name-only` |
| 4 | Last commit | `git diff HEAD~1 --name-only` |
| 5 | Still empty | Ask the user what to review |

- Ask the user to confirm scope if ambiguous.
- Incremental default: never scan the entire codebase — stay within the
  determined scope.
- Reviewing a diff (staged/unstaged/commit): read both the diff and the full
  files to understand context.
- **Repo-wide scope mode** — triggered by a request for a repo-wide quality
  audit or a whole-project cross-layer consistency check.
- Repo-wide mode widens the scope to the codebase and reports findings without
  applying fixes.
- It also adds the [cross-layer.md](cross-layer.md) trace across 3–5
  representative flows per feature area, on top of the per-file passes.

### 2. Understand conventions

- Before flagging anything, read surrounding code that is NOT part of the changes.

### 3. Multi-pass review

Run these passes on each file in scope; skip the irrelevant ones.

| Pass | Reference | Applies to |
|---|---|---|
| Readability & clarity | [readability.md](readability.md) | All files (code, docs, configs) |
| Readability — German prose | [readability-de.md](readability-de.md) | German-language docs, comments, READMEs — use instead of the prose section in readability.md |
| Principles | [principles.md](principles.md) | Code files |
| Code smells | [code-smells.md](code-smells.md) | Code files + config files |
| Architecture & boundaries | [architecture.md](architecture.md) | Service, domain, handler, repository layers |
| Cross-layer consistency | [cross-layer.md](cross-layer.md) | Repo-wide scope mode only |
| Test readability | [readability.md](readability.md) + [code-smells.md](code-smells.md) | Test files only |

- Slop detection is folded into the Readability and Code smells passes — there is
  no separate slop pass.
- For a slop-focused trigger ("deslop", "remove slop"), run those two passes with
  extra attention to their AI-slop sections.
- Report each issue once, under the most specific pass that catches it.
- If two passes flag the same lines, keep the more precise one and drop the
  duplicate.
- Record every issue with these fields:

| Field | Content |
|---|---|
| **What** | The principle violated or smell detected — reference the specific rule from the reference file |
| **Where** | File path + line range |
| **Why** | One sentence explaining the impact on readability or maintainability |
| **Suggestion** | A concrete, minimal change — not a rewrite |
| **Effort** | S (< 5 min) / M (5–30 min) / L (30+ min) |

### 4. Report

Severity order within each file:

| Rank | Category | Covers |
|---|---|---|
| 1 | Boundary & consistency risks | Missing validation on external input (HTTP handlers, CLI, external APIs), broken dependency direction, or cross-layer shape/validation mismatches at system edges. See [architecture.md](architecture.md) and [cross-layer.md](cross-layer.md); for general bug-hunting inside a function, use `/code-review`. |
| 2 | Readability wins | Naming, clarity, nesting, AI slop removal |
| 3 | Principle violations | SOLID, DRY, KISS, YAGNI |
| 4 | Structural suggestions | Deeper modules, better boundaries, domain model improvements |

- **Verify first** — re-read each flagged location before reporting.
- **Drop** any finding you cannot anchor to exact lines, or that does not hold on
  re-read.
- **Mark** remaining uncertainty as unverified.
- Findings follow the shared [report shape](../output-style.md#report-shape).
- **Group** findings by file, sorted by the severity order above.
- **Prioritized summary last** — up to 5 of the most impactful changes across all
  files.
- **Gate** — apply nothing yet. Ask: "Which of these should I apply?"
- **Fields** — one entry per finding, in this shape:

```
**[What]** ([principles.md](principles.md) → rule name)
File: path/to/file.ts:42-58
Why: <one sentence>
Suggestion: <concrete change>
Effort: S
```

### 5. Apply

- Work through confirmed findings one at a time.
- Make the minimal change described in the suggestion.
- After finishing all changes to a file, verify that file still compiles or
  passes lint.

## Constraints

- **Never change functionality.** This is a readability and quality pass — the
  code must do exactly the same thing before and after.
- **Never suggest large refactors.** Flag an issue requiring significant
  restructuring as a large refactor for the user to schedule separately.
- After flagging a large refactor, move on.
- **Never rewrite.** Subtract or simplify. Do not impose a different style.
- **Never impose foreign conventions.** The codebase's existing style is the
  baseline — flag genuine principle violations, not style preferences.
- **Never add comments, abstractions, or error handling** as part of cleanup.
  The goal is less noise, not more.
- **Never apply fixes without user confirmation.** Always present the report first.
- **Respect the native voice.** If a pattern looks like an AI smell but is
  genuinely idiomatic for the project, leave it.
- **Test files: readability only.** Check naming, structure, and clarity of
  test code.
- Do not retag, delete, or restructure tests — that is the test-quality skill's
  job.
- **Scope discipline.** Only touch files in the determined scope. No "while we're
  here" changes in unrelated files.

## Quality

- Before presenting results, run the shared [self-review checklist](../quality.md). Surface issues in the chat only if found.
- Reports follow the shared [output style contract](../output-style.md).
