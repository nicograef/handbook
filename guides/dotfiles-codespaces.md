# Dotfiles for GitHub Codespaces

Automatically apply your shell config (prompt, aliases, git settings) to every
new Codespace. Uses [`scripts/install-dotfiles.sh`](../scripts/install-dotfiles.sh)
to symlink config files into `$HOME`.

## Files used

| Source in this repo       | Symlinked to               | Content                                  |
| ------------------------- | --------------------------- | ----------------------------------------- |
| `templates/.bash_aliases` | `~/.bash_aliases`           | Aliases (`gfp`, `gcm`, `m`, `p`, …), history tuning, git prompt |
| `templates/.tmux.conf`    | `~/.tmux.conf`              | tmux defaults (mouse, scrollback, escape-time) |
| `claude/CLAUDE.md`        | `~/.claude/CLAUDE.md`       | Global Claude Code instructions |
| `claude/settings.json`    | `~/.claude/settings.json`   | Claude Code permissions, plugins, hooks |
| `claude/statusline.sh`    | `~/.claude/statusline.sh`   | Claude Code status line script |
| `.claude/agents`          | `~/.claude/agents`          | Shared subagent definitions |
| `.claude/skills`          | `~/.claude/skills`          | Shared agent skills |
| `.claude/skills`          | `~/.agents/skills`          | Same skills, mirrored for the Copilot CLI |

`~/.claude/settings.local.json` stays machine-local and is intentionally not linked.

The script also:

- Creates the **handbook-plugin opt-out** (`.claude/settings.local.json`) in
  every `/workspaces` repo whose committed `.claude/settings.json` enables
  `handbook@nicograef`, so skills don't load twice next to the symlink tier —
  see [claude-plugin.md → Dev-machine opt-out](claude-plugin.md#dev-machine-opt-out).
- Sets **git config** defaults — see [Extending → Git config](#extending) below.
- Installs **gh CLI** if missing (binary to `~/.local/bin`, no sudo needed;
  already pre-installed in Codespaces)

> **Why no `.bashrc`?** Every stock `.bashrc` (Debian, Ubuntu, Codespaces)
> already sources `~/.bash_aliases` *after* setting its own history defaults
> and PS1, so all portable config — aliases, history tuning, the git prompt —
> lives there and wins by sourcing order. Replacing `.bashrc` would only lose
> distro-specific defaults.

## Prerequisites

- A GitHub account with Codespaces enabled.
- This repository forked or cloned under your account.
- `bash`, `git`, and `curl` on the target machine (all present in Codespaces).

## Setup (one-time)

1. Go to **github.com → Settings → Codespaces**.
2. Under **Dotfiles**, check _"Automatically install dotfiles"_.
3. Select this repository (`nicograef/handbook`).

Every new Codespace will now clone this repo and run `scripts/install-dotfiles.sh`.

## How it works

Codespaces looks for an install script in the dotfiles repo root or common
locations. The lookup order is:

1. `install.sh`
2. `install`
3. `bootstrap.sh`
4. `setup.sh`
5. `script/setup`

Our script lives at `scripts/install-dotfiles.sh`, so the wrapper Codespaces
looks for already exists in the repo root: [install.sh](../install.sh). It just
execs the real script — nothing to create.

## Manual run

If the dotfiles repo is already cloned (e.g. inside a Codespace at
`/workspaces/.codespaces/.persistedshare/dotfiles`):

```bash
bash /workspaces/.codespaces/.persistedshare/dotfiles/scripts/install-dotfiles.sh
source ~/.bashrc
```

## Staying up to date

`~/.claude/skills`, `~/.agents/skills`, and `~/.claude/agents` are **directory**
symlinks into the repo clone, so pulling the clone is the whole update — new
skills and agents appear immediately, with no re-link and no restart:

```bash
git -C ~/handbook pull
```

Re-run `install.sh` only when [`scripts/install-dotfiles.sh`](../scripts/install-dotfiles.sh)
itself changes (a new symlink target, a new git-config default). It is
idempotent, so re-running when unsure is harmless.

For the plugin tier on machines without a clone, see
[claude-plugin.md](claude-plugin.md) → *Update behavior*.

## Verify

```bash
# the dotfile symlinks resolve back into the repo
readlink -f ~/.bash_aliases
readlink -f ~/.tmux.conf

# history tuning from .bash_aliases is active
bash -i -c 'echo $HISTSIZE'                  # → 100000

# an alias is active in the current shell
type gcm

# git defaults were applied
git config --global --get pull.rebase        # → true
git config --global --get init.defaultBranch # → main
git config --global --get core.editor        # → nano
git config --global --get merge.conflictStyle # → zdiff3

# Claude Code config symlinked
readlink -f ~/.claude/CLAUDE.md
readlink -f ~/.agents/skills

# plugin opt-out created (Codespace on an adopted repo)
cat /workspaces/*/.claude/settings.local.json

# gh is on PATH
gh --version

# git tab-completion is the real one, not fzf's path completer
# (fzf must wrap git's completion, not clobber it — see templates/.bash_aliases)
bash -i -c '_completion_loader git 2>/dev/null; complete -p git' | grep -q __git_wrap__git_main \
  && echo "git completion OK" || echo "git completion BROKEN (fzf clobbered it)"
```

Expected: `~/.bash_aliases` and `~/.tmux.conf` point into the repo's
`templates/`, `HISTSIZE` prints `100000`,
`gcm` resolves to its alias, the `git config` reads print `true` / `main` /
`nano` / `zdiff3`, `~/.claude/CLAUDE.md` and `~/.agents/skills` resolve into
the repo, `gh --version` prints a version, and git completion prints `OK`.

### Smoke test 1 — fresh Codespace on this repo (PENDING)

Create a fresh Codespace on `nicograef/handbook` (the root
[.devcontainer/devcontainer.json](../.devcontainer/devcontainer.json) applies),
then confirm: the account-level dotfiles install ran automatically, the Verify
commands above pass, skills load in a Claude Code session, and `make check` is
green with all seven stages (docker and the claude CLI come from the dev
container features). Requires an interactive Codespace — operator step.

- Date:
- Environment:
- Result:

## Extending

- **Git config** – `install-dotfiles.sh` already sets global defaults:
  `init.defaultBranch main`, `pull.rebase true`, `push.autoSetupRemote true`,
  `rerere.enabled true`, `core.editor nano`, `merge.conflictStyle zdiff3`, and
  a `delta`-based pager setup (`core.pager`, `interactive.diffFilter`,
  `delta.navigate`, `delta.line-numbers` — falls back to `less`/`cat` if
  `delta` isn't installed). To add more, append `git config --global` lines to
  the script.
- **gh CLI** – automatically installed by `install-dotfiles.sh` if missing
  (binary to `~/.local/bin`). Pre-installed in Codespaces.
- **VS Code settings** – use _Settings Sync_ (syncs extensions, keybindings,
  editor settings via your GitHub account). This is complementary to dotfiles.
- **Extra tools per project** – use
  [`templates/devcontainer.json`](../templates/devcontainer.json) as a starting
  point for `.devcontainer/devcontainer.json`. Uncomment the Dev Container
  Features your project needs (Go, Node, Docker-in-Docker).

---

See also:
- [templates/.bash_aliases](../templates/.bash_aliases) — shell aliases template
- [templates/devcontainer.json](../templates/devcontainer.json) — Dev Container template
- [scripts/install-dotfiles.sh](../scripts/install-dotfiles.sh) — dotfile bootstrap script
