# Plan: SOTA adoptions for the agent setup

> Source PRD: n/a. Source: the 2026-10-05 comparison of the handbook against the state of the art.

## Goal

Close the verified security and drift gaps, and move hand-built messaging to native features.
Keep the parts that lead the field: plan-run-guard, radar and announce.

## Architectural decisions

- **Git guard**: one script, `~/.claude/git-guard.sh`, linked from `scripts/`, is the only PreToolUse Bash hook.
- **Secret scan**: the git guard runs gitleaks on every agent `git commit`. Absent gitleaks prints a warning and allows.
- **gitleaks source**: the Ubuntu apt package (8.16), so unattended-upgrades keeps it current. Its staged-scan command is `gitleaks protect --staged`.
- **Messaging**: native SendMessage, ListAgents and `notify_when_idle`. `agent-bus.sh` keeps register, peers, announce, radar and sweep.
- **Credential reads**: `permissions.deny` Read rules. No Claude Code sandbox.
- **Branch protection**: a GitHub ruleset blocks non-fast-forward and deletion on the default branch. No required checks, because sessions push to main.
- **Evals**: `claude plugin eval` over a temporary plugin of symlinked skills, run by hand only.

## Inventory

- `claude/settings.json — hooks.PreToolUse` — inline force-push guard; bypassed by `bash -c` and `/usr/bin/git`
- `claude/settings.json — hooks.PermissionDenied` — reads `.denial_reason`; the payload field is `.reason`
- `scripts/agent-bus.sh — cmd_send(), cmd_inbox(), cmd_sent(), hook_stop(), hook_user_prompt_submit()` — the messaging half
- `scripts/install-dotfiles.sh — LINKS` — sets `rebase.autoStash`, which contradicts the stash ban
- `.claude/agents/web-researcher.md` — grants Bash next to untrusted web input
- `scripts/check-repo.sh — INDEX_EXCLUDE` — a new top-level `.github/` must be listed
- `~/.claude/rules/machine.md` — machine-local, outside the repo; loads in every session

## Resolved decisions

- SSH key: one key with a passphrase; GNOME keyring unlocks it at login. The user runs `ssh-keygen -p`.
- Sandbox: skipped. Deny rules, the Bash-free researcher and the git guard carry the load.
- Ruleset: on `nicograef/handbook` now, plus a step in `guides/new-project.md`. Applying it is approved (2026-10-05).
- Extras in scope: the plan critic and the status-line reset time. `/doctor prompt-audit` is out.
- `Bash(pnpm run:*)` and `Bash(uv run:*)` stay for non-auto modes. No narrow `pnpm run`/`uv run` rules are added.
- No agent-review CI job and no `templates/REVIEW.md`: no repo has PRs to review yet.
- Evals cover all three skills: testing, decide and plan.
- Env deny patterns: `.env`, `.env.local`, `.env.*.local`. `.env.example` stays readable.

## Open questions / Risks

- Read deny rules do not stop `cat ~/.ssh/id_ed25519` through Bash. Only the auto-mode classifier stands there.
- Every `claude plugin eval` run counts against the Max plan usage.
- `make check` has never run on a GitHub runner. Phase 5's first run may surface missing tools.
- Native cross-session messaging lists every session on the machine. Peer discovery stays repo-scoped through the registry.

## Phase 1: Git guard and secret scan

**Depends on**: none

### Context

- `claude/settings.json — hooks.PreToolUse` — the current rules to port unchanged
- `scripts/test-plan-run-guard.sh` — fixture-test style to follow
- `scripts/install-dotfiles.sh — LINKS` — link table and git defaults
- `guides/dev-machine.md — Set up` — host package installs

### What to build

`scripts/git-guard.sh` reads the hook JSON on stdin and blocks with exit 2. It blocks pushes with force, `+refspec`, `--mirror` or `--no-verify`. It blocks commits with `-n` or `--no-verify`. It unwraps `sh/bash/zsh -c` payloads and `eval` arguments before quote stripping. It matches `git` behind a path, `env`, `command` or `-C`/`-c` options.

On a commit it runs gitleaks against the target repo (`-C <dir>` or the payload `cwd`). `-a`/`--all` scans the working tree, otherwise the staged diff. A finding blocks with the gitleaks summary on stderr.

`scripts/test-git-guard.sh` holds match and not-match fixtures, with gitleaks stubbed on `PATH`. Add a `test-git-guard` Makefile target. Link the script into `~/.claude` and drop `rebase.autoStash` from the git defaults. Add gitleaks to `guides/dev-machine.md` and install it here. Index both scripts in `README.md`.

### Acceptance criteria

- [x] `make test-git-guard` passes; fixtures cover `bash -c 'git push --force'`, `sh -c "git push -f"`, `eval git push -f`, `/usr/bin/git push -f`, `git -C x push +main`, `git commit -n`, a quoted `-f` inside a commit message (allowed) and a gitleaks finding (blocked)
- [x] `scripts/install-dotfiles.sh --check | grep git-guard.sh` prints the link
- [x] `grep -c autoStash scripts/install-dotfiles.sh` prints 0 and `git config --global rebase.autoStash` prints nothing
- [x] `dpkg-query -W -f '${Version}' gitleaks` prints 8.16 or later; the Ubuntu build leaves `gitleaks version` empty
- [x] `make check` passes

## Phase 2: Agent bus on native messaging

**Depends on**: none

### Context

- `scripts/agent-bus.sh — cmd_send(), cmd_inbox(), cmd_sent(), hook_stop(), hook_user_prompt_submit(), hook_session_start()`
- `scripts/test-agent-bus.sh` — send, inbox and wake-budget cases
- `.claude/skills/parallel-sessions/SKILL.md` — message steps 4 and 5
- `.claude/skills/implement-plan/lead.md` — check-in list, landing step 5, verification budget
- `.claude/skills/programme/SKILL.md` — "the bus told"
- `claude/CLAUDE.md` — the peers line

### What to build

Delete `send`, `inbox`, `sent`, the outbox, acks, wake budget and the `user-prompt-submit` and `stop` hook events. `hook session-start` keeps registering and summarising peers, with no message delivery. Keep `peers`, `announce`, `radar` and `sweep`, and their fixture cases.

Rewrite the parallel-sessions skill to message peers through SendMessage, found with ListAgents. Waits use `notify_when_idle`. Add both tools to its `allowed-tools`. Point lead.md, programme and `claude/CLAUDE.md` at native messaging.

In lead.md's verification budget, a diff touching auth, input handling, shell, SQL or dependency manifests adds a `/security-review` pass.

### Acceptance criteria

- [x] `make test-agent-bus` passes with the messaging cases removed
- [x] `grep -rnE 'agent-bus\.sh (send|inbox|sent)|bus inbox|wake budget' --include='*.md' --include='*.sh' .` prints nothing
- [x] `scripts/agent-bus.sh send x y` exits non-zero with the usage text
- [x] `grep -c security-review .claude/skills/implement-plan/lead.md` prints at least 1
- [x] `make check` passes

## Phase 3: Settings hardening

**Depends on**: 1

### Context

- `claude/settings.json — permissions, hooks, enabledPlugins, autoMode.environment`
- `/etc/claude-code/managed-settings.d/10-gyva.json` — company facts that stay out of the public file
- `guides/unattended-agents.md` — reads the denials log

### What to build

Replace the inline PreToolUse command with `~/.claude/git-guard.sh`. The PermissionDenied hook logs `reason:.reason` and drops `verdict`. Remove the bus `UserPromptSubmit` hook and the bus entry of the `Stop` hook; plan-run-guard stays.

Add deny rules: `Read(~/.ssh/id_*)`, `Read(~/.claude/.credentials.json)`, `Read(~/.config/gh/hosts.yml)`, `Read(**/.env)`, `Read(**/.env.local)` and `Read(**/.env.*.local)`. Drop the `code-review`, `code-simplifier` and `github` plugins.

Replace each "not yet provided" clause in `autoMode.environment` with a pointer to the machine's managed settings. Fix any guide statement these changes make false.

### Acceptance criteria

- [ ] `jq -r '.hooks.PreToolUse[0].hooks[0].command' claude/settings.json` names `git-guard.sh`
- [ ] A Bash call `bash -c 'git push --force'` in a fresh session is blocked by the hook
- [ ] A new auto-mode denial lands in `~/.claude/denials.log` with a non-null `reason`
- [ ] A Read of `~/.ssh/id_ed25519` in a fresh session is denied
- [ ] `grep -c 'not yet provided' claude/settings.json` prints 0
- [ ] `make check` passes

## Phase 4: Small edits

**Depends on**: none

### Context

- `.claude/agents/web-researcher.md — tools`
- `claude/statusline.sh` — the 5h and 7d segment
- `AGENTS.md — Layout`
- `.claude/skills/plan/SKILL.md — Workflow`

### What to build

Remove `Bash` from web-researcher's tools. The status line shows the 5h window's reset as local `HH:MM` beside its percentage, from `rate_limits.five_hour.resets_at`.

Shrink AGENTS.md's Layout section to the rules an agent cannot derive from the tree. Keep one-kind-per-folder, the install payload and the frozen paths.

The plan skill gains a step after the placeholder review. A fresh-context `opus` subagent critiques the plan file for unverifiable criteria, wrong `Depends on` lines and choke files shared across parallel phases. Its findings route through the decide skill.

### Acceptance criteria

- [x] `grep -c 'Bash' .claude/agents/web-researcher.md` prints 0
- [x] `echo '{"rate_limits":{"five_hour":{"used_percentage":40,"resets_at":1791200000}}}' | bash claude/statusline.sh` prints the reset time
- [x] `grep -cE 'fresh-context|critic' .claude/skills/plan/SKILL.md` prints at least 1
- [x] `make check` passes

## Phase 5: CI and ruleset

**Depends on**: 1

### Context

- `templates/ci.yml` — SHA-pinned actions, least-privilege token, stack markers
- `guides/new-project.md — Create the repository`
- `scripts/check-repo.sh — INDEX_EXCLUDE`

### What to build

`.github/workflows/check.yml` runs `make check` and the three fixture-test targets on every push, with SHA-pinned actions. Add `.github` to `INDEX_EXCLUDE` with its reason.

`templates/ci.yml` gains a gitleaks job over the full history, run on push and on the weekly schedule.

Apply the ruleset to `nicograef/handbook` through `gh api`. `guides/new-project.md` gains that ruleset step.

### Acceptance criteria

- [ ] `gh run list --workflow check.yml --limit 1 --json conclusion -q '.[0].conclusion'` prints `success`
- [x] `gh api repos/nicograef/handbook/rules/branches/main -q '[.[].type] | sort | join(",")'` prints `deletion,non_fast_forward`
- [ ] `actionlint templates/ci.yml .github/workflows/check.yml` passes
- [ ] `make check` passes

## Phase 6: Skill evals

**Depends on**: 1

### Context

- `.claude/skills/testing/SKILL.md`, `.claude/skills/decide/SKILL.md`, `.claude/skills/plan/SKILL.md` — the skills under test
- https://code.claude.com/docs/en/plugin-evals — case format and graders

### What to build

`.claude/evals/run.sh` assembles a temporary plugin with symlinks to the three skills. It runs `claude plugin eval` on it with `--max-cost-usd`. Cases live in `.claude/evals/`, three per skill, with judge-free graders where one fits. `testing` writes a failing test first. `decide` calls AskUserQuestion. `plan` writes a file matching the plan template. A `make eval` target runs it; `make check` does not.

### Acceptance criteria

- [ ] `make eval` completes and reports a pass rate per skill against the no-plugin baseline
- [ ] `grep -c eval Makefile` prints at least 2 and `make check` does not call it
- [ ] `make check` passes

## Phase 7: Machine-local hardening

**Depends on**: 1

Nothing here is committed: these files live outside the repo.

### Context

- `~/.claude/rules/machine.md` — Hardware, Laptop specifics, Toolchain state
- `~/.ssh/id_ed25519` — the single auth and signing key

### What to build

Move the hardware table, battery, PAM, Wi-Fi and firmware lines into `~/.claude/machine-reference.md`. Leave one pointer line in machine.md. Record the passphrase and gitleaks in machine.md's toolchain and SSH lines.

### Acceptance criteria

- [x] `ssh-keygen -y -P '' -f ~/.ssh/id_ed25519` fails
- [x] `ssh -T git@github.com` authenticates and `git commit -S --allow-empty -m probe` in a scratch repo signs without a prompt
- [x] `grep -cE 'SSID|Battery|fprintd' ~/.claude/rules/machine.md` prints 0
