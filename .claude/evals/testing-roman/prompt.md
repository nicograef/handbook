---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Write, Edit, Bash]
---

Build `toRoman(n)` in a new ES module `roman.js`, test-first, with Node's built-in `node:test` runner.

The behaviours are agreed. It converts integers from 1 to 3999 to Roman numerals, using subtractive forms such as IV and XC. Any other input throws a `RangeError`.
