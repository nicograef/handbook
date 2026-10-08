# Lead mechanics

This file serves a single-plan run and a [programme](programme.md) alike. The run's status file is the plan file of a single-plan run, or `docs/plans/programme.md` of a programme. Git command sequences live in [git.md](git.md).

## Lead upkeep

Arm both jobs before the first dispatch, as fixed-interval scheduled jobs. A self-paced loop is not restored when the session resumes.

| Job | Interval | Each fire |
| --- | --- | --- |
| Check-in | 15 minutes | Read the list below. Act on what changes an agent's next step, otherwise nothing. Bring the scratchpad up to date |
| Recovery | hourly, off the full hour | Assume the last turn died. Rebuild state from the scratchpad and verify it. Resume or re-dispatch each dead agent from its last commit. Re-arm a missing job |

The check-in reads:

- the agents' last tool calls, through `~/.claude/check-agents.sh <tasks-dir> <id>=<label> ...`;
- the workflow runs;
- ListAgents for busy or idle agents and sessions, and `agent-bus.sh peers` for this repo's peers;
- `free -m` and the detached units;
- the base branch's log.

Keeping state:

- Both job prompts name the scratchpad and the status file by path, so a fire needs no context.
- The scratchpad holds what git does not. Its first line is the resume action. A limit leaves no last turn, so the scratchpad is the handoff.
- Its rows: agent id per lane, the tasks directory, job ids, unit names, open owner items, the next step.
- Verify before trusting. At every check-in hold each row against its source: `git worktree list`, branch tips, the scheduled jobs, the detached units, the live agents. Rewrite the row that lies.
- Memory changes when state changes: a landed group or a ruling. Check that every path and flag it names still exists.
- Recurring jobs expire; the recovery fire re-creates a job close to its expiry.
- A job fires only while the session is idle and cannot answer a permission prompt. A quiet fire ends in one line.

## Failures

Record the harness's message verbatim in the handoff; match it by kind, not by exact wording.

| Kind | Response |
| --- | --- |
| Session or weekly usage limit | Commit the handoff, name the reset time. These limits span all models, so no model switch helps. The reset or the owner's account switch continues the run |
| Model-specific usage limit | It stops that model's workers, and the lead if it runs on it. Commit the handoff, name the reset time. A worker never changes model |
| Subagent terminated by an API error | Its `agent()` returned `null`: the work did not happen, its branch keeps its commits. Re-dispatch from `git log <branch>`, never from scratch |
| Capacity throttling that outlasted the retries | Stop, hand off |
| Server error mid-response | Not retried, output may be partial; rerun the phase from its last commit |

## Dispatch

- Cap writers at 4, one checkout, install and fold each. Read-only scouts and reviewers run at the runtime's cap.
- While one writer works, a read-only scout may prepare the next phase.
- A defect a review finds goes back to the owning agent via SendMessage. Re-review after the fix, one review per fix round.
- Carry the defect classes into the next prompt of that agent or phase.

## Verification budget

Budget verification by blast radius. Set a tier per phase or lane before dispatch.

| Tier | For | Gets |
| --- | --- | --- |
| Gate | redoable work | the gate plus one batched review |
| Probe | work whose rerun is paid or slow | one probe before the full run |
| Read | irreversible work: spend, overwrite, publish, production migration | probes plus the owner's read; spend skips the read where the project's AGENTS.md approves it |

- The gate runs once, where the change is, and again only after a fold, a rebase or an unseen edit.
- The rules for irreversible work, reviews and model switches bind every session: [global CLAUDE.md](../../../claude/CLAUDE.md#models-and-subagents).
- Review a finished phase or lane once, over its whole diff, on `opus`.
- A diff touching auth, input handling, shell, SQL or dependency manifests adds a `/security-review` pass.
- Review workflows: finders on `opus`, one per lens, few.
- Verifying a finding is a fully specified check (claim, evidence, command) and runs on `sonnet`.
- One verifier per critical or major finding. Minor and cleanup findings go unverified to the fixer.
- The fixer holds each finding against the code before applying it. It runs on `opus`, the gate on `sonnet` at low effort.
- Verify agents never exceed three times the finders. Beyond that, verify by severity and batch the rest ten per agent.
- More votes per finding only on the owner's instruction for that run.

## Landing

One protocol for a run branch and a lane alike. Commands: [git.md](git.md#land-on-the-base-branch).

1. Peers commit to the base mid-landing. Follow [parallel-sessions](../parallel-sessions/SKILL.md) steps 3 and 9 before every rebase and landing. A conflict with a peer is settled by landing order, the later branch rebasing.
2. Pin the base and rebase the branch onto it. A rebase that brings code means a full re-gate. Docs only means the lints plus the suites naming the changed directory.
3. The gate runs on the rebased branch. Green means a complete run.
4. Apply the confirmed findings of the tier's review, verified as [Verification budget](#verification-budget) says.
5. Fast-forward the base, push it, and SendMessage `landed` to each live peer `agent-bus.sh peers` lists. The base tip then equals the gated tip, so no second gate runs. A fast-forward refused because the base moved means one more rebase.
6. Remove the branch's worktree and delete the branch with `-d`. Cleanup that a permission rule or the auto-mode classifier refuses goes to the owner as a `! <command>` line in the handoff.
