# Lead

A session with background agents, a workflow or lanes is a lead. This file serves a single-plan run, a [programme](programme.md) and any other lead. The status file is the plan of a single-plan run, or `docs/plans/programme.md`.

## Upkeep

- Before the first dispatch, arm two fixed-interval scheduled jobs. A self-paced loop is not restored on resume.
- Check-in, every 15 minutes: read agents' last tool calls with `~/.claude/check-agents.sh <tasks-dir> <id>=<label> ...`. Also read workflow runs, ListAgents, `agent-bus.sh peers`, `free -m`, detached units and the base log. Act only on what changes an agent's next step.
- Recovery, hourly off the full hour: assume the last turn died. Rebuild state from the scratchpad, verify it, resume dead agents from their last commit, re-arm missing jobs.
- Both job prompts name the scratchpad and the status file by path, so a fire needs no context.
- A job fires only while the session is idle and cannot answer a permission prompt. Recurring jobs expire; recovery re-creates one near expiry.
- The scratchpad holds what git does not: agent ids per lane, tasks directory, job ids, unit names, open owner items. Its first line is the resume action.
- At each check-in, hold every scratchpad row against its source and rewrite the row that lies.

## Failures

Record the harness message verbatim in the handoff. Match it by kind, not by wording.

- Session or weekly usage limit: commit the handoff and name the reset time. It spans all models, so no model switch helps.
- Model-specific limit: it stops that model's workers. Commit the handoff and name the reset time; a worker never changes model.
- Subagent ended by an API error: its `agent()` returned `null`, and its branch keeps its commits. Re-dispatch from `git log <branch>`, never from scratch.
- Throttling that outlasted the retries: stop and hand off.
- Server error mid-response: output may be partial. Rerun the phase from its last commit.

## Dispatch and review

- Cap writers at 4, each with its own checkout, install and fold. Read-only scouts and reviewers run at the runtime's cap.
- Set a tier per phase before dispatch. Redoable work gets the gate plus one batched review. Paid or slow reruns get one probe first.
- Irreversible work follows the [global irreversible-work rule](../../../claude/global.md#models-and-subagents).
- The gate runs once where the change is, and again only after a fold, rebase or unseen edit. Gate agents run at low effort.
- Review a finished phase or lane once, over its whole diff. Auth, input handling, shell, SQL or dependency manifests add `/security-review`.
- The phase reviewer gets the plan path. It reports criteria missing, partial or built wrong, and unrequested behaviour, apart from code-quality findings.
- A defect goes back to the owning agent via SendMessage, with one re-review per fix round. Carry its class into that agent's next prompt.

## Landing

One protocol for a run branch and a lane alike.

1. Before every rebase and landing, run `agent-bus.sh radar` as [parallel-sessions](../parallel-sessions/SKILL.md) says. Before landing, also `claim` the base branch. The later branch rebases.
2. Pin the base, dry-run with `git merge-tree`, and rebase the branch onto the pin.
3. Re-gate. A rebase that brings code needs the full gate. Docs only need the lints and the suites naming the changed directory.
4. Apply the review's confirmed findings.
5. From the main checkout, `merge --ff-only` into the base, push, then SendMessage `landed` to each live peer.
6. A refused fast-forward means the base moved: re-pin, rebase, retry once, then stop. A rejected push means fetch, land again, retry once.
7. Remove the worktree with plain `worktree remove` and delete the branch with `-d`. Refused cleanup goes to the owner as a `! <command>` line in the handoff.

## Git hazards

[claude/settings.json](../../../claude/settings.json) denies only the plain spelling of these. `git -C`, reordered flags and other spellings pass, so use the alternative in every spelling:

| Denied | Use instead |
| --- | --- |
| `gc --prune=now` | plain `gc` |
| `update-ref refs/heads/<b>` | rebase and `merge --ff-only` |
| `rebase --update-refs` | land one branch at a time |
| `stash` | commit |
| `checkout -- .`, `restore .`, `clean -fd`, `reset --hard` | commit, then `git revert` |
| `branch -D` | `branch -d`; note the sha first |
| Force-push, `--no-verify` | nothing; `git-guard.sh` blocks them too |

- `worktree remove --force` discards staged work. Use the plain form and read its refusal.
- Never clear another session's worktree or `index.lock`; staleness cannot be proven. Report and stop.
- `git reflog show <branch>` is the undo ledger.
