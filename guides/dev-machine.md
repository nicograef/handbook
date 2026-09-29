# New Dev Machine

Set up a developer machine with the handbook's CLI tools, dotfiles, Claude config, editor and Docker.

## Prerequisites

An Ubuntu machine with a `sudo` user. Cloning needs `git`; `install.sh` stops before any change without `jq`:

```bash
sudo apt install -y git jq
```

## Set up

1. **CLI tools** — the apt line in [After provisioning](provision-server.md#after-provisioning).
   Add gh from its apt repo: [install_linux.md](https://github.com/cli/cli/blob/trunk/docs/install_linux.md).
2. Clone the handbook and run [`install.sh`](../install.sh). It symlinks the shell dotfiles, the Claude config and the shared skills into `$HOME`.
   A real file in the way moves to `<name>.bak`.
   With `~/.ssh/id_ed25519.pub` present, it sets up SSH commit signing.
3. **Signing key** — add that key to GitHub with key type "Signing Key":
   [adding a new SSH key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account).
4. **Editor** — [neovim.md](neovim.md) installs Neovim; `install.sh` has already linked its config.
5. **Docker** — Ubuntu's packages `docker.io`, `docker-compose-v2` and `docker-buildx`, then join the `docker` group.
   Without `docker-buildx`, `docker build` falls back to the legacy builder.

## Verify

**Done when** `ls -l ~/.claude/CLAUDE.md ~/.bash_aliases` shows both as symlinks into the clone, and `docker buildx version` runs.
