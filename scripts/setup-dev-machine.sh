#!/usr/bin/env bash
# setup-dev-machine.sh – check an Ubuntu dev machine against the handbook, then fix what differs
#
# Usage (from a handbook clone):
#   sudo scripts/setup-dev-machine.sh          # check, then ask before each fix
#   sudo scripts/setup-dev-machine.sh --yes    # check, then fix all; human steps still prompt
#   scripts/setup-dev-machine.sh --check       # report only, no root; exit 1 if anything differs
#
# What it does:
#   1. Prints one line per item: ok, MISSING, OUTDATED or WRONG, with the reason
#   2. Walks the items that differ in the order of ITEMS and fixes each after a [Y/n/q] prompt
#   3. Runs apt, snap and usermod as root; everything in $HOME runs as the user who ran sudo
#   4. Updates only the tools listed here; unattended-upgrades handles the rest of the system
#
# Human steps: git identity, SSH key passphrase, gh login, the GitHub key title.
set -euo pipefail

usage() {
  printf 'usage: %s [--check | --yes]\n' "$0" >&2
}

MODE=ask
case "$#:${1:-}" in
  0:) ;;
  1:--check) MODE=check ;;
  1:--yes) MODE=yes ;;
  *) usage; exit 2 ;;
esac

# ── Configuration ────────────────────────────────────────────────────────────
NODE_CHANNEL="${NODE_CHANNEL:-26/stable}"           # Node's snap channel; refreshes within the major
TARGET_USER="${TARGET_USER:-${SUDO_USER:-$(id -un)}}"
TARGET_HOME="${TARGET_HOME:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}"
USER_PATH="${USER_PATH:-$TARGET_HOME/.local/bin:$TARGET_HOME/go/bin:/snap/bin:/usr/local/bin:/usr/bin:/bin}"
ETC_DIR="${ETC_DIR:-/etc}"                          # the fixture test points this at a temp dir
SETUP_ALLOW_NONROOT="${SETUP_ALLOW_NONROOT:-false}" # the fixture test only: skip the root guard
# ─────────────────────────────────────────────────────────────────────────────

HANDBOOK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HANDBOOK_SSH_URL="git@github.com:nicograef/handbook.git"

APT_PACKAGES=(git jq curl gcc make shellcheck tmux bat eza fzf fd-find ripgrep git-delta gitleaks
  xclip pipx docker.io docker-compose-v2 docker-buildx)
SNAPS=("node $NODE_CHANNEL" "go latest/stable" "nvim latest/stable")
NPM_TOOLS=(pnpm)
# guides/neovim.md repeats these two lists for servers; check-repo's contracts stage compares them.
NPM_SERVERS=(typescript bash-language-server yaml-language-server vscode-langservers-extracted tree-sitter-cli)
UV_TOOLS=(ruff ty)
NPM_ALLOW_SCRIPTS="pnpm,tree-sitter-cli" # their install scripts put the native binary in place

# Apply order: each item may rely on the ones above it.
ITEMS=(
  "apt|apt packages"
  "ghrepo|gh apt repo"
  "snaps|snaps"
  "aptnvim|no apt neovim"
  "docker|docker group"
  "gitid|git identity"
  "sshkey|SSH key"
  "ghauth|gh login"
  "uv|uv"
  "npm|npm tools"
  "uvtools|uv tools"
  "claude|Claude Code"
  "dotfiles|dotfiles and config"
  "sshconfig|SSH config"
  "ghkeys|GitHub keys"
  "remote|handbook remote"
  "font|Nerd Font"
  "nvim|Neovim plugins"
)

KEY="$TARGET_HOME/.ssh/id_ed25519"
KEYRING="$ETC_DIR/apt/keyrings/githubcli-archive-keyring.gpg"
GH_LIST="$ETC_DIR/apt/sources.list.d/github-cli.list"
GH_LIST_LINE="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"
GH_UU="$ETC_DIR/apt/apt.conf.d/52unattended-upgrades-gh"
GH_UU_LINE='Unattended-Upgrade::Origins-Pattern { "origin=gh,codename=stable"; };'
GH_KEY_SCOPES="admin:public_key,admin:ssh_signing_key" # to list and add both key types
NVIM_DATA="$TARGET_HOME/.local/share/nvim/site"
NVIM_LOCK="$HANDBOOK_DIR/dotfiles/nvim/nvim-pack-lock.json"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.tar.xz"
# The parser list lives in init.lua's nvim-treesitter install call.
mapfile -t PARSERS < <(sed -n "/require('nvim-treesitter').install({/,/})/p" "$HANDBOOK_DIR/dotfiles/nvim/init.lua" \
  | sed 1d | grep -o "'[a-z_]*'" | tr -d "'")

log() { printf '\033[1;34m▸ %s\033[0m\n' "$1"; }
die() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

# as_user <cmd...> — run in the user's home with a clean environment; the session bus keeps gh's keyring.
as_user() {
  local run="/run/user/$TARGET_UID"
  local -a envs=(HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" PATH="$USER_PATH"
    TERM="${TERM:-dumb}" LANG=C.UTF-8 LC_ALL=C.UTF-8)
  if [[ -d "$run" ]]; then
    envs+=(XDG_RUNTIME_DIR="$run" DBUS_SESSION_BUS_ADDRESS="unix:path=$run/bus")
  fi
  if [[ -n "${DISPLAY:-}" ]]; then envs+=(DISPLAY="$DISPLAY"); fi
  if [[ "$(id -u)" == "$TARGET_UID" ]]; then
    env -i "${envs[@]}" "$@"
  else
    sudo -u "$TARGET_USER" env -i "${envs[@]}" "$@"
  fi
}

# shellcheck disable=SC2016 # $1 expands in the inner shell
user_has() { as_user sh -c 'command -v "$1"' _ "$1" >/dev/null 2>&1; }
installed() { [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" == "install ok installed" ]]; }
in_list() { [[ " $2 " == *" $1 "* ]]; }

# Upgradable apt packages and refreshable snaps, read once per pass.
refresh_caches() {
  APT_UPGRADABLE="$(LC_ALL=C apt list --upgradable 2>/dev/null | sed -n 's|/.*||p' | tr '\n' ' ')"
  SNAP_REFRESHABLE="$(LC_ALL=C snap refresh --list 2>/dev/null | awk 'NR > 1 {print $1}' | tr '\n' ' ')"
}

# flag <status> <detail> — the first non-ok status sticks; details accumulate.
flag() {
  if [[ "$STATUS" == ok ]]; then STATUS="$1"; fi
  DETAIL+="${DETAIL:+; }$2"
}

ask() {
  local reply
  read -r -p "$1 " reply || reply=n
  printf '%s' "$reply"
}

# ── Items: check_<id> sets STATUS and DETAIL, fix_<id> brings the item to target ─

check_apt() {
  local p missing=() old=()
  for p in "${APT_PACKAGES[@]}"; do
    if ! installed "$p"; then missing+=("$p"); elif in_list "$p" "$APT_UPGRADABLE"; then old+=("$p"); fi
  done
  if ((${#missing[@]})); then flag MISSING "${missing[*]}"; fi
  if ((${#old[@]})); then flag OUTDATED "${old[*]}"; fi
}
# install also upgrades an installed package to its candidate.
fix_apt() { apt-get install -y "${APT_PACKAGES[@]}"; }

check_ghrepo() {
  if [[ ! -s "$KEYRING" ]]; then flag MISSING "keyring"; fi
  if [[ "$(cat "$GH_LIST" 2>/dev/null)" != "$GH_LIST_LINE" ]]; then flag WRONG "$GH_LIST"; fi
  if [[ "$(cat "$GH_UU" 2>/dev/null)" != "$GH_UU_LINE" ]]; then flag WRONG "$GH_UU"; fi
  if ! installed gh; then flag MISSING gh; elif in_list gh "$APT_UPGRADABLE"; then flag OUTDATED gh; fi
}
fix_ghrepo() {
  install -d -m 755 "$(dirname "$KEYRING")" "$(dirname "$GH_LIST")" "$(dirname "$GH_UU")"
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "$KEYRING"
  chmod go+r "$KEYRING"
  printf '%s\n' "$GH_LIST_LINE" > "$GH_LIST"
  printf '%s\n' "$GH_UU_LINE" > "$GH_UU"
  apt-get update -qq
  apt-get install -y gh
}

check_snaps() {
  local entry name channel tracking
  for entry in "${SNAPS[@]}"; do
    name="${entry% *}" channel="${entry#* }"
    tracking="$(LC_ALL=C snap list "$name" 2>/dev/null | awk 'NR == 2 {print $4}' || true)"
    if [[ -z "$tracking" ]]; then
      flag MISSING "$name"
    elif [[ "$tracking" != "$channel" ]]; then
      flag WRONG "$name tracks $tracking, not $channel"
    elif in_list "$name" "$SNAP_REFRESHABLE"; then
      flag OUTDATED "$name"
    fi
  done
}
fix_snaps() {
  local entry name channel
  for entry in "${SNAPS[@]}"; do
    name="${entry% *}" channel="${entry#* }"
    if snap list "$name" >/dev/null 2>&1; then
      snap refresh "$name" --channel="$channel"
    else
      snap install "$name" --classic --channel="$channel"
    fi
  done
}

# /usr/bin precedes /snap/bin, so the apt package would shadow the snap.
check_aptnvim() { if installed neovim; then flag WRONG "apt neovim shadows the snap"; fi; }
fix_aptnvim() { apt-get remove -y neovim; }

check_docker() {
  if ! in_list docker "$(id -nG "$TARGET_USER")"; then flag MISSING "$TARGET_USER not in docker"; fi
}
fix_docker() { usermod -aG docker "$TARGET_USER"; }

check_gitid() {
  if [[ -z "$(as_user git config --global user.name || true)" ]]; then flag MISSING user.name; fi
  if [[ -z "$(as_user git config --global user.email || true)" ]]; then flag MISSING user.email; fi
}
fix_gitid() {
  local name email
  name="$(ask 'git user.name:')" email="$(ask 'git user.email:')"
  [[ -n "$name" && -n "$email" ]] || { printf 'Both values are required.\n'; return 1; }
  as_user git config --global user.name "$name"
  as_user git config --global user.email "$email"
}

check_sshkey() { if [[ ! -f "$KEY.pub" ]]; then flag MISSING "$KEY.pub"; fi; }
fix_sshkey() {
  as_user mkdir -p -m 700 "$TARGET_HOME/.ssh"
  as_user ssh-keygen -t ed25519 -C "$(as_user git config --global user.email)" -f "$KEY"
}

check_ghauth() {
  if ! user_has gh; then flag MISSING "gh not installed"; return; fi
  if ! as_user gh auth status >/dev/null 2>&1; then flag MISSING "not logged in"; fi
}
# The GitHub keys item uploads the key; the scopes it needs come with this login.
fix_ghauth() { as_user gh auth login -h github.com -p ssh --skip-ssh-key -s "$GH_KEY_SCOPES"; }

check_uv() {
  local current latest
  if ! user_has uv; then flag MISSING uv; return; fi
  current="$(as_user uv --version | awk '{print $2}')"
  latest="$(curl -fsS --max-time 10 https://pypi.org/pypi/uv/json 2>/dev/null | jq -r '.info.version' || true)"
  if [[ -n "$latest" && "$current" != "$latest" ]]; then flag OUTDATED "uv $current → $latest"; fi
}
# .bash_aliases puts ~/.local/bin on PATH for new terminals.
fix_uv() { if user_has uv; then as_user pipx upgrade uv; else as_user pipx install uv; fi; }

check_npm() {
  local p have old prefix
  if ! user_has npm; then flag MISSING "npm; install the node snap first"; return; fi
  prefix="$(as_user npm config get prefix)"
  if [[ "$prefix" != "$TARGET_HOME/.local" ]]; then flag WRONG "npm prefix is $prefix"; fi
  if [[ "$(as_user npm config get allow-scripts)" != "$NPM_ALLOW_SCRIPTS" ]]; then flag WRONG "allow-scripts"; fi
  have="$(as_user npm ls -g --depth=0 --json 2>/dev/null | jq -r '.dependencies // {} | keys[]' | tr '\n' ' ' || true)"
  old="$(as_user npm outdated -g --json 2>/dev/null | jq -r 'keys[]' | tr '\n' ' ' || true)"
  NPM_FIX=()
  for p in "${NPM_TOOLS[@]}" "${NPM_SERVERS[@]}"; do
    if ! in_list "$p" "$have"; then flag MISSING "$p"; NPM_FIX+=("$p@latest");
    elif in_list "$p" "$old"; then flag OUTDATED "$p"; NPM_FIX+=("$p@latest"); fi
  done
}
fix_npm() {
  as_user npm config set prefix "$TARGET_HOME/.local"
  as_user npm config set allow-scripts="$NPM_ALLOW_SCRIPTS" --location=user
  if ((${#NPM_FIX[@]})); then as_user npm install -g "${NPM_FIX[@]}"; fi
}

check_uvtools() {
  local t have old
  if ! user_has uv; then flag MISSING "uv"; return; fi
  have="$(as_user uv tool list 2>/dev/null | awk '!/^-/ {print $1}' | tr '\n' ' ')"
  old="$(as_user uv tool list --outdated 2>/dev/null | awk '!/^-/ {print $1}' | tr '\n' ' ')"
  for t in "${UV_TOOLS[@]}"; do
    if ! in_list "$t" "$have"; then flag MISSING "$t"; elif in_list "$t" "$old"; then flag OUTDATED "$t"; fi
  done
}
fix_uvtools() {
  local t have
  have="$(as_user uv tool list 2>/dev/null | awk '!/^-/ {print $1}' | tr '\n' ' ')"
  for t in "${UV_TOOLS[@]}"; do
    if in_list "$t" "$have"; then as_user uv tool upgrade "$t"; else as_user uv tool install "$t"; fi
  done
}

# The native install updates itself, so only presence is checked.
check_claude() { if ! user_has claude; then flag MISSING claude; fi; }
fix_claude() { as_user bash -c 'curl -fsSL https://claude.ai/install.sh | bash'; }

check_dotfiles() {
  local origin dest wrong=()
  while read -r origin dest; do
    if [[ "$(readlink -f "$TARGET_HOME/$dest")" != "$(readlink -f "$HANDBOOK_DIR/$origin")" ]]; then
      wrong+=("$dest")
    fi
  done < <("$HANDBOOK_DIR/scripts/install-dotfiles.sh" --check)
  if ((${#wrong[@]})); then flag WRONG "unlinked in home: ${wrong[*]}"; fi
  if user_has claude && ! as_user claude plugin list --json 2>/dev/null \
    | jq -e 'any(.id == "nico@handbook" and .enabled)' >/dev/null; then
    flag MISSING "plugin nico@handbook"
  fi
  if [[ -f "$KEY.pub" && "$(as_user git config --global commit.gpgsign || true)" != true ]]; then
    flag MISSING "commit signing"
  fi
}
fix_dotfiles() { as_user "$HANDBOOK_DIR/install.sh"; }

check_sshconfig() { if [[ ! -f "$TARGET_HOME/.ssh/config" ]]; then flag MISSING "$TARGET_HOME/.ssh/config"; fi; }
fix_sshconfig() {
  as_user mkdir -p -m 700 "$TARGET_HOME/.ssh"
  as_user cp --update=none "$HANDBOOK_DIR/templates/ssh_config" "$TARGET_HOME/.ssh/config"
  as_user chmod 600 "$TARGET_HOME/.ssh/config"
}

# missing_key_types — the types of the local key that GitHub lacks, space-separated.
missing_key_types() {
  local key list type out=""
  key="$(cut -d' ' -f2 "$KEY.pub")"
  list="$(as_user gh ssh-key list 2>/dev/null || true)"
  for type in authentication signing; do
    if ! awk -v k="$key" -v t="$type" 'index($0, k) && $NF == t {found = 1} END {exit !found}' <<<"$list"; then
      out+="$type "
    fi
  done
  printf '%s' "$out"
}
check_ghkeys() {
  local missing
  if [[ ! -f "$KEY.pub" ]]; then flag MISSING "no SSH key"; return; fi
  if ! user_has gh || ! as_user gh auth status >/dev/null 2>&1; then flag MISSING "gh not logged in"; return; fi
  missing="$(missing_key_types)"
  if [[ -n "$missing" ]]; then flag MISSING "${missing% } key"; fi
}
fix_ghkeys() {
  local status scope type title
  # A login made outside this script may lack the scopes, and then the key list reads empty.
  status="$(as_user gh auth status 2>&1 || true)"
  for scope in ${GH_KEY_SCOPES//,/ }; do
    if [[ "$status" != *"'$scope'"* ]]; then as_user gh auth refresh -h github.com -s "$GH_KEY_SCOPES"; break; fi
  done
  title="$(ask "Key title on GitHub [$(hostname)]:")"
  title="${title:-$(hostname)}"
  for type in $(missing_key_types); do
    as_user gh ssh-key add "$KEY.pub" --type "$type" --title "$title"
  done
}

check_remote() {
  local url
  url="$(as_user git -C "$HANDBOOK_DIR" remote get-url origin 2>/dev/null || true)"
  if [[ "$url" != "$HANDBOOK_SSH_URL" ]]; then flag WRONG "origin is ${url:-unset}"; fi
}
fix_remote() { as_user git -C "$HANDBOOK_DIR" remote set-url origin "$HANDBOOK_SSH_URL"; }

check_font() {
  if [[ "$(as_user fc-list : family 2>/dev/null || true)" != *[Nn]erd* ]]; then flag MISSING "no Nerd Font"; fi
}
fix_font() {
  as_user mkdir -p "$TARGET_HOME/.local/share/fonts/nerd"
  # shellcheck disable=SC2016 # $1 and $2 expand in the inner shell
  as_user bash -c 'curl -fsSL "$1" | tar -C "$2" -xJf -' _ "$FONT_URL" "$TARGET_HOME/.local/share/fonts/nerd"
  as_user fc-cache -f
}

check_nvim() {
  local name rev actual missing=()
  if ! user_has nvim; then flag MISSING "nvim not installed"; return; fi
  while read -r name rev; do
    actual="$(as_user git -C "$NVIM_DATA/pack/core/opt/$name" rev-parse HEAD 2>/dev/null || true)"
    if [[ -z "$actual" ]]; then flag MISSING "$name"; elif [[ "$actual" != "$rev" ]]; then flag WRONG "$name off the lockfile"; fi
  done < <(jq -r '.plugins | to_entries[] | "\(.key) \(.value.rev)"' "$NVIM_LOCK")
  for name in "${PARSERS[@]}"; do
    if [[ ! -f "$NVIM_DATA/parser/$name.so" ]]; then missing+=("$name"); fi
  done
  if ((${#missing[@]})); then flag MISSING "parsers: ${missing[*]}"; fi
}
fix_nvim() {
  local langs
  langs="$(printf "'%s'," "${PARSERS[@]}")"
  as_user nvim --headless "+lua vim.pack.update(nil, { target = 'lockfile', force = true })" \
    "+lua require('nvim-treesitter').install({ ${langs%,} }):wait(600000)" +qa
}

# ── Main ─────────────────────────────────────────────────────────────────────

# run_check <id> — reset STATUS and DETAIL, then run the item's check.
run_check() {
  STATUS=ok DETAIL=""
  "check_$1"
}

print_row() { printf '%-9s %-20s %s\n' "$STATUS" "$2" "$DETAIL"; }

[[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] || die "no home directory for user '$TARGET_USER'"
command -v jq >/dev/null 2>&1 || die "jq not found; install it first (apt install git jq)"
TARGET_UID="$(id -u "$TARGET_USER")"
if [[ "$MODE" != check && "$SETUP_ALLOW_NONROOT" != true ]]; then
  [[ "$EUID" -eq 0 ]] || die "run with sudo, or pass --check to report only"
  [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]] || die "run with sudo from your own account, not as root"
fi

if [[ "$MODE" != check ]]; then
  log "Refreshing apt indexes"
  apt-get update -qq
fi
refresh_caches

log "Checking $TARGET_USER's machine against $HANDBOOK_DIR"
bad=0
for entry in "${ITEMS[@]}"; do
  run_check "${entry%%|*}"
  print_row "${entry%%|*}" "${entry#*|}"
  if [[ "$STATUS" != ok ]]; then bad=$((bad + 1)); fi
done

if [[ "$MODE" == check || "$bad" -eq 0 ]]; then
  if [[ "$bad" -eq 0 ]]; then log "Everything matches the handbook"; fi
  exit $((bad > 0))
fi

RELOGIN=false
left=()
for entry in "${ITEMS[@]}"; do
  id="${entry%%|*}" label="${entry#*|}"
  run_check "$id"
  if [[ "$STATUS" == ok ]]; then continue; fi
  reply=y
  # Removing a package always asks, --yes included.
  if [[ "$MODE" == ask || "$id" == aptnvim ]]; then
    reply="$(ask "Fix $label ($DETAIL)? [Y/n/q]")"
  fi
  case "${reply:-y}" in
    q|Q) left+=("$label"); break ;;
    n|N) left+=("$label"); continue ;;
  esac
  log "Fixing $label"
  # A subshell outside any condition keeps errexit on inside the fix.
  set +e
  (set -e; "fix_$id")
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then printf 'Fix for %s failed (exit %s).\n' "$label" "$rc" >&2; fi
  refresh_caches
  run_check "$id"
  print_row "$id" "$label"
  # A running session keeps its groups, and a running terminal its font list.
  if [[ "$STATUS" != ok ]]; then left+=("$label"); elif [[ "$id" == docker || "$id" == font ]]; then RELOGIN=true; fi
done

if [[ "$RELOGIN" == true ]]; then log "Log out and back in: the session then has the docker group and the terminal finds the new font"; fi
if ((${#left[@]})); then
  log "Still differs: $(IFS=,; printf '%s' "${left[*]}")"
  exit 1
fi
log "Done – open a new terminal for the new PATH"
