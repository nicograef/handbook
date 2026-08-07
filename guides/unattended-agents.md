# Unattended Agent Runs

Run a long session without it stopping for a prompt nobody answers. Applies to an
[implement-plan](../.claude/skills/implement-plan/SKILL.md) run, a distill, or a migration.

Source: [Permission modes](https://code.claude.com/docs/en/permission-modes),
[Configure auto mode](https://code.claude.com/docs/en/auto-mode-config),
[Hooks](https://code.claude.com/docs/en/hooks).

## Prerequisites

- Claude Code v2.1.212 or later (`claude --version`).
- `~/.claude/settings.json` — this repo's [claude/settings.json](../claude/settings.json).
- Docker, for the container posture.

## What does not work

Prompt text cannot grant permission. The gate never reads it.

> Permission rules are enforced by Claude Code, not by the model. Instructions in
> your prompt or `CLAUDE.md` shape what Claude tries to do, but they don't change
> what Claude Code allows.

| Habit | What it actually does |
| --- | --- |
| "you have no constraints and no gates" | Nothing to any gate. Auto mode's classifier reads user messages and treats stated intent to run without oversight as a block signal — it raises the stall rate. |
| "set a timer to wake you when stuck" | Nothing answers a prompt. Scheduled tasks and `/loop` fire only while the session is idle. |
| "you can spend money on the api" | Nothing. No gate reads it. |
| A supervisor session babysitting workers | Cannot approve a worker's prompt either. It only observes. |

## What actually stalls a run

Measured over ten sessions on this machine: 67 idle stretches past ten minutes,
every one after a plain-text turn. None followed a question or a denial.

| Cause | Share |
| --- | --- |
| The turn ended on a status report — "phase 5 is running", "phase 3 is next" | 67 of 67 idle gaps |
| A question whose answer the agent had already recommended | 13 of 17 questions |
| A permission denial | 12 across ten sessions |

- A session that ended its turn cannot be restarted by a peer, a cron, or a
  supervisor session. Only a keystroke from you restarts it.
- So the fix is not waking a stopped session. The fix is not stopping.
- Never end a turn on "next I will X". End on X done, or on a forced stop.
- A progress report is not a turn ending. Report and keep working.

## Step 1 — pick the posture

| Posture | Mode | Stops on | Use for |
| --- | --- | --- | --- |
| Attended | `auto` | Classifier pause after 3 consecutive or 20 total blocks | Normal interactive work |
| Unattended | `bypassPermissions` in a container | `deny` rules, `ask` rules, `rm -rf /` circuit breaker | Whole-plan runs, migrations |
| Pipeline | `dontAsk` | Nothing — it denies instead of asking | CI, scripted runs |

- `auto`'s pause thresholds are not configurable. Attended runs will stop.
- `-p` non-interactive runs **abort** on repeated blocks instead of pausing.
- `dontAsk` denies `AskUserQuestion` outright, so the run cannot ask you anything.

## Step 2 — make the denials visible

Add a `PermissionDenied` hook so a stalled run leaves evidence of what it wanted.

```json
"PermissionDenied": [
  {
    "matcher": ".*",
    "hooks": [
      {
        "type": "command",
        "command": "jq -c '{t:(now|todate),cwd,tool:.tool_name,cmd:(.tool_input.command // .tool_input.file_path // \"\"),reason:.denial_reason}' >> \"$HOME/.claude/denials.log\" 2>/dev/null; exit 0"
      }
    ]
  }
]
```

- Already present in [claude/settings.json](../claude/settings.json).
- Read it after a run: `tail -20 ~/.claude/denials.log`.
- Each line names the exact command to allowlist or the destination to add to
  `autoMode.environment`.

## Step 3 — teach the classifier your infrastructure

`autoMode.environment` is what stops the classifier guessing. It is read from
`~/.claude/settings.json` only — never from a repo's `.claude/settings.json`.

- Keep `"$defaults"` as the first entry, or you discard the built-in rules.
- Name your source-control org, repo visibility, trusted hosts and sensitive paths.
- Confirm it took effect: `claude auto-mode config`.
- Print the built-in rules to compare: `claude auto-mode defaults`.

## Step 4 — run unattended in the container

`bypassPermissions` skips the classifier entirely. Only run it where a mistake
cannot reach the host.

```bash
cd <repo>
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . claude --permission-mode bypassPermissions
```

- The [dev container](../.devcontainer/devcontainer.json) runs Claude Code as a
  non-root user; `bypassPermissions` refuses to start as root or under `sudo`.
- Accept the responsibility dialog once, interactively, before any `--bg` run.
- `deny` rules still apply in this mode. That is what makes it usable: the
  destructive git set in [claude/settings.json](../claude/settings.json) stays
  blocked even here.

## Step 5 — survive the stops you cannot prevent

| Stop | Recovery |
| --- | --- |
| Usage limit, terminal API error | Committed work survives. Resume from git — [recovery.md](../.claude/skills/implement-plan/recovery.md). |
| Capacity 429 / 529 | `CLAUDE_CODE_RETRY_WATCHDOG=1` retries indefinitely. Documented for capacity errors only. |
| Agent returned `null` | Its branch holds every criterion it committed. Re-dispatch from its last commit. |

- The durable record is the commits, never the session.
- Commit per acceptance criterion so a kill costs one criterion, not one phase.

## Verify

```bash
claude auto-mode config | jq -r '.environment[] | select(startswith("Source control"))'
```

Expected: the `Source control: GitHub, org github.com/nicograef …` entry from
[claude/settings.json](../claude/settings.json).

```bash
jq -e '.hooks.PermissionDenied and (.autoMode.environment | index("$defaults") == 0)' \
  ~/.claude/settings.json
```

Expected: `true`.
