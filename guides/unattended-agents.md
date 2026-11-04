# Unattended Agent Runs

Set up Claude Code so a long session never stops on an unanswered prompt, and resumes after a limit.
Applies to an [implement-plan](../plugin/skills/implement-plan/SKILL.md) run, a distill or a migration.

## Prerequisites

- Claude Code v2.1.234 or later (`claude --version`).
- `~/.claude/settings.json` is this repo's [claude/settings.json](../claude/settings.json), which enables the `nico` plugin.
- Docker and the [Dev Containers CLI](https://github.com/devcontainers/cli) (`npm install -g @devcontainers/cli`), for the container posture.
- The repo holds `.devcontainer/devcontainer.json` from [templates/devcontainer.json](../templates/devcontainer.json).
- A claude.ai subscription login, for automatic continue at a usage limit.
- `<handbook>` is the absolute path of your handbook clone, `<repo>` the repo's path, `<name>` its directory name.

## Choose the posture

Source: [Permission modes](https://code.claude.com/docs/en/permission-modes).

| Posture | Mode | Stops on | Use for |
| --- | --- | --- | --- |
| Attended | `auto` | A classifier pause after 3 consecutive or 20 total blocks, both fixed | Normal interactive work |
| Unattended | `bypassPermissions` in a container | `deny` rules, `ask` rules, critical-path removals | Whole-plan runs, migrations |
| Pipeline | `dontAsk` | Nothing: it denies what would prompt | CI, scripted runs |

- A `-p` run without `--permission-prompt-tool` never pauses; a blocked action does not run, and Claude keeps working.

## Describe your infrastructure to the classifier

Fill `autoMode.environment` in [claude/settings.json](../claude/settings.json) with your source-control org, repo visibility, trusted hosts and sensitive paths.
Source: [Configure auto mode](https://code.claude.com/docs/en/auto-mode-config).

- The classifier reads it from `~/.claude/settings.json`, managed settings and `--settings`, never from a repo's `.claude/settings.json`.
- Keep `"$defaults"` in the array; the built-in entries splice in at its position. Omitting it discards them.
- An `ask` rule prompts even in `auto` mode, and the classifier cannot approve a matching command.

Expected: `claude auto-mode config` lists your entries, as Verify checks.

## Add Claude Code to the dev container

Add the Claude Code feature, a config volume, a read-only mount of the handbook, and its `~/.claude` links.
Source: [Development containers](https://code.claude.com/docs/en/devcontainer).

```diff
   "features": {
+    "ghcr.io/anthropics/devcontainer-features/claude-code:1.0": {},
     // -- Go --
@@
   "postCreateCommand": "bash scripts/setup-dev-tools.sh",
+  "mounts": [
+    "source=claude-code-config-${devcontainerId},target=/home/vscode/.claude,type=volume",
+    "source=<handbook>,target=<handbook>,type=bind,readonly",
+    "source=<handbook>/claude/global.md,target=/home/vscode/.claude/CLAUDE.md,type=bind,readonly",
+    "source=<handbook>/claude/statusline.sh,target=/home/vscode/.claude/statusline.sh,type=bind,readonly",
+    "source=<handbook>/plugin/scripts/agent-bus.sh,target=/home/vscode/.claude/agent-bus.sh,type=bind,readonly",
+    "source=<handbook>/plugin/scripts/check-agents.sh,target=/home/vscode/.claude/check-agents.sh,type=bind,readonly"
+  ],
+  "containerEnv": { "CLAUDE_CONFIG_DIR": "/home/vscode/.claude" },
```

Expected: `devcontainer up --workspace-folder .` builds the container without errors.

- The volume keeps the login and the bypass acceptance across rebuilds; `CLAUDE_CONFIG_DIR` puts `.claude.json` in it too.
- The handbook mounts at its host path, the marketplace path the settings name. The skills' links into `claude/` resolve there.
- The four file mounts are the `.claude` rows of `scripts/install-dotfiles.sh --check`, except `settings.json`, which `--settings` loads on every start.
- The plugin's PreToolUse hook blocks every Bash command while its git guard is missing or failing.

## Snapshot what the host runs

The repo is a read-write bind mount, `.git/` and `.devcontainer/` included.
The host runs some files there: `core.fsmonitor` or a hook on its next `git status`, `initializeCommand` on `devcontainer up`.
`repo-status` runs `git status` in every repo under `~/r`.

Define the snapshot in the host shell and record it outside the repo; it reads the files without running `git`:

```bash
hostrun() {
  { find .git -type f \( -name config -o -name config.worktree -o -path '*/hooks/*' \) -exec sha256sum {} +
    find .devcontainer "$@" -type f -exec sha256sum {} +
    find . -path ./.git -prune -o -name .git -print; } | sort
}
(cd <repo> && hostrun) > ~/.cache/hostrun-<name>.txt
```

The subshell keeps the host shell outside the repo: the handbook prompt runs `git diff` in any directory inside it.
Expected: one hash line per config and hook of the repo, its submodules and worktrees, and per `.devcontainer` file.

- Pass each in-repo `core.hooksPath` or `include.path` target as an argument, such as `hostrun .husky`, on both calls.
  `grep -riA1 -e hookspath -e '\[include' .git --include='config*'` lists them.

## Start the run in the container

`bypassPermissions` skips the classifier, so its commands must run in the container.

```bash
devcontainer up --workspace-folder <repo>
devcontainer exec --workspace-folder <repo> env CLAUDE_CODE_RETRY_WATCHDOG=1 \
  claude --settings <handbook>/claude/settings.json --permission-mode bypassPermissions
```

On the first start, sign in and accept the responsibility dialog; a `--bg` run is refused until then.
That session registers the plugin's marketplace in the background, so restart Claude Code once.
Expected: Claude Code starts as `vscode`, the base image's non-root user, in bypass-permissions mode with the handbook's `ask` and `deny` rules.

- `bypassPermissions` refuses to start as root or under `sudo`. Source: [Permission modes](https://code.claude.com/docs/en/permission-modes#skip-all-checks-with-bypasspermissions-mode).
- `CLAUDE_CODE_RETRY_WATCHDOG=1` retries `429` and `529` capacity errors indefinitely, backing off up to 5 minutes.
- It retries server errors, timeouts and dropped connections up to 300 times, roughly three hours.
- A `429` for a spend limit or exhausted usage credits still fails at once. Source: [Environment variables](https://code.claude.com/docs/en/env-vars).
- Set it on the command line, not in settings, so attended sessions keep failing fast.
- Rules match the usual command form only: `Bash(git push *)` misses `git -C . push`. The container and the host-run check are the security boundary.

## Check what the host will run

After the run, and before any host `git`, `repo-status`, `devcontainer up` or `cd` in the repo, compare the snapshot:

```bash
(cd <repo> && hostrun) | diff ~/.cache/hostrun-<name>.txt - && echo unchanged
```

Expected: `unchanged`. Read each file a differing line names before the host runs `git` there.

## Let an open session wait out a usage limit

A claude.ai usage limit mid-task makes an open interactive session wait and continue after the reset.
`autoContinueAtUsageLimit` is on by default. Source: [Wait for a usage limit to reset](https://code.claude.com/docs/en/interactive-mode#wait-for-a-usage-limit-to-reset).

Leave the terminal open. Expected: the conversation records `Usage limit reached · continuing automatically at <time>`.

- It continues at most three times in a row, then stops.
- It does not start for `--bg` or `-p` runs, teammate sessions, or a reset more than 24 hours away.
- The continued turn still asks for permissions as usual.

## Verify

```bash
claude auto-mode config | jq -e '.environment | any(startswith("Source control"))'   # → true
jq -e '.autoMode.environment | index("$defaults") == 0' ~/.claude/settings.json      # → true
claude plugin list --json | jq -e 'any(.id == "nico@handbook" and .enabled)'        # → true
devcontainer exec --workspace-folder <repo> bash -c 'echo "git push -f" | <handbook>/plugin/scripts/git-guard.sh; echo "exit $?"'   # → a Blocked: line, then exit 2
```

## Troubleshooting

Committed work survives every stop; the session does not. The messages are listed on [Errors](https://code.claude.com/docs/en/errors).

| Symptom | Recovery |
| --- | --- |
| `You've hit your session limit` or `weekly limit`, session still open | [Wait out the limit](#let-an-open-session-wait-out-a-usage-limit) |
| `Repeated 529 Overloaded errors` or `Request rejected (429)` ended the run | Restart it with `CLAUDE_CODE_RETRY_WATCHDOG=1`, then [resume from the last commit](../plugin/skills/implement-plan/SKILL.md#resume) |
| The run stalled on a denial | Read `~/.claude/denials.log`: the [`PermissionDenied`](https://code.claude.com/docs/en/hooks#permissiondenied) hook in [plugin/hooks/hooks.json](../plugin/hooks/hooks.json) appends one JSON line per `auto`-mode denial. Add an allow rule or an `autoMode.environment` entry for the command or path it names |
| Any other limit or API error stopped the run | [Respond per error kind](../plugin/skills/implement-plan/lead.md#failures), then [resume from the last commit](../plugin/skills/implement-plan/SKILL.md#resume) |
