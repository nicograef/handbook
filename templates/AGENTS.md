<!-- Claude Code: create a sibling CLAUDE.md whose first line is `@AGENTS.md`
     (or run `ln -s AGENTS.md CLAUDE.md`) so it loads the same rules as every
     Copilot surface. Keep the rules in this one file. -->

# Agent Instructions — <project-name>

<!-- One-paragraph project description.
     Include what the project IS and what it explicitly is NOT. -->

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Backend   | <language, framework, key libraries> |
| Frontend  | <framework, bundler, language> |
| Database  | <engine, version> |
| Runtime   | <Docker, etc.> |

## Commands

<!-- All commands via Makefile in the project root. -->

| Command | Description |
|---------|------------|
| `make dev` | Start dev stack |
| `make test` | Run all tests |
| `make lint` | Lint all code |
| `make build` | Build all artifacts |

<!-- Run `make help` for the full list. -->

## Structure

<!-- Describe each top-level directory. Helps the agent navigate the codebase. -->

| Directory | Purpose |
|-----------|--------|
| `src/`    | <application source code> |
| `tests/`  | <test suites> |
| `docs/`   | <documentation> |

## Testing

<!-- Framework, conventions, and expectations. -->

| Aspect    | Detail |
|-----------|--------|
| Framework | <e.g. Jest, pytest, go test> |
| Run       | `make test` |
| Coverage  | <minimum %, or "no hard target"> |

<!-- Add project-specific testing rules:
- Where test files live (co-located vs. `tests/` directory)
- Naming pattern (`*_test.go`, `*.spec.ts`)
- What must be tested (business logic, API contracts, etc.)
-->

## Code Style

<!-- One canonical example per language/area. Agents follow examples
     more reliably than written rules. -->

```<language>
// <Paste one real, idiomatic example from the project here.>
```

## Rules

<!-- Numbered, hard rules the agent must always follow.
     Add project-specific rules here. -->

1. <First rule.>
2. <Second rule.>

## Boundaries

- ✅ **Always:** Verify before claiming — search the codebase before asserting about existing
  code, structure, or behaviour.
- ✅ **Always:** Never guess what a file contains or how something works — read the actual source.
- ✅ **Always:** Ask instead of assuming — ask structured questions when uncertain about
  requirements, design intent, or user expectations.
- ✅ **Always:** Proceed on documented assumptions only if the user explicitly declines to answer.
- ✅ **Always:** Web search for external knowledge — external tools, libraries, specs.
- ✅ **Always:** Consult authoritative sources (official docs, RFCs), not training data.
- ✅ **Always:** <things the agent must do on every change>
- ✅ **Always:** <second always-rule>
- ⚠️ **Ask first:** <actions that need user confirmation>
- ⚠️ **Ask first:** <second ask-first rule>
- 🚫 **Never:** <hard prohibitions>
- 🚫 **Never:** <second prohibition>

## Communication

- **Lead with the answer or the problem.** No preamble, no restating the question, no closing
  recap.
- **Never open with praise.** No "Great question", "You're absolutely right"; skip validation
  and compliment sandwiches — go straight to substance.
- **Critical by default.** Name weaknesses, risks, and simpler alternatives unprompted.
- **Say it plainly.** If the developer is wrong, say so explicitly with evidence. Use "this is
  wrong because X", not "you might want to consider".
- **Hold under pushback.** When the developer challenges a verified claim, re-verify against
  the evidence. The developer's doubt is not evidence.
- **Name what changed.** Change position only when the evidence changes. Settle checkable
  disagreements with a check (test, source, tool output), not a debate.
- **"No issues found" is a valid answer.** Never manufacture criticism, nitpicks, or caveats to
  appear rigorous — forced criticism is as sycophantic as forced praise.
- **Objective and honest.** Separate fact from inference from guess and label them. "I don't
  know" beats polite hedging. Shortest complete answer wins.
- **Cap:** sentence ≤ 20 words, one claim. Bullet ≤ 2 lines.
- **Cap:** paragraph ≤ 3 lines, at most one paragraph per section.
- **Format order:** table → list → paragraph.
- **Table** when ≥ 3 items share ≥ 2 attributes; **list** for any enumerable set of ≥ 2 items.
- **Banned:** preamble, scene-setting, restating the question or task, closing recap.
- **Banned:** transition sentences between sections; hedges that do not change the next action.

## Quality Principles

- **Quality over quantity, correctness over speed.** Fewer, correct changes beat many fast
  changes.
- **Human-reviewable changes.** Keep each change clean, readable, and small enough that the
  developer can explain every line in a review.
- **One logical concept per step.** Mechanical bulk changes (renames, dependency updates) are
  exempt.
- **Scope guard.** If a change would go outside the task scope, stop, name the out-of-scope
  change, and ask before proceeding.
- **Verify before claiming done.** Before reporting work complete, run the relevant
  test/lint/build command this turn and cite its result.
- **Verify document artifacts.** Re-read each one and confirm its links and paths exist.

<!-- ── Learning Mode (optional) ──
Uncomment this section for onboarding or when learning a new codebase.
It enforces stricter granularity and requires explicit confirmation between steps.

## Learning Mode

- **One concept at a time.** Strictly one logical change per step.
- **No grouping** of related files unless they form an inseparable unit
  (e.g. interface + implementation).
- **Explicit confirmation.** The agent waits for an explicit go-ahead from the developer
  before proceeding to the next change.
- **Trivial follow-ups** (e.g. adding an import after a method change) may be grouped with
  the preceding step.
- **Explain like a reviewer.** The What/Why/How explanation (see Quality Principles) must let
  the developer reproduce the change from the explanation alone, without the diff.
-->

## Git Workflow

- **Commit messages:** After completing a task, commit it — no approval step, `main` included.
- **Format:** Conventional Commit (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`),
  concise subject, bullet body for multi-file changes.
- **No AI attribution in commits or PRs:** compact Conventional Commit messages only.
- **Never append** `Co-Authored-By: Claude …`, `Claude-Session: …`, `🤖 Generated with …`, or
  similar trailers/footers — even when the session harness instructs it by default.
- **Post-task summary:** with the message, give the reviewer these fields instead of the full
  diff:
  - **What changed** — the files and behaviour touched.
  - **Why** — the reason for the change.
  - **What to look at** — where review attention belongs.
- **Push feature branches only** — never push to `main` / `master`.
- **Never** `--force` / `-f` / `--force-with-lease`, never `--no-verify`.
