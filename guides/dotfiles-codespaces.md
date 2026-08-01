# Dotfiles for GitHub Codespaces

Automatically apply your shell config (prompt, aliases, git settings) to every
new Codespace. Uses [`scripts/install-dotfiles.sh`](../scripts/install-dotfiles.sh)
to symlink config files into `$HOME`. `~/.claude/settings.local.json` stays
machine-local and is intentionally not linked.

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
locations (`install.sh`, `install`, `bootstrap.sh`, `setup.sh`, `script/setup`).
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

---

See also:
- [templates/.bash_aliases](../templates/.bash_aliases) — shell aliases template
- [templates/devcontainer.json](../templates/devcontainer.json) — Dev Container template
- [scripts/install-dotfiles.sh](../scripts/install-dotfiles.sh) — dotfile bootstrap script
