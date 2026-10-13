#!/usr/bin/env bash
# install-dotfiles.sh – bootstrap shell config in a new environment
#
# Usage:
#   scripts/install-dotfiles.sh            # link, merge and configure; install.sh runs this
#   scripts/install-dotfiles.sh --check    # pre-flight only: print "<origin> <dest>" per link
#   scripts/install-dotfiles.sh --status   # change nothing: print "<status> <item>" per item a run would change
#
# What it does:
#   1. Pre-flight: jq present, every link origin exists, both plugin manifests name the plugin
#   2. Symlinks every LINKS entry below into $HOME: shell dotfiles, Neovim, repo-status and the
#      Claude Code config; a real file or directory in the way is moved to <name>.bak, and an
#      older <name>.bak to <name>.bak.~N~. A link already in place is left alone.
#      Removes links in ~/.claude and ~/.agents that point into this repo at a file that is gone.
#   3. Selects the handbook palette in Ptyxis's default profile when Ptyxis is installed
#   4. Installs the plugin in plugin/ (skills, agent, hooks) when claude is on PATH; a disabled one stays disabled
#   5. Merges the /config prefs into ~/.claude.json
#   6. Sets git config defaults (pull.rebase, fetch.prune, etc.)
#   7. Sets up SSH commit signing when ~/.ssh/id_ed25519.pub exists
#   8. Points to the gh install docs if gh is missing
#
# Each step acts only when its item differs. --status runs the same probes: one MISSING or WRONG line
# per item, an ok line for a note, exit 1 when an item differs. A failed pre-flight or command exits 2.
#
# .bashrc is left alone: the Ubuntu default sources ~/.bash_aliases.
set -Eeuo pipefail

usage() {
  printf 'usage: %s [--check | --status]\n' "$0" >&2
}

MODE=apply
case "$#:${1:-}" in
  0:) ;;
  1:--check) MODE=check ;;
  1:--status) MODE=status ;;
  *) usage; exit 2 ;;
esac

# on_err <line> — exit 2 keeps --status's exit 1 for drift alone. A subshell passes its code to the caller's trap.
on_err() {
  local rc=$?
  if [[ "$BASHPID" != "$$" ]]; then exit "$rc"; fi
  printf 'ERROR: %s failed (exit %s, line %s)\n' "$BASH_COMMAND" "$rc" "$1" >&2
  exit 2
}
trap 'on_err "$LINENO"' ERR

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_META="$DOTFILES_DIR/plugin/.claude-plugin"

log() { if [[ "$MODE" != status ]]; then printf '\033[1;34m▸ %s\033[0m\n' "$1"; fi; }

DRIFT=false
# differs <status> <item> — --status prints the item and fails; any other mode succeeds, so the caller fixes it.
differs() {
  if [[ "$MODE" != status ]]; then return 0; fi
  printf '%s %s\n' "$1" "$2"
  DRIFT=true
  return 1
}
# remark <note> — an ok line under --status, a log line otherwise.
remark() { if [[ "$MODE" == status ]]; then printf 'ok %s\n' "$1"; else log "$1"; fi; }

# The one link table, as "<origin> <dest>": origin relative to the repo, dest to $HOME.
# settings.local.json stays machine-local and is intentionally NOT linked.
# Copilot CLI reads ~/.agents/skills; Claude Code reads the plugin's skills.
LINKS=(
  "dotfiles/.bash_aliases .bash_aliases"
  "dotfiles/.tmux.conf .tmux.conf"
  "dotfiles/.inputrc .inputrc"
  "dotfiles/gitignore-global .config/git/ignore"
  "dotfiles/nvim .config/nvim"
  "dotfiles/ptyxis/catppuccin-mocha-grey.palette .local/share/org.gnome.Ptyxis/palettes/catppuccin-mocha-grey.palette"
  "scripts/report-repo-status.sh .local/bin/repo-status"
  "claude/global.md .claude/CLAUDE.md"
  "claude/settings.json .claude/settings.json"
  "claude/statusline.sh .claude/statusline.sh"
  "plugin/scripts/agent-bus.sh .claude/agent-bus.sh"
  "plugin/scripts/check-agents.sh .claude/check-agents.sh"
  "plugin/skills .agents/skills"
)

preflight() {
  local entry origin manifest ok=true
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
  for manifest in plugin.json marketplace.json; do
    if [[ "$ok" == true ]] && ! jq -e '.name | strings | length > 0' "$PLUGIN_META/$manifest" >/dev/null 2>&1; then
      printf 'ERROR: plugin/.claude-plugin/%s has no name\n' "$manifest" >&2
      ok=false
    fi
  done
  [[ "$ok" == true ]] || exit 2
}

# Moves a real file or directory at the destination to .bak, then links it.
link() {
  local origin="$DOTFILES_DIR/$1" dest="$HOME/$2" status=MISSING
  if [[ -L "$dest" && "$(readlink "$dest")" == "$origin" ]]; then return; fi
  if [[ -e "$dest" || -L "$dest" ]]; then status=WRONG; fi
  differs "$status" "link ~/$2" || return 0
  relinked=true
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    mv -T --backup=numbered "$dest" "$dest.bak"
    log "Moved $dest to $dest.bak"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -sfnT "$origin" "$dest"
  log "Linked $dest → $origin"
}

# git_set <key> <value> — set a global git key unless it holds the value.
git_set() {
  local current status=MISSING
  current="$(git config --global "$1" || true)"
  if [[ "$current" == "$2" ]]; then return; fi
  if [[ -n "$current" ]]; then status=WRONG; fi
  if differs "$status" "git $1"; then git config --global "$1" "$2"; fi
}

preflight

if [[ "$MODE" == check ]]; then
  printf '%s\n' "${LINKS[@]}"
  exit 0
fi

# The id claude gives the plugin: <plugin name>@<marketplace name>.
PLUGIN_ID="$(jq -r .name "$PLUGIN_META/plugin.json")@$(jq -r .name "$PLUGIN_META/marketplace.json")"

relinked=false
for entry in "${LINKS[@]}"; do
  link "${entry%% *}" "${entry#* }"
done
if [[ "$relinked" == false ]]; then log "Every link already in place"; fi

# A link into this repo whose target is gone names a moved or deleted file.
for dest in "$HOME"/.claude/* "$HOME"/.agents/*; do
  if [[ -L "$dest" && ! -e "$dest" && "$(readlink "$dest")" == "$DOTFILES_DIR"/* ]] \
    && differs WRONG "stale link ~/${dest#"$HOME"/}"; then
    rm "$dest"
    log "Removed stale link $dest"
  fi
done

# Ptyxis names a palette by its file name without .palette. It watches the palettes folder,
# not the link target: after editing the palette, re-run this script to re-link it.
if ! gsettings list-schemas 2>/dev/null | grep -qx org.gnome.Ptyxis; then
  log "SKIP: Ptyxis not installed, terminal palette not set"
elif ! uuid="$(gsettings get org.gnome.Ptyxis default-profile-uuid | tr -d "'")" || [[ -z "$uuid" ]]; then
  log "SKIP: Ptyxis has no default profile until its first start; rerun install.sh after it"
else
  profile="org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/$uuid/"
  if [[ "$(gsettings get "$profile" palette)" == "'catppuccin-mocha-grey'" ]]; then
    log "Ptyxis palette already catppuccin-mocha-grey"
  elif differs WRONG "Ptyxis palette"; then
    gsettings set "$profile" palette catppuccin-mocha-grey
    log "Ptyxis palette: catppuccin-mocha-grey"
  fi
fi

# claude/settings.json enables the plugin; registering its local marketplace makes it load.
if ! command -v claude >/dev/null 2>&1; then
  log "SKIP: claude not installed; rerun install.sh after installing Claude Code"
else
  plugins="$(claude plugin list --json)"
  if ! jq -e --arg id "$PLUGIN_ID" 'any(.id == $id)' >/dev/null <<<"$plugins"; then
    if differs MISSING "plugin $PLUGIN_ID"; then
      claude plugin marketplace add "$DOTFILES_DIR/plugin"
      claude plugin install "$PLUGIN_ID"
      log "Installed plugin $PLUGIN_ID"
    fi
  elif jq -e --arg id "$PLUGIN_ID" 'any(.id == $id and .enabled)' >/dev/null <<<"$plugins"; then
    log "Plugin $PLUGIN_ID already installed"
  else
    # A disabled plugin is the user's choice: reported, never re-enabled.
    remark "plugin $PLUGIN_ID disabled; enable it with /plugin"
  fi
fi

# ~/.claude.json holds machine state (auth, project list), so it is merged, not linked.
# It carries the /config choices that have no settings.json key.
# Running sessions write it too, so it is rewritten only when a pref differs.
CLAUDE_JSON="$HOME/.claude.json"
pref=MISSING
if [[ -f "$CLAUDE_JSON" ]] && jq -e 'has("leftArrowOpensAgents")' "$CLAUDE_JSON" >/dev/null; then pref=WRONG; fi
if [[ -f "$CLAUDE_JSON" ]] && jq -e '.leftArrowOpensAgents == false' "$CLAUDE_JSON" >/dev/null; then
  log "/config prefs already in $CLAUDE_JSON"
elif differs "$pref" "/config prefs in ~/.claude.json"; then
  [[ -f "$CLAUDE_JSON" ]] || echo '{}' > "$CLAUDE_JSON"
  tmp="$(mktemp)"
  jq '. + {leftArrowOpensAgents: false}' "$CLAUDE_JSON" > "$tmp"
  chmod --reference="$CLAUDE_JSON" "$tmp"
  mv "$tmp" "$CLAUDE_JSON"
  log "Merged /config prefs into $CLAUDE_JSON"
fi

git_set init.defaultBranch main
git_set pull.rebase true
git_set push.autoSetupRemote true
git_set fetch.prune true
git_set merge.conflictStyle zdiff3
# delta as pager if installed, else fall back (safe on machines without delta)
git_set core.pager 'delta || less'
git_set interactive.diffFilter 'delta --color-only || cat'
git_set delta.navigate true
git_set delta.line-numbers true
log "Git config defaults set"

SIGNING_KEY="$HOME/.ssh/id_ed25519.pub"
if [[ -f "$SIGNING_KEY" ]]; then
  ALLOWED_SIGNERS="$HOME/.config/git/allowed-signers"
  git_set gpg.format ssh
  git_set user.signingkey "$SIGNING_KEY"
  git_set commit.gpgsign true
  git_set tag.gpgsign true
  git_set gpg.ssh.allowedSignersFile "$ALLOWED_SIGNERS"
  email="$(git config --global user.email || true)"
  key="$(cut -d' ' -f1,2 "$SIGNING_KEY")"
  if [[ -n "$email" ]] && ! grep -qF "$key" "$ALLOWED_SIGNERS" 2>/dev/null \
    && differs MISSING "allowed signer ~/.ssh/id_ed25519.pub"; then
    mkdir -p "$(dirname "$ALLOWED_SIGNERS")"
    echo "$email $key" >> "$ALLOWED_SIGNERS"
  fi
  log "Commits and tags are SSH-signed with $SIGNING_KEY"
else
  log "SKIP: $SIGNING_KEY not found, commit signing not configured"
fi

if [[ "$MODE" == status ]]; then
  if [[ "$DRIFT" == true ]]; then exit 1; fi
  exit 0
fi

if command -v gh >/dev/null 2>&1; then
  log "gh already installed: $(gh --version | head -1)"
else
  log "gh missing: install it from its apt repo, https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
fi

log "Done – restart your shell or run: source ~/.bashrc"
