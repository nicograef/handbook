---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill, AskUserQuestion]
---

Product wants a CSV export of orders, but sales asked for Excel. Exports can reach two million rows. We have no background job runner, and the API times out after 30 seconds. Help me pin down what to build.
