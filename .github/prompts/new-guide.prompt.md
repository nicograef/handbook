---
description: "Scaffolds a new step-by-step guide with the correct structure, then updates README.md."
---

# New Guide

Create a new guide in `guides/`. Follow these steps in order:

## Input

- **Topic**: What does the guide cover?
- **Filename**: `guides/<topic>.md` (lowercase, hyphens)

## Steps

1. **Create the guide file** at `guides/<topic>.md` with this structure:
   - `# Title`
   - `## Prerequisites` — OS, packages, access needed
   - Numbered steps with fenced `bash` blocks (copy-paste-ready)
   - `## Verify` — command + expected output
2. **Cross-reference** existing templates or scripts where applicable — link, don't copy.
3. **Update `README.md`** — add a row to the Guides table in alphabetical position.
4. **Verify links** — `grep -r '<filename>' .` to ensure no dead references.

## Conventions

- English only.
- Runbook-style — a reader follows steps top-to-bottom.
- Fenced code blocks for every command, `diff` blocks for config changes.
- No explanatory paragraphs — keep it scannable.
