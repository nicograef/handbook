#!/usr/bin/env bash
# install-dotfiles.sh – bootstrap shell config in a new environment
#
# Usage:
#   scripts/install-dotfiles.sh           # link, merge and configure; install.sh runs this
#   scripts/install-dotfiles.sh --check   # pre-flight only: print "<origin> <dest>" per link
#
# Run after cloning the repo:
#   git clone https://github.com/nicograef/handbook.git && cd handbook && ./install.sh
#
# What it does:
#   1. Pre-flight: jq present, every link origin exists; any failure exits 1 before a change
#   2. Symlinks .bash_aliases, .tmux.conf, .inputrc, the global git ignore, the Neovim
#      init.lua and repo-status into $HOME;
#      a real file or directory in the way is moved to <name>.bak
#   3. Symlinks Claude Code config (global CLAUDE.md, settings, agents, skills,
#      agent-bus.sh, plan-run-guard.sh, git-guard.sh and check-agents.sh — the
#      global hooks in settings.json and the skills call them by those paths)
#   4. Sets git config defaults (pull.rebase, fetch.prune, etc.)
#   5. Sets up SSH commit signing when ~/.ssh/id_ed25519.pub exists
#   6. Points to the gh install docs if gh is missing
#
# --check touches nothing; its origins are relative to the repo, its dests to $HOME.
# .bashrc is left alone: the Ubuntu default sources ~/.bash_aliases.
set -euo pipefail

usage() {
  printf 'usage: %s [--check]\n' "$0" >&2
}

CHECK=false
case "$#:${1:-}" in
  0:) ;;
  1:--check) CHECK=true ;;
  *) usage; exit 2 ;;
esac

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

log() { printf '\033[1;34m▸ %s\033[0m\n' "$1"; }

# The one link table, as "<origin> <dest>": origin relative to the repo, dest to $HOME.
# settings.local.json stays machine-local and is intentionally NOT linked.
# Copilot CLI reads ~/.agents/skills, not ~/.claude/skills.
LINKS=(
  "dotfiles/.bash_aliases .bash_aliases"
  "dotfiles/.tmux.conf .tmux.conf"
  "dotfiles/.inputrc .inputrc"
  "dotfiles/gitignore-global .config/git/ignore"
  "dotfiles/init.lua .config/nvim/init.lua"
  "scripts/report-repo-status.sh .local/bin/repo-status"
  "claude/CLAUDE.md .claude/CLAUDE.md"
  "claude/settings.json .claude/settings.json"
  "claude/statusline.sh .claude/statusline.sh"
  "scripts/agent-bus.sh .claude/agent-bus.sh"
  "scripts/plan-run-guard.sh .claude/plan-run-guard.sh"
  "scripts/git-guard.sh .claude/git-guard.sh"
  "scripts/check-agents.sh .claude/check-agents.sh"
  ".claude/agents .claude/agents"
  ".claude/skills .claude/skills"
  ".claude/skills .agents/skills"
)

# Checks every precondition before the first change; exits 1 naming each failure.
preflight() {
  local entry origin ok=true
  if ! command -v jq >/dev/null 2>&1; then
    printf 'ERROR: jq not found; install it first (apt install jq)\n' >&2
    ok=false
  fi
  for entry in "${LINKS[@]}"; do
    origin="${entry%% *}"
    if [[ ! -e "$DOTFILES_DIR/$origin" ]]; then
      printf 'ERROR: link origin not found: %s\n' "$origin" >&2
      ok=false
    fi
  done
  [[ "$ok" == true ]] || exit 1
}

# Moves a real file or directory at the destination to .bak, then links it.
link() {
  local origin="$DOTFILES_DIR/$1" dest="$HOME/$2"
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    mv -T --backup=numbered "$dest" "$dest.bak"
    log "Moved $dest to $dest.bak"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -sfnT "$origin" "$dest"
  log "Linked $dest → $origin"
}

preflight

if [[ "$CHECK" == true ]]; then
  printf '%s\n' "${LINKS[@]}"
  exit 0
fi

# ── Symlink dotfiles and Claude Code config ─────────────────────────────────
for entry in "${LINKS[@]}"; do
  link "${entry%% *}" "${entry#* }"
done

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
