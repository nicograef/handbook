# New Dev Machine

Take a fresh Ubuntu laptop to a working toolchain in one pass.
It installs git, gh, Node, pnpm, uv, Claude Code, Docker, the CLI tools, the handbook dotfiles and the editor.

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

6. **pnpm** — install it globally with npm, prefixed to `~/.local`, so no global install needs sudo. `pnpm --version` prints a version:

   ```bash
   npm config set prefix ~/.local
   npm install -g pnpm
   ```

7. **Claude Code** — the native installer puts `claude` into `~/.local/bin` and updates itself. Run it without sudo; `claude --version` then prints a version:

   ```bash
   curl -fsSL https://claude.ai/install.sh | bash
   ```

8. **Docker** — Ubuntu's packages, then join the `docker` group. After a new login, `docker run --rm hello-world` works without sudo.
   Without `docker-buildx`, `docker build` falls back to the legacy builder:

   ```bash
   sudo apt install -y docker.io docker-compose-v2 docker-buildx
   sudo usermod -aG docker "$USER"
   ```

9. **CLI tools** — tmux, the modern tools the shell aliases expect, and `make` and `shellcheck` for the handbook's `make check`.
   gitleaks lets the git guard hook scan each agent commit for secrets. Without bat, eza, fd-find or fzf, their aliases stay inactive.
   [dotfiles/.bash_aliases](../dotfiles/.bash_aliases) holds those aliases. `rg --version` then prints a version:

   ```bash
   sudo apt install -y tmux bat eza fzf fd-find ripgrep git-delta make shellcheck gitleaks
   ```

10. **Clone the handbook** — over SSH, with the key gh uploaded. `~/r/handbook` then holds the clone:

    ```bash
    mkdir -p ~/r && git clone git@github.com:nicograef/handbook.git ~/r/handbook
    ```

11. **Run install.sh** — it links the dotfiles, the Claude config and the skills, and sets up commit signing.
    The header of [scripts/install-dotfiles.sh](../scripts/install-dotfiles.sh) lists what it does. It ends with `Done – restart your shell`; the line above reads `gh already installed`:

    ```bash
    cd ~/r/handbook && ./install.sh
    ```

12. **SSH config** — copy the [ssh_config](../templates/ssh_config) template; `--update=none` keeps an existing config.
    Host entries go above its defaults. `ssh -G github.com | grep identitiesonly` then prints `identitiesonly yes`:

    ```bash
    cp --update=none ~/r/handbook/templates/ssh_config ~/.ssh/config && chmod 600 ~/.ssh/config
    ```

13. **Signing key** — grant gh the signing-key scope, then upload the same key as a signing key.
    `gh ssh-key list` then shows it twice, typed `authentication` and `signing`:

    ```bash
    gh auth refresh -h github.com -s admin:ssh_signing_key
    gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "<title>"
    ```

14. **Editor** — [neovim.md](neovim.md) installs Neovim; `install.sh` has already linked its config.
15. **New login** — log out and back in. The session then has the `docker` group and the new `PATH`.

## Verify

Each version command prints a version; the symlinks resolve into the clone:

```bash
for c in 'git --version' 'gh --version' 'node --version' 'pnpm --version' 'uv --version' \
  'claude --version' 'docker --version' 'docker compose version' 'docker buildx version' \
  'tmux -V' 'batcat --version' 'eza --version' 'fzf --version' 'fdfind --version' \
  'rg --version' 'delta --version' 'jq --version' 'make --version' 'shellcheck --version' 'nvim --version'; do
  $c >/dev/null 2>&1 && echo "ok   $c" || echo "FAIL $c"
done                                               # → 20 lines, each starting with ok
readlink -f ~/.claude/CLAUDE.md ~/.bash_aliases    # → <home>/r/handbook/claude/CLAUDE.md, <home>/r/handbook/dotfiles/.bash_aliases
git config --global commit.gpgsign                 # → true
apt-config dump | grep -F 'origin=gh'              # → Unattended-Upgrade::Origins-Pattern:: "origin=gh,codename=stable";
docker run --rm hello-world | grep Hello           # → Hello from Docker!
```

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `pnpm`, `uv` or `claude`: command not found | The shell predates `pipx ensurepath` | Open a new terminal |
| `docker`: permission denied on the socket | The session predates the `docker` group | Log out and back in |
| `install.sh` reports signing skipped | `~/.ssh/id_ed25519.pub` was missing | Create the key, then re-run `./install.sh` |
