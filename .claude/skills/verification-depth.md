# Verification Depth

Shared budget contract for the handbook skills. A skill that checks another agent's
work links here instead of restating it.

Verification is bought, and an unattended run pays in wall clock. Buy it where a
defect found late costs more than the check costs now.

- [The tier is what a late catch costs](#the-tier-is-what-a-late-catch-costs)
- [Every layer consumes the one below](#every-layer-consumes-the-one-below)
- [A finding carries its proof](#a-finding-carries-its-proof)
- [A parallel stage costs its slowest member](#a-parallel-stage-costs-its-slowest-member)
- [A review blocks only where its defects propagate](#a-review-blocks-only-where-its-defects-propagate)
- [A finding that recurs becomes a gate](#a-finding-that-recurs-becomes-a-gate)
- [Mechanise what is mechanical](#mechanise-what-is-mechanical)
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

## A review blocks only where its defects propagate

- A read-only probe blocks nothing. Overlap it with the work it reviews.
- Its findings stream to the author as each lands, never batched behind the slowest.
- The next unit may start under an open review at the gate-only tier.
- It may not when the reviewed unit feeds an irreversible one.
- Work built on a unit the review then refutes is repaid at full price.

## A finding that recurs becomes a gate

- A probe discovers a defect *class*. A gate catches that class's instances, free.
- A class found twice has earned a linter. Write it, and no probe looks again.
- Any rule with a mechanical shape is a script, never a reviewer.
- Report the class beside its new gate. A fix alone leaves the class alive.
- A probe that keeps re-finding what a grep would catch is the review paying rent.
- A gate retrofitted to a tree that violates it scans the **diff**, never the tree.
  - Tree-wide it is red on arrival, and a red gate nobody can fix gets switched off.
  - Diff-scoped it cannot make the tree worse, and every change leaves it cleaner.
- Measure a candidate gate's hits on real history before landing it. Noise is what
  kills a gate, not absence.

## Mechanise what is mechanical

- Split each probe into the reasoning and the loop that reasoning drives.
- A mutation probe reasons about which mutations matter. A script then runs them.
- Edit, run the targeted tests, restore: a shell loop, not model work.
- A test nobody has watched fail is not a test.
- Its author proves it red before green, holding the file already. A probe proving
  it later costs a whole stage.
- **A differential check proves its own baseline first.**
  - A mutation run whose suite is red for its own reasons marks every mutant caught.
  - It then reports perfect coverage over tests that never ran.
  - The same holds for any check that reads a failure as evidence.

## Anti-patterns

| Anti-pattern | What it costs | Instead |
| --- | --- | --- |
| One depth for every unit | Irreversible-tier price on free-to-redo work | Tier per unit |
| A judge that verifies from scratch | A second full review, bought twice | The lead adjudicates |
| The lead re-running a green gate | The implementer's run, paid again | Read the exit code |
| An uncapped mutation probe | It alone sets its stage's wall clock | Rank, cap, report the cap |
| A fresh agent to repair a review's findings | A cold read of files the author still holds | Resume the author |
| Depth inherited from the fan-out default | `ultracode` deepens a tier, never raises it | Tier first, then fan out |
