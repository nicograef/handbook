---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Write, Edit, Bash]
---

`parse_duration("1h30m")` in `duration.py` returns 1800 instead of 5400. Fix it test-first. The tests live in `test_duration.py` and run with `python3 -m unittest`.
