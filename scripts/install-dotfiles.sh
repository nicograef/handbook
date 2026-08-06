#!/usr/bin/env bash
# install-dotfiles.sh – bootstrap shell config in a new environment
#
# Called automatically by GitHub Codespaces when this repo is set as
# your dotfiles repository (Settings → Codespaces → Dotfiles).
# Can also be run manually after cloning the repo:
#   git clone https://github.com/nicograef/handbook.git && cd handbook && ./install.sh
#
# What it does:
#   1. Symlinks .bash_aliases and .tmux.conf into $HOME
#   2. Symlinks Claude Code config (global CLAUDE.md, settings, agents, skills,
#      agent-bus.sh — the global hooks in settings.json call it by that path)
#   3. Creates the handbook-plugin opt-out in adopted /workspaces repos
#   4. Sets git config defaults (pull.rebase, push.autoSetupRemote, etc.)
#   5. Installs gh CLI if missing (binary to ~/.local/bin, no sudo)
#
# Note: We intentionally do NOT replace .bashrc. The Codespaces default
# already includes a git-branch prompt, color support, and sources
# ~/.bash_aliases automatically. Overwriting it would lose those features.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

log() { printf '\033[1;34m▸ %s\033[0m\n' "$1"; }

# Guard: abort early if the repo root is wrong (templates/.bash_aliases missing),
# so we don't silently create broken symlinks.
if [[ ! -f "$DOTFILES_DIR/templates/.bash_aliases" ]]; then
  echo "ERROR: $DOTFILES_DIR/templates/.bash_aliases not found — run this from the handbook repo." >&2
  exit 1
fi

# ── Symlink dotfiles ────────────────────────────────────────────────────────
declare -A FILES=(
  ["templates/.bash_aliases"]=".bash_aliases"
  ["templates/.tmux.conf"]=".tmux.conf"
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

# ── Claude Code config ──────────────────────────────────────────────────────
# settings.local.json stays machine-local and is intentionally NOT linked.
mkdir -p "$HOME/.claude"
declare -A CLAUDE_LINKS=(
  ["claude/CLAUDE.md"]=".claude/CLAUDE.md"
  ["claude/settings.json"]=".claude/settings.json"
  ["claude/statusline.sh"]=".claude/statusline.sh"
  ["scripts/agent-bus.sh"]=".claude/agent-bus.sh"
  [".claude/agents"]=".claude/agents"
  [".claude/skills"]=".claude/skills"
)
for src in "${!CLAUDE_LINKS[@]}"; do
  origin="$DOTFILES_DIR/$src"
  dest="$HOME/${CLAUDE_LINKS[$src]}"
  if [[ -e "$origin" ]]; then
    ln -sfn "$origin" "$dest"
    log "Linked $dest → $origin"
  else
    echo "SKIP: $origin not found"
  fi
done

# Copilot CLI reads ~/.agents/skills, not ~/.claude/skills — mirror the skills there.
mkdir -p "$HOME/.agents"
if [[ -d "$DOTFILES_DIR/.claude/skills" ]]; then
  ln -sfn "$DOTFILES_DIR/.claude/skills" "$HOME/.agents/skills"
  log "Linked $HOME/.agents/skills → $DOTFILES_DIR/.claude/skills"
else
  echo "SKIP: $DOTFILES_DIR/.claude/skills not found"
fi

# ── Handbook plugin opt-out (Codespaces) ────────────────────────────────────
# Repos that adopt the handbook plugin via a committed .claude/settings.json
# would load every skill twice on a machine that also has the symlink tier
# above (guides/claude-plugin.md → "Dev-machine opt-out"). Codespaces clones
# the workspace repo before dotfiles run, so create the machine-local opt-out
# here. No-op outside Codespaces (no /workspaces) and on already-opted-out repos.
for settings in /workspaces/*/.claude/settings.json; do
  [[ -f "$settings" ]] || continue
  grep -Eq '"handbook@nicograef"[[:space:]]*:[[:space:]]*true' "$settings" || continue
  repo_dir="$(dirname "$(dirname "$settings")")"
  local_settings="$repo_dir/.claude/settings.local.json"
  if [[ -f "$local_settings" ]]; then
    log "Plugin opt-out already present: $local_settings"
  else
    printf '{ "enabledPlugins": { "handbook@nicograef": false } }\n' > "$local_settings"
    log "Created plugin opt-out: $local_settings"
  fi
  if ! git -C "$repo_dir" check-ignore -q .claude/settings.local.json 2>/dev/null; then
    echo "WARN: $repo_dir does not gitignore .claude/settings.local.json — add it there."
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
git config --global core.editor nano
git config --global merge.conflictStyle zdiff3
# delta as pager if installed, else fall back (safe on machines without delta)
git config --global core.pager 'delta || less'
git config --global interactive.diffFilter 'delta --color-only || cat'
git config --global delta.navigate true
git config --global delta.line-numbers true

# ── GitHub CLI ──────────────────────────────────────────────────────────────
# Pre-installed in Codespaces; install on local machines if missing.
if command -v gh >/dev/null 2>&1; then
  log "gh already installed: $(gh --version | head -1)"
else
  GH_VERSION="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/')" || true
  # gh release tarballs are named linux_amd64 / linux_arm64; map from dpkg's arch.
  GH_ARCH="$(dpkg --print-architecture)"   # amd64 or arm64 on Debian/Ubuntu
  if [[ -n "${GH_VERSION:-}" ]]; then
    log "Installing gh ${GH_VERSION} (linux_${GH_ARCH}) to ~/.local/bin…"
    mkdir -p "$HOME/.local/bin"
    TMP="$(mktemp -d)"
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz" \
      | tar -xz -C "$TMP"
    mv "$TMP/gh_${GH_VERSION}_linux_${GH_ARCH}/bin/gh" "$HOME/.local/bin/gh"
    chmod +x "$HOME/.local/bin/gh"
    rm -rf "$TMP"
    log "gh ${GH_VERSION} installed. Run 'gh auth login' to authenticate."
  else
    log "SKIP: Could not determine latest gh version (no curl or no network)."
  fi
fi

log "Done – restart your shell or run: source ~/.bashrc"
