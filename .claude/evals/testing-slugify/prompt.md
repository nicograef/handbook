---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Write, Edit, Bash]
---

Use TDD to add `slugify(text)` to a new Python module `slug.py`. Test it with the standard library's unittest.

The behaviours are agreed. It lowercases the text and turns each run of non-alphanumeric characters into one hyphen. It strips leading and trailing hyphens. Empty input returns an empty string.
