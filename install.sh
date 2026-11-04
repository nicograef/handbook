#!/usr/bin/env bash
# install.sh – dotfiles entrypoint for scripts/install-dotfiles.sh
exec "$(dirname "$0")/scripts/install-dotfiles.sh" "$@"
