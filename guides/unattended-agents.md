# Unattended Agent Runs

Set up Claude Code so a long session never stops on an unanswered prompt, and resumes after a limit.
Applies to an [implement-plan](../plugin/skills/implement-plan/SKILL.md) run, a distill or a migration.

## Prerequisites

- Claude Code v2.1.234 or later (`claude --version`).
- `~/.claude/settings.json` is this repo's [claude/settings.json](../claude/settings.json), which enables the `handbook` plugin.
- Docker, for the container posture.
- The Dev Containers CLI, from [devcontainers/cli](https://github.com/devcontainers/cli): `npm install -g @devcontainers/cli`.
- The repo holds `.devcontainer/devcontainer.json` from [templates/devcontainer.json](../templates/devcontainer.json).
- A claude.ai subscription login, for automatic continue at a usage limit.

## Choose the posture

The mode is what the session starts with.
Source: [Permission modes](https://code.claude.com/docs/en/permission-modes).

| Posture | Mode | Stops on | Use for |
| --- | --- | --- | --- |
| Attended | `auto` | A classifier pause after 3 consecutive or 20 total blocks | Normal interactive work |
| Unattended | `bypassPermissions` in a container | `deny` rules, `ask` rules, critical-path removals | Whole-plan runs, migrations |
| Pipeline | `dontAsk` | Nothing: it denies what would prompt | CI, scripted runs |

- The `auto` pause thresholds are not configurable.
- A `-p` run without `--permission-prompt-tool` never pauses; a blocked action does not run, and Claude keeps working.

## Confirm the denial log

The `PermissionDenied` hook in [plugin/hooks/hooks.json](../plugin/hooks/hooks.json) appends each auto-mode denial to a log.
It fires in `auto` mode only. Source: [Hooks](https://code.claude.com/docs/en/hooks#permissiondenied).

```bash
tail -20 ~/.claude/denials.log
```

Expected: one JSON line per denial, naming the Bash command or file path to allowlist.

## Describe your infrastructure to the classifier

Fill `autoMode.environment` in [claude/settings.json](../claude/settings.json) with your source-control org, repo visibility, trusted hosts and sensitive paths.
Source: [Configure auto mode](https://code.claude.com/docs/en/auto-mode-config).

- The classifier reads it from `~/.claude/settings.json`, managed settings and `--settings`, never from a repo's `.claude/settings.json`.
- Keep `"$defaults"` in the array; the built-in entries splice in at its position. Omitting it discards them.
- An `ask` rule prompts even in `auto` mode, and the classifier cannot approve a matching command.

Expected: `claude auto-mode config` lists your entries, as Verify checks.

## Add Claude Code to the dev container

The template's base image has no Claude Code, no settings and no login.
Add the Claude Code feature, a config volume, and read-only mounts of this repo's settings and plugin.
Source: [Development containers](https://code.claude.com/docs/en/devcontainer).

```diff
   "features": {
+    "ghcr.io/anthropics/devcontainer-features/claude-code:1.0": {},
     // -- Go --
@@
   "postCreateCommand": "bash scripts/setup-dev-tools.sh",
+  "mounts": [
+    "source=claude-code-config-${devcontainerId},target=/home/vscode/.claude,type=volume",
+    "source=<handbook>/claude/settings.json,target=/etc/handbook/settings.json,type=bind,readonly",
+    "source=<handbook>/plugin,target=<handbook>/plugin,type=bind,readonly"
+  ],
+  "containerEnv": { "CLAUDE_CONFIG_DIR": "/home/vscode/.claude" },
```

`<handbook>` is the absolute path of your handbook clone; `vscode` is the base image's non-root user.
Expected: `devcontainer up --workspace-folder .` builds the container without errors.

- The volume keeps the login and the bypass acceptance across rebuilds; `CLAUDE_CONFIG_DIR` puts `.claude.json` in it too.
- The settings and the plugin stay read-only in the container; `--settings` loads the settings on every start.
- The plugin mounts at its host path, the marketplace path the settings name.
- The plugin's PreToolUse hook blocks every Bash command while its git guard is missing or failing.

## Start the run in the container

`bypassPermissions` skips the classifier, so run it only where a mistake cannot reach the host.

```bash
cd <repo>
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . env CLAUDE_CODE_RETRY_WATCHDOG=1 \
  claude --settings /etc/handbook/settings.json --permission-mode bypassPermissions
```

On the first start, sign in and accept the responsibility dialog. The volume keeps both.
That session registers the plugin's marketplace in the background, so restart Claude Code once.
Expected: Claude Code starts as `vscode` in bypass-permissions mode, with this repo's `ask` and `deny` rules.

- `bypassPermissions` refuses to start as root or under `sudo`. Source: [Permission modes](https://code.claude.com/docs/en/permission-modes#skip-all-checks-with-bypasspermissions-mode).
- Accept the dialog interactively before any `--bg` run; a `--bg` run is refused until then.
- `CLAUDE_CODE_RETRY_WATCHDOG=1` retries `429` and `529` capacity errors indefinitely, backing off up to 5 minutes.
- It raises the retry count for server errors, timeouts and dropped connections to 300, roughly three hours.
- A `429` that reports a spend limit or exhausted usage credits still fails at once.
  Source: [Environment variables](https://code.claude.com/docs/en/env-vars).
- Set it on the command line, not in settings, so attended sessions keep failing fast.
- Rules match the usual command form only: `Bash(git push *)` misses `git -C . push`. The container is the security boundary.

## Let an open session wait out a usage limit

A claude.ai usage limit mid-task makes an open interactive session wait and continue after the reset.
`autoContinueAtUsageLimit` is on by default. Source: [Wait for a usage limit to reset](https://code.claude.com/docs/en/interactive-mode#wait-for-a-usage-limit-to-reset).

Leave the terminal open. Expected: the bottom line reads `Usage limit reached · continuing automatically at <time>`.

- It re-arms at most twice in a row, then stops.
- It does not start for `--bg` or `-p` runs, teammate sessions, or a reset more than 24 hours away.
- The continued turn still asks for permissions as usual.

## Disarm the plan-run guard in a repo

[plugin/scripts/plan-run-guard.sh](../plugin/scripts/plan-run-guard.sh) is a Stop hook. It blocks the stop of the session that claimed `plan/<slug>` while that plan has an unticked criterion.
To let sessions in one checkout or worktree stop freely, run there:

```bash
touch "$(git rev-parse --git-dir)/plan-run-guard-off"
```

Expected: the next stop in that checkout ends the turn without a nudge. Source: [Hooks](https://code.claude.com/docs/en/hooks#stop).

## Verify

```bash
claude auto-mode config | jq -e '.environment | any(startswith("Source control"))'
jq -e '.autoMode.environment | index("$defaults") == 0' ~/.claude/settings.json
claude plugin list --json | jq -e 'any(.id == "handbook@handbook" and .enabled)'
```

Expected: `true` from each command.

```bash
devcontainer exec --workspace-folder <repo> bash -c 'echo "git push -f" | <handbook>/plugin/scripts/git-guard.sh; echo "exit $?"'
```

Expected: a `Blocked:` line, then `exit 2`.

## Troubleshooting

Committed work survives every stop; the session does not. The messages are listed on [Errors](https://code.claude.com/docs/en/errors).

| Symptom | Recovery |
| --- | --- |
| `You've hit your session limit` or `weekly limit`, session still open | [Wait out the limit](#let-an-open-session-wait-out-a-usage-limit) |
| `Repeated 529 Overloaded errors` or `Request rejected (429)` ended the run | Restart it with `CLAUDE_CODE_RETRY_WATCHDOG=1`, then [resume from the last commit](../plugin/skills/implement-plan/git.md#pickup) |
| The run stalled on a denial | Read `~/.claude/denials.log`; add an allow rule or an `autoMode.environment` entry |
| Any other limit or API error stopped the run | [Respond per error kind](../plugin/skills/implement-plan/lead.md#failures), then [resume from the last commit](../plugin/skills/implement-plan/git.md#pickup) |
