---
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion, Write]
---

Plan password reset by email for our Flask app, which keeps users in Postgres. A user requests a reset link, receives a single-use token, and sets a new password. Write the plan file; no code yet.
