#!/usr/bin/env bash
# install.sh — Codespaces dotfiles entrypoint; delegates to scripts/install-dotfiles.sh
exec "$(dirname "$0")/scripts/install-dotfiles.sh"
