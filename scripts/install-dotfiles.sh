#!/usr/bin/env bash
# install-dotfiles.sh – bootstrap shell config in a new environment
#
# Called automatically by GitHub Codespaces when this repo is set as
# your dotfiles repository (Settings → Codespaces → Dotfiles).
# Can also be run manually:
#   curl -sL <raw-url> | bash
#
# What it does:
#   1. Symlinks .bashrc and .bash_aliases into $HOME
#   2. Sources the new config in the current shell
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

log() { printf '\033[1;34m▸ %s\033[0m\n' "$1"; }

# ── Symlink dotfiles ────────────────────────────────────────────────────────
declare -A FILES=(
  ["templates/.bashrc"]=".bashrc"
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

# ── Optional: .gitconfig defaults ───────────────────────────────────────────
# Uncomment and adjust if you want to set git config globally.
# git config --global init.defaultBranch main
# git config --global pull.rebase true

log "Done – restart your shell or run: source ~/.bashrc"
