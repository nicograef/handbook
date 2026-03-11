---
description: "Use when editing or creating conceptual reference documents in the theory/ directory."
applyTo: "theory/**"
---

# Theory Conventions

## Purpose

Theory files are conceptual reference material — like lectures or book chapters. They cover architecture patterns, domain knowledge, and technology deep-dives. They are **not** personal runbooks (that's what `guides/` is for).

## Language

All existing theory files are written in **German**. Keep them in German. Do not translate.

## Format

- Use clear section headings (`##`, `###`).
- Use fenced code blocks for examples.
- Keep content self-contained — each file should cover one topic comprehensively.

## File naming

`<topic>.md` — lowercase, hyphens. Example: `event-sourcing.md`.

## After creating or renaming a theory file

1. Add or update the entry in `README.md` (Theory table).
2. Search for references to the old filename: `grep -r '<old-name>' .`
