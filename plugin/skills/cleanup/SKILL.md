---
name: cleanup
description: "Finds and fixes bugs, removes dead, unused, deprecated and stale code, comments, docs, config and dependencies, and checks mobile UX. Applies only picked findings. Triggers: cleanup, dead code, bug sweep, ux review."
argument-hint: "[paths | staged | last-commit | repo | ux]"
---

# Cleanup

Arguments: `$ARGUMENTS`. Report first, change nothing until the user picks. Removals keep behaviour identical; a bug fix changes only the faulty behaviour. Architecture, layering and test design belong to `/nico:architecture`, readability and slop to `/simplify`, doc volume to `/nico:distill`.

## Hazards

- No reference found does not mean unused. Rule out dynamic access first: reflection, string-keyed lookups, `getattr`, DI containers.
- Rule out framework conventions: route and page files, decorators, entry points, CLI commands, fixtures, signal handlers.
- Rule out consumers outside the code: other repos, published packages, config, templates, CI, Dockerfiles, Makefiles, infra.
- A name you cannot clear is reported as Suspect and stays.
- Persisted shapes stay until the data says otherwise: DB columns, serialized fields, event payloads, API response fields, deployed env vars. Report them with the migration they need, effort L.
- Migrations, `CHANGELOG.md` and ADRs record history by design; leave them.
- A bug finding names the input and the wrong output, or it is not a bug finding.

## Scope

Named files or area, else staged changes, else unstaged, else the last commit, else ask. Before flagging anything, read the full files around a diff and the neighbouring code outside the change. `repo` widens to the codebase and fans out one read-only `opus` reviewer per area; each reads this file for the criteria. `ux` runs the UX pass instead.

## Passes

| Pass | Look for |
| --- | --- |
| Bugs | Boundary and off-by-one errors; unhandled null paths; swallowed or mis-mapped errors; error paths returning success; unawaited promises; races on shared state; leaked files, connections, timers or listeners; wrong unit or time zone; missing validation at a trust boundary |
| Dead | Unreachable branches; unused exports, functions, parameters, fields, types, enum members, CSS classes, i18n keys, files, scripts and Make targets; feature flags fixed on or off; tests of removed code |
| Unused config | Dependencies nothing imports, env vars nothing reads, config keys, CI jobs, Docker stages, assets |
| Deprecated | Symbols marked `@deprecated` or raising deprecation warnings; deprecated dependency APIs, read from build and test warnings; shims and polyfills for runtimes or versions out of support |
| Stale | Comments and docs naming removed or renamed symbols, files, flags or commands, or describing old behaviour; TODO and FIXME already done or obsolete; commented-out code; suppressions (`@ts-ignore`, `eslint-disable`, `# type: ignore`, `# noqa`, `//nolint`) that suppress nothing; skipped tests |
| UX (`ux` only) | At 375×667 (Playwright if the app runs, else a static review labelled so): components that break, tables without a mobile fallback, touch targets under 44×44 px, primary action below the fold, one concept labelled two ways, inconsistent loading/empty/error states, labels diverging from the repo's glossary, else `docs/UBIQUITOUS_LANGUAGE.md` |

Dead-code candidates come from a detector the repo configures, else one run ad hoc: `npx knip`, `uvx vulture`, Go's `deadcode`. Confirm every hit with `git grep` over all tracked files, not only code.

## Report

Re-read every flagged location; drop anything that does not anchor to exact lines or does not hold on re-read. Group by file, ordered: bugs, deprecated, dead and unused, stale, Suspect. One entry per finding:

```
**[What]** (pass → rule)
File: path/to/file.ts:42-58
Why: <one sentence>
Suggestion: <minimal concrete change>
Effort: S | M | L
```

Close with up to five most impactful changes across all files, then ask which to apply. Zero findings is one line.

## Apply

- A bug fix starts with a regression test that fails before the fix and passes after it.
- A deprecated symbol with callers gets its callers migrated in the same finding, then is deleted.
- A removal takes the whole chain: symbol, its tests, exports, docs and config references. `git grep` the name afterwards and fix each hit.
- A skipped test gets its cause fixed, or is deleted when its behaviour is gone.
- Compile, lint and run the full suite once, after the last finding. A failure reverts that finding; report it as used.
- Flag a large refactor for the user to schedule instead of doing it.
- Add no comments, abstractions or error handling. Leave patterns that look like slop but are the project's own idiom.
