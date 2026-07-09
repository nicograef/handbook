# Quality Checklist

Shared self-review checklist for the handbook skills. Every skill's **Quality**
section links here instead of restating it. Run this silently before presenting
results — surface issues in the chat only if you find them.

## Principles

- **Quality over quantity, correctness over speed.** Fewer, correct changes beat
  many fast ones.
- **Human-reviewable changes.** Every change must be clean, readable, and
  maintainable enough for a senior developer to review and maintain long-term —
  no clever code, no unnecessary abstractions.
- **Small, explainable changes.** Each change small enough to explain every line
  in review — one logical concept per step. Mechanical bulk changes (renames,
  dependency updates) are exempt.

## Self-review checklist

Before presenting results, silently confirm the work is:

1. **Correct** — does it actually solve the stated problem?
2. **Clean** — no dead code, no debug artifacts, consistent style?
3. **Readable** — would a human reviewer understand it without extra explanation?
4. **Maintainable** — no over-engineering, no unnecessary abstractions?
5. **In scope** — nothing beyond what was requested or clearly necessary?
6. **Complete** — tests, validation, and both sides updated where needed?

## Scope guard

If you notice you are making, or about to make, changes outside the task scope,
stop, name the out-of-scope changes, and ask the user before proceeding.

## Verify before claiming done

Evidence before assertions. Before saying work is complete, fixed, or passing —
or before committing or opening a PR — prove it, don't assume it.

- Name the exact command that proves it (the project's test, build, or lint
  command) and run it fresh this turn, even if it "should" already pass.
- Read the full output — exit code, failure count, error text — not just the
  last few lines.
- State the result only after seeing that output, and cite the command you ran.
- If a delegated agent, sub-skill, or tool reported success, don't repeat that
  as fact — check the actual diff or output yourself first.
