# PRD: Handbook Agent Layer

Third of three PRDs from the 2026-09-29 multi-expert review. This one: the Claude Code config the handbook installs.
Layout: [prd-handbook-structure.md](prd-handbook-structure.md). Content: [prd-handbook-journeys.md](prd-handbook-journeys.md).

## Problem Statement

My global allowlist lets Claude run commands I have ruled out without asking. `gh api` can post and delete on GitHub. `find` can delete files, and `docker compose down` can remove the volume that holds a database.

About a third of my global instructions describe orchestration. They load into every session, although only a session that dispatches agents needs them. The same mechanics are also written out in two skills that borrow sections from each other.

Three session skills restate the same memory rule in their own words. The unattended-agents guide points to skill sections that do not exist.

## Solution

The allowlist approves only read-only forms, so every outbound or destructive command reaches me first. Allow entries follow the stacks I actually use.

Orchestration mechanics live in one shared reference that the orchestration skills load on demand. The global instructions keep a short pointer.

Each rule is stated once and linked from everywhere else. The unattended-agents guide becomes a human setup runbook whose links resolve.

## User Stories

1. As the owner, I want outbound and destructive commands to always prompt, so that nothing irreversible runs without my read.
2. As the owner, I want Node and Python read-only tools allowed, so that routine checks do not prompt.
3. As a session that dispatches no agents, I want lean global instructions, so that my context stays small.
4. As a lead session, I want one orchestration reference, so that two skills cannot disagree about upkeep, failures or landing.
5. As the maintainer, I want the memory rule stated once, so that a change to it lands in one file.
6. As the reader setting up unattended runs, I want a runbook whose links resolve, so that I skip skill internals.

## Implementation Decisions

### Allowlist

- `gh api` is allowed for GET only. `find` is allowed without `-delete` and `-exec`.
- `docker compose down` is allowed without `-v` or `--volumes`. `docker compose exec` leaves the allowlist.
- Node and Python read-only tools gain allow entries. PHP and Java entries stay, because live repos use both.
- The `agent-bus.sh` allow entry names its installed path.

### Global instructions

`claude/CLAUDE.md` keeps the model choice per task, the self-contained-prompt rule and a pointer to the orchestration reference. The lead, verification-budget, review-workflow and limit bullets move to that reference. The failure threshold matches the one in implement-plan.

### Orchestration reference

A `lead.md` file inside the implement-plan skill holds lead upkeep, failures, dispatch, the verification budget and landing. implement-plan and programme both link it. programme keeps only waves, the programme file and lane briefs.

### Session skills

prog, prune and reflect stay separate, because `/prog` and `/prune` are commands I type. prune and reflect link the memory rule in `claude/CLAUDE.md` instead of restating it.

### Unattended-agents guide

The guide becomes a human runbook: setup steps, then Verify. Agent procedure moves to skill links that resolve by anchor. The watchdog and failure-string references either point to real content or go.

### Landing

`claude/CLAUDE.md` and `claude/settings.json` are symlinked live into every session. This PRD lands after the other two, outside any running programme.

## Testing Decisions

- `jq -r '.permissions.allow[]' claude/settings.json` lists no write form of `gh api`, `find`, `compose down` or `compose exec`.
- A probe session asks for `docker compose down -v` and gets a permission prompt.
- `make check` passes, including every skill anchor link.
- Prior art: the skills stage of `check-repo.sh`.

## Out of Scope

- Merging prog and prune into one skill.
- Making programme a mode of implement-plan.
- Rewriting skills for human readers. They are model-facing by design.
- Moving skill folders: [prd-handbook-structure.md](prd-handbook-structure.md).
