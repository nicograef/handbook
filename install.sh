#!/usr/bin/env bash
# install.sh — dotfiles entrypoint; delegates to scripts/install-dotfiles.sh with its arguments (--check)
exec "$(dirname "$0")/scripts/install-dotfiles.sh" "$@"
