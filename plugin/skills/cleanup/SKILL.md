---
name: cleanup
description: "Finds and fixes bugs and removes outdated, stale, deprecated and unused code, comments, docs, config and dependencies. Triggers: cleanup, dead code, bug sweep, ux review."
argument-hint: "[paths | staged | last-commit | repo | ux]"
---

# Cleanup

Arguments: `$ARGUMENTS`: named paths, staged changes, the last commit, or the whole repo. Without arguments: staged, else unstaged, else the last commit.

- Find bugs and fix them, add a regression test if suitable.
- Remove outdated, stale, deprecated and unused code, comments, docs, config, tests and dependencies.
- Before removing something as unused, rule out uses the grep misses: dynamic access, framework conventions, external consumers, persisted data.
- Apply the findings directly. Removals that touch external consumers or persisted data go to the user first.
- Run the build and the tests after applying.
- `ux` reviews the UI on a 375×667 viewport instead: broken layouts, small touch targets, inconsistent labels and states.
