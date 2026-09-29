# Plan: Handbook Agent Layer

> Source PRD: docs/prds/prd-handbook-agent-layer.md

## Goal

Outbound and destructive commands always prompt, and Node and Python read-only tools never do. Orchestration mechanics live in one skill reference file, `.claude/skills/implement-plan/lead.md`, that implement-plan and programme load on demand. The global `claude/CLAUDE.md` keeps a short pointer. The memory rule is stated once. `guides/unattended-agents.md` is a human runbook whose links resolve.

## Architectural decisions

- **Base**: the structure and journeys plans have landed, the structure phase 9 `install.sh` run included. `make check` resolves `#anchor` links against GitHub heading slugs. `claude/settings.json` already allows `~/.claude/check-agents.sh`, `~/.claude/plan-run-guard.sh` and the two audiobook scripts; programme step 6 already calls `~/.claude/check-agents.sh`. `.claude/rules/guides.md` carries the journeys writing rules. Every phase reads its files as those plans left them.
- **Choke files**: `claude/settings.json` holds the structure plan's allowlist additions; `claude/CLAUDE.md`, `guides/unattended-agents.md` and the prune and reflect skills are as on main, since neither earlier plan edits them. This plan leaves `README.md`, `AGENTS.md`, `scripts/check-repo.sh`, `.claude/rules/` and `.claude/settings.json` unchanged; `lead.md` is a skill reference file, so neither index lists it.
- **Permission shape**: `allow` approves without a prompt; `ask` always prompts, in auto mode too, and beats a matching `allow` rule. Bash rules cannot express "without flag X" in an allow rule, so each write form is an `ask` rule laid over the allowed prefix.
  Source: code.claude.com/docs/en/permissions (§ Wildcard patterns, § Compound commands, "Rules are evaluated in order: deny, then ask, then allow") and /docs/en/auto-mode-config (§ Add a human checkpoint), read 2026-09-29.
- **Ask rules** (new `permissions.ask` array, exactly these eleven, in this order):
  `Bash(gh api *-X*)`, `Bash(gh api *--method*)`, `Bash(gh api *-f*)`, `Bash(gh api *-F*)`, `Bash(gh api *--input*)`,
  `Bash(find *-delete*)`, `Bash(find *-exec*)`, `Bash(find *-ok*)`, `Bash(find *-fprint*)`, `Bash(find *-fls*)`,
  `Bash(docker compose *down *-v*)`.
  A `*` matches any text, spaces included, so `*-f*` also covers `--field` and `--raw-field`, `*-exec*` covers `-execdir`, `*-ok*` covers `-okdir`, `*-fprint*` covers `-fprint0` and `-fprintf`, and `*-v*` covers `--volumes`.
- **Allow changes**: remove `Bash(docker compose exec:*)`, `Bash(java --version)`, `Bash(mvn:*)`, `Bash(./mvnw:*)`, `Bash(scripts/agent-bus.sh:*)`, `Bash(./scripts/agent-bus.sh:*)`. The `autoMode.environment` registry line drops Maven Central, the last Java entry. Keep `Bash(gh api:*)`, `Bash(find:*)` and `Bash(docker compose down:*)` under the ask rules. PHP and Go entries stay. Add exactly these fourteen:
  `Bash(pnpm ls:*)`, `Bash(pnpm list:*)`, `Bash(pnpm outdated:*)`, `Bash(pnpm why:*)`, `Bash(pnpm audit)`, `Bash(pnpm audit --audit-level:*)`, `Bash(pnpm exec tsc:*)`,
  `Bash(npm ls:*)`, `Bash(npm view:*)`, `Bash(npm outdated:*)`,
  `Bash(python3 --version)`, `Bash(uv tree:*)`, `Bash(uv pip list:*)`, `Bash(uv python list:*)`.
- **Orchestration reference file**: `.claude/skills/implement-plan/lead.md` with exactly these `##` headings, whose slugs other files link: `Lead upkeep` (`#lead-upkeep`), `Failures` (`#failures`), `Dispatch` (`#dispatch`), `Verification budget` (`#verification-budget`), `Landing` (`#landing`). Git command sequences stay in `implement-plan/git.md`; `lead.md` links them.
- **Skill split**: implement-plan keeps Gotchas, Workflow, Stops, Run state block and, under a new `## Workers` heading, the run-specific dispatch items (commit trailer, worker prompt contents, 30-minute return). The writer cap moves to `lead.md#dispatch`. The check-in read list of programme Workflow step 6 moves into `lead.md#lead-upkeep`; step 6 links it. programme keeps waves, the programme file, lane briefs and the programme-specific notes (stores, migration numbers, spend, artefact sharding). Neither skill links a section of the other.
- **Global instructions**: `claude/CLAUDE.md` keeps its four `##` headings. § Models and subagents keeps the model choice per task (minus the review sentence), the self-contained-prompt rule, the web-researcher rule, the memory rule and one pointer: `[lead.md](../.claude/skills/implement-plan/lead.md)`. That relative link resolves both in the repo and from `~/.claude/CLAUDE.md`.
- **Failure threshold**: the PRD's "matches the one in implement-plan" reads as CLAUDE.md adopting implement-plan's two. The debugging bullet becomes "After two failed fixes, question the design instead of trying a third patch." implement-plan step 8 stays as is.
- **Memory rule**: one bullet in `claude/CLAUDE.md` § Models and subagents, carrying the residue clause: an event is rewritten as its residue, in present tense. prune and reflect link `claude/CLAUDE.md#models-and-subagents`, with link text naming it the memory rule of the global CLAUDE.md.
- **Retry watchdog**: `CLAUDE_CODE_RETRY_WATCHDOG=1` is a documented env var (code.claude.com/docs/en/env-vars, read 2026-09-29). The guide sets it on the unattended run's command line, not in `claude/settings.json`, so attended sessions keep failing fast.
- **Landing**: no new install origin, so no phase runs `install.sh`. Landing on `main` makes `claude/settings.json`, `claude/CLAUDE.md` and the skills live in every session at once. The run starts only after the structure and journeys runs have landed, outside any programme. After landing, the owner runs the PRD's interactive probe: a fresh session asked for `docker compose -p agent-layer-probe down -v` shows a permission prompt. The implement-plan report lists it as an owed item.

## Inventory

- `claude/settings.json — permissions.allow` — `gh api:*`, `find:*`, `docker compose down:*`, `docker compose exec:*`; Java entries; three agent-bus forms; no Node or Python query entries
- `claude/settings.json — autoMode.environment` — the registry line names Maven Central
- `claude/settings.json — permissions` — no `ask` array; `defaultMode` is `auto`, so a command outside `allow` reaches the classifier, not the owner
- `claude/CLAUDE.md — § Working rules` — debugging bullet with the three-fix threshold
- `claude/CLAUDE.md — § Models and subagents` — review-workflow, lead, lead-scratchpad, limit and verification-budget bullets; memory bullet; 330 words
- `.claude/skills/implement-plan/SKILL.md — § Failures, § Dispatch, Workflow step 4` — failure kinds, dispatch rules, review tiers; Dispatch links programme § Lead upkeep
- `.claude/skills/implement-plan/git.md — § Land on the base branch, § Pickup` — landing and pickup command sequences
- `.claude/skills/programme/SKILL.md — § Gotchas, § Lead upkeep, Workflow steps 5-8, § Landing a group` — links implement-plan § Failures; restates the ff-only landing
- `.claude/skills/programme/lane-brief.md` — lane brief layout; unaffected
- `.claude/skills/prune/SKILL.md — § 3 Review, Memory row` — restates the residue rule
- `.claude/skills/reflect/SKILL.md — Workflow step 4` — restates the residue rule
- `.claude/skills/prog/SKILL.md` — unchanged; `/prog` stays its own command
- `guides/unattended-agents.md` — numbered step headings; claims failure strings and the watchdog live in implement-plan; links programme § Lead upkeep
- `scripts/check-repo.sh — check_links()` — resolves anchors once the structure plan lands; no change here

## Resolved decisions

- The PRD's test "`jq` lists no write form in allow" becomes "every write form matches an ask rule, and `compose exec` has no allow entry". An allow rule cannot exclude a flag; the ask rule does, and it prompts in auto mode.
- `Bash(find:*)` stays. The docs state a `find *` rule never covers `-exec` or `-delete`, and are silent on `-ok`, `-okdir`, `-fprint*` and `-fls`. Those run commands or truncate files, so user story 1 gives them ask rules too. The ask rules make every such form prompt instead of reaching the classifier.
- `docker compose exec` gets no ask rule. The PRD only removes it from the allowlist; the classifier judges it.
- A `-X GET` or GraphQL read through `gh api` prompts too. So does a plain GET whose path contains `-f`, `-F` or `-X`, such as `repos/o/some-feature`. GET is the default without `-X`, so the cost is small. Leading-space forms (`* -f*`) would miss `gh api -f …` right after `api` and `--field`, so the broad forms stay.
- programme also keeps its programme-only gotchas: lane agents stopping at their plan's end, lane agents off the bus with migration numbers reserved by the orchestrator, the host-wide `flock` around lane gates, and artefact sharding. They are no lead mechanics, and `lead.md` also serves implement-plan leads that have none of them. The limit gotcha, the peers-mid-landing gotcha and the refused-cleanup gotcha move to `lead.md`.
- prune and reflect link the memory rule by anchor, so `make check` catches a renamed heading. From `~/.claude/skills/` the relative path resolves only through the symlink. The rule is always in context as the global CLAUDE.md, which the link text names.
- The Verify block of the guide uses commands without placeholders, so phase 4 runs them as written.
- The pointer in `claude/CLAUDE.md` is a Markdown link, so `make check` catches a moved `lead.md`.
- prog is untouched: the PRD names only prune and reflect, and prog step 3 states the current-state rule, not the memory rule.
- The guide links the official errors page for failure strings and `lead.md#failures` for the agent's response.
- Zero clarification questions: the PRD, the two earlier plans and the Claude Code docs settle every fork.
- Owner ruling 2026-09-29: `claude/CLAUDE.md` takes the two-fix threshold; implement-plan step 8 stays.
- Owner ruling 2026-09-29: the runbook keeps the `CLAUDE_CODE_RETRY_WATCHDOG=1` step.
- Owner ruling 2026-09-29: the phase 1 probe keeps all three commands.

## Open questions / Risks

- Bash rules match command text. `/usr/bin/find`, `sh -c '…'` or the standalone `docker-compose down -v` slip past the ask rules and reach the classifier. A flag before the subcommand does not: `docker compose -f x.yml down -v` matches, because `*` spans spaces. The docs call rules no security boundary; the container posture is.
- The phase 1 probe relies on `claude -p --output-format json` reporting `permission_denials`. No allow rule covers `claude -p`, so the run contract lists the probe under missing allowlist commands (implement-plan Workflow step 5) and the owner approves it there.
- The probe model may decline a command it reads as destructive. A declined command is a probe failure, not a rule failure: reword the prompt and rerun. Fewer than three denials never ticks the criterion.
- The ask rules also stop a `bypassPermissions` container run on those commands. That is the intent.

## Phase 1: Allowlist

**User stories**: 1, 2
**Depends on**: none

### Context

- `claude/settings.json — permissions.allow, permissions.ask, autoMode.environment` (the registry line only)

### What to build

`claude/settings.json` gains the `permissions.ask` array and the allow changes from the header decisions, entries in the existing order, new ones beside their stack. The registry line loses Maven Central. Nothing else in the file changes. A session then prompts for the eleven ask forms, never for the fourteen new read-only entries, and no longer auto-approves `compose exec`, Java tools or the repo-relative bus paths.

### Acceptance criteria

- [ ] `grep -ciE 'java|maven|mvn' claude/settings.json` prints 0, `jq -r '.permissions.allow[]' claude/settings.json | grep -E 'compose exec|scripts/agent-bus'` prints nothing, and `jq -r '.permissions.allow[]' claude/settings.json | grep -c 'agent-bus'` prints 1.
- [ ] `jq -c '.permissions.ask' claude/settings.json` prints `["Bash(gh api *-X*)","Bash(gh api *--method*)","Bash(gh api *-f*)","Bash(gh api *-F*)","Bash(gh api *--input*)","Bash(find *-delete*)","Bash(find *-exec*)","Bash(find *-ok*)","Bash(find *-fprint*)","Bash(find *-fls*)","Bash(docker compose *down *-v*)"]`.
- [ ] `jq -r '.permissions.allow[]' claude/settings.json | grep -cE '^Bash\((pnpm (ls|list|outdated|why|audit|exec tsc)|npm (ls|view|outdated)|python3 --version|uv (tree|pip list|python list))'` prints 14.
- [ ] Probe, harmless if a rule fails (no such project, empty directory, no such repo). From the phase's worktree, run `s="$(git rev-parse --show-toplevel)/claude/settings.json" && mkdir -p /tmp/agent-layer-probe && cd /tmp/agent-layer-probe && claude -p --output-format json --settings "$s" "Permission probe. Run these three Bash commands exactly as written, one tool call each, and report each outcome: docker compose -p agent-layer-probe down -v; find /tmp/agent-layer-probe -name none -delete; gh api -X DELETE repos/nicograef/agent-layer-probe-none" | jq -r '.permission_denials[].tool_input.command'`. It lists all three commands.
- [ ] `jq empty claude/settings.json && make check` passes.

## Phase 2: Orchestration reference file

**User stories**: 4
**Depends on**: none

### Context

- `.claude/skills/implement-plan/SKILL.md — § Failures, § Dispatch, Workflow steps 4 and 10, § Stops`
- `.claude/skills/implement-plan/git.md — § Land on the base branch` (read only)
- `.claude/skills/programme/SKILL.md — § Gotchas, § Lead upkeep, § The programme file, Workflow steps 5-8, § Landing a group`
- `claude/CLAUDE.md — § Models and subagents` (read only; the source of the moved bullets)
- `guides/unattended-agents.md — Stop table, Session or weekly limit row` (one link only; phase 4 rewrites the rest)

### What to build

A new `.claude/skills/implement-plan/lead.md` holds the five sections of the header decision. It absorbs programme § Lead upkeep, implement-plan § Failures, the generic part of both skills' dispatch and review steps, and one landing protocol that links `git.md` for commands. It also takes the content of the CLAUDE.md bullets on review workflows, leads, lead scratchpads, limits and the verification budget. Each rule appears once. `lead.md#lead-upkeep` holds the check-in read list itself, so it never refers back to a programme step. Both skills introduce `lead.md` with when to open it and link its anchors where they lose a section; text references such as "§ Dispatch" become those links. implement-plan's run-specific dispatch items sit under `## Workers`. programme's gotcha, its programme-file row "Landing a group" and implement-plan's Stops row point to `lead.md`. The guide's `programme § Lead upkeep` link becomes `../.claude/skills/implement-plan/lead.md#lead-upkeep`, with link text free of agent terms. `lead.md` follows `.claude/rules/skills.md` and the prose caps.

### Acceptance criteria

- [ ] `grep -cE '^## (Lead upkeep|Failures|Dispatch|Verification budget|Landing)$' .claude/skills/implement-plan/lead.md` prints 5.
- [ ] `grep -nE '^## (Lead upkeep|Landing a group|Failures|Dispatch)$' .claude/skills/programme/SKILL.md .claude/skills/implement-plan/SKILL.md` prints nothing, and `grep -c '^## Workers$' .claude/skills/implement-plan/SKILL.md` prints 1.
- [ ] `grep -nE '§ (Lead upkeep|Landing a group|Failures|Dispatch)' .claude/skills/*/SKILL.md guides/unattended-agents.md` prints nothing.
- [ ] `grep -c 'check-agents.sh' .claude/skills/implement-plan/lead.md` prints 1 or more, and `grep -c 'step 6' .claude/skills/implement-plan/lead.md` prints 0.
- [ ] `grep -l 'lead.md#' .claude/skills/implement-plan/SKILL.md .claude/skills/programme/SKILL.md` lists both files, and `grep -nE 'programme/SKILL.md#|implement-plan/SKILL.md#' .claude/skills/*/SKILL.md` prints nothing.
- [ ] `grep -ciE '15 minutes|blast radius|span all models|finders' .claude/skills/implement-plan/lead.md` prints 4 or more.
- [ ] `grep -c 'ff-only' .claude/skills/programme/SKILL.md` prints 0.
- [ ] `make check` passes, anchors included.

## Phase 3: Global instructions and memory rule

**User stories**: 3, 5
**Depends on**: 2

### Context

- `claude/CLAUDE.md — § Working rules, § Models and subagents`
- `.claude/skills/prune/SKILL.md — § 3 Review, Memory row`
- `.claude/skills/reflect/SKILL.md — Workflow step 4`
- `.claude/skills/implement-plan/lead.md` (read only; the pointer target)

### What to build

`claude/CLAUDE.md` § Models and subagents loses the bullets phase 2 moved, and the review sentence of the model-choice bullet. It gains one pointer bullet: a session with background agents, a workflow or lanes is a lead and follows `lead.md`. The debugging bullet takes the two-fix threshold. The memory bullet carries the residue clause. prune's Memory row and reflect's step 4 drop their own residue wording and link the memory rule by anchor, as the header's memory-rule decision words it.

### Acceptance criteria

- [ ] `grep -ciE '15-minute|hourly recovery|blast radius|span all models|finders on|Review means' claude/CLAUDE.md` prints 0.
- [ ] `grep -c '](../.claude/skills/implement-plan/lead.md)' claude/CLAUDE.md` prints 1.
- [ ] `grep -c 'two failed fixes' claude/CLAUDE.md` prints 1, and `grep -c 'three failed' claude/CLAUDE.md` prints 0.
- [ ] `sed -n '/^## Models and subagents/,$p' claude/CLAUDE.md | wc -w` prints at most 160.
- [ ] `grep -c 'residue' claude/CLAUDE.md` prints 1; `grep -c 'residue' .claude/skills/prune/SKILL.md .claude/skills/reflect/SKILL.md` prints 0 for each.
- [ ] `grep -l 'claude/CLAUDE.md#models-and-subagents' .claude/skills/prune/SKILL.md .claude/skills/reflect/SKILL.md` lists both.
- [ ] `make check` passes, anchors included.

## Phase 4: Unattended-runs runbook

**User stories**: 6
**Depends on**: 2

### Context

- `guides/unattended-agents.md`
- `.claude/rules/guides.md` (read only; runbook shape and writing rules)
- `.claude/skills/implement-plan/lead.md`, `.claude/skills/implement-plan/git.md` (read only; anchor targets)

### What to build

`guides/unattended-agents.md` becomes a runbook: Prerequisites, then task-named setup steps, then Verify, then Troubleshooting. The steps cover what the operator sets up: choose the posture and its mode, confirm the denial log, fill `autoMode.environment`, start the container run with `CLAUDE_CODE_RETRY_WATCHDOG=1`, rely on `autoContinueAtUsageLimit` in an open interactive session, and disarm `plan-run-guard.sh` per repo. Each fact cites its official Claude Code page. Recovery after a limit or an API error is one Troubleshooting table. Its rows link `lead.md#failures`, `lead.md#lead-upkeep` and `git.md#pickup` instead of restating agent procedure; link text names the task, never an agent term. Verify holds two placeholder-free commands: `claude auto-mode config | jq -e '.environment | any(startswith("Source control"))'` and `jq -e '.hooks.PermissionDenied and (.autoMode.environment | index("$defaults") == 0)' ~/.claude/settings.json`, each expecting `true`. The stall measurements and prompt-habit tables go; the turn-ending rule stays in `claude/CLAUDE.md` § Working rules.

### Acceptance criteria

- [ ] `grep -nE '^#{2,} +(Step|[0-9])' guides/unattended-agents.md` prints nothing, and `grep -cE '^## (Prerequisites|Verify|Troubleshooting)$' guides/unattended-agents.md` prints 3.
- [ ] `grep -oE '(lead|git)\.md#(failures|lead-upkeep|pickup)' guides/unattended-agents.md | sort -u | wc -l` prints 3.
- [ ] `grep -c 'CLAUDE_CODE_RETRY_WATCHDOG=1' guides/unattended-agents.md` prints 1 or more, and `grep -oE 'code\.claude\.com/docs/en/(permission-modes|auto-mode-config|hooks|env-vars|interactive-mode|errors)' guides/unattended-agents.md | sort -u | wc -l` prints 6.
- [ ] `sed -E 's/\]\([^)]*\)/]/g' guides/unattended-agents.md | grep -nwiE 'gate|lane|fold|lead'` prints nothing, and `wc -l < guides/unattended-agents.md` prints 50 to 150.
- [ ] `grep -cF 'any(startswith("Source control"))' guides/unattended-agents.md` and `grep -cF 'index("$defaults") == 0' guides/unattended-agents.md` each print 1, and both Verify commands of What to build print `true`.
- [ ] `make check` passes, anchors included.
