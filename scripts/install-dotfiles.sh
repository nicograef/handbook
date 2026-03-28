#!/usr/bin/env bash
# install-dotfiles.sh – bootstrap shell config in a new environment
#
# Called automatically by GitHub Codespaces when this repo is set as
# your dotfiles repository (Settings → Codespaces → Dotfiles).
# Can also be run manually:
#   curl -sL <raw-url> | bash
#
# What it does:
#   1. Symlinks .bash_aliases into $HOME
#   2. Sets git config defaults (pull.rebase, push.autoSetupRemote, etc.)
#   3. Installs gh CLI if missing (binary to ~/.local/bin, no sudo)
#   4. Sources the new config in the current shell
#
# Note: We intentionally do NOT replace .bashrc. The Codespaces default
# already includes a git-branch prompt, color support, and sources
# ~/.bash_aliases automatically. Overwriting it would lose those features.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

log() { printf '\033[1;34m▸ %s\033[0m\n' "$1"; }

# ── Symlink dotfiles ────────────────────────────────────────────────────────
declare -A FILES=(
  ["templates/.bash_aliases"]=".bash_aliases"
)

for src in "${!FILES[@]}"; do
  dest="$HOME/${FILES[$src]}"
  origin="$DOTFILES_DIR/$src"
  if [[ -f "$origin" ]]; then
    ln -sf "$origin" "$dest"
    log "Linked $dest → $origin"
  else
    echo "SKIP: $origin not found"
  fi
done

# ── Git config defaults ─────────────────────────────────────────────────────
# Idempotent – safe to run on every Codespace create.
# user.name / user.email are set automatically by Codespaces.
log "Setting git config defaults…"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global push.autoSetupRemote true
git config --global rerere.enabled true

# ── GitHub CLI ──────────────────────────────────────────────────────────────
# Pre-installed in Codespaces; install on local machines if missing.
if command -v gh >/dev/null 2>&1; then
  log "gh already installed: $(gh --version | head -1)"
else
  GH_VERSION="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/')"
  if [[ -n "$GH_VERSION" ]]; then
    log "Installing gh ${GH_VERSION} to ~/.local/bin…"
    mkdir -p "$HOME/.local/bin"
    TMP="$(mktemp -d)"
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
      | tar -xz -C "$TMP"
    mv "$TMP/gh_${GH_VERSION}_linux_amd64/bin/gh" "$HOME/.local/bin/gh"
    chmod +x "$HOME/.local/bin/gh"
    rm -rf "$TMP"
    log "gh ${GH_VERSION} installed. Run 'gh auth login' to authenticate."
  else
    log "SKIP: Could not determine latest gh version (no curl or no network)."
  fi
fi

log "Done – restart your shell or run: source ~/.bashrc"
