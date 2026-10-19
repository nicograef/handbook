---
name: cleanup
description: "Finds and fixes bugs and removes outdated, stale, deprecated and unused code, comments, docs, config and dependencies. Triggers: cleanup, dead code, bug sweep."
argument-hint: "[paths | staged | last-commit | repo | ux]"
---

# Cleanup

Arguments: `$ARGUMENTS`: named paths, staged changes, the last commit, or the whole repo. Without arguments: staged, else unstaged, else the last commit.

- Find bugs and fix them, each with a regression test.
- Remove outdated, stale, deprecated and unused code, comments, docs, config, tests and dependencies.
- Before removing something as unused, rule out uses the grep misses: dynamic access, framework conventions, external consumers, persisted data.
- Report the findings first; apply the ones the user picks.
- Run the build and the tests after applying.
- `ux` reviews the UI on a 375×667 viewport instead: broken layouts, small touch targets, inconsistent labels and states.

Architecture belongs to `/nico:architecture`, readability to `/simplify`, doc volume to `/nico:distill`.
