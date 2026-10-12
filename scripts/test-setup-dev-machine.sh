#!/usr/bin/env bash
# test-setup-dev-machine.sh – fixture test for scripts/setup-dev-machine.sh.
#
# Usage:
#   scripts/test-setup-dev-machine.sh    # or: make test-setup-dev-machine
#
# What it does:
#   1. Copies the working tree to a temp clone with an HTTPS origin and an empty home.
#   2. Puts one logging stub first on PATH for apt, snap, gh, npm, uv, nvim and the rest;
#      marker files hold the fake machine state, and a tool appears when its fix installs it.
#   3. Asserts the root guard, --check on the fresh machine, --yes on it, then --check again.

set -euo pipefail

# shellcheck source=scripts/lib/test-harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/test-harness.sh"

CLONE="$FIX/handbook"
HOME_DIR="$FIX/home"
STATE="$FIX/state"
CALLS="$FIX/calls"
OUT="$FIX/stdout"
mkdir -p "$CLONE" "$HOME_DIR" "$STATE" "$FIX/bin" "$FIX/stubs" "$FIX/etc" "$FIX/font"

tar -C "$REPO_ROOT" --exclude=.git -cf - . | tar -C "$CLONE" -xf -
git -C "$CLONE" init -q
git -C "$CLONE" remote add origin https://github.com/nicograef/handbook.git
touch "$FIX/font/SymbolsNerdFont-Regular.ttf"
tar -C "$FIX/font" -cJf "$FIX/font.tar.xz" .

# One stub for every command; it dispatches on its own name. @FIX@ and @LOCK@ are filled below.
cat > "$FIX/stub" <<'STUB'
#!/usr/bin/env bash
FIX=@FIX@ S=@FIX@/state LOCK=@LOCK@
name="$(basename "$0")"
echo "$name $*" >> "$FIX/calls"
appear() { ln -sf "$FIX/stub" "$FIX/bin/$1"; }
case "$name" in
  dpkg-query)
    pkg="${*: -1}"
    if [[ "$pkg" == neovim ]]; then printf 'unknown ok not-installed'
    elif [[ -f "$S/$pkg" || ( "$pkg" != gh && -f "$S/apt" ) ]]; then printf 'install ok installed'
    else exit 1; fi ;;
  apt) echo 'Listing...' ;;
  apt-get)
    if [[ "$1 $2" == "install -y" && "$3" == gh ]]; then touch "$S/gh"; appear gh
    elif [[ "$1" == install ]]; then touch "$S/apt"; fi ;;
  snap)
    case "$1" in
      list)
        [[ -f "$S/snaps" ]] || exit 1
        channel=latest/stable; [[ "$2" == node ]] && channel=26/stable
        printf 'Name Version Rev Tracking Publisher Notes\n%s 1 1 %s pub classic\n' "$2" "$channel" ;;
      install|refresh)
        [[ "$2" == --list ]] && { echo 'All snaps up to date.'; exit 0; }
        touch "$S/snaps"; [[ "$2" == node ]] && appear npm; [[ "$2" == nvim ]] && appear nvim ;;
    esac ;;
  id)
    if [[ "$1" == -nG ]]; then [[ -f "$S/docker" ]] && echo "$2 docker" || echo "$2"; exit 0; fi
    exec /usr/bin/id "$@" ;;
  usermod) touch "$S/docker" ;;
  curl)
    case "$*" in
      *pypi.org*) echo '{"info":{"version":"1.0.0"}}' ;;
      *keyring*) out="${*: -1}"; echo key > "$out" ;;
      *claude.ai*) echo "ln -sf $FIX/stub $FIX/bin/claude" ;;
      *nerd-fonts*) cat "$FIX/font.tar.xz" ;;
    esac ;;
  git)
    if [[ "$1" == -C && "$2" == */pack/core/opt/* && "$3" == rev-parse ]]; then
      [[ -f "$S/nvim" ]] || exit 128
      jq -r --arg n "${2##*/}" '.plugins[$n].rev' "$LOCK"; exit 0
    fi
    exec /usr/bin/git "$@" ;;
  ssh-keygen)
    while [[ $# -gt 0 && "$1" != -f ]]; do shift; done
    echo "ssh-ed25519 AAAAFIXTUREKEY fixture" > "$2.pub" ;;
  gh)
    case "$1 $2" in
      "--version "*) echo 'gh version 2.0.0' ;;
      "auth status") [[ -f "$S/ghauth" ]] || exit 1; [[ -f "$S/scope" ]] && echo 'scopes: admin:ssh_signing_key' ;;
      "auth login") touch "$S/ghauth" ;;
      "auth refresh") touch "$S/scope" ;;
      "ssh-key list") cat "$S/keys" 2>/dev/null ;;
      "ssh-key add") printf 'title\tssh-ed25519 AAAAFIXTUREKEY\tdate\t1\t%s\n' "$5" >> "$S/keys" ;;
    esac ;;
  pipx) [[ "$1 $2" == "install uv" ]] && appear uv; true ;;
  uv)
    case "$*" in
      --version) echo 'uv 1.0.0' ;;
      "tool list") cat "$S/uvtools" 2>/dev/null ;;
      "tool install "*) printf '%s v1\n- %s\n' "$3" "$3" >> "$S/uvtools" ;;
    esac ;;
  npm)
    case "$1 $2 $3" in
      "config get prefix") cat "$S/npmprefix" 2>/dev/null || echo /usr ;;
      "config set prefix") echo "$4" > "$S/npmprefix" ;;
      "ls -g --depth=0") jq -Rn '{dependencies: ([inputs | {(.): {}}] | add // {})}' "$S/npm" 2>/dev/null || echo '{}' ;;
      "outdated -g --json") echo '{}' ;;
      "install -g "*) shift 2; printf '%s\n' "${@%@latest}" >> "$S/npm" ;;
    esac ;;
  claude)
    case "$1 $2" in
      "plugin list") [[ -f "$S/plugin" ]] && echo '[{"id":"nico@handbook","enabled":true}]' || echo '[]' ;;
      "plugin install") touch "$S/plugin" ;;
    esac ;;
  fc-list) compgen -G "$FIX/home/.local/share/fonts/nerd/*" >/dev/null && echo 'Symbols Nerd Font' ;;
  nvim)
    touch "$S/nvim"; mkdir -p "$FIX/home/.local/share/nvim/site/parser"
    for p in bash css html javascript json python toml tsx typescript yaml; do
      touch "$FIX/home/.local/share/nvim/site/parser/$p.so"
    done ;;
esac
exit 0
STUB
sed -i "s|@FIX@|$FIX|g; s|@LOCK@|$CLONE/dotfiles/nvim/nvim-pack-lock.json|g" "$FIX/stub"
chmod +x "$FIX/stub"
# Present from the start, gh too so the real one never runs; npm, nvim, uv and claude appear when their fix runs.
for c in dpkg-query apt apt-get snap id usermod curl git ssh-keygen pipx fc-list fc-cache gh; do
  ln -s "$FIX/stub" "$FIX/bin/$c"
done

export PATH="$FIX/bin:$PATH"
TARGET_USER="$(id -un)"
export TARGET_USER TARGET_HOME="$HOME_DIR" ETC_DIR="$FIX/etc" USER_PATH="$FIX/bin:/usr/bin:/bin"
SCRIPT="$CLONE/scripts/setup-dev-machine.sh"

run() { # run <stdin> [args...]; sets rc, stdout in $OUT
  local input="$1"
  shift
  : > "$CALLS"
  rc=0
  printf '%b' "$input" | bash "$SCRIPT" "$@" > "$OUT" 2>&1 || rc=$?
}

rows() { grep -cE "^$1 " "$OUT" || true; }

# 1. Without root, only --check runs.
if [[ "$EUID" -ne 0 ]]; then
  run ''
  if [[ "$rc" -eq 1 ]] && grep -qF 'run with sudo' "$OUT"; then log "non-root apply -> refused"
  else fail "non-root apply: rc $rc: $(cat "$OUT")"; fi
fi

export SETUP_ALLOW_NONROOT=true

# 2. A fresh machine: everything but the absent apt neovim differs, and nothing changes.
run '' --check
if [[ "$rc" -eq 1 && "$(rows ok)" -eq 1 ]]; then log "fresh --check -> exit 1, 17 rows differ"
else fail "fresh --check: rc $rc, ok rows $(rows ok): $(cat "$OUT")"; fi
if grep -vE '^(dpkg-query|apt list|snap (list|refresh --list)|id|curl .*pypi|git|fc-list|gh auth status)( |$)' "$CALLS" | grep -q .; then
  fail "fresh --check changed something: $(grep -vE '^(dpkg-query|apt list|snap (list|refresh --list)|id|curl .*pypi|git|fc-list|gh auth status)( |$)' "$CALLS")"
else log "fresh --check -> read-only"; fi

# 3. --yes fixes every item; the prompts get name, email and the default key title.
run 'Fixture User\nfixture@example.com\n\n' --yes
if [[ "$rc" -eq 0 ]]; then log "fresh --yes -> exit 0"; else fail "fresh --yes: rc $rc: $(cat "$OUT")"; fi
order=("apt-get install -y git" "apt-get install -y gh" "snap install node --classic --channel=26/stable"
  "usermod -aG docker" "ssh-keygen -t ed25519 -C fixture@example.com" "gh auth login" "pipx install uv"
  "npm config set prefix $HOME_DIR/.local" "uv tool install ruff" "claude plugin install"
  "gh ssh-key add $HOME_DIR/.ssh/id_ed25519.pub --type signing" "nvim --headless")
last=0
for call in "${order[@]}"; do
  line="$(grep -nF -- "$call" "$CALLS" | head -1 | cut -d: -f1)"
  if [[ -z "$line" ]]; then fail "--yes never ran: $call"
  elif [[ "$line" -lt "$last" ]]; then fail "--yes ran out of order: $call"
  else last="$line"; fi
done
log "--yes -> fixes run in item order"
if [[ "$(git -C "$CLONE" remote get-url origin)" == git@github.com:nicograef/handbook.git ]]; then
  log "--yes -> origin over SSH"; else fail "origin not switched to SSH"; fi
if grep -qF 'docker group' "$OUT" && grep -qF 'Log out and back in' "$OUT"; then
  log "--yes -> asks for a new login"; else fail "no new-login notice: $(cat "$OUT")"; fi

# 4. The fixed machine matches.
run '' --check
if [[ "$rc" -eq 0 && "$(rows ok)" -eq 18 ]]; then log "fixed --check -> 18 rows ok"
else fail "fixed --check: rc $rc: $(cat "$OUT")"; fi

finish
