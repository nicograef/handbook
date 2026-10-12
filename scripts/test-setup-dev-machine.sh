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
#   4. Reruns --yes on a gh login that lacks the key scopes and a deleted font, then with both keys present,
#      with an inactive account holding the scopes or an invalid token, and with a key list that fails whole
#      or for one type.
#   5. Asserts a broken snap probe names itself and another distro is refused.
#   6. Repeats the fresh and fixed runs on a headless Debian: no snap, the Node, Go and Neovim tarballs,
#      no font or xclip. A rerun changes nothing; a Node upgrade drops the old files; a wrong signature or
#      digest leaves the old trees; a NodeSource host moves to the tarball; a host with docker-ce keeps it
#      and never upgrades it; a --yes without a terminal skips the human steps.
#   Every --check leaves the fixture's files as they were.

set -euo pipefail

# shellcheck source=scripts/lib/test-harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/test-harness.sh"

CLONE="$FIX/handbook"
HOME_DIR="$FIX/home"
STATE="$FIX/state"
CALLS="$FIX/calls"
OUT="$FIX/stdout"
ARCH="$(dpkg --print-architecture)"
if [[ "$ARCH" == amd64 ]]; then NVIM_ARCH=x86_64 NODE_ARCH=x64; else NVIM_ARCH="$ARCH" NODE_ARCH="$ARCH"; fi
mkdir -p "$CLONE" "$FIX/bin" "$FIX/font" "$FIX/go/go/bin" "$FIX/nvim/nvim-linux-$NVIM_ARCH/bin"

tar -C "$REPO_ROOT" --exclude=.git -cf - . | tar -C "$CLONE" -xf -
git -C "$CLONE" init -q
touch "$FIX/font/SymbolsNerdFont-Regular.ttf"
tar -C "$FIX/font" -cJf "$FIX/font.tar.xz" .

# fresh_machine <os-release ID> — an empty home, no state, an HTTPS origin.
fresh_machine() {
  rm -rf "$HOME_DIR" "$STATE" "${FIX:?}/etc" "$FIX/usr-local" "${FIX:?}/usr"
  rm -f "$FIX/bin/npm" "$FIX/bin/nvim" "$FIX/bin/uv" "$FIX/bin/claude"
  mkdir -p "$HOME_DIR" "$STATE" "$FIX/etc" "$FIX/usr-local"
  printf 'PRETTY_NAME="fixture"\nID=%s\n' "$1" > "$FIX/etc/os-release"
  # The Ubuntu fixture is a desktop, the Debian one a headless VPS.
  if [[ "$1" == ubuntu ]]; then touch "$STATE/xwayland"; fi
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
    elif [[ -f "$S/$pkg" || ( " gh nodejs docker-ce xwayland xserver-xorg-core " != *" $pkg "* && -f "$S/apt" ) ]]; then
      printf 'install ok installed'
    else exit 1; fi ;;
  apt) echo 'Listing...'; cat "$S/upgradable" 2>/dev/null ;;
  apt-get)
    if [[ "$1 $2" == "install -y" && "$3" == gh ]]; then touch "$S/gh"; appear gh
    elif [[ "$1 $2" == "remove -y" ]]; then rm -f "$S/$3"
    elif [[ "$1 $2" == "-s remove" ]]; then echo "Remv $3 [1]"; cat "$S/rdeps" 2>/dev/null
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
      *nodejs.org/dist/index.json*) cat "$FIX/node-index.json" ;;
      *release-keys*) cp "$FIX/node-keys.gpg" "${*: -1}" ;;
      *nodejs.org/dist/v26.*/SHASUMS256.txt.asc*) cp "$FIX/node-shasums.asc" "${*: -1}" ;;
      *nodejs.org/dist/v26.*/node-*) out="${*: -1}"; cp "$FIX/${out##*/}" "$out" ;;
      *go.dev/dl/?mode=json*) cat "$FIX/go.json" ;;
      *go.dev/dl/go1.99.*) cp "$FIX/go.tar.gz" "${*: -1}" ;;
      *api.github.com/repos/neovim*) cat "$FIX/nvim.json" ;;
      *releases/download/v0.99.*) cp "$FIX/nvim.tar.gz" "${*: -1}" ;;
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
    # $S/scopes holds the active token's scopes, one per line, $S/otherscopes an inactive account's;
    # login and refresh take them from -s, the last argument.
    has() { grep -qx "$1" "$S/scopes" 2>/dev/null; }
    scopes() { paste -sd, "$1" 2>/dev/null | sed 's/,/, /g'; }
    # list_type <type> <scope> — one key type's rows, or gh's warning when the scope or $S/<type>down denies it.
    list_type() {
      if has "$2" && [[ ! -f "$S/$1down" ]]; then grep -P "\t$1\$" "$S/keys" 2>/dev/null; return 0; fi
      echo "warning:  HTTP 404: Not Found (https://api.github.com/user/$1)" >&2; return 1
    }
    case "$1 $2" in
      "--version "*) echo 'gh version 2.0.0' ;;
      "auth status")
        [[ -f "$S/ghauth" ]] || exit 1
        # $S/otherbad: the inactive account's token is invalid, and gh then exits 1 unless --active.
        [[ -f "$S/otherbad" && "$*" != *--active* && "$*" != *--json* ]] && exit 1
        if [[ "$*" == *--json* ]]; then
          # Without --active, gh lists every account of the host, as the text form does.
          other=false; [[ -f "$S/otherscopes" && "$*" != *--active* ]] && other=true
          jq -n --arg s "$(scopes "$S/scopes")" --arg o "$(scopes "$S/otherscopes")" --argjson other "$other" \
            '{hosts: {"github.com": ([{active: true, scopes: $s}] + if $other then [{active: false, scopes: $o}] else [] end)}}' \
            | jq -r "${*: -1}"
        else
          echo "  - Token scopes: $(sed "s/.*/'&'/" "$S/scopes" 2>/dev/null | paste -sd,)"
          [[ -f "$S/otherscopes" ]] && echo "  - Active account: false"$'\n'"  - Token scopes: $(sed "s/.*/'&'/" "$S/otherscopes" | paste -sd,)"
        fi ;;
      "auth login"|"auth refresh") touch "$S/ghauth"; tr , '\n' <<<"${*: -1}" >> "$S/scopes" ;;
      "ssh-key list")
        [[ -f "$S/listdown" ]] && { echo 'warning:  HTTP 502: Bad Gateway (https://api.github.com/user/keys)' >&2; exit 1; }
        fails=0
        list_type authentication admin:public_key || fails=$((fails + 1))
        list_type signing admin:ssh_signing_key || fails=$((fails + 1))
        [[ "$fails" -lt 2 ]] || exit 1 ;;
      "ssh-key add")
        if [[ "$5" == signing ]]; then has admin:ssh_signing_key || exit 1; else has admin:public_key || exit 1; fi
        printf 'title\tssh-ed25519 AAAAFIXTUREKEY\tdate\t1\t%s\n' "$5" >> "$S/keys" ;;
    esac ;;
  pipx)
    case "$*" in
      "list --short") [[ -f "$S/pipxuv" ]] && echo 'uv 1.0.0' ;;
      "install --force uv") touch "$S/pipxuv"; appear uv; mkdir -p "$FIX/home/.local/bin"; ln -sf "$FIX/stub" "$FIX/home/.local/bin/uv" ;;
    esac ;;
  # Only the GitHub key title's prompt and default call it: its call log line marks the ask under piped stdin.
  hostname) echo fixture ;;
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
for c in dpkg-query apt apt-get snap id usermod curl git ssh-keygen pipx fc-list fc-cache gh hostname; do
  ln -s "$FIX/stub" "$FIX/bin/$c"
done

# The Debian downloads: Go and Neovim tarballs whose binaries are the stub, their release JSON with
# the real digests, and Node tarballs whose SHASUMS256.txt a fixture releaser key signs.
cp "$FIX/stub" "$FIX/go/go/bin/go"
tar -C "$FIX/go" -czf "$FIX/go.tar.gz" go
cp "$FIX/stub" "$FIX/nvim/nvim-linux-$NVIM_ARCH/bin/nvim"
tar -C "$FIX/nvim" -czf "$FIX/nvim.tar.gz" "nvim-linux-$NVIM_ARCH"
jq -n --arg a "$ARCH" --arg s "$(sha256sum "$FIX/go.tar.gz" | cut -d' ' -f1)" \
  '[{version: "go1.99.0", files: [{os: "linux", arch: $a, kind: "archive", sha256: $s}]}]' > "$FIX/go.json"
jq -n --arg n "nvim-linux-$NVIM_ARCH.tar.gz" --arg d "sha256:$(sha256sum "$FIX/nvim.tar.gz" | cut -d' ' -f1)" \
  '{tag_name: "v0.99.0", assets: [{name: $n, digest: $d}]}' > "$FIX/nvim.json"
export GNUPGHOME="$FIX/gnupg"
mkdir -m 700 "$GNUPGHOME"
# Two releaser keys: the pinned one and one in the keyring that NODE_KEYS leaves out.
for who in Releaser Stranger; do
  gpg --batch --quiet --passphrase '' --quick-gen-key "Fixture $who <$who@example.com>" ed25519 sign never 2>/dev/null
done
mapfile -t keys < <(gpg --batch --with-colons --list-keys 2>/dev/null | awk -F: '$1 == "pub" {p = 1} $1 == "fpr" && p {print $10; p = 0}')
NODE_KEY="${keys[0]}" STRANGER_KEY="${keys[1]}"
gpg --batch --export 2>/dev/null > "$FIX/node-keys.gpg"
# node_tarball <version> [extra file|-include] — a Node tarball: node prints the version, npm is the stub;
# -include leaves out include/, so extracting the named members fails halfway.
node_tarball() {
  local top="node-$1-linux-$NODE_ARCH" d="$FIX/nodetar"
  rm -rf "$d" && mkdir -p "$d/$top/bin" "$d/$top/lib/node_modules/npm" "$d/$top/include/node" "$d/$top/share/doc/node"
  printf '#!/bin/sh\necho %s\n' "$1" > "$d/$top/bin/node" && chmod +x "$d/$top/bin/node"
  cp "$FIX/stub" "$d/$top/bin/npm"
  touch "$d/$top/lib/node_modules/npm/package.json" "$d/$top/include/node/node.h" "$d/$top/share/doc/node/notes" "$d/$top/README.md"
  case "${2:-}" in
    -include) rm -r "$d/$top/include" ;;
    ?*) touch "$d/$top/$2" ;;
  esac
  tar -C "$d" -cJf "$FIX/$top.tar.xz" "$top"
}
# node_release <version> [sha256] [signer] — index.json names it newest of 26; SHASUMS256.txt carries its
# digest or the given one, signed by the pinned key or the given one.
node_release() {
  local file="node-$1-linux-$NODE_ARCH.tar.xz"
  jq -n --arg v "$1" --arg f "linux-$NODE_ARCH" '[{version: $v, files: [$f]}, {version: "v25.9.0", files: [$f]}]' > "$FIX/node-index.json"
  printf '%s  %s\n' "${2:-$(sha256sum "$FIX/$file" | cut -d' ' -f1)}" "$file" \
    | gpg --batch --quiet --local-user "${3:-$NODE_KEY}" --clearsign 2>/dev/null > "$FIX/node-shasums.asc"
}
node_tarball v26.99.0 bin/npx
node_tarball v26.99.1
node_release v26.99.0

export PATH="$FIX/bin:$PATH"
TARGET_USER="$(id -un)"
export TARGET_USER TARGET_HOME="$HOME_DIR" ETC_DIR="$FIX/etc" GO_ROOT="$FIX/usr-local/go"
export NODE_PREFIX="$FIX/usr-local" NODE_KEYS="$NODE_KEY"
# The user's PATH holds the stubs and these system tools only, so a real npm, uv or nvim on the host stays out.
mkdir -p "$FIX/sysbin"
for c in bash sh env git mkdir cp mv chmod rm ln readlink cat grep sed awk tr cut sort head paste jq mktemp \
  tar xz gzip basename dirname touch; do
  ln -s "$(command -v "$c")" "$FIX/sysbin/$c"
done
export USER_PATH="$HOME_DIR/.local/bin:$FIX/usr-local/bin:$FIX/bin:$FIX/sysbin"
SCRIPT="$CLONE/scripts/setup-dev-machine.sh"
# What a --check on a fresh machine may call: reads only.
READS='^(dpkg-query .*|apt list .*|snap (list|refresh --list).*|id .*|curl .*(pypi|go\.dev/dl/\?mode|api\.github|nodejs\.org/dist/index)[^ ]*'
READS+='|git (-C [^ ]+ (rev-parse HEAD|remote get-url origin)|config --global [a-zA-Z.]+)|fc-list .*|gh auth status( .*)?|pipx list --short)$'
# What a fix calls: a rerun on a matching machine must call none of them.
WRITES='^(apt-get (install|remove)|snap (install|refresh [a-z])|usermod|ssh-keygen|gh (auth (login|refresh)|ssh-key add)|pipx (install|upgrade)|npm (config set|install)|uv tool (install|upgrade)|claude plugin (install|marketplace)|curl -fsSL|nvim --headless|git (config --global [a-zA-Z.]+ .|remote set-url)|fc-cache)'

run() { # run <stdin> [args...]; sets rc, stdout in $OUT
  local input="$1"
  shift
  : > "$CALLS"
  rc=0
  printf '%b' "$input" | bash "$SCRIPT" "$@" > "$OUT" 2>&1 || rc=$?
}

rows() { grep -cE "^$1 " "$OUT" || true; }

# snapshot — every file of the fake machine with its mtime and size.
snapshot() { find "$HOME_DIR" "$STATE" "$FIX/etc" "$FIX/usr-local" "$CLONE" -printf '%p %T@ %s\n' | sort; }

# node_kept — the v26.99.0 install is whole.
node_kept() { [[ "$("$FIX/usr-local/bin/node")" == v26.99.0 && -f "$FIX/usr-local/bin/npx" && -f "$FIX/usr-local/lib/node_modules/npm/package.json" ]]; }

# check_run <label> — run --check and fail if it touched a file.
check_run() {
  local before
  before="$(snapshot)"
  run '' --check
  if [[ "$(snapshot)" != "$before" ]]; then fail "$1 --check changed files: $(diff <(echo "$before") <(snapshot) | head -5)"
  else log "$1 --check -> no file changed"; fi
}

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

export SETUP_ALLOW_NONROOT=true SETUP_ASSUME_TTY=true

# 2. A fresh machine: everything but the absent apt neovim differs, and nothing changes.
check_run fresh
if [[ "$rc" -eq 1 && "$(rows ok)" -eq 1 ]]; then log "fresh --check -> exit 1, 17 rows differ"
else fail "fresh --check: rc $rc, ok rows $(rows ok): $(cat "$OUT")"; fi
if grep -vE "$READS" "$CALLS" | grep -q .; then fail "fresh --check changed something: $(grep -vE "$READS" "$CALLS")"
else log "fresh --check -> read-only"; fi

# 3. --yes fixes every item; the prompts get name, email and the default key title.
run 'Fixture User\nfixture@example.com\n\n' --yes
if [[ "$rc" -eq 0 ]]; then log "fresh --yes -> exit 0"; else fail "fresh --yes: rc $rc: $(cat "$OUT")"; fi
in_order "apt-get install -y git" "xz-utils xclip" "apt-get install -y --no-upgrade docker.io docker-compose-v2 docker-buildx" \
  "apt-get install -y gh" \
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
check_run fixed
if [[ "$rc" -eq 0 && "$(rows ok)" -eq 18 ]]; then log "fixed --check -> 18 rows ok"
else fail "fixed --check: rc $rc: $(cat "$OUT")"; fi

# 5. A login without the key scopes, the authentication key already on GitHub, the font gone.
grep -F authentication "$STATE/keys" > "$STATE/keys.auth" && mv "$STATE/keys.auth" "$STATE/keys"
printf 'repo\n' > "$STATE/scopes"
rm -r "$HOME_DIR/.local/share/fonts/nerd"
run '\n' --yes
refreshes="$(grep -c '^gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key$' "$CALLS" || true)"
adds="$(grep '^gh ssh-key add' "$CALLS" || true)"
if [[ "$rc" -eq 0 && "$refreshes" -eq 1 && "$adds" == *"--type signing"* && "$adds" != *authentication* ]] \
  && grep -q '^hostname' "$CALLS"; then
  log "scopeless login -> one refresh, title asked, only the signing key added"
else fail "scopeless login: rc $rc, $refreshes refreshes, adds: $adds: $(cat "$OUT")"; fi
if grep -qF 'terminal finds the new font' "$OUT"; then log "font fix -> asks for a new login"
else fail "no new-login notice after the font fix: $(cat "$OUT")"; fi

# 5b. A login without the key scopes, both keys already on GitHub: the row names the scopes, no title is asked.
printf 'repo\n' > "$STATE/scopes"
run '' --check
if grep -qE '^WRONG .*lacks admin:public_key admin:ssh_signing_key' "$OUT"; then log "scopeless login, keys present --check -> names the scopes"
else fail "scopeless login, keys present --check: $(cat "$OUT")"; fi
run '' --yes
if [[ "$rc" -eq 0 ]] && ! grep -qE '^(gh ssh-key add|hostname)' "$CALLS"; then
  log "scopeless login, keys present --yes -> no title asked, nothing added"
else fail "scopeless login, keys present --yes: rc $rc: $(cat "$OUT")"; fi

# 5c. An inactive account holds the key scopes the active login lacks: the row still names the scopes.
printf 'repo\n' > "$STATE/scopes"
printf 'admin:public_key\nadmin:ssh_signing_key\n' > "$STATE/otherscopes"
run '' --check
if grep -qE '^WRONG .*lacks admin:public_key admin:ssh_signing_key' "$OUT"; then log "inactive account's scopes --check -> names the scopes"
else fail "inactive account's scopes --check: $(cat "$OUT")"; fi
run 'ne\n' --yes
if [[ "$rc" -eq 0 ]] && ! grep -qE '^(gh ssh-key add|hostname)' "$CALLS"; then log "inactive account's scopes --yes -> no title asked, nothing added"
else fail "inactive account's scopes --yes: rc $rc: $(cat "$OUT")"; fi
rm "$STATE/otherscopes"

# 5d. An inactive account with an invalid token leaves the active login and the keys ok.
touch "$STATE/otherbad"
run '' --check
if grep -qE '^ok +gh login' "$OUT" && grep -qE '^ok +GitHub keys' "$OUT"; then log "invalid inactive account --check -> login and keys ok"
else fail "invalid inactive account --check: $(cat "$OUT")"; fi
rm "$STATE/otherbad"

# 5e. Both keys on GitHub, but the list fails whole or for one type: WRONG with gh's error, nothing added.
for down in listdown signingdown; do
  touch "$STATE/$down"
  run '' --check
  if grep -qE '^WRONG +GitHub keys +cannot list the GitHub keys: HTTP' "$OUT"; then log "$down --check -> WRONG with gh's error"
  else fail "$down --check: $(cat "$OUT")"; fi
  run 'ne\n' --yes
  if [[ "$rc" -eq 1 ]] && ! grep -qE '^(gh (ssh-key add|auth refresh)|hostname)' "$CALLS" && grep -qF 'Cannot list the GitHub keys' "$OUT"; then
    log "$down --yes -> no refresh, no title asked, nothing added, still WRONG"
  else fail "$down --yes: rc $rc: $(cat "$OUT")"; fi
  rm "$STATE/$down"
done

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

# 8. A headless Debian: no snap call even with snapd broken, the distro's docker packages, no font or xclip.
fresh_machine debian
touch "$STATE/nosnap"
check_run "debian fresh"
if [[ "$rc" -eq 1 && "$(rows ok)" -eq 3 ]] && grep -qE '^MISSING +Go ' "$OUT" && grep -qE '^MISSING +Node ' "$OUT" \
  && grep -qE '^ok +Nerd Font +not needed: no display server' "$OUT"; then log "debian fresh --check -> exit 1, 18 rows differ, no font"
else fail "debian fresh --check: rc $rc, ok rows $(rows ok): $(cat "$OUT")"; fi
if grep -vE "$READS" "$CALLS" | grep -q .; then fail "debian fresh --check called more than reads: $(grep -vE "$READS" "$CALLS")"
else log "debian fresh --check -> reads only"; fi

run 'Fixture User\nfixture@example.com\n\n' --yes
if [[ "$rc" -eq 0 ]] && ! grep -qF 'failed (exit' "$OUT"; then log "debian fresh --yes -> exit 0, no fix failed"
else fail "debian fresh --yes: rc $rc: $(cat "$OUT")"; fi
in_order "apt-get install -y git" "apt-get install -y --no-upgrade docker.io docker-compose docker-buildx" \
  "apt-get install -y gh" "curl -fsSL https://nodejs.org/dist/v26.99.0/node-v26.99.0-linux-$NODE_ARCH.tar.xz" \
  "curl -fsSL https://go.dev/dl/go1.99.0.linux-$ARCH.tar.gz" \
  "curl -fsSL https://github.com/neovim/neovim/releases/download/v0.99.0/nvim-linux-$NVIM_ARCH.tar.gz" \
  "usermod -aG docker" "pipx install --force uv" "npm config set prefix $HOME_DIR/.local" "nvim --headless"
log "debian --yes -> fixes run in item order"
if grep -q '^snap' "$CALLS"; then fail "debian --yes called snap"; else log "debian --yes -> no snap call"; fi
if grep -qE 'xclip|nerd-fonts|^fc-cache' "$CALLS"; then fail "headless --yes installed xclip or the font"
else log "headless --yes -> no xclip, no font"; fi
if [[ "$(readlink -f "$HOME_DIR/.local/bin/nvim")" == "$HOME_DIR/.local/nvim-linux-$NVIM_ARCH/bin/nvim" \
  && -x "$FIX/usr-local/go/bin/go" ]]; then log "debian --yes -> nvim in ~/.local, go in GO_ROOT"
else fail "debian --yes: nvim or go not in place"; fi
if node_kept && [[ ! -e "$FIX/usr-local/README.md" ]] && grep -qx 'bin/npx' "$FIX/usr-local/lib/node-tarball.files"; then
  log "debian --yes -> node in NODE_PREFIX, manifest written"
else fail "debian --yes: node install: $(find "$FIX/usr-local" -maxdepth 3 | head -20)"; fi

check_run "debian fixed"
if [[ "$rc" -eq 0 && "$(rows ok)" -eq 21 ]]; then log "debian fixed --check -> 21 rows ok"
else fail "debian fixed --check: rc $rc: $(cat "$OUT")"; fi

# A rerun on the fixed machine reports every row ok and runs no fix.
run '' --yes
if [[ "$rc" -eq 0 && "$(rows ok)" -eq 21 ]] && ! grep -qE "$WRITES" "$CALLS"; then log "debian rerun --yes -> changes nothing"
else fail "debian rerun --yes: rc $rc: $(grep -E "$WRITES" "$CALLS")"; fi

# 9. Newer Go and Neovim releases whose digests do not match: both fixes fail, the old trees stay.
cp "$FIX/go.json" "$FIX/go.json.good"
cp "$FIX/nvim.json" "$FIX/nvim.json.good"
jq '.[0].version = "go1.99.1" | .[0].files[0].sha256 = ("0" * 64)' "$FIX/go.json.good" > "$FIX/go.json"
jq '.tag_name = "v0.99.1" | .assets[0].digest = ("sha256:" + "0" * 64)' "$FIX/nvim.json.good" > "$FIX/nvim.json"
run '' --yes
if [[ "$rc" -eq 1 ]] && grep -qF 'Fix for Go failed' "$OUT" && grep -qF 'Fix for Neovim failed' "$OUT" \
  && [[ -x "$FIX/usr-local/go/bin/go" && -x "$HOME_DIR/.local/nvim-linux-$NVIM_ARCH/bin/nvim" ]]; then
  log "wrong digests -> both fixes fail, old trees kept"
else fail "wrong digests: rc $rc: $(cat "$OUT")"; fi
mv "$FIX/go.json.good" "$FIX/go.json"
mv "$FIX/nvim.json.good" "$FIX/nvim.json"

# 10. A newer Node whose signature is broken, signed by an unpinned key, whose digest is wrong, or whose
#     extraction fails halfway: the fix fails, v26.99.0 stays whole.
node_release v26.99.1
sed -i 's/^\([0-9a-f]\{63\}\)[0-9a-f]  /\1x  /' "$FIX/node-shasums.asc"
run '' --yes
if [[ "$rc" -eq 1 ]] && grep -qF 'Fix for Node failed' "$OUT" && grep -qF 'no valid signature of a pinned releaser key' "$OUT" \
  && node_kept; then log "broken signature -> node fix fails, old install kept"
else fail "broken signature: rc $rc: $(cat "$OUT")"; fi
node_release v26.99.1 "$(printf '0%.0s' {1..64})"
run '' --yes
if [[ "$rc" -eq 1 ]] && grep -qF 'Fix for Node failed' "$OUT" && grep -qF 'FAILED' "$OUT" && node_kept; then
  log "wrong digest -> node fix fails, old install kept"
else fail "wrong digest: rc $rc: $(cat "$OUT")"; fi
node_release v26.99.1 "" "$STRANGER_KEY"
run '' --yes
if [[ "$rc" -eq 1 ]] && grep -qF 'no valid signature of a pinned releaser key' "$OUT" && node_kept; then
  log "unpinned signer -> node fix fails, old install kept"
else fail "unpinned signer: rc $rc: $(cat "$OUT")"; fi
node_tarball v26.99.1 -include
node_release v26.99.1
run '' --yes
if [[ "$rc" -eq 1 ]] && grep -qF 'Fix for Node failed' "$OUT" && node_kept \
  && [[ -s "$FIX/usr-local/lib/node-tarball.files" ]] && ! compgen -G "$FIX/usr-local/.node-stage.*" >/dev/null; then
  log "extraction fails halfway -> live install and manifest untouched, stage removed"
else fail "extraction fails halfway: rc $rc: $(cat "$OUT")"; fi
node_tarball v26.99.1

# An install with a file gone or no manifest is unfinished: WRONG, and the fix puts it back.
rm -r "$FIX/usr-local/lib/node_modules/npm"
node_release v26.99.0
run '' --check
if [[ "$rc" -eq 1 ]] && grep -qE '^WRONG +Node +gone: lib/node_modules/npm' "$OUT"; then log "file gone -> WRONG"
else fail "file gone: rc $rc: $(cat "$OUT")"; fi
rm "$FIX/usr-local/lib/node-tarball.files"
run '' --check
if [[ "$rc" -eq 1 ]] && grep -qE '^WRONG +Node +no .*node-tarball.files: the last install did not finish' "$OUT"; then
  log "no manifest -> WRONG"
else fail "no manifest: rc $rc: $(cat "$OUT")"; fi
run '' --yes
if [[ "$rc" -eq 0 ]] && node_kept; then log "unfinished install -> reinstalled"; else fail "reinstall: rc $rc: $(cat "$OUT")"; fi

# A corrupt manifest: its bad lines are reported and never deleted.
mkdir -p "$FIX/etc/keep" && touch "$FIX/usr-local/lib/keep" "$FIX/etc/keep/file"
printf '\nlib\n../etc\nbin/../../etc\nbin/node\n' >> "$FIX/usr-local/lib/node-tarball.files"
run '' --check
if [[ "$rc" -eq 1 ]] && grep -qF "manifest lines outside bin, include, lib and share: '' 'lib' '../etc' 'bin/../../etc'" "$OUT"; then
  log "corrupt manifest -> WRONG, lines named"
else fail "corrupt manifest --check: rc $rc: $(cat "$OUT")"; fi

# A valid newer release replaces the old one, drops the files it no longer ships, and skips bad lines.
node_release v26.99.1
run '' --yes
if [[ "$rc" -eq 0 && "$("$FIX/usr-local/bin/node")" == v26.99.1 && ! -e "$FIX/usr-local/bin/npx" ]] \
  && [[ -f "$FIX/usr-local/lib/keep" && -f "$FIX/etc/keep/file" ]] && grep -qF 'Skipping manifest line' "$OUT"; then
  log "node upgrade -> v26.99.1, stale npx gone, bad manifest lines left alone"
else fail "node upgrade: rc $rc: $(cat "$OUT")"; fi

# An index naming an older signed release: no downgrade, from the check or the fix.
node_release v26.99.0
run '' --check
if [[ "$rc" -eq 0 ]] && grep -qE '^ok +Node +nodejs.org names the older v26.99.0; kept v26.99.1' "$OUT"; then
  log "older index -> ok, kept"
else fail "older index --check: rc $rc: $(cat "$OUT")"; fi
rm "$FIX/usr-local/lib/node-tarball.files"
run '' --yes
if [[ "$rc" -eq 1 && "$("$FIX/usr-local/bin/node")" == v26.99.1 ]] && grep -qF 'no downgrade' "$OUT"; then
  log "older index -> the fix refuses to downgrade"
else fail "older index --yes: rc $rc: $(cat "$OUT")"; fi
node_release v26.99.1
run '' --yes
if [[ "$rc" -eq 0 ]]; then log "same release -> manifest rewritten"; else fail "same release: rc $rc: $(cat "$OUT")"; fi

# Without nodejs.org the check says so instead of a silent ok.
mv "$FIX/node-index.json" "$FIX/node-index.json.off"
run '' --check
if [[ "$rc" -eq 0 ]] && grep -qE '^ok +Node +nodejs.org did not answer; version not compared' "$OUT"; then
  log "nodejs.org offline -> ok with a note"
else fail "nodejs.org offline: rc $rc: $(cat "$OUT")"; fi
mv "$FIX/node-index.json.off" "$FIX/node-index.json"

# 11. A host with Docker's own packages, as setup-server.sh installs them: kept, and a newer docker-ce
#     is no reason to touch it.
touch "$STATE/docker-ce"
printf 'docker-ce/trixie 5:99 amd64 [upgradable from: 5:98]\n' > "$STATE/upgradable"
run '' --check
if [[ "$rc" -eq 0 ]]; then log "docker-ce upgradable -> still ok"; else fail "docker-ce upgradable: rc $rc: $(cat "$OUT")"; fi
rm "$STATE/apt"
run '' --yes
if grep -qxF 'apt-get install -y --no-upgrade docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin' "$CALLS" \
  && ! grep -E '^apt-get install -y [^-]' "$CALLS" | grep -qF docker && ! grep -qF 'docker.io' "$CALLS"; then
  log "docker-ce host -> keeps docker-ce, installs only what is missing"
else fail "docker-ce host: $(grep '^apt-get install' "$CALLS")"; fi

# 12. A NodeSource host: the check names what NodeSource left. A tarball that fails verification leaves the
#     apt Node alone; one that installs is followed by the removal, after its prompt.
fresh_machine debian
node_tarball v26.99.0 bin/npx
node_release v26.99.0
sed -i 's/^\([0-9a-f]\{63\}\)[0-9a-f]  /\1x  /' "$FIX/node-shasums.asc"
mkdir -p "$FIX/etc/apt/sources.list.d" "$FIX/etc/apt/preferences.d" "$FIX/etc/apt/apt.conf.d" "$FIX/usr/share/keyrings"
touch "$FIX/etc/apt/sources.list.d/nodesource.sources" "$FIX/etc/apt/preferences.d/nodejs" "$FIX/etc/apt/preferences.d/nsolid" \
  "$FIX/etc/apt/apt.conf.d/52unattended-upgrades-nodesource" "$FIX/usr/share/keyrings/nodesource.gpg" "$STATE/nodejs"
check_run "nodesource"
if grep -qE '^WRONG +no apt nodejs +apt nodejs 26\.1\.0-1nodesource1 \(removes: nodejs\) sources\.list\.d/nodesource\.sources keyrings/nodesource\.gpg.*replaces them once installed' "$OUT"; then
  log "nodesource --check -> WRONG with what it left"
else fail "nodesource --check: $(cat "$OUT")"; fi
run 'y\nFixture User\nfixture@example.com\n\n' --yes
if [[ "$rc" -eq 1 && -f "$STATE/nodejs" && -f "$FIX/etc/apt/sources.list.d/nodesource.sources" ]] \
  && ! grep -q '^apt-get remove -y nodejs' "$CALLS" && grep -qF 'Fix for Node failed' "$OUT"; then
  log "nodesource, tarball fails -> apt Node kept"
else fail "nodesource, tarball fails: rc $rc: $(grep '^apt-get' "$CALLS")"; fi
node_release v26.99.0
printf 'Remv node-acorn [8]\n' > "$STATE/rdeps"
run 'y\n' --yes
in_order "curl -fsSL https://nodejs.org/dist/v26.99.0/node-v26.99.0-linux-$NODE_ARCH.tar.xz"
if [[ "$rc" -eq 1 && -f "$STATE/nodejs" ]] && ! grep -q '^apt-get remove' "$CALLS" && node_kept \
  && grep -qF 'would also remove node-acorn' "$OUT" && grep -qF '(removes: nodejs node-acorn)' "$OUT"; then
  log "tarball in, removal takes another package -> refused, apt Node kept"
else fail "extra removal: rc $rc: $(cat "$OUT")"; fi
rm "$STATE/rdeps"
run 'y\n' --yes
leftover="$(find "$FIX/etc" "$FIX/usr" -name '*nodesource*' -o -name nodejs -o -name nsolid)"
if [[ "$rc" -eq 0 && -z "$leftover" && ! -f "$STATE/nodejs" ]] && node_kept; then
  log "nodesource --yes -> apt Node and NodeSource removed after the prompt"
else fail "nodesource --yes: rc $rc, left: $leftover: $(cat "$OUT")"; fi

# 13. A --yes without a terminal: no git identity or GitHub key from an empty pipe.
fresh_machine debian
SETUP_ASSUME_TTY=false run '' --yes
if [[ "$rc" -eq 1 ]] && ! grep -qE '^git config --global user\.(name|email) ' "$CALLS" && ! grep -q '^gh ssh-key add' "$CALLS" \
  && grep -qF 'git identity needs a terminal' "$OUT" && grep -qF 'GitHub keys need a terminal' "$OUT"; then
  log "piped --yes -> human steps skipped"
else fail "piped --yes: rc $rc: $(grep -E '^(git config --global user|gh ssh-key add)' "$CALLS")"; fi

finish
