# PRD: Handbook Structure

First of three PRDs from the 2026-09-29 multi-expert review. This one: layout and guards.
[prd-handbook-journeys.md](prd-handbook-journeys.md) rewrites the content; [prd-handbook-agent-layer.md](prd-handbook-agent-layer.md) fixes the agent config.

## Problem Statement

I cannot tell from a folder name what kind of page I will find. `guides/` holds runbooks, a routing page and two reference pages. `templates/` holds files I copy once next to files that are symlinked live into my home directory.

The handbook has two entry points, the README and `guides/bootstrap.md`. The bootstrap page calls itself routing only. Yet it is the only place that sets up a dev machine or first deploy.

What `install.sh` puts into `~/.claude` is spread over `claude/`, `.claude/` and `scripts/`. Some installed skills call scripts that are never installed. A moved file does not fail: install prints SKIP, hooks exit quietly, and public raw URLs return 404.

## Solution

Each folder holds exactly one kind of document, and the README is the single entry. It routes by journey first, then indexes every file grouped by area.

Lookup pages live on one reference shelf. Everything `install.sh` links into `~/.claude` lives under `claude/`, and dotfiles linked into `$HOME` live under `dotfiles/`.

The live contracts become checked. `make check` fails when a raw URL, an install origin or a settings script path points nowhere. `install.sh` fails when an origin is missing.

## User Stories

1. As the reader, I want one entry page that routes by journey, so that I find the right runbook.
2. As the reader, I want one document kind per folder, so that I know what I will find.
3. As the reader, I want all lookup pages on one shelf, so that I can scan commands mid-task.
4. As the maintainer, I want the `~/.claude` payload in one folder, so that I see the installed surface at a glance.
5. As the maintainer, I want dotfiles apart from copy-once templates, so that I know which edits go live immediately.
6. As the maintainer, I want `install.sh` to fail on a missing origin, so that a move never disables a hook silently.
7. As the maintainer, I want `make check` to verify every live path contract, so that none breaks unnoticed.
8. As an agent session, I want every script a skill calls installed and allowed, so that check-ins never stall.
9. As an agent session, I want the Stop hook to release me after one report.

## Implementation Decisions

### Folder kinds

| Folder | Holds |
| --- | --- |
| `guides/` | Runbooks only: Prerequisites, numbered steps, Verify, Troubleshooting |
| `reference/` | Lookup pages: command tables, and rule lists with one line of rationale |
| `templates/` | Files a project or server copies once |
| `dotfiles/` | Files `install.sh` links into `$HOME` outside `~/.claude` |
| `scripts/` | Server scripts and repo tools |
| `claude/` | The whole `~/.claude` payload: `CLAUDE.md`, `settings.json`, `statusline.sh`, `bin/`, `agents/`, `skills/` |
| `.claude/` | Repo-local only: path-scoped rules and the Stop hook |

### Moves

- `cheatsheets/` becomes `reference/`; `guides/stack-conventions.md` joins it.
- `bootstrap.md` is dissolved. Its routing becomes the README Journeys section. Its dev-machine and first-deploy steps move to `guides/dev-machine.md` and `guides/deploy.md`.
- `.bash_aliases`, `.tmux.conf` and `init.lua` move from `templates/` to `dotfiles/`.
- `.claude/skills` and `.claude/agents` move to `claude/`. The agent scripts and their tests move to `claude/bin/`.
- The audiobook pipeline guide, `md-to-epub.sh`, `check-terms.sh` and `strip-visuals.lua` move into the audiobook skill directory.
- The dangling root `agents` symlink is deleted.
- `scripts/report-repo-status.sh` stays in `scripts/`; its link target does not depend on the folder.

### Frozen paths

`scripts/setup-server.sh` and `scripts/report-health.sh` are fetched by raw GitHub URL from servers and cloud-init. They never move. `AGENTS.md` names both.

### Guards

- `check-repo.sh` indexes `reference/`, `dotfiles/`, the top-level files of `claude/` and `claude/bin/`. The skills index keeps sole ownership of `claude/skills/**`.
- A new `contracts` stage checks three things. Every handbook raw URL resolves to a tracked file. Every install origin exists. Every script path in both settings files exists.
- Link checking resolves `#anchor` against GitHub heading slugs.
- Every tracked top-level folder is either indexed or explicitly excluded.
- `install-dotfiles.sh` exits 1 on a missing origin and fails fast without `jq`. It also links `check-agents.sh`.
- `claude/settings.json` allows `~/.claude/check-agents.sh`.
- The repo Stop hook command exits 0 when `stop_hook_active` is true; `check-repo.sh` itself stays unaware of hooks.

### Landing

`install.sh` never runs from a worktree, because it would repoint `~/.claude` into it. The phase that moves installed files lands on `main`, then runs `~/r/handbook/install.sh` at once. A phase that deletes or moves a file owns every inbound reference to it.

## Testing Decisions

- `make check` passes after every phase.
- `./install.sh` run twice prints no SKIP, and `ls -L` resolves every installed path.
- One negative probe per contract. A scratch edit that breaks a raw URL, an origin or a settings path fails `make check`.
- Prior art: the existing `check-repo.sh` stages and `scripts/test-agent-bus.sh`.

## Out of Scope

- Content rewrites and new runbooks beyond the moved steps: [prd-handbook-journeys.md](prd-handbook-journeys.md).
- Allowlist, global `CLAUDE.md` and skill overlap: [prd-handbook-agent-layer.md](prd-handbook-agent-layer.md).
- Domain folders such as `server/` or `workstation/`. They mix page shapes that need different rules.
- One merged folder for guides and reference pages.
- Moving or re-versioning the two frozen scripts.
- A generic "every mentioned path exists" check. Templates name paths inside the target project, not the handbook.
- Pruning stale symlinks in `$HOME`. Every target keeps its name, so relinking overwrites it.

## Further Notes

`~/.claude/rules/machine.md` names `templates/init.lua`. It is machine-local and gets updated by hand after the dotfiles move.
