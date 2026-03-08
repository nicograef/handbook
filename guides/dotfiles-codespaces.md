# Dotfiles for GitHub Codespaces

Automatically apply your shell config (prompt, aliases, git settings) to every
new Codespace. Uses [`scripts/install-dotfiles.sh`](../scripts/install-dotfiles.sh)
to symlink config files into `$HOME`.

## Files used

| Source in this repo | Symlinked to | Content |
| ------------------- | ------------ | ------- |
| `templates/.bashrc` | `~/.bashrc` | Custom prompt (git branch) + base aliases |
| `.bash_aliases` | `~/.bash_aliases` | Personal aliases (`gfp`, `gcm`, `p`, …) |

## Setup (one-time)

1. Go to **github.com → Settings → Codespaces**.
2. Under **Dotfiles**, check *"Automatically install dotfiles"*.
3. Select this repository (`nicograef/admin`).

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

- **Git config** – uncomment the `git config` lines in `install-dotfiles.sh`
  or add a `.gitconfig` to `templates/` and extend the `FILES` map.
- **VS Code settings** – use *Settings Sync* (syncs extensions, keybindings,
  editor settings via your GitHub account). This is complementary to dotfiles.
- **Extra tools per project** – add Dev Container Features in
  `.devcontainer/devcontainer.json` (e.g. Node, Go, Docker-in-Docker). These
  are project-scoped, not global.
