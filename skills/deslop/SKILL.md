---
name: deslop
description: >-
  Remove AI-generated slop from code, documentation, and other content.
  Use when reviewing AI-generated output to clean up unnecessary comments,
  defensive code, type hacks, style inconsistencies, puffery, and LLM
  vocabulary. Triggers: "deslop", "remove slop", "clean up AI code",
  "review for slop", "remove AI writing".
---

# Deslop

Remove AI-generated slop from code, text, or other content. Scan the specified
files or diff and strip everything that feels imported rather than native.

This skill has separate reference files for different content types:

- [code.md](code.md) — code-specific slop patterns and removal rules
- [text.md](text.md) — prose and documentation slop patterns
- [config.md](config.md) — config files, YAML, CI pipelines, IaC

## Workflow

### 1. Determine scope

- If the user specifies files or a diff, use those.
- If not specified, check staged changes (`git diff --cached`).
- Fall back to recently modified files if nothing is staged.

### 2. Identify content type

For each file, determine which reference to apply:

| Content type | Reference | Examples |
|---|---|---|
| Code | [code.md](code.md) | `.go`, `.ts`, `.js`, `.py`, `.java`, `.sh` |
| Prose / docs | [text.md](text.md) | `.md`, `.txt`, `.adoc`, READMEs, comments in PRDs |
| Config / infra | [config.md](config.md) | `.yml`, `.yaml`, `.json`, `.toml`, `Dockerfile`, `.tf` |

If a file contains mixed content (e.g. inline docs in code), apply both
code and text rules to the relevant sections.

### 3. Read the file's voice

Before making changes, read the surrounding code or prose that was NOT
AI-generated. Every codebase and document has its own dialect — match it:

- What is the existing comment style and density?
- What is the error-handling convention?
- What is the documentation tone and structure?
- How are config files annotated?

### 4. Remove slop

Apply the rules from the appropriate reference file. Remove only what does not
belong. Do not rewrite — subtract.

### 5. Verify

- Confirm no functionality changed (code still compiles, tests pass).
- Confirm no information was lost (docs still say the same things).
- Re-read changed files — they should now read like a human wrote them.

### 6. Report

End with a 1–3 sentence summary of what you changed and why the result is
cleaner.

## Principles

- **Preserve functionality** — never change what code does, only how it reads.
- **Preserve information** — never remove facts from docs, only rephrase slop.
- **Prefer clarity over brevity** — explicit readable code/prose beats compact
  cleverness.
- **Match the native voice** — every file has a dialect. Respect it.
- **Subtract, don't rewrite** — remove the foreign patterns; don't impose new
  ones.
- **Focus scope** — only touch specified files or recent changes unless told
  otherwise.

## Anti-Patterns

- Do not add new comments, abstractions, or error handling while deslopping.
- Do not refactor logic — this is a cosmetic pass, not a rewrite.
- Do not flag patterns that are genuinely idiomatic for the project, even if
  they happen to overlap with AI tells.
- Do not run AI detection tools — use your judgment based on the reference
  files, not statistical classifiers.
