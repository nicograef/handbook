#!/usr/bin/env bash
# setup-dev-machine.sh – check an Ubuntu or Debian dev machine against the handbook, then fix what differs
#
# Usage (from a handbook clone):
#   sudo scripts/setup-dev-machine.sh          # check, then ask before each fix
#   sudo scripts/setup-dev-machine.sh --yes    # check, then fix all; human steps still prompt
#   scripts/setup-dev-machine.sh --check       # report only, no root; exit 1 if anything differs
#
# What it does:
#   1. Reads the distro from /etc/os-release and refuses any but Ubuntu and Debian
#   2. Refuses a production server in every mode: /etc/handbook-role says prod, or setup-server.sh's
#      sshd drop-in marks a server without that file. A laptop has neither; a dev server's file says dev.
#   3. Prints one line per item: ok, MISSING, OUTDATED or WRONG, with the reason
#   4. Walks the items that differ in the order of ITEMS and fixes each after a [Y/n/q] prompt
#   5. Runs apt, snap, usermod and the /usr/local install as root; everything in $HOME runs as the user who ran sudo
#   6. Updates only the tools listed here; unattended-upgrades handles the rest of the system
#
# Node, Go and Neovim: snaps on Ubuntu. Debian has no snap, so Node comes from the nodejs.org tarball in
# /usr/local, Go from go.dev's tarball in /usr/local/go, and Neovim from the release tarball in ~/.local.
# An apt nodejs, NodeSource's included, is removed after its own prompt, once the tarball is in place.
# A host without a display server skips the Nerd Font and xclip; the client's terminal renders the font.
# Docker packages are installed, never upgraded: that restarts dockerd. A piped --yes skips the human steps.
# A probe that fails stops the run with an ERROR line naming it; --check exits 1 when an item differs.
#
# Human steps: git identity, SSH key passphrase, gh login, the GitHub key title.
set -Eeuo pipefail

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

log() { printf '\033[1;34m▸ %s\033[0m\n' "$1"; }
die() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

# on_err <line> — a failing command outside a condition ends the run; this names it. Subshells stay quiet.
on_err() {
  local rc=$?
  if [[ "$BASHPID" == "$$" ]]; then printf 'ERROR: %s failed (exit %s, line %s)\n' "$BASH_COMMAND" "$rc" "$1" >&2; fi
}
trap 'on_err "$LINENO"' ERR

# ── Configuration ────────────────────────────────────────────────────────────
NODE_CHANNEL="${NODE_CHANNEL:-26/stable}"           # Node's snap channel; on Debian, its major picks the tarball
TARGET_USER="${TARGET_USER:-${SUDO_USER:-$(id -un)}}"
TARGET_HOME="${TARGET_HOME:-$(getent passwd "$TARGET_USER" | cut -d: -f6)}"
# A new terminal's order: .bash_aliases puts ~/go/bin and ~/.local/bin before Ubuntu's PATH and /usr/local/go/bin after it.
USER_PATH="${USER_PATH:-$TARGET_HOME/go/bin:$TARGET_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/snap/bin:/usr/local/go/bin}"
ETC_DIR="${ETC_DIR:-/etc}"                          # the fixture test points this at a temp dir
GO_ROOT="${GO_ROOT:-/usr/local/go}"                 # Debian: go.dev's install path; the tarball unpacks a go/ dir
NODE_PREFIX="${NODE_PREFIX:-/usr/local}"            # Debian: the Node tarball's bin, include, lib and share land here
# The active Node.js releasers' primary keys, as the official Docker image pins them; the fixture test swaps them.
# Source: https://github.com/nodejs/release-keys#readme
NODE_KEYS="${NODE_KEYS:-5BE8A3F6C8A5C01D106C0AD820B1A390B168D356 DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7
  CC68F5A3106FF448322E48ED27F5E38D5B0A215F 890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4
  C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C 108F52B48DB57BB0CC439B2997B01419BD92F80A
  655F3B5C1FB3FA8D1A0CA6BDE4A7D232B936D2FD A363A499291CBBC940DD62E41F10027AF002F8B0}"
SETUP_ALLOW_NONROOT="${SETUP_ALLOW_NONROOT:-false}" # the fixture test only: skip the root guard
SETUP_ASSUME_TTY="${SETUP_ASSUME_TTY:-false}"       # the fixture test only: answer the human steps from a pipe
# ─────────────────────────────────────────────────────────────────────────────

DISTRO="$(sed -n 's/^ID="\{0,1\}\([a-z]*\).*/\1/p' "$ETC_DIR/os-release" 2>/dev/null || true)"
case "$DISTRO" in
  ubuntu|debian) ;;
  *) die "this script supports Ubuntu and Debian; $ETC_DIR/os-release names '${DISTRO:-nothing}'" ;;
esac

# setup-server.sh writes both files; a dev or agent server declares itself with its HOST_ROLE=dev rerun.
ROLE_FILE="$ETC_DIR/handbook-role"
SERVER_MARKER="$ETC_DIR/ssh/sshd_config.d/00-hardening.conf"
DEV_RERUN="on a dev server, rerun setup-server.sh with HOST_ROLE=dev"
if [[ -f "$ROLE_FILE" ]]; then
  ROLE="$(tr -d '[:space:]' < "$ROLE_FILE")"
  case "$ROLE" in
    dev) ;;
    prod) die "$ROLE_FILE says prod: a production server gets no dev toolchain; $DEV_RERUN" ;;
    *) printf 'ERROR: %s says %s, not prod or dev\n' "$ROLE_FILE" "${ROLE:-nothing}" >&2; usage; exit 2 ;;
  esac
elif [[ -f "$SERVER_MARKER" ]]; then
  die "$SERVER_MARKER marks a server, but $ROLE_FILE is missing; $DEV_RERUN"
fi

HANDBOOK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HANDBOOK_SSH_URL="git@github.com:nicograef/handbook.git"
ARCH="$(dpkg --print-architecture)"

# xclip and the docker packages join once dpkg can be asked about the display server and the Docker in use.
APT_PACKAGES=(git jq curl gcc make shellcheck tmux bat eza fzf fd-find ripgrep git-delta gitleaks lazygit pipx gpgv xz-utils)
DOCKER_PACKAGES=()
SNAPS=("node $NODE_CHANNEL" "go latest/stable" "nvim latest/stable")
NPM_TOOLS=(pnpm)
# guides/neovim.md repeats these two lists for servers; check-repo's contracts stage compares them.
NPM_SERVERS=(typescript bash-language-server yaml-language-server vscode-langservers-extracted tree-sitter-cli)
UV_TOOLS=(ruff ty)
NPM_ALLOW_SCRIPTS="pnpm,tree-sitter-cli" # their install scripts put the native binary in place

# Apply order: each item may rely on the ones above it.
ITEMS=("apt|apt packages" "ghrepo|gh apt repo")
if [[ "$DISTRO" == ubuntu ]]; then
  ITEMS+=("snaps|snaps")
else
  # The tarball lands first: /usr/local/bin precedes /usr/bin, so the apt Node goes only once it is replaced.
  ITEMS+=("node|Node" "aptnode|no apt nodejs" "go|Go" "nvimbin|Neovim")
fi
ITEMS+=(
  "aptnvim|no apt neovim"
  "docker|docker group"
  "gitid|git identity"
  "sshkey|SSH key"
  "ghauth|gh login"
  "uv|uv"
  "npm|npm tools"
  "uvtools|uv tools"
  "marksman|marksman"
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
GH_LIST_LINE="deb [arch=$ARCH signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"
GH_UU="$ETC_DIR/apt/apt.conf.d/52unattended-upgrades-gh"
GH_UU_LINE='Unattended-Upgrade::Origins-Pattern { "origin=gh,codename=stable"; };'
GH_KEY_SCOPES="admin:public_key,admin:ssh_signing_key" # to list and add both key types
NODE_MAJOR="${NODE_CHANNEL%%/*}"
NODE_KEYS="$(tr -s ' \n' '  ' <<<"$NODE_KEYS")"
NODE_KEYRING_URL="https://github.com/nodejs/release-keys/raw/HEAD/gpg-only-active-keys/pubring.kbx"
if [[ "$ARCH" == amd64 ]]; then NODE_ARCH=x64; else NODE_ARCH="$ARCH"; fi
NODE_MANIFEST="$NODE_PREFIX/lib/node-tarball.files" # what the last tarball install put under NODE_PREFIX
# What NodeSource's setup script writes; its keyring sits outside /etc.
NODESOURCE_FILES=("$ETC_DIR/apt/sources.list.d/nodesource.sources" "$ETC_DIR/apt/sources.list.d/nodesource.list"
  "$ETC_DIR/apt/keyrings/nodesource.gpg" "${ETC_DIR%/etc}/usr/share/keyrings/nodesource.gpg"
  "$ETC_DIR/apt/preferences.d/nodejs" "$ETC_DIR/apt/preferences.d/nsolid"
  "$ETC_DIR/apt/apt.conf.d/52unattended-upgrades-nodesource")
if [[ "$ARCH" == amd64 ]]; then NVIM_ARCH=x86_64; else NVIM_ARCH="$ARCH"; fi
NVIM_DIR="$TARGET_HOME/.local/nvim-linux-$NVIM_ARCH"
NVIM_LINK="$TARGET_HOME/.local/bin/nvim"
UV_BIN="$TARGET_HOME/.local/bin/uv"
NVIM_DATA="$TARGET_HOME/.local/share/nvim/site"
NVIM_LOCK="$HANDBOOK_DIR/dotfiles/nvim/nvim-pack-lock.json"
MARKSMAN_BIN="$TARGET_HOME/.local/bin/marksman"
MARKSMAN_API="https://api.github.com/repos/artempyanykh/marksman/releases/latest"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.tar.xz"
mapfile -t PARSERS < "$HANDBOOK_DIR/dotfiles/nvim/parsers.txt"

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
    env -i -C "$TARGET_HOME" "${envs[@]}" "$@"
  else
    sudo -u "$TARGET_USER" env -i -C "$TARGET_HOME" "${envs[@]}" "$@"
  fi
}

# shellcheck disable=SC2016 # $1 expands in the inner shell
user_has() { as_user sh -c 'command -v "$1"' _ "$1" >/dev/null 2>&1; }
gh_logged_in() { as_user gh auth status --active -h github.com >/dev/null 2>&1; }
installed() { [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" == "install ok installed" ]]; }
in_list() { [[ " $2 " == *" $1 "* ]]; }

# read_caches — upgradable apt packages and refreshable snaps. The fix loop clears CACHES_READ after each
# fix, so the next check that needs them reads them anew.
CACHES_READ=false
read_caches() {
  if [[ "$CACHES_READ" == true ]]; then return 0; fi
  CACHES_READ=true
  APT_UPGRADABLE="$(LC_ALL=C apt list --upgradable 2>/dev/null | sed -n 's|/.*||p' | tr '\n' ' ')"
  SNAP_REFRESHABLE=""
  if [[ "$DISTRO" == ubuntu ]] && command -v snap >/dev/null 2>&1; then
    SNAP_REFRESHABLE="$(LC_ALL=C snap refresh --list 2>/dev/null | awk 'NR > 1 {print $1}' | tr '\n' ' ')"
  fi
}

# read_releases — the newest uv, and on Debian the newest Node of NODE_MAJOR, Go and Neovim, read once per run;
# unreachable leaves them empty and unflagged.
read_releases() {
  local json
  NODE_LATEST="" GO_LATEST="" GO_SHA256="" NVIM_LATEST="" NVIM_SHA256=""
  UV_LATEST="$(curl -fsS --compressed --max-time 10 https://pypi.org/pypi/uv/json 2>/dev/null \
    | jq -r '.info.version // empty' 2>/dev/null || true)"
  [[ "$DISTRO" == debian ]] || return 0
  json="$(curl -fsS --compressed --max-time 10 https://nodejs.org/dist/index.json 2>/dev/null || true)"
  NODE_LATEST="$(jq -r --arg m "v$NODE_MAJOR." --arg f "linux-$NODE_ARCH" \
    'map(select((.version | startswith($m)) and (.files | index($f)))) | .[0].version // empty' <<<"$json" 2>/dev/null || true)"
  json="$(curl -fsS --compressed --max-time 10 'https://go.dev/dl/?mode=json' 2>/dev/null || true)"
  GO_LATEST="$(jq -r '.[0].version // empty' <<<"$json" 2>/dev/null || true)"
  GO_SHA256="$(jq -r --arg a "$ARCH" '.[0].files[] | select(.os == "linux" and .arch == $a and .kind == "archive")
    | .sha256' <<<"$json" 2>/dev/null || true)"
  json="$(curl -fsS --compressed --max-time 10 https://api.github.com/repos/neovim/neovim/releases/latest 2>/dev/null || true)"
  NVIM_LATEST="$(jq -r '.tag_name // empty' <<<"$json" 2>/dev/null || true)"
  NVIM_SHA256="$(jq -r --arg n "nvim-linux-$NVIM_ARCH.tar.gz" '.assets[] | select(.name == $n) | .digest
    | ltrimstr("sha256:")' <<<"$json" 2>/dev/null || true)"
}

# flag <status> <detail> — the first non-ok status sticks; details accumulate.
flag() {
  if [[ "$STATUS" == ok ]]; then STATUS="$1"; fi
  note "$2"
}
# note <detail> — add a detail and leave the status as it is.
note() { DETAIL+="${DETAIL:+; }$1"; }

# ask <prompt> — print the reply; fail at the end of input, so no answer is ever made up.
ask() {
  local reply
  read -r -p "$1 " reply || return 1
  printf '%s' "$reply"
}

# The human steps need someone at a terminal; a piped --yes skips them.
interactive() { [[ -t 0 || "$SETUP_ASSUME_TTY" == true ]]; }

# ── Items: check_<id> sets STATUS and DETAIL, fix_<id> brings the item to target ─

check_apt() {
  local p missing=() old=()
  read_caches
  for p in "${APT_PACKAGES[@]}"; do
    if ! installed "$p"; then missing+=("$p"); elif in_list "$p" "$APT_UPGRADABLE"; then old+=("$p"); fi
  done
  for p in "${DOCKER_PACKAGES[@]}"; do
    if ! installed "$p"; then missing+=("$p"); fi
  done
  if ((${#missing[@]})); then flag MISSING "${missing[*]}"; fi
  if ((${#old[@]})); then flag OUTDATED "${old[*]}"; fi
  if [[ "$DESKTOP" != true ]]; then note "xclip not needed: no display server"; fi
}
# install also upgrades an installed package to its candidate. Docker is only installed: an upgrade
# restarts dockerd, which stops every container, so it waits for the maintenance window's full-upgrade.
fix_apt() {
  apt-get install -y "${APT_PACKAGES[@]}"
  apt-get install -y --no-upgrade "${DOCKER_PACKAGES[@]}"
}

check_ghrepo() {
  read_caches
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
  if ! command -v snap >/dev/null 2>&1; then flag MISSING "snapd"; return; fi
  read_caches
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
  if ! command -v snap >/dev/null 2>&1; then apt-get install -y snapd; fi
  for entry in "${SNAPS[@]}"; do
    name="${entry% *}" channel="${entry#* }"
    if snap list "$name" >/dev/null 2>&1; then
      snap refresh "$name" --channel="$channel"
    else
      snap install "$name" --classic --channel="$channel"
    fi
  done
}

# node_removals — every package apt-get would remove along with nodejs, nodejs included.
node_removals() { LC_ALL=C apt-get -s remove nodejs 2>/dev/null | awk '$1 == "Remv" {print $2}' | tr '\n' ' ' || true; }
check_aptnode() {
  local f found=() removals
  if installed nodejs; then
    removals="$(node_removals)"
    found+=("apt nodejs $(dpkg-query -W -f='${Version}' nodejs 2>/dev/null || true) (removes: ${removals% })")
  fi
  for f in "${NODESOURCE_FILES[@]}"; do
    if [[ -e "$f" ]]; then found+=("${f%/*}"); found[-1]="${found[-1]##*/}/${f##*/}"; fi
  done
  if ((${#found[@]})); then flag WRONG "${found[*]}; the nodejs.org tarball replaces them once installed"; fi
}
fix_aptnode() {
  local p extra=()
  run_check node
  if [[ "$STATUS" != ok ]]; then printf 'The nodejs.org Node is not in place (%s); the apt Node stays.\n' "$DETAIL"; return 1; fi
  if installed nodejs; then
    for p in $(node_removals); do
      case "$p" in nodejs|npm|libnode*) ;; *) extra+=("$p") ;; esac
    done
    if ((${#extra[@]})); then printf 'Removing nodejs would also remove %s; remove them yourself first.\n' "${extra[*]}"; return 1; fi
  fi
  rm -f "${NODESOURCE_FILES[@]}"
  if installed nodejs; then apt-get remove -y nodejs; fi
  apt-get update -qq
}

# valid_unit <path> — a manifest line names one path under bin, include, lib or share, never their root
# or a way out; anything else is never deleted.
valid_unit() { [[ "$1" =~ ^(bin|include|lib|share)/[^/] && "/$1/" != *"/../"* && "$1" != */ ]]; }

# node_units <top> — the tarball's paths under bin, include, lib and share, cut to what one rm removes:
# a package in lib/node_modules, include/node, share/doc/node, otherwise the file.
node_units() {
  local unit
  sed -n "s|^$1/||p" | awk -F/ '
    $1 == "lib" && $2 == "node_modules" {print $1 "/" $2 "/" $3; next}
    $1 == "include" {print $1 "/" $2; next}
    $1 == "share" && $2 == "doc" {print $1 "/" $2 "/" $3; next}
    {print}' | sort -u | while IFS= read -r unit; do if valid_unit "$unit"; then printf '%s\n' "$unit"; fi; done
}

# node_version — the tarball Node's version, empty when it does not run.
node_version() { as_user "$NODE_PREFIX/bin/node" --version 2>/dev/null || true; }
# version_lt <a> <b> — a sorts before b.
version_lt() { [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$1" ]]; }

check_node() {
  local current unit invalid=() gone=()
  if [[ ! -x "$NODE_PREFIX/bin/node" ]]; then flag MISSING "$NODE_PREFIX/bin/node"; return; fi
  # The manifest is written last, so its absence or a file it lists gone means an interrupted install.
  if [[ ! -s "$NODE_MANIFEST" ]]; then
    flag WRONG "no $NODE_MANIFEST: the last install did not finish"
  else
    while IFS= read -r unit; do
      if ! valid_unit "$unit"; then invalid+=("'$unit'")
      elif [[ ! -e "$NODE_PREFIX/$unit" && ! -L "$NODE_PREFIX/$unit" ]]; then gone+=("$unit"); fi
    done < "$NODE_MANIFEST"
    if ((${#invalid[@]})); then flag WRONG "manifest lines outside bin, include, lib and share: ${invalid[*]}"; fi
    if ((${#gone[@]})); then flag WRONG "gone: ${gone[*]}"; fi
  fi
  current="$(node_version)"
  if [[ "$current" != "v$NODE_MAJOR".* ]]; then flag WRONG "node '$current', not $NODE_MAJOR.x"
  elif [[ -z "$NODE_LATEST" ]]; then note "nodejs.org did not answer; version not compared"
  elif version_lt "$current" "$NODE_LATEST"; then flag OUTDATED "node $current → $NODE_LATEST"
  elif version_lt "$NODE_LATEST" "$current"; then note "nodejs.org names the older $NODE_LATEST; kept $current"
  fi
}
# The download fixes run in a subshell; TMP_DIR and STAGE_DIR are global, so their EXIT trap sees them.

# Verified as the official Docker image does: a pinned releaser's signature over SHASUMS256.txt, then the
# tarball's sha256. Source: https://github.com/nodejs/node#verifying-binaries
# It unpacks into a stage on the same filesystem, moves each piece into place and writes the manifest last.
fix_node() {
  local signer unit current name="node-$NODE_LATEST-linux-$NODE_ARCH"
  [[ -n "$NODE_LATEST" ]] || { printf 'nodejs.org/dist did not answer.\n'; return 1; }
  current="$(node_version)"
  if [[ -n "$current" ]] && version_lt "$NODE_LATEST" "$current"; then
    printf 'nodejs.org names %s, older than the installed %s; no downgrade.\n' "$NODE_LATEST" "$current"
    return 1
  fi
  TMP_DIR="$(mktemp -d)"
  mkdir -p "$NODE_PREFIX"
  STAGE_DIR="$(mktemp -d "$NODE_PREFIX/.node-stage.XXXXXX")"
  trap 'rm -rf "$TMP_DIR" "$STAGE_DIR"' EXIT
  curl -fsSL "$NODE_KEYRING_URL" -o "$TMP_DIR/keys.kbx"
  curl -fsSL "https://nodejs.org/dist/$NODE_LATEST/SHASUMS256.txt.asc" -o "$TMP_DIR/SHASUMS256.txt.asc"
  curl -fsSL "https://nodejs.org/dist/$NODE_LATEST/$name.tar.xz" -o "$TMP_DIR/$name.tar.xz"
  # VALIDSIG's last field is the signer's primary key.
  signer="$(gpgv --status-fd 1 --keyring "$TMP_DIR/keys.kbx" --output "$TMP_DIR/SHASUMS256.txt" <"$TMP_DIR/SHASUMS256.txt.asc" \
    2>/dev/null | awk '$2 == "VALIDSIG" {print $NF}' || true)"
  if [[ -z "$signer" ]] || ! in_list "$signer" "$NODE_KEYS"; then
    printf 'SHASUMS256.txt of %s carries no valid signature of a pinned releaser key.\n' "$NODE_LATEST"
    return 1
  fi
  (cd "$TMP_DIR" && grep " $name.tar.xz\$" SHASUMS256.txt | sha256sum --quiet -c -)
  tar -tJf "$TMP_DIR/$name.tar.xz" | node_units "$name" > "$TMP_DIR/units"
  [[ -s "$TMP_DIR/units" ]] || { printf '%s holds nothing under bin, include, lib or share.\n' "$name.tar.xz"; return 1; }
  tar -xJf "$TMP_DIR/$name.tar.xz" -C "$STAGE_DIR" --strip-components=1 --no-same-owner \
    "$name/bin" "$name/include" "$name/lib" "$name/share"
  # From here the live tree changes; without a manifest, check_node calls it unfinished.
  touch "$TMP_DIR/old"
  if [[ -f "$NODE_MANIFEST" ]]; then
    while IFS= read -r unit; do
      if valid_unit "$unit"; then printf '%s\n' "$unit"; else printf 'Skipping manifest line %q.\n' "$unit" >&2; fi
    done < "$NODE_MANIFEST" > "$TMP_DIR/old"
    rm -f "$NODE_MANIFEST"
  fi
  # What only the old release shipped goes before anything moves, so no removal can reach a new file.
  while IFS= read -r unit; do rm -rf "${NODE_PREFIX:?}/$unit"; done < <(sort -u "$TMP_DIR/old" | comm -23 - "$TMP_DIR/units")
  while IFS= read -r unit; do
    rm -rf "${NODE_PREFIX:?}/$unit"
    mkdir -p "$(dirname "$NODE_PREFIX/$unit")"
    mv -T "$STAGE_DIR/$unit" "$NODE_PREFIX/$unit"
  done < "$TMP_DIR/units"
  cp "$TMP_DIR/units" "$NODE_MANIFEST.new"
  mv -T "$NODE_MANIFEST.new" "$NODE_MANIFEST"
}

check_go() {
  local current
  if [[ ! -x "$GO_ROOT/bin/go" ]]; then flag MISSING "$GO_ROOT"; return; fi
  current="$(as_user "$GO_ROOT/bin/go" version | awk '{print $3}')"
  if [[ -n "$GO_LATEST" && "$current" != "$GO_LATEST" ]]; then flag OUTDATED "$current → $GO_LATEST"; fi
}
# go.dev's steps: untarring over an existing tree breaks it, so the old one goes first.
fix_go() {
  local file="$GO_LATEST.linux-$ARCH.tar.gz"
  [[ -n "$GO_LATEST" && -n "$GO_SHA256" ]] || { printf 'go.dev/dl did not answer.\n'; return 1; }
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  curl -fsSL "https://go.dev/dl/$file" -o "$TMP_DIR/$file"
  sha256sum --quiet -c <<<"$GO_SHA256  $TMP_DIR/$file"
  rm -rf "$GO_ROOT"
  tar -C "$(dirname "$GO_ROOT")" -xzf "$TMP_DIR/$file"
}

check_nvimbin() {
  local current
  if [[ ! -x "$NVIM_DIR/bin/nvim" || "$(readlink -f "$NVIM_LINK")" != "$(readlink -f "$NVIM_DIR/bin/nvim")" ]]; then
    flag MISSING "$NVIM_LINK → $NVIM_DIR"; return
  fi
  current="$(as_user "$NVIM_LINK" --version | awk 'NR == 1 {print $2}')"
  if [[ -n "$NVIM_LATEST" && "$current" != "$NVIM_LATEST" ]]; then flag OUTDATED "nvim $current → $NVIM_LATEST"; fi
}
# guides/neovim.md's install step; the digest GitHub publishes for the asset verifies it.
fix_nvimbin() {
  local file="nvim-linux-$NVIM_ARCH.tar.gz"
  [[ -n "$NVIM_LATEST" && -n "$NVIM_SHA256" ]] || { printf 'The GitHub releases API did not answer.\n'; return 1; }
  TMP_DIR="$(as_user mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  as_user curl -fsSL "https://github.com/neovim/neovim/releases/download/$NVIM_LATEST/$file" -o "$TMP_DIR/$file"
  sha256sum --quiet -c <<<"$NVIM_SHA256  $TMP_DIR/$file"
  as_user rm -rf "$NVIM_DIR"
  as_user mkdir -p "$(dirname "$NVIM_LINK")"
  as_user tar -C "$(dirname "$NVIM_DIR")" -xzf "$TMP_DIR/$file"
  as_user ln -sfn "$NVIM_DIR/bin/nvim" "$NVIM_LINK"
}

# Debian's and Ubuntu's neovim lag the release vim.pack needs; on Ubuntu /usr/bin also shadows /snap/bin.
check_aptnvim() { if installed neovim; then flag WRONG "apt neovim predates vim.pack"; fi; }
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
  local name="" email=""
  interactive || { printf 'The git identity needs a terminal to ask for it.\n'; return 1; }
  name="$(ask 'git user.name:')" || true
  email="$(ask 'git user.email:')" || true
  [[ -n "$name" && -n "$email" ]] || { printf 'Both values are required.\n'; return 1; }
  as_user git config --global user.name "$name"
  as_user git config --global user.email "$email"
}

check_sshkey() { if [[ ! -f "$KEY.pub" ]]; then flag MISSING "$KEY.pub"; fi; }
fix_sshkey() {
  interactive || { printf 'The SSH key needs a terminal for its passphrase.\n'; return 1; }
  as_user mkdir -p -m 700 "$TARGET_HOME/.ssh"
  as_user ssh-keygen -t ed25519 -C "$(as_user git config --global user.email)" -f "$KEY"
}

check_ghauth() {
  if ! user_has gh; then flag MISSING "gh not installed"; return; fi
  if ! gh_logged_in; then flag MISSING "not logged in"; fi
}
# The GitHub keys item uploads the key; the scopes it needs come with this login.
fix_ghauth() {
  interactive || { printf 'The gh login needs a terminal for the browser approval.\n'; return 1; }
  as_user gh auth login -h github.com -p ssh --skip-ssh-key -s "$GH_KEY_SCOPES"
}

# The dev machine runs pipx's uv at PyPI's latest; a project's required-version is only a floor.
pipx_has_uv() { user_has pipx && in_list uv "$(as_user pipx list --short 2>/dev/null | awk '{print $1}' | tr '\n' ' ' || true)"; }
check_uv() {
  local current other
  if ! pipx_has_uv; then
    other="$(as_user sh -c 'command -v uv' 2>/dev/null || true)"
    if [[ "$other" == "$UV_BIN" ]]; then flag MISSING "uv from pipx; replaces the non-pipx $UV_BIN"
    elif [[ -n "$other" ]]; then flag MISSING "uv from pipx; it shadows $other in your shells"
    else flag MISSING "uv from pipx"; fi
    return
  fi
  current="$(as_user "$UV_BIN" --version | awk '{print $2}')"
  if [[ -n "$UV_LATEST" && "$current" != "$UV_LATEST" ]]; then flag OUTDATED "uv $current → $UV_LATEST"; fi
}
# .bash_aliases puts ~/.local/bin on PATH for new terminals; --force replaces a uv the standalone installer left there.
fix_uv() { if pipx_has_uv; then as_user pipx upgrade uv; else as_user pipx install --force uv; fi; }

check_npm() {
  local p have old prefix
  if ! user_has npm; then flag MISSING "npm; install node first"; return; fi
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

# uv_tools [--outdated] — the user's uv tools, space-separated.
uv_tools() { as_user uv tool list "$@" 2>/dev/null | awk '!/^-/ {print $1}' | tr '\n' ' '; }
check_uvtools() {
  local t have old
  if ! user_has uv; then flag MISSING "uv"; return; fi
  have="$(uv_tools)"
  old="$(uv_tools --outdated)"
  for t in "${UV_TOOLS[@]}"; do
    if ! in_list "$t" "$have"; then flag MISSING "$t"; elif in_list "$t" "$old"; then flag OUTDATED "$t"; fi
  done
}
fix_uvtools() {
  local t have
  have="$(uv_tools)"
  for t in "${UV_TOOLS[@]}"; do
    if in_list "$t" "$have"; then as_user uv tool upgrade "$t"; else as_user uv tool install "$t"; fi
  done
}

# The native install updates itself, so only presence is checked.
check_claude() { if ! user_has claude; then flag MISSING claude; fi; }
fix_claude() { as_user bash -c 'curl -fsSL https://claude.ai/install.sh | bash'; }

# install.sh's own probe: one "<status> <item>" line per item it would change, ok lines carrying a note.
check_dotfiles() {
  local out status item rc=0
  out="$(as_user "$HANDBOOK_DIR/scripts/install-dotfiles.sh" --status)" || rc=$?
  if ((rc > 1)); then die "install-dotfiles.sh --status failed (exit $rc)"; fi
  while read -r status item; do
    if [[ -z "$status" ]]; then continue; fi
    if [[ "$status" == ok ]]; then note "$item"; else flag "$status" "$item"; fi
  done <<<"$out"
}
fix_dotfiles() { as_user "$HANDBOOK_DIR/install.sh"; }

check_sshconfig() { if [[ ! -f "$TARGET_HOME/.ssh/config" ]]; then flag MISSING "$TARGET_HOME/.ssh/config"; fi; }
fix_sshconfig() {
  as_user mkdir -p -m 700 "$TARGET_HOME/.ssh"
  as_user cp --update=none "$HANDBOOK_DIR/templates/ssh_config" "$TARGET_HOME/.ssh/config"
  as_user chmod 600 "$TARGET_HOME/.ssh/config"
}

# missing_scopes — the key scopes the active gh login lacks, space-separated; without them the key list fails.
# The text status lists every account's scopes, so only the active account's JSON entry counts.
missing_scopes() {
  local scopes scope out=""
  scopes="$(as_user gh auth status --active -h github.com --json hosts \
    --jq '.hosts["github.com"][]? | select(.active) | .scopes // ""' 2>/dev/null || true)"
  for scope in ${GH_KEY_SCOPES//,/ }; do
    if ! in_list "$scope" "${scopes//,/ }"; then out+="$scope "; fi
  done
  printf '%s' "$out"
}
# missing_key_types — the types of the local key that GitHub lacks, space-separated. Fails with gh's first
# error when either type's list cannot be read: gh then prints a warning and may still exit 0 with the other.
missing_key_types() {
  local key list err type out=""
  key="$(cut -d' ' -f2 "$KEY.pub")"
  err="$(mktemp)"
  if ! list="$(as_user gh ssh-key list 2>"$err")" || [[ -s "$err" ]]; then
    sed -n '1{s/^warning: *//;p}' "$err"
    rm -f "$err"
    return 1
  fi
  rm -f "$err"
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
  if ! user_has gh || ! gh_logged_in; then flag MISSING "gh not logged in"; return; fi
  missing="$(missing_scopes)"
  if [[ -n "$missing" ]]; then flag WRONG "gh login lacks ${missing% }, so the keys cannot be listed"; return; fi
  if ! missing="$(missing_key_types)"; then flag WRONG "cannot list the GitHub keys: ${missing:-gh failed}"; return; fi
  if [[ -n "$missing" ]]; then flag MISSING "${missing% } key"; fi
}
fix_ghkeys() {
  local type types title=""
  interactive || { printf 'The GitHub keys need a terminal for the key title and the browser approval.\n'; return 1; }
  if [[ -n "$(missing_scopes)" ]]; then as_user gh auth refresh -h github.com -s "$GH_KEY_SCOPES"; fi
  if ! types="$(missing_key_types)"; then printf 'Cannot list the GitHub keys: %s\n' "${types:-gh failed}"; return 1; fi
  if [[ -z "$types" ]]; then printf 'GitHub already has both keys.\n'; return 0; fi
  title="$(ask "Key title on GitHub [$(hostname)]:")" || true
  title="${title:-$(hostname)}"
  for type in $types; do
    as_user gh ssh-key add "$KEY.pub" --type "$type" --title "$title"
  done
}

check_remote() {
  local url
  url="$(as_user git -C "$HANDBOOK_DIR" remote get-url origin 2>/dev/null || true)"
  if [[ "$url" != "$HANDBOOK_SSH_URL" ]]; then flag WRONG "origin is ${url:-unset}"; fi
}
fix_remote() { as_user git -C "$HANDBOOK_DIR" remote set-url origin "$HANDBOOK_SSH_URL"; }

# The font renders in the terminal of the machine the screen belongs to, never on a headless host.
check_font() {
  if [[ "$DESKTOP" != true ]]; then note "not needed: no display server"; return; fi
  if [[ "$(as_user fc-list : family 2>/dev/null || true)" != *[Nn]erd* ]]; then flag MISSING "no Nerd Font"; fi
}
fix_font() {
  as_user mkdir -p "$TARGET_HOME/.local/share/fonts/nerd"
  # shellcheck disable=SC2016 # $1 and $2 expand in the inner shell
  as_user bash -c 'curl -fsSL "$1" | tar -C "$2" -xJf -' _ "$FONT_URL" "$TARGET_HOME/.local/share/fonts/nerd"
  as_user fc-cache -f
}

# The release binary, not the snap: the snap cannot read ~/.config/marksman. A release is not re-fetched once installed.
check_marksman() { if [[ ! -x "$MARKSMAN_BIN" ]]; then flag MISSING "$MARKSMAN_BIN"; fi; }
# guides/neovim.md's marksman step; the digest GitHub publishes for the asset verifies it.
fix_marksman() {
  local file="marksman-linux-x64" json sha
  [[ "$ARCH" == amd64 ]] || file="marksman-linux-$ARCH"
  json="$(curl -fsS --compressed --max-time 10 "$MARKSMAN_API" 2>/dev/null || true)"
  sha="$(jq -r --arg n "$file" '.assets[] | select(.name == $n) | .digest | ltrimstr("sha256:")' <<<"$json" 2>/dev/null || true)"
  [[ -n "$sha" ]] || { printf 'The GitHub releases API did not answer.\n'; return 1; }
  TMP_DIR="$(as_user mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  as_user curl -fsSL "https://github.com/artempyanykh/marksman/releases/latest/download/$file" -o "$TMP_DIR/$file"
  sha256sum --quiet -c <<<"$sha  $TMP_DIR/$file"
  as_user mkdir -p "$(dirname "$MARKSMAN_BIN")"
  as_user cp "$TMP_DIR/$file" "$MARKSMAN_BIN"
  as_user chmod 755 "$MARKSMAN_BIN"
}

check_nvim() {
  local name rev actual dir locked missing=() stray=()
  if ! user_has nvim; then flag MISSING "nvim not installed"; return; fi
  while read -r name rev; do
    actual="$(as_user git -C "$NVIM_DATA/pack/core/opt/$name" rev-parse HEAD 2>/dev/null || true)"
    if [[ -z "$actual" ]]; then flag MISSING "$name"; elif [[ "$actual" != "$rev" ]]; then flag WRONG "$name off the lockfile"; fi
  done < <(jq -r '.plugins | to_entries[] | "\(.key) \(.value.rev)"' "$NVIM_LOCK")
  # A plugin init.lua dropped stays on disk, and nvim's next start writes it back into the lockfile.
  locked="$(jq -r '.plugins | keys[]' "$NVIM_LOCK" | tr '\n' ' ')"
  for dir in "$NVIM_DATA"/pack/core/opt/*/; do
    if [[ -d "$dir" ]] && ! in_list "$(basename "$dir")" "$locked"; then stray+=("$(basename "$dir")"); fi
  done
  if ((${#stray[@]})); then flag WRONG "not in the lockfile: ${stray[*]}"; fi
  for name in "${PARSERS[@]}"; do
    if [[ ! -f "$NVIM_DATA/parser/$name.so" ]]; then missing+=("$name"); fi
  done
  if ((${#missing[@]})); then flag MISSING "parsers: ${missing[*]}"; fi
}
fix_nvim() {
  local langs stray
  langs="$(printf "'%s'," "${PARSERS[@]}")"
  # init.lua's vim.pack.add marks its plugins active; the rest go before the update.
  stray='local s = vim.iter(vim.pack.get(nil, { info = false })):filter(function(p) return not p.active end)'
  stray+=':map(function(p) return p.spec.name end):totable(); if #s > 0 then vim.pack.del(s) end'
  as_user nvim --headless "+lua $stray" "+lua vim.pack.update(nil, { target = 'lockfile', force = true })" \
    "+lua require('nvim-treesitter').install({ ${langs%,} }):wait(600000)" +qa
}

# ── Main ─────────────────────────────────────────────────────────────────────

# run_check <id> — reset STATUS and DETAIL, then run the item's check.
run_check() {
  STATUS=ok DETAIL=""
  "check_$1"
}

print_row() { printf '%-9s %-20s %s\n' "$STATUS" "$1" "$DETAIL"; }

[[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] || die "no home directory for user '$TARGET_USER'"
command -v jq >/dev/null 2>&1 || die "jq not found; install it first (apt install git jq)"
TARGET_UID="$(id -u "$TARGET_USER")"
# A host that runs Docker's own packages, as setup-server.sh installs them, keeps them: the distro's would replace them.
if installed docker-ce; then
  DOCKER_PACKAGES=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
elif [[ "$DISTRO" == ubuntu ]]; then
  DOCKER_PACKAGES=(docker.io docker-compose-v2 docker-buildx)
else
  DOCKER_PACKAGES=(docker.io docker-compose docker-buildx)
fi
# A desktop has a display server; a headless host (a VPS, even one booting graphical.target) has neither package.
DESKTOP=false
if installed xwayland || installed xserver-xorg-core; then DESKTOP=true APT_PACKAGES+=(xclip); fi
if [[ "$MODE" != check && "$SETUP_ALLOW_NONROOT" != true ]]; then
  [[ "$EUID" -eq 0 ]] || die "run with sudo, or pass --check to report only"
  [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]] || die "run with sudo from your own account, not as root"
fi

if [[ "$MODE" != check ]]; then
  log "Refreshing apt indexes"
  apt-get update -qq
fi
read_caches
read_releases

log "Checking $TARGET_USER's machine against $HANDBOOK_DIR"
bad=0
for entry in "${ITEMS[@]}"; do
  run_check "${entry%%|*}"
  print_row "${entry#*|}"
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
  if [[ "$MODE" == ask || "$id" == aptnvim || "$id" == aptnode ]]; then
    reply="$(ask "Fix $label ($DETAIL)? [Y/n/q]")" || reply=n
  fi
  case "${reply:-y}" in
    q|Q) left+=("$label"); break ;;
    n|N) left+=("$label"); continue ;;
  esac
  log "Fixing $label"
  # A subshell outside any condition keeps errexit on inside the fix; its failure is reported below.
  trap - ERR
  set +e
  (set -e; "fix_$id")
  rc=$?
  set -e
  trap 'on_err "$LINENO"' ERR
  if [[ "$rc" -ne 0 ]]; then printf 'Fix for %s failed (exit %s).\n' "$label" "$rc" >&2; fi
  CACHES_READ=false
  run_check "$id"
  print_row "$label"
  # A running session keeps its groups, and a running terminal its font list.
  if [[ "$STATUS" != ok ]]; then left+=("$label"); elif [[ "$id" == docker || "$id" == font ]]; then RELOGIN=true; fi
done

if [[ "$RELOGIN" == true ]]; then log "Log out and back in: the session then has the docker group and the terminal finds the new font"; fi
if ((${#left[@]})); then
  log "Still differs: $(IFS=,; printf '%s' "${left[*]}")"
  exit 1
fi
log "Done – open a new terminal for the new PATH"
