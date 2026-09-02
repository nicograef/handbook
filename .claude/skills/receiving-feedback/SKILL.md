---
name: receiving-feedback
description: >-
  Acts on code-review feedback (from a human, a PR comment, or an AI
  reviewer) by verifying each item against the codebase before implementing,
  and asking when items are unclear. Use when receiving code review
  comments, PR feedback, or suggestions from another reviewer — before
  implementing any of them.
---

# Receiving Feedback

_Adapted from the MIT-licensed [superpowers](https://github.com/obra/superpowers) plugin._

## Workflow

1. **Read all feedback first.** Do not reply or start fixing item by item.
   - Items are often related; a partial read leads to a wrong fix.
2. **Restate each item as a concrete technical requirement** in your own words.
   - Genuinely ambiguous item — mark it unclear instead of guessing.
3. **Any item unclear — ask about all unclear items before implementing anything.**
   - Never implement the clear items first and ask later.
   - Resolving the unclear ones can change how the clear ones should be done.
4. **Verify each clear item against the actual codebase:**
   - Does it match current behavior, or is the reviewer assuming something false?
   - Would the change break existing tests or other callers?
   - Is there a reason the code is the way it is?
   - Such reasons: compatibility, a prior decision, a constraint the reviewer may not see.
   - Is the suggestion actually used, or does it add something nothing calls (YAGNI)?
5. **Evaluate technical soundness for this stack.**
   - A suggestion can be generically reasonable and still wrong for Nico's stack.
   - Judge it in that context, never in the abstract.
   - That context: Go stdlib patterns, React/TS conventions, sqlc-generated code, etc.
6. **Push back with reasoning when a suggestion is wrong.**
   - State the specific technical reason: a failing assumption, a broken test, a compatibility
     constraint.
   - Then propose an alternative, or ask which tradeoff to take.
7. **Implement one item at a time, in this order:** blocking issues (bugs, security), then
   simple fixes, then complex/structural fixes.
   - Verify each one (tests, build, manual check) before moving to the next.
8. **Report back factually.**
   - **Implemented** — what changed and where.
   - **Not implemented** — the item, plus the technical reason it was rejected.
   - **Wrong pushback** — you pushed back and were wrong: say so plainly, then fix it.

## Constraints

- Acknowledge with the fix itself or a one-line factual note.
- No social filler, per the [report shape](../output-style.md#report-shape) rule 6.
- Architectural pushback goes to Nico, never into a unilateral decision.
- A suggestion conflicting with an existing architectural choice — flag it and ask.
- Never silently override either the reviewer or the prior decision.
- Reply to inline PR comments on GitHub in the comment thread, not as a new top-level PR comment.
- Thread reply endpoint: `gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies`.

## Quality

- Before presenting results, run the shared [self-review checklist](../quality.md).
- Format the report per the [output style contract](../output-style.md).
