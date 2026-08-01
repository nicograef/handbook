# Principles

The principles pass covers KISS, YAGNI, DRY, SOLID, separation of concerns, least
surprise, composition over inheritance, fail fast, and minimal mutable state. Their
definitions and the usual violation tells are assumed known — what follows is only the
calibration that keeps the pass from over-firing.

---

## YAGNI — You Aren't Gonna Need It

**Suggest:** Add the extension point when a second use case actually appears. For the
concrete single-implementation-interface and pure-delegation tells, see
[code-smells.md → Redundant Abstractions](code-smells.md#redundant-abstractions).

---

## DRY — Don't Repeat Yourself

**Ask:** Is this duplication of knowledge (same business rule, same source of
truth), or is it coincidental similarity (two things that happen to look alike
but represent different concepts)?

**Do NOT flag when:**

- Two functions have similar structure but represent different domain concepts
- Test setup code is repeated across tests for clarity
- Two API endpoints happen to have similar response shapes

**Suggest:** Extract the shared knowledge to a single source of truth. For
coincidental similarity, leave it alone — wrong DRY (coupling unrelated things)
is worse than repetition.

---

## Single Responsibility (SOLID — S)

**Ask:** Does this function, class, or module have exactly one reason to change?

**Suggest:** Identify the separate responsibilities — for a layering leak, which
concern is leaking where — and note which could be extracted. Do not extract during
cleanup: note the small ones, and flag large ones as a separate refactor for the user
to schedule.

---

## Open/Closed (SOLID — O)

**Ask:** Can new behavior be added without modifying existing code?

**Suggest:** Note the violation. For small cases (2–3 branches), this is often
acceptable — do not over-engineer. Flag only when the pattern is actively
causing maintenance pain.
