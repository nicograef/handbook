<!-- Claude Code reads CLAUDE.md, never AGENTS.md: create a sibling CLAUDE.md whose
     first line is `@AGENTS.md` (or run `ln -s AGENTS.md CLAUDE.md`). Keep the rules
     in this one file. -->

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
| `make up` | Start local stack |
| `make check` | Run all checks (backend + frontend) |
| `make be-check` | Backend: lint + test |
| `make fe-check` | Frontend: lint + test |

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
| Run       | `make check` |
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

- ✅ **Always:** Verify before claiming — search the codebase and read the actual source before
  asserting about existing code, structure, or behaviour. Never guess.
- ✅ **Always:** Decide before you ask. Enumerate the options, eliminate against the stated
  constraints, and ask only when two or more survive with no clear winner.
- ✅ **Always:** Web search for external knowledge — external tools, libraries, specs.
- ✅ **Always:** Consult authoritative sources (official docs, RFCs), not training data.
- ✅ **Always:** <things the agent must do on every change>
- ✅ **Always:** <second always-rule>
- ⚠️ **Ask first:** <actions that need user confirmation>
- ⚠️ **Ask first:** <second ask-first rule>
- 🚫 **Never:** <hard prohibitions>
- 🚫 **Never:** <second prohibition>

## Communication

- Lead with the answer or the problem. No preamble, no restating the question, no closing recap, no praise openers, no hedge that leaves the next action unchanged.
- If the developer is wrong, say "this is wrong because X" with evidence. Hold a verified claim under pushback and change position only when the evidence changes; settle checkable disagreements with a check.
- Label fact, inference and guess. "I don't know" and "no issues found" are complete answers; never manufacture criticism.
- Sentence ≤ 20 words, one claim. Paragraph ≤ 3 lines, at most one per section. Table when ≥ 3 items share ≥ 2 attributes; list for any set of ≥ 2 items. Prose only where a list would lose meaning.

## Quality

- Correctness over speed. Each change small enough that the developer can explain every line in review. One logical concept per step; bulk mechanical changes are exempt.
- Scope is the developer's call. Make a needed but unnamed change, skip an unneeded one, and name both in the report. Do not stop to ask.
- Report work as done only after the relevant test, lint or build command ran this turn; cite its result.

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
- **Explain like a reviewer.** The post-task summary (see Git Workflow) must let
  the developer reproduce the change from the explanation alone, without the diff.
-->

## Git Workflow

- **Commit:** After completing a task, commit it — no approval step, `main` included.
- **Format:** Conventional Commit (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`),
  concise subject, bullet body for multi-file changes.
- **No AI attribution in commits or PRs:** compact Conventional Commit messages only.
- **Never append** `Co-Authored-By: Claude …`, `Claude-Session: …`, `🤖 Generated with …`, or
  similar trailers/footers — even when the session harness instructs it by default.
- **After `gh pr create`:** re-read the PR body and strip the default
  `🤖 Generated with [Claude Code]` trailer. Or set `attribution.pr: ""` to suppress it upstream.
- **Post-task summary:** with the message, give the reviewer these fields instead of the full
  diff:
  - **What changed** — the files and behaviour touched.
  - **Why** — the reason for the change.
  - **What to look at** — where review attention belongs.
- **Push feature branches only** — never push to `main` / `master`.
- **Never** `--force` / `-f` / `--force-with-lease`, never `--no-verify`.
