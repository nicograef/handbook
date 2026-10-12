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
#   4. Reruns --yes on a gh login that lacks the key scopes and a deleted font.
#   5. Asserts a broken snap probe names itself and another distro is refused.
#   6. Repeats the fresh and fixed runs on Debian: no snap, NodeSource, the Go and Neovim tarballs.
#      A rerun changes nothing, and a host with docker-ce keeps it.

set -euo pipefail

# shellcheck source=scripts/lib/test-harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/test-harness.sh"

CLONE="$FIX/handbook"
HOME_DIR="$FIX/home"
STATE="$FIX/state"
CALLS="$FIX/calls"
OUT="$FIX/stdout"
ARCH="$(dpkg --print-architecture)"
if [[ "$ARCH" == amd64 ]]; then NVIM_ARCH=x86_64; else NVIM_ARCH="$ARCH"; fi
mkdir -p "$CLONE" "$FIX/bin" "$FIX/font" "$FIX/go/go/bin" "$FIX/nvim/nvim-linux-$NVIM_ARCH/bin"

tar -C "$REPO_ROOT" --exclude=.git -cf - . | tar -C "$CLONE" -xf -
git -C "$CLONE" init -q
touch "$FIX/font/SymbolsNerdFont-Regular.ttf"
tar -C "$FIX/font" -cJf "$FIX/font.tar.xz" .

# fresh_machine <os-release ID> — an empty home, no state, an HTTPS origin.
fresh_machine() {
  rm -rf "$HOME_DIR" "$STATE" "${FIX:?}/etc" "$FIX/usr-local"
  rm -f "$FIX/bin/npm" "$FIX/bin/nvim" "$FIX/bin/uv" "$FIX/bin/claude"
  mkdir -p "$HOME_DIR" "$STATE" "$FIX/etc" "$FIX/usr-local"
  printf 'PRETTY_NAME="fixture"\nID=%s\n' "$1" > "$FIX/etc/os-release"
  git -C "$CLONE" remote remove origin 2>/dev/null || true
  git -C "$CLONE" remote add origin https://github.com/nicograef/handbook.git
}

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
    if [[ "$*" == *Version* ]]; then [[ -f "$S/$pkg" ]] && printf '26.1.0-1nodesource1'; exit 0; fi
    if [[ "$pkg" == neovim ]]; then printf 'unknown ok not-installed'
    elif [[ -f "$S/$pkg" || ( " gh nodejs docker-ce " != *" $pkg "* && -f "$S/apt" ) ]]; then printf 'install ok installed'
    else exit 1; fi ;;
  apt) echo 'Listing...' ;;
  apt-get)
    if [[ "$1 $2" == "install -y" && "$3" == gh ]]; then touch "$S/gh"; appear gh
    elif [[ "$1 $2" == "install -y" && "$3" == nodejs ]]; then touch "$S/nodejs"; appear npm
    elif [[ "$1" == install ]]; then touch "$S/apt"; fi ;;
  snap)
    # A broken snapd: the probe the script once died on without a word.
    [[ -f "$S/nosnap" ]] && exit 127
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
      *deb.nodesource.com/setup_26.x*) cp "$FIX/nodesource-setup" "${*: -1}" ;;
      *go.dev/dl/?mode=json*) cat "$FIX/go.json" ;;
      *go.dev/dl/go1.99.0.*) cp "$FIX/go.tar.gz" "${*: -1}" ;;
      *api.github.com/repos/neovim*) cat "$FIX/nvim.json" ;;
      *releases/download/v0.99.0/*) cp "$FIX/nvim.tar.gz" "${*: -1}" ;;
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
    # $S/scopes holds the token's scopes, one per line; login and refresh take them from -s, the last argument.
    has() { grep -qx "$1" "$S/scopes" 2>/dev/null; }
    case "$1 $2" in
      "--version "*) echo 'gh version 2.0.0' ;;
      "auth status") [[ -f "$S/ghauth" ]] || exit 1; echo "Token scopes: $(sed "s/.*/'&'/" "$S/scopes" 2>/dev/null | paste -sd,)" ;;
      "auth login"|"auth refresh") touch "$S/ghauth"; tr , '\n' <<<"${*: -1}" >> "$S/scopes" ;;
      "ssh-key list") has admin:public_key || exit 1; cat "$S/keys" 2>/dev/null ;;
      "ssh-key add")
        if [[ "$5" == signing ]]; then has admin:ssh_signing_key || exit 1; else has admin:public_key || exit 1; fi
        printf 'title\tssh-ed25519 AAAAFIXTUREKEY\tdate\t1\t%s\n' "$5" >> "$S/keys" ;;
    esac ;;
  pipx)
    case "$*" in
      "list --short") [[ -f "$S/pipxuv" ]] && echo 'uv 1.0.0' ;;
      "install --force uv") touch "$S/pipxuv"; appear uv; mkdir -p "$FIX/home/.local/bin"; ln -sf "$FIX/stub" "$FIX/home/.local/bin/uv" ;;
    esac ;;
  go) echo 'go version go1.99.0 linux/amd64' ;;
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
      "config get allow-scripts") cat "$S/npmallow" 2>/dev/null ;;
      "config set allow-scripts="*) echo "${3#allow-scripts=}" > "$S/npmallow" ;;
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
    [[ "$1" == --version ]] && { echo 'NVIM v0.99.0'; exit 0; }
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

# The Debian downloads: Go and Neovim tarballs whose binaries are the stub, their release JSON with
# the real digests, and a NodeSource setup script that writes only the source.
cp "$FIX/stub" "$FIX/go/go/bin/go"
tar -C "$FIX/go" -czf "$FIX/go.tar.gz" go
cp "$FIX/stub" "$FIX/nvim/nvim-linux-$NVIM_ARCH/bin/nvim"
tar -C "$FIX/nvim" -czf "$FIX/nvim.tar.gz" "nvim-linux-$NVIM_ARCH"
jq -n --arg a "$ARCH" --arg s "$(sha256sum "$FIX/go.tar.gz" | cut -d' ' -f1)" \
  '[{version: "go1.99.0", files: [{os: "linux", arch: $a, kind: "archive", sha256: $s}]}]' > "$FIX/go.json"
jq -n --arg n "nvim-linux-$NVIM_ARCH.tar.gz" --arg d "sha256:$(sha256sum "$FIX/nvim.tar.gz" | cut -d' ' -f1)" \
  '{tag_name: "v0.99.0", assets: [{name: $n, digest: $d}]}' > "$FIX/nvim.json"
cat > "$FIX/nodesource-setup" <<'SETUP'
echo "nodesource-setup" >> "$(dirname "$ETC_DIR")/calls"
mkdir -p "$ETC_DIR/apt/sources.list.d"
printf 'Types: deb\nURIs: https://deb.nodesource.com/node_26.x\n' > "$ETC_DIR/apt/sources.list.d/nodesource.sources"
SETUP

export PATH="$FIX/bin:$PATH"
TARGET_USER="$(id -un)"
export TARGET_USER TARGET_HOME="$HOME_DIR" ETC_DIR="$FIX/etc" GO_ROOT="$FIX/usr-local/go"
export USER_PATH="$HOME_DIR/.local/bin:$FIX/bin:/usr/bin:/bin"
SCRIPT="$CLONE/scripts/setup-dev-machine.sh"
# What a --check may call: reads only.
READS='^(dpkg-query|apt list|snap (list|refresh --list)|id|curl .*(pypi|go\.dev/dl/\?mode|api\.github)[^ ]*|git|fc-list|gh auth status|pipx list)( |$)'
# What a fix calls: a rerun on a matching machine must call none of them.
WRITES='^(apt-get (install|remove)|snap (install|refresh [a-z])|usermod|ssh-keygen|gh (auth (login|refresh)|ssh-key add)|pipx (install|upgrade)|npm (config set|install)|uv tool (install|upgrade)|claude plugin (install|marketplace)|nodesource-setup|curl -fsSL|nvim --headless|git (config --global [a-zA-Z.]+ .|remote set-url)|fc-cache)'

run() { # run <stdin> [args...]; sets rc, stdout in $OUT
  local input="$1"
  shift
  : > "$CALLS"
  rc=0
  printf '%b' "$input" | bash "$SCRIPT" "$@" > "$OUT" 2>&1 || rc=$?
}

rows() { grep -cE "^$1 " "$OUT" || true; }

# in_order <call...> — each call ran, in this order.
in_order() {
  local call line last=0
  for call in "$@"; do
    line="$(grep -nF -- "$call" "$CALLS" | head -1 | cut -d: -f1 || true)"
    if [[ -z "$line" ]]; then fail "--yes never ran: $call"
    elif [[ "$line" -lt "$last" ]]; then fail "--yes ran out of order: $call"
    else last="$line"; fi
  done
}

fresh_machine ubuntu

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
if grep -vE "$READS" "$CALLS" | grep -q .; then fail "fresh --check changed something: $(grep -vE "$READS" "$CALLS")"
else log "fresh --check -> read-only"; fi

# 3. --yes fixes every item; the prompts get name, email and the default key title.
run 'Fixture User\nfixture@example.com\n\n' --yes
if [[ "$rc" -eq 0 ]]; then log "fresh --yes -> exit 0"; else fail "fresh --yes: rc $rc: $(cat "$OUT")"; fi
in_order "apt-get install -y git" "docker.io docker-compose-v2 docker-buildx" "apt-get install -y gh" \
  "snap install node --classic --channel=26/stable" \
  "usermod -aG docker" "ssh-keygen -t ed25519 -C fixture@example.com" \
  "gh auth login -h github.com -p ssh --skip-ssh-key -s admin:public_key,admin:ssh_signing_key" "pipx install --force uv" \
  "npm config set prefix $HOME_DIR/.local" \
  "npm config set allow-scripts=pnpm,tree-sitter-cli --location=user" "uv tool install ruff" "claude plugin install" \
  "gh ssh-key add $HOME_DIR/.ssh/id_ed25519.pub --type authentication" \
  "gh ssh-key add $HOME_DIR/.ssh/id_ed25519.pub --type signing" "nvim --headless"
log "--yes -> fixes run in item order"
if grep -q '^gh auth refresh' "$CALLS"; then fail "--yes asked for a second gh approval"
else log "--yes -> the gh login carries the key scopes"; fi
# shellcheck disable=SC2016 # the new shell expands $PATH
path="$(env -i HOME="$HOME_DIR" PATH=/usr/bin:/bin bash -c '. ~/.bash_aliases >/dev/null 2>&1; echo "$PATH"')"
if [[ ":$path:" == *":$HOME_DIR/.local/bin:"* ]]; then log "--yes -> a new terminal has ~/.local/bin"
else fail "a new terminal lacks ~/.local/bin: $path"; fi
if [[ "$(git -C "$CLONE" remote get-url origin)" == git@github.com:nicograef/handbook.git ]]; then
  log "--yes -> origin over SSH"; else fail "origin not switched to SSH"; fi
if grep -qF 'docker group' "$OUT" && grep -qF 'Log out and back in' "$OUT"; then
  log "--yes -> asks for a new login"; else fail "no new-login notice: $(cat "$OUT")"; fi

# 4. The fixed machine matches.
run '' --check
if [[ "$rc" -eq 0 && "$(rows ok)" -eq 18 ]]; then log "fixed --check -> 18 rows ok"
else fail "fixed --check: rc $rc: $(cat "$OUT")"; fi

# 5. A login without the key scopes, the authentication key already on GitHub, the font gone.
grep -F authentication "$STATE/keys" > "$STATE/keys.auth" && mv "$STATE/keys.auth" "$STATE/keys"
printf 'repo\n' > "$STATE/scopes"
rm -r "$HOME_DIR/.local/share/fonts/nerd"
run '\n' --yes
refreshes="$(grep -c '^gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key$' "$CALLS" || true)"
adds="$(grep '^gh ssh-key add' "$CALLS" || true)"
if [[ "$rc" -eq 0 && "$refreshes" -eq 1 && "$adds" == *"--type signing"* && "$adds" != *authentication* ]]; then
  log "scopeless login -> one refresh, only the signing key added"
else fail "scopeless login: rc $rc, $refreshes refreshes, adds: $adds: $(cat "$OUT")"; fi
if grep -qF 'terminal finds the new font' "$OUT"; then log "font fix -> asks for a new login"
else fail "no new-login notice after the font fix: $(cat "$OUT")"; fi

# 6. A broken snap probe stops the run with its name, never silently.
touch "$STATE/nosnap"
run '' --check
if [[ "$rc" -ne 0 && "$rc" -ne 1 ]] && grep -qE '^ERROR: .*snap refresh --list.* failed \(exit 127' "$OUT"; then
  log "broken snap probe -> named, exit $rc"
else fail "broken snap probe: rc $rc: $(cat "$OUT")"; fi
rm "$STATE/nosnap"

# 7. Another distro is refused before any probe.
printf 'ID=fedora\n' > "$FIX/etc/os-release"
run '' --check
if [[ "$rc" -eq 1 ]] && grep -qF "supports Ubuntu and Debian; $FIX/etc/os-release names 'fedora'" "$OUT" && ! grep -q . "$CALLS"; then
  log "fedora -> refused"
else fail "fedora: rc $rc: $(cat "$OUT")"; fi

# 8. Debian: no snap call even with snapd broken, and the distro's docker packages.
fresh_machine debian
touch "$STATE/nosnap"
run '' --check
if [[ "$rc" -eq 1 && "$(rows ok)" -eq 1 ]] && grep -qE '^MISSING +Go ' "$OUT"; then log "debian fresh --check -> exit 1, 19 rows differ"
else fail "debian fresh --check: rc $rc, ok rows $(rows ok): $(cat "$OUT")"; fi
if grep -vE "$READS" "$CALLS" | grep -q .; then fail "debian fresh --check changed something: $(grep -vE "$READS" "$CALLS")"
else log "debian fresh --check -> read-only"; fi

run 'Fixture User\nfixture@example.com\n\n' --yes
if [[ "$rc" -eq 0 ]]; then log "debian fresh --yes -> exit 0"; else fail "debian fresh --yes: rc $rc: $(cat "$OUT")"; fi
in_order "apt-get install -y git" "docker.io docker-compose docker-buildx" "apt-get install -y gh" "nodesource-setup" \
  "apt-get install -y nodejs" "curl -fsSL https://go.dev/dl/go1.99.0.linux-$ARCH.tar.gz" \
  "curl -fsSL https://github.com/neovim/neovim/releases/download/v0.99.0/nvim-linux-$NVIM_ARCH.tar.gz" \
  "usermod -aG docker" "pipx install --force uv" "npm config set prefix $HOME_DIR/.local" "nvim --headless"
log "debian --yes -> fixes run in item order"
if grep -q '^snap' "$CALLS"; then fail "debian --yes called snap"; else log "debian --yes -> no snap call"; fi
if [[ "$(readlink -f "$HOME_DIR/.local/bin/nvim")" == "$HOME_DIR/.local/nvim-linux-$NVIM_ARCH/bin/nvim" \
  && -x "$FIX/usr-local/go/bin/go" ]]; then log "debian --yes -> nvim in ~/.local, go in GO_ROOT"
else fail "debian --yes: nvim or go not in place"; fi

run '' --check
if [[ "$rc" -eq 0 && "$(rows ok)" -eq 20 ]]; then log "debian fixed --check -> 20 rows ok"
else fail "debian fixed --check: rc $rc: $(cat "$OUT")"; fi

# A rerun on the fixed machine reports every row ok and runs no fix.
run '' --yes
if [[ "$rc" -eq 0 && "$(rows ok)" -eq 20 ]] && ! grep -qE "$WRITES" "$CALLS"; then log "debian rerun --yes -> changes nothing"
else fail "debian rerun --yes: rc $rc: $(grep -E "$WRITES" "$CALLS")"; fi

# A host with Docker's own packages, as setup-server.sh installs them, keeps them.
rm "$STATE/apt"
touch "$STATE/docker-ce"
run '' --yes
if grep -qF 'docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin' "$CALLS" \
  && ! grep -qF 'docker.io' "$CALLS"; then log "docker-ce host -> keeps docker-ce"
else fail "docker-ce host: $(grep '^apt-get install' "$CALLS")"; fi

finish
