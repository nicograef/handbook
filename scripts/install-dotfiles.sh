#!/usr/bin/env bash
# install-dotfiles.sh – bootstrap shell config in a new environment
#
# Run after cloning the repo:
#   git clone https://github.com/nicograef/handbook.git && cd handbook && ./install.sh
#
# What it does:
#   1. Symlinks .bash_aliases, .tmux.conf, the Neovim init.lua and repo-status into $HOME;
#      a real file or directory in the way is moved to <name>.bak
#   2. Symlinks Claude Code config (global CLAUDE.md, settings, agents, skills,
#      agent-bus.sh and plan-run-guard.sh — the global hooks in settings.json
#      call them by those paths)
#   3. Sets git config defaults (pull.rebase, fetch.prune, etc.)
#   4. Sets up SSH commit signing when ~/.ssh/id_ed25519.pub exists
#   5. Points to the gh install docs if gh is missing
#
# .bashrc is left alone: the Ubuntu default sources ~/.bash_aliases.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

log() { printf '\033[1;34m▸ %s\033[0m\n' "$1"; }

# Guard: abort early if the repo root is wrong (templates/.bash_aliases missing),
# so we don't silently create broken symlinks.
if [[ ! -f "$DOTFILES_DIR/templates/.bash_aliases" ]]; then
  echo "ERROR: $DOTFILES_DIR/templates/.bash_aliases not found — run this from the handbook repo." >&2
  exit 1
fi

# Moves a real file or directory at the destination to .bak, then links it.
link() {
  local origin="$DOTFILES_DIR/$1" dest="$HOME/$2"
  if [[ ! -e "$origin" ]]; then
    echo "SKIP: $origin not found"
    return
  fi
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    mv -T --backup=numbered "$dest" "$dest.bak"
    log "Moved $dest to $dest.bak"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -sfnT "$origin" "$dest"
  log "Linked $dest → $origin"
}

# ── Symlink dotfiles ────────────────────────────────────────────────────────
link templates/.bash_aliases .bash_aliases
link templates/.tmux.conf .tmux.conf
link templates/init.lua .config/nvim/init.lua
link scripts/report-repo-status.sh .local/bin/repo-status

# ── Claude Code config ──────────────────────────────────────────────────────
# settings.local.json stays machine-local and is intentionally NOT linked.
link claude/CLAUDE.md .claude/CLAUDE.md
link claude/settings.json .claude/settings.json
link claude/statusline.sh .claude/statusline.sh
link scripts/agent-bus.sh .claude/agent-bus.sh
link scripts/plan-run-guard.sh .claude/plan-run-guard.sh
link .claude/agents .claude/agents
link .claude/skills .claude/skills
# Copilot CLI reads ~/.agents/skills, not ~/.claude/skills.
link .claude/skills .agents/skills

# ~/.claude.json holds machine state (auth, project list), so it is merged, not linked.
# It carries the /config choices that have no settings.json key.
CLAUDE_JSON="$HOME/.claude.json"
[[ -f "$CLAUDE_JSON" ]] || echo '{}' > "$CLAUDE_JSON"
tmp="$(mktemp)"
jq '. + {leftArrowOpensAgents: false}' "$CLAUDE_JSON" > "$tmp" && mv "$tmp" "$CLAUDE_JSON"
log "Merged /config prefs into $CLAUDE_JSON"

# ── Git config defaults ─────────────────────────────────────────────────────
log "Setting git config defaults…"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global push.autoSetupRemote true
git config --global rerere.enabled true
git config --global fetch.prune true
git config --global rebase.autoStash true
git config --global core.editor nano
git config --global merge.conflictStyle zdiff3
# delta as pager if installed, else fall back (safe on machines without delta)
git config --global core.pager 'delta || less'
git config --global interactive.diffFilter 'delta --color-only || cat'
git config --global delta.navigate true
git config --global delta.line-numbers true

# ── Commit signing ──────────────────────────────────────────────────────────
SIGNING_KEY="$HOME/.ssh/id_ed25519.pub"
if [[ -f "$SIGNING_KEY" ]]; then
  ALLOWED_SIGNERS="$HOME/.config/git/allowed-signers"
  git config --global gpg.format ssh
  git config --global user.signingkey "$SIGNING_KEY"
  git config --global commit.gpgsign true
  git config --global tag.gpgsign true
  git config --global gpg.ssh.allowedSignersFile "$ALLOWED_SIGNERS"
  email="$(git config --global user.email || true)"
  key="$(cut -d' ' -f1,2 "$SIGNING_KEY")"
  if [[ -n "$email" ]] && ! grep -qF "$key" "$ALLOWED_SIGNERS" 2>/dev/null; then
    mkdir -p "$(dirname "$ALLOWED_SIGNERS")"
    echo "$email $key" >> "$ALLOWED_SIGNERS"
  fi
  log "Commits and tags are SSH-signed with $SIGNING_KEY"
else
  log "SKIP: $SIGNING_KEY not found, commit signing not configured"
fi

# ── GitHub CLI ──────────────────────────────────────────────────────────────
if command -v gh >/dev/null 2>&1; then
  log "gh already installed: $(gh --version | head -1)"
else
  log "gh missing: install it from its apt repo, https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
fi

log "Done – restart your shell or run: source ~/.bashrc"
