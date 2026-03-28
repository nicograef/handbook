# Dotfiles for GitHub Codespaces

Automatically apply your shell config (prompt, aliases, git settings) to every
new Codespace. Uses [`scripts/install-dotfiles.sh`](../scripts/install-dotfiles.sh)
to symlink config files into `$HOME`.

## Files used

| Source in this repo       | Symlinked to      | Content                                      |
| ------------------------- | ----------------- | -------------------------------------------- |
| `templates/.bash_aliases` | `~/.bash_aliases` | Personal aliases (`gfp`, `gcm`, `m`, `p`, …) |

The script also:

- Sets **git config** defaults (`pull.rebase`, `push.autoSetupRemote`,
  `rerere.enabled`, `init.defaultBranch`)
- Installs **gh CLI** if missing (binary to `~/.local/bin`, no sudo needed;
  already pre-installed in Codespaces)

> **Why no `.bashrc`?** The Codespaces default already includes a git-branch
> prompt, color support, and `source ~/.bash_aliases`. Replacing it would lose
> those features.

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

Since our script lives at `scripts/install-dotfiles.sh`, create a thin wrapper
in the repo root so Codespaces finds it:

```bash
# install.sh (repo root) – Codespaces entry point
#!/usr/bin/env bash
exec "$(dirname "$0")/scripts/install-dotfiles.sh"
```

Alternatively, rename or symlink directly.

## Manual run

If the dotfiles repo is already cloned (e.g. inside a Codespace at
`/workspaces/.codespaces/.persistedshare/dotfiles`):

```bash
bash /workspaces/.codespaces/.persistedshare/dotfiles/scripts/install-dotfiles.sh
source ~/.bashrc
```

## Extending

- **Git config** – `install-dotfiles.sh` already sets global defaults
  (`pull.rebase`, `push.autoSetupRemote`, `rerere.enabled`,
  `init.defaultBranch`). To add more, append `git config --global` lines to the
  script.
- **gh CLI** – automatically installed by `install-dotfiles.sh` if missing
  (binary to `~/.local/bin`). Pre-installed in Codespaces.
- **VS Code settings** – use _Settings Sync_ (syncs extensions, keybindings,
  editor settings via your GitHub account). This is complementary to dotfiles.
- **Extra tools per project** – use
  [`templates/devcontainer.json`](../templates/devcontainer.json) as a starting
  point for `.devcontainer/devcontainer.json`. Uncomment the Dev Container
  Features your project needs (Go, Node, Docker-in-Docker).
