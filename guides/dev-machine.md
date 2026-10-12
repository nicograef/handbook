# New Dev Machine

Take a fresh Ubuntu laptop to a working toolchain in one pass.

## Prerequisites

An Ubuntu machine with a `sudo` user. Cloning needs `git`; `install.sh` stops before any change without `jq`:

```bash
sudo apt install -y git jq
```

Placeholders: `<name>` and `<email>` are your git identity; `<title>` names this machine's key on GitHub.

## Set up

1. **SSH key** — create the key GitHub uses for pushes and commit signing. `~/.ssh/id_ed25519.pub` then exists:

   ```bash
   ssh-keygen -t ed25519 -C "<email>"
   ```

2. **Git identity** — set it before `install.sh`, which writes the email into the allowed-signers file:

   ```bash
   git config --global user.name "<name>"
   git config --global user.email "<email>"
   ```

3. **gh** — add GitHub's apt repo, allow unattended-upgrades to update from it, install gh and log in.
   Pick SSH as the protocol and upload `~/.ssh/id_ed25519.pub`.
   `gh auth status` then shows the account ([install_linux.md](https://github.com/cli/cli/blob/trunk/docs/install_linux.md)):

   ```bash
   sudo apt install -y curl
   sudo mkdir -p -m 755 /etc/apt/keyrings
   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
   sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
   echo 'Unattended-Upgrade::Origins-Pattern { "origin=gh,codename=stable"; };' | sudo tee /etc/apt/apt.conf.d/52unattended-upgrades-gh >/dev/null
   sudo apt update && sudo apt install -y gh
   gh auth login
   ```

4. **Node** — the classic snap on the `26/stable` channel refreshes itself within Node 26. `node --version` prints `v26.<minor>.<patch>`:

   ```bash
   sudo snap install node --classic --channel=26/stable
   ```

5. **uv** — install it with pipx, which also puts `~/.local/bin` on `PATH` for new shells. Open a new terminal afterwards:

   ```bash
   sudo apt install -y pipx
   pipx install uv
   pipx ensurepath
   ```

6. **Go** — the classic snap tracks the latest release. `go install` builds into `~/go/bin`, which `.bash_aliases` puts on `PATH`.
   Without `gcc`, Go disables cgo and `go test -race` fails. `go env CGO_ENABLED` then prints `1`:

   ```bash
   sudo snap install go --classic && sudo apt install -y gcc
   ```

7. **pnpm** — install it globally with npm, prefixed to `~/.local`, so no global install needs sudo. `pnpm --version` prints a version:

   ```bash
   npm config set prefix ~/.local
   npm install -g pnpm
   ```

8. **Claude Code** — the native installer puts `claude` into `~/.local/bin` and updates itself. Run it without sudo; `claude --version` then prints a version:

   ```bash
   curl -fsSL https://claude.ai/install.sh | bash
   ```

9. **Docker** — Ubuntu's packages, then join the `docker` group. After a new login, `docker run --rm hello-world` works without sudo.
   Without `docker-buildx`, `docker build` falls back to the legacy builder:

   ```bash
   sudo apt install -y docker.io docker-compose-v2 docker-buildx
   sudo usermod -aG docker "$USER"
   ```

10. **CLI tools** — tmux, the tools [dotfiles/.bash_aliases](../dotfiles/.bash_aliases) aliases, and `make` and `shellcheck` for the handbook's `make check`.
    gitleaks lets the git guard hook scan each agent commit for secrets. `rg --version` then prints a version:

    ```bash
    sudo apt install -y tmux bat eza fzf fd-find ripgrep git-delta make shellcheck gitleaks
    ```

11. **Clone the handbook** — over SSH, with the key gh uploaded. `~/r/handbook` then holds the clone:

    ```bash
    mkdir -p ~/r && git clone git@github.com:nicograef/handbook.git ~/r/handbook
    ```

12. **Run install.sh** — it links the dotfiles and the Claude config, and sets up commit signing.
    The header of [scripts/install-dotfiles.sh](../scripts/install-dotfiles.sh) lists what it does. It ends with `Done – restart your shell`; the line above reads `gh already installed`:

    ```bash
    cd ~/r/handbook && ./install.sh
    ```

    The Claude config enables the `nico` plugin from `/home/nico/r/handbook/plugin`; another clone path edits `extraKnownMarketplaces`.
    `install.sh` installs the plugin when `claude` is on PATH; otherwise rerun it after installing Claude Code.

13. **SSH config** — copy the [ssh_config](../templates/ssh_config) template; `--update=none` keeps an existing config.
    Host entries go above its defaults. `ssh -G github.com | grep identitiesonly` then prints `identitiesonly yes`:

    ```bash
    cp --update=none ~/r/handbook/templates/ssh_config ~/.ssh/config && chmod 600 ~/.ssh/config
    ```

14. **Signing key** — grant gh the signing-key scope, then upload the same key as a signing key.
    `gh ssh-key list` then shows it twice, typed `authentication` and `signing`:

    ```bash
    gh auth refresh -h github.com -s admin:ssh_signing_key
    gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "<title>"
    ```

15. **Editor** — [neovim.md](neovim.md) installs Neovim; `install.sh` has already linked its config.
16. **New login** — log out and back in. The session then has the `docker` group and the new `PATH`.

## Verify

Each version command prints a version; the symlinks resolve into the clone:

```bash
for c in 'git --version' 'gh --version' 'node --version' 'pnpm --version' 'uv --version' 'go version' \
  'claude --version' 'docker --version' 'docker compose version' 'docker buildx version' \
  'tmux -V' 'batcat --version' 'eza --version' 'fzf --version' 'fdfind --version' \
  'rg --version' 'delta --version' 'jq --version' 'make --version' 'shellcheck --version' 'nvim --version'; do
  $c >/dev/null 2>&1 && echo "ok   $c" || echo "FAIL $c"
done                                               # → 21 lines, each starting with ok
readlink -f ~/.claude/CLAUDE.md ~/.bash_aliases    # → <home>/r/handbook/claude/global.md, <home>/r/handbook/dotfiles/.bash_aliases
claude plugin list --json | jq -e 'any(.id == "nico@handbook" and .enabled)'   # → true
git config --global commit.gpgsign                 # → true
apt-config dump | grep -F 'origin=gh'              # → Unattended-Upgrade::Origins-Pattern:: "origin=gh,codename=stable";
docker run --rm hello-world | grep Hello           # → Hello from Docker!
```

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `install.sh` reports signing skipped | `~/.ssh/id_ed25519.pub` was missing | Create the key, then re-run `./install.sh` |
