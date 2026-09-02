---
name: ux-review
description: >-
  Reviews a frontend for mobile UX, UI consistency, workflow friction, and
  terminology drift. Use when the user wants a UX audit of a mobile-first
  web app or needs to find usability problems on small screens.
---

# Mobile UX Review

## Workflow

### 1. Scope and set up

- Identify the screens or flows to review; default to the primary user journeys when unspecified.

### 2. Render at a mobile viewport

- If Playwright MCP tools are available and the app can run, open each key
  screen at 375×667.
- That viewport is the iPhone SE / small-phone baseline.
- Navigate the flows and take snapshots.
- If the app can't run (no dev server, missing credentials, backend down),
  fall back to a static review.
- That fallback reviews the frontend source and labels the report
  **static-only**, so the user knows screens weren't rendered.

### 3. Walk the top flows

- Step through each flow as a phone user would, watching for the review-area
  problems below.
- Capture the screen and the source location for each issue.

### 4. Map problems to source

- Locate the responsible component for every finding.
- Record the file and line range.
- A finding without a `file:lines` anchor is not usable.
- Drop it, or keep digging until you can anchor it.

### 5. Report

- Re-read each flagged location before reporting.
- Drop findings that don't anchor to exact lines.
- Drop findings that don't hold up on re-read.
- Mark any remaining uncertainty as unverified.
- Findings follow the [report shape](../output-style.md#report-shape) rules.
- One bullet per finding, bold keyword first.
- Fields: **Category** → **What** → **Where** (file:lines) →
  **User Impact** → **Suggestion** → **Effort** (S/M/L).
- Order findings quick wins first, then consistency fixes to batch.

## Review Areas

### Workflow Friction

- Error states that are hard to recover from

### Mobile-First Quality

- Components that break on narrow screens
- Dense tables or forms without a mobile fallback
- Touch targets smaller than 44×44 CSS px, or spaced less than 8 px apart
- The primary action for a screen not visible at 375×667 without scrolling

### UI Consistency

- Same concept labelled differently across screens
- Similar actions with different button labels or placements
- Inconsistent loading, empty, and error states

### Domain Language

- Terminology drift in UI labels vs. backend/domain terms.
- If `docs/UBIQUITOUS_LANGUAGE.md` exists, treat it as the canonical term list
  and flag labels that diverge from it.
- Labels that are technically correct but unclear to end users

## Constraints

- Stay scoped to UX only.
- Do not audit code quality, architecture, performance, or security.
- Flag those only in passing, if they directly cause a UX symptom.
- Judge mobile-first, not desktop-first.
- A desktop-only layout is a finding, not an acceptable baseline.
- Do not flag inconsistency without naming both sides of the drift (e.g.
  which two screens or labels disagree).
- Avoid subjective visual-taste feedback (colors, spacing preferences) that
  isn't tied to friction, consistency, or clarity.

## Quality

- Reports follow the [output style contract](../output-style.md).
