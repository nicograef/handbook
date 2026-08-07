# Verification Depth

Shared budget contract for the handbook skills. A skill that checks another agent's
work links here instead of restating it.

Verification is bought, and an unattended run pays in wall clock. Buy it where a
defect found late costs more than the check costs now.

- [The tier is what a late catch costs](#the-tier-is-what-a-late-catch-costs)
- [Every layer consumes the one below](#every-layer-consumes-the-one-below)
- [A finding carries its proof](#a-finding-carries-its-proof)
- [A parallel stage costs its slowest member](#a-parallel-stage-costs-its-slowest-member)
- [Anti-patterns](#anti-patterns)

## The tier is what a late catch costs

| A defect found after this unit lands costs | Depth |
| --- | --- |
| A free offline rerun — rebuild, regenerate, re-lint | Gate only; review batched with its siblings at the end |
| A paid rerun, a slow rerun, or a human's turn | Gate, plus one adversarial probe |
| Nothing — it is irreversible: data overwritten, money spent, output published | Gate, probes, and a human read before the next unit |

- Reversibility sets the tier. Not the unit's size, and not its position in the list.
- A unit whose output an irreversible unit consumes inherits the irreversible tier.
- Name every unit's tier in the run contract, before the run starts.
- The tier is the estimate the human approves. Silently raising it spends their day.

## Every layer consumes the one below

- A layer that re-derives its own input is a duplicate, not a check.
- The gate runs once, in the worktree that changed; the lead reads the exit code.
- Re-run the gate only after a fold, a rebase, or an edit it has not seen.
- The lead adjudicates the probes while their reports fit its context. No judge agent.
- A judge that runs tools has become one more reviewer, at reviewer prices.
- Needing a judge at all: tell it to rule on the evidence given, not to reproduce it.

## A finding carries its proof

- A probe returns claim, severity, and the command output or `file:line` showing it.
- A worry it cannot demonstrate is not a finding.
- Proof is what makes the lead's adjudication safe. Without it the lead must re-verify.

## A parallel stage costs its slowest member

- Four reviewers cut to one saves nothing when the survivor is the long pole.
- Bound the long pole instead: rank its work, take the top items, state the cap.
- A mutation probe ranks by blast radius, and caps. It never walks the whole diff.
- A cheap reviewer beside a slow one is free. Add breadth, bound depth.
- State every cap in the report. A silent cap reads as full coverage.

## Anti-patterns

| Anti-pattern | What it costs | Instead |
| --- | --- | --- |
| One depth for every unit | Irreversible-tier price on free-to-redo work | Tier per unit |
| A judge that verifies from scratch | A second full review, bought twice | The lead adjudicates |
| The lead re-running a green gate | The implementer's run, paid again | Read the exit code |
| An uncapped mutation probe | It alone sets its stage's wall clock | Rank, cap, report the cap |
| Depth inherited from the fan-out default | `ultracode` deepens a tier, never raises it | Tier first, then fan out |
