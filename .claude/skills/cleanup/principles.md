# Principles

This pass covers KISS, YAGNI, DRY, SOLID, separation of concerns, least
surprise, composition over inheritance, fail fast, minimal mutable state.

- Their definitions and the usual violation tells are assumed known.
- What follows is only the calibration that keeps the pass from over-firing.

## YAGNI — You Aren't Gonna Need It

- **Suggest:** Add the extension point when a second or third use case makes
  it earn its keep (Rule of Three).
- Concrete single-implementation-interface and pure-delegation tells:
  [code-smells.md → Redundant Abstractions](code-smells.md#redundant-abstractions).

## DRY — Don't Repeat Yourself

- **Ask:** Is this duplication of knowledge — same business rule, same source of
  truth?
- Or is it coincidental similarity: two things that look alike but represent
  different concepts?

**Do NOT flag when:**

- Two functions have similar structure but represent different domain concepts
- Test setup code is repeated across tests for clarity
- Two API endpoints happen to have similar response shapes

**Suggest:** Extract the shared knowledge to a single source of truth. Leave
coincidental similarity alone — wrong DRY couples unrelated things, which is
worse than repetition.

## Single Responsibility (SOLID — S)

- **Ask:** Does this function, class, or module have exactly one reason to change?
- **Suggest:** Identify the separate responsibilities and note which could be
  extracted.
- For a layering leak, name which concern is leaking where.
- Do not extract during cleanup — note the small ones.
- Flag large ones as a separate refactor for the user to schedule.

## Open/Closed (SOLID — O)

- **Ask:** Can new behavior be added without modifying existing code?
- **Suggest:** Note the violation.
- Small cases (2–3 branches) are often acceptable — do not over-engineer.
- Flag only when the pattern is actively causing maintenance pain.
