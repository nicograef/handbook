---
name: ux-review
description: >-
  Reviews a frontend for mobile UX, UI consistency, workflow friction, and
  terminology drift. Use when the user wants a UX audit of a mobile-first
  web app or needs to find usability problems on small screens.
---

# Mobile UX Review

Find UX problems that slow down users on smartphones during real-world usage.

## Workflow

### 1. Scope and set up

- Identify the screens or flows to review. If the user did not specify, ask
  which flows matter most, or default to the primary user journeys.
- Find how to run the app (`package.json` scripts, README, Makefile). Note the
  dev URL and any login/seed steps needed to reach the flows.

### 2. Render at a mobile viewport

- If the Playwright MCP tools are available and the app can run, open each key
  screen at a 375×667 viewport (iPhone SE / small-phone baseline), navigate the
  flows, and take snapshots.
- If the app cannot run (no dev server, missing credentials, backend down),
  fall back to a static review of the frontend source and label the report
  **static-only** so the user knows screens were not rendered.

### 3. Walk the top flows

Step through each flow as a phone user would, watching for the review-area
problems below. Capture the screen and the source location for each issue.

### 4. Map problems to source

For every finding, locate the responsible component and record the file and line
range. A finding without a `file:lines` anchor is not usable — drop it or keep
digging until you can anchor it.

### 5. Report

Before reporting, re-read each flagged location; drop any finding you cannot
anchor to exact lines or that does not hold on re-read; mark remaining
uncertainty as unverified. Zero findings is a valid outcome — if nothing
survives the criteria, report that the UX is clean and stop; do not manufacture
findings.

Per finding: **Category** → **What** → **Where** (file:lines) →
**User Impact** → **Suggestion** → **Effort** (S/M/L).

End with quick wins first, then consistency fixes to batch.

## Review Areas

### Workflow Friction

- Too many taps for frequent actions
- Hidden or unclear next steps
- Missing feedback after save, submit, or destructive actions
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

- Terminology drift in UI labels vs. backend/domain terms. If
  `docs/UBIQUITOUS_LANGUAGE.md` exists, treat it as the canonical term list and
  flag labels that diverge from it.
- Labels that are technically correct but unclear to end users

## Constraints

- Stay scoped to UX: do not audit code quality, architecture, performance, or security — flag those only in passing if they directly cause a UX symptom.
- Judge mobile-first, not desktop-first — a layout that only works at desktop widths is a finding, not an acceptable baseline.
- Do not flag inconsistency without naming both sides of the drift (e.g. which two screens or labels disagree).
- Avoid subjective visual-taste feedback (colors, spacing preferences) that isn't tied to friction, consistency, or clarity.
