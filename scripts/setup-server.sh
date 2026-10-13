#!/usr/bin/env bash
# setup-server.sh – provision a fresh Debian / Ubuntu VPS
#
# Usage (run as root on the new server, passing config inline over SSH, from a handbook clone):
#   git pull --ff-only && REF="$(git rev-parse HEAD)"   # a pushed commit; report-health.sh comes from it
#   HASH="$(mkpasswd -m yescrypt)"   # prompts for the password; mkpasswd ships in the whois package
#   ssh root@host "HANDBOOK_REF=$REF SSH_PUBLIC_KEY='ssh-ed25519 AAAA...' USERNAME=nico USER_PASSWORD_HASH='$HASH' bash -s" < scripts/setup-server.sh
#   ssh root@host "HANDBOOK_REF=$REF SSH_PUBLIC_KEY='ssh-ed25519 AAAA...' bash -s -- --dry-run" < scripts/setup-server.sh   # preview only
#
# Rerun on a set-up host, as USERNAME in its handbook clone; root has no login by then.
# The keys in authorized_keys and the user's password stay, so neither value is needed.
# Repeat every other Configuration value the first run set, such as EXTRA_UFW_PORTS= or HOST_ROLE=dev.
# Every run writes HOST_ROLE to /etc/handbook-role; a dev or agent server declares itself with HOST_ROLE=dev.
# The rerun upgrades every package and restarts ssh, fail2ban and an upgraded Docker: run it in a maintenance window.
#   git -C ~/r/handbook pull --ff-only && cd ~/r/handbook
#   sudo scripts/setup-server.sh
#
# What it does:
#   0. Write HOST_ROLE to /etc/handbook-role, which setup-dev-machine.sh refuses unless it says dev
#   1. System update & base packages
#   1b. Swapfile (auto-sized from RAM, capped at 8G); appends it to /etc/fstab
#   1c. Locales: the system's LANG and those the operator's SSH client forwards
#   1d. Take report-health.sh from the clone, or fetch it at HANDBOOK_REF when piped; abort unless its sha256 matches
#   2. Create non-root user with sudo and lingering
#   3. SSH hardening (pubkey only, no root login) via a drop-in
#   4. UFW firewall
#   5. fail2ban
#   6. Docker + Compose, container-log rotation (IPv6 networking auto-enabled on IPv6-only hosts)
#   7. Unattended upgrades (stock distro origins) + hourly health ping

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
USERNAME="${USERNAME:-nico}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"              # paste your pubkey here or export before running; a rerun may omit it
EXTRA_UFW_PORTS="${EXTRA_UFW_PORTS-80/tcp 443/tcp}"   # space-separated; empty opens only SSH
PASSWORDLESS_SUDO="${PASSWORDLESS_SUDO:-false}"  # "true" grants NOPASSWD sudo (convenience over prompts)
USER_PASSWORD_HASH="${USER_PASSWORD_HASH:-}"     # `mkpasswd -m yescrypt` output; required unless PASSWORDLESS_SUDO=true or the user has a password
HEALTH_PING_URL="${HEALTH_PING_URL:-}"           # optional: hourly dead-man health-ping URL (e.g. a Better Stack heartbeat)
SWAP_SIZE_GB="${SWAP_SIZE_GB:-auto}"             # swapfile size in GB; "auto" = RAM capped at 8; "0" skips swap
SYSTEM_LOCALE="${SYSTEM_LOCALE:-en_US.UTF-8}"     # the system's LANG, for cron, services and sessions that send none
EXTRA_LOCALES="${EXTRA_LOCALES:-en_GB.UTF-8}"     # space-separated; the other LANG/LC_* your SSH client sends
HANDBOOK_REF="${HANDBOOK_REF:-}"                 # piped runs only: the 40-hex handbook commit this script came from
HOST_ROLE="${HOST_ROLE:-prod}"                   # "prod" or "dev"; only a dev server takes setup-dev-machine.sh
DRY_RUN="${DRY_RUN:-false}"                      # set to "true" or pass --dry-run
# ─────────────────────────────────────────────────────────────────────────────

# sha256 of scripts/report-health.sh in the same commit; check-repo's contracts stage keeps it in sync.
REPORT_HEALTH_SHA256="c30cabb5055830d10cf87d08a50655778c9ad28d12da7ce58e341a51f843b51d"
# Run from a clone, the sibling report-health.sh is installed; a piped run (bash -s) has no file beside it.
LOCAL_REPORT_HEALTH=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "$(dirname "${BASH_SOURCE[0]}")/report-health.sh" ]]; then
  LOCAL_REPORT_HEALTH="$(dirname "${BASH_SOURCE[0]}")/report-health.sh"
fi

usage() {
  printf 'usage: [HOST_ROLE=prod|dev] %s [--dry-run]; the header lists every Configuration value\n' "$0" >&2
}

log() { printf '\n\033[1;34m▸ %s\033[0m\n' "$1"; }
die() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }
dry() { printf '  \033[0;33m[DRY-RUN]\033[0m %s\n' "$*"; }

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    dry "$*"
  else
    "$@"
  fi
}

# write_file <path> — write stdin to <path>, previewing (not writing) in dry-run.
write_file() {
  local path="$1"
  if [[ "$DRY_RUN" == "true" ]]; then
    dry "write $path"
    cat >/dev/null
  else
    cat > "$path"
  fi
}

# append_line <path> <line> — append <line> unless <path> holds it, previewing (not writing) in dry-run.
append_line() {
  if grep -qxF -- "$2" "$1" 2>/dev/null; then return 0; fi
  if [[ "$DRY_RUN" == "true" ]]; then
    dry "append '$2' to $1"
  else
    printf '%s\n' "$2" >> "$1"
  fi
}

# ── Parse flags ──────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="true" ;;
    *) echo "Unknown flag: $arg" >&2; usage; exit 2 ;;
  esac
done

case "$HOST_ROLE" in
  prod|dev) ;;
  *) printf 'ERROR: HOST_ROLE is %s, not prod or dev\n' "${HOST_ROLE:-empty}" >&2; usage; exit 2 ;;
esac

if [[ "$DRY_RUN" == "true" ]]; then
  printf '\n\033[1;33m⚠ DRY-RUN MODE — no changes will be made\033[0m\n'
fi

# ── Pre-flight checks ───────────────────────────────────────────────────────
# Root is required for real runs; a dry-run only previews, so allow it anywhere.
if [[ $EUID -ne 0 && "$DRY_RUN" != "true" ]]; then
  die "This script must be run as root."
fi

USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"
# Password login ends below, so a key must parse: blank or comment lines would lock the user out.
if [[ -n "$SSH_PUBLIC_KEY" ]]; then
  if ! ssh-keygen -lf - <<<"$SSH_PUBLIC_KEY" >/dev/null 2>&1; then
    die "SSH_PUBLIC_KEY is not a public key."
  fi
elif ! ssh-keygen -lf "$SSH_DIR/authorized_keys" >/dev/null 2>&1; then
  die "SSH_PUBLIC_KEY is not set and $SSH_DIR/authorized_keys holds no valid key. Export it or edit the script."
fi

SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
SUDOERS_LINE="$USERNAME ALL=(ALL) NOPASSWD:ALL"

# passwd -S prints P for a usable password; a missing user or a non-root dry-run reads as none.
HAS_PASSWORD=false
if [[ "$(passwd -S "$USERNAME" 2>/dev/null | awk '{print $2}' || true)" == P ]]; then HAS_PASSWORD=true; fi

# A commit URL never changes, so the fetched file is the one this script's digest names.
if [[ -z "$LOCAL_REPORT_HEALTH" && ! "$HANDBOOK_REF" =~ ^[0-9a-f]{40}$ ]]; then
  die "a piped run needs HANDBOOK_REF, a full commit sha: git rev-parse HEAD in a pushed handbook clone"
fi

if [[ "$PASSWORDLESS_SUDO" != "true" ]]; then
  if [[ -z "$USER_PASSWORD_HASH" && "$HAS_PASSWORD" != true ]]; then
    die "USER_PASSWORD_HASH is not set and '$USERNAME' has no password. Set it, or pass PASSWORDLESS_SUDO=true for NOPASSWD sudo."
  fi
  # chpasswd -e stores the value verbatim, so plaintext would leave an unusable password.
  if [[ -n "$USER_PASSWORD_HASH" && "$USER_PASSWORD_HASH" != \$* ]]; then
    die "USER_PASSWORD_HASH is not a crypt hash. Generate it with: mkpasswd -m yescrypt"
  fi
  # Only a non-root dry-run cannot read the 440 root file, so it skips the check instead of failing it.
  if [[ -f "$SUDOERS_FILE" && ! -r "$SUDOERS_FILE" ]]; then
    dry "cannot read $SUDOERS_FILE without root; a real run checks it holds only '$SUDOERS_LINE'"
  elif [[ -f "$SUDOERS_FILE" && "$(cat "$SUDOERS_FILE")" != "$SUDOERS_LINE" ]]; then
    die "$SUDOERS_FILE holds rules this script did not write. Review it, then rerun."
  fi
fi

# ── 0. Host role ────────────────────────────────────────────────────────────
# Written first, so an interrupted first run never leaves the sshd drop-in without it.
log "Recording host role '$HOST_ROLE'"
write_file /etc/handbook-role <<< "$HOST_ROLE"
run chmod 644 /etc/handbook-role

# ── 1. System update & base packages ────────────────────────────────────────
log "Updating system"
run apt update -y
run apt full-upgrade -y
run apt install -y \
  curl wget git make vim unzip \
  ca-certificates \
  jq lsof cron locales \
  ufw fail2ban

# ── 1b. Swap ────────────────────────────────────────────────────────────────
# A stock VPS image ships with no swap, so under memory pressure the kernel's only move is to kill.
# Why one kill can take every tmux session: guides/maintenance.md#after-an-oom-kill.
log "Configuring swap"
if [[ "$SWAP_SIZE_GB" == "0" ]]; then
  echo "  SWAP_SIZE_GB=0 — skipping swap by request."
elif [[ "$(awk 'NR > 1' /proc/swaps | wc -l)" -gt 0 ]]; then
  echo "  Swap is already active — leaving it alone."
elif [[ -e /swapfile ]]; then
  echo "  /swapfile exists but is not active — leaving it alone."
else
  if [[ "$SWAP_SIZE_GB" == "auto" ]]; then
    # Match RAM, capped at 8 GB: enough to absorb a spike, never so much that a
    # runaway thrashes the disk for an hour before the OOM killer settles it.
    ram_gb="$(awk '/^MemTotal:/ { printf "%d", ($2 + 1048575) / 1048576 }' /proc/meminfo)"
    SWAP_SIZE_GB=$(( ram_gb < 8 ? ram_gb : 8 ))
    (( SWAP_SIZE_GB >= 1 )) || SWAP_SIZE_GB=1
  fi
  log "Creating a ${SWAP_SIZE_GB}G swapfile"
  # fallocate can leave an extent layout swapon refuses on some filesystems; dd is
  # slower and always produces a file swapon accepts.
  run bash -c "fallocate -l ${SWAP_SIZE_GB}G /swapfile \
    || dd if=/dev/zero of=/swapfile bs=1M count=$(( SWAP_SIZE_GB * 1024 )) status=none"
  run chmod 600 /swapfile
  run mkswap /swapfile
  run swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab 2>/dev/null || append_line /etc/fstab '/swapfile none swap sw 0 0'
fi

# A tmpfs /tmp is RAM- and swap-backed; it cannot be dropped like page cache.
# Report it and leave it: a disk /tmp survives a reboot, a change the operator should choose.
if findmnt -no FSTYPE /tmp 2>/dev/null | grep -q tmpfs; then
  echo "  NOTE: /tmp is a tmpfs — everything written there is RAM."
  echo "        For build or agent workloads: systemctl mask tmp.mount && reboot"
fi

# ── 1c. Locales ─────────────────────────────────────────────────────────────
# sshd's stock AcceptEnv takes the client's LANG and LC_*. A forwarded locale the
# image lacks makes perl, and every tool built on it, warn on each call.
log "Generating locales"
for loc in $SYSTEM_LOCALE $EXTRA_LOCALES; do
  append_line /etc/locale.gen "$loc ${loc#*.}"
done
run locale-gen
# A stock image sets LANG=C.UTF-8 in /etc/default/locale.
run update-locale "LANG=$SYSTEM_LOCALE"

# ── 1d. Fetch report-health ─────────────────────────────────────────────────
# Fetched and verified before any account, SSH or firewall change, so a bad ref aborts a clean host.
if [[ -n "$LOCAL_REPORT_HEALTH" ]]; then
  log "Verifying $LOCAL_REPORT_HEALTH"
  REPORT_HEALTH_SOURCE="$LOCAL_REPORT_HEALTH"
else
  log "Fetching report-health.sh at $HANDBOOK_REF"
  REPORT_HEALTH_SOURCE="https://raw.githubusercontent.com/nicograef/handbook/${HANDBOOK_REF}/scripts/report-health.sh"
fi
if [[ "$DRY_RUN" == "true" ]]; then
  dry "copy $REPORT_HEALTH_SOURCE and verify sha256 $REPORT_HEALTH_SHA256"
else
  REPORT_HEALTH_TMP="$(mktemp)"
  trap 'rm -f "$REPORT_HEALTH_TMP"' EXIT
  if [[ -n "$LOCAL_REPORT_HEALTH" ]]; then
    cp "$LOCAL_REPORT_HEALTH" "$REPORT_HEALTH_TMP"
  elif ! curl -fsSL "$REPORT_HEALTH_SOURCE" -o "$REPORT_HEALTH_TMP"; then
    die "cannot fetch $REPORT_HEALTH_SOURCE. Is HANDBOOK_REF pushed?"
  fi
  if ! sha256sum --quiet -c <<< "$REPORT_HEALTH_SHA256  $REPORT_HEALTH_TMP"; then
    die "$REPORT_HEALTH_SOURCE does not match this script's REPORT_HEALTH_SHA256. Use the setup-server.sh of the same commit."
  fi
fi

# ── 2. Create non-root user ─────────────────────────────────────────────────
log "Creating user '$USERNAME'"
if id "$USERNAME" &>/dev/null; then
  echo "User '$USERNAME' already exists – skipping."
else
  run adduser --disabled-password --gecos "" "$USERNAME"
fi
run usermod -aG sudo "$USERNAME"
# The provider's image ships a root password; locked, root has no login of any kind.
run passwd -l root
# Lingering keeps the user manager, and every tmux session under it, alive past the last logout.
# Why that matters: guides/maintenance.md#after-an-oom-kill.
run loginctl enable-linger "$USERNAME"

if [[ "$PASSWORDLESS_SUDO" == "true" ]]; then
  write_file "$SUDOERS_FILE" <<< "$SUDOERS_LINE"
  run chmod 440 "$SUDOERS_FILE"
else
  if [[ -z "$USER_PASSWORD_HASH" ]]; then
    echo "  No USER_PASSWORD_HASH — keeping the password of '$USERNAME'."
  else
    # adduser --disabled-password leaves the password unset, which locks prompted sudo out.
    run chpasswd -e <<<"$USERNAME:$USER_PASSWORD_HASH"
  fi
  # A run with PASSWORDLESS_SUDO=true left this file; the pre-flight checked it holds only that line.
  if [[ -f "$SUDOERS_FILE" ]]; then run rm -f "$SUDOERS_FILE"; fi
fi

# ── 3. SSH hardening ────────────────────────────────────────────────────────
log "Setting up SSH key for '$USERNAME'"
run mkdir -p "$SSH_DIR"
if [[ -z "$SSH_PUBLIC_KEY" ]]; then
  echo "  No SSH_PUBLIC_KEY — keeping the keys in $SSH_DIR/authorized_keys."
else
  # Appending only absent lines keeps the file's order and each comment above its key.
  while IFS= read -r key; do
    if [[ -n "$key" ]]; then append_line "$SSH_DIR/authorized_keys" "$key"; fi
  done <<<"$SSH_PUBLIC_KEY"
fi
run chmod 700 "$SSH_DIR"
run chmod 600 "$SSH_DIR/authorized_keys"
run chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

log "Hardening sshd via drop-in"
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_DROPIN="/etc/ssh/sshd_config.d/00-hardening.conf"

# sshd keeps the first value it reads and cloud images ship 50-cloud-init.conf, so the 00- drop-in wins.
# Some minimal images omit the Include; line 1 puts the drop-ins ahead of every main-config directive.
INCLUDE_LINE="Include /etc/ssh/sshd_config.d/*.conf"
grep -qsxF "$INCLUDE_LINE" "$SSHD_CONFIG" || run sed -i "1i $INCLUDE_LINE" "$SSHD_CONFIG"

run install -m 0755 -d /etc/ssh/sshd_config.d
write_file "$SSHD_DROPIN" <<'EOF'
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin no
KbdInteractiveAuthentication no
EOF
run chmod 644 "$SSHD_DROPIN"

# Validate first: a broken config would lock SSH out on restart.
# The canonical service unit is 'ssh' on Debian/Ubuntu; 'sshd' is only an alias.
# Socket-activated ssh (Ubuntu 24.04+) creates /run/sshd only on start; sshd -t needs it.
run install -d -m 0755 /run/sshd
run sshd -t
run systemctl restart ssh

# ── 4. UFW firewall ─────────────────────────────────────────────────────────
# Docker-published ports bypass UFW, so only the reverse proxy may publish ports.
log "Configuring UFW"
run ufw default deny incoming
run ufw default allow outgoing
run ufw limit ssh

for port in $EXTRA_UFW_PORTS; do
  run ufw allow "$port"
done

run ufw --force enable
run systemctl enable ufw

# ── 5. fail2ban ─────────────────────────────────────────────────────────────
log "Configuring fail2ban"
write_file /etc/fail2ban/jail.local <<'EOF'
[sshd]
backend      = systemd
journalmatch = _SYSTEMD_UNIT=ssh.service + _COMM=sshd + _COMM=sshd-session
enabled      = true
maxretry     = 5
bantime      = 3600
EOF

run systemctl enable fail2ban
run systemctl restart fail2ban

# ── 6. Docker ───────────────────────────────────────────────────────────────
log "Installing Docker"

# shellcheck source=/dev/null
. /etc/os-release
REPO_URL="https://download.docker.com/linux/${ID}"

# Drop the one-line list and dearmored key a legacy setup may have left behind.
run rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg
run install -m 0755 -d /etc/apt/keyrings

if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
  run curl -fsSL "$REPO_URL/gpg" -o /etc/apt/keyrings/docker.asc
  run chmod a+r /etc/apt/keyrings/docker.asc
fi

write_file /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: ${REPO_URL}
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

run apt update -y
run apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

run usermod -aG docker "$USERNAME"

# ── 6b. Docker daemon config ────────────────────────────────────────────────
# Unbounded json-file logs fill the disk, so every host gets log rotation. Without an IPv4 default
# route the default bridge leaves containers no egress, so IPv6-only hosts get IPv6 networking.
# New (Compose) networks drop IPv4 entirely: RFC 6724 selection would prefer a dead IPv4 over a ULA
# source for dual-stack targets. See guides/ipv6-only-vps.md.
# host-audit.sh expects exactly these rotation values.
LOG_KEYS='"log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }'
if [[ -f /etc/docker/daemon.json ]]; then
  echo "  /etc/docker/daemon.json already exists — merge these log-rotation keys manually:"
  echo "  $LOG_KEYS"
  echo "  On an IPv6-only host, also merge the IPv6 keys of step 6b in setup-server.sh."
elif ! ip -4 route get 1.1.1.1 &>/dev/null; then
  log "No IPv4 route — enabling IPv6-only container networking + log rotation"
  write_file /etc/docker/daemon.json <<EOF
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:d0c:1::/64",
  "default-network-opts": {
    "bridge": {
      "com.docker.network.enable_ipv6": "true",
      "com.docker.network.enable_ipv4": "false"
    }
  },
  $LOG_KEYS
}
EOF
  run systemctl restart docker
else
  log "Configuring Docker log rotation"
  write_file /etc/docker/daemon.json <<EOF
{
  $LOG_KEYS
}
EOF
  run systemctl restart docker
fi

# ── 7. Unattended upgrades & health ping ─────────────────────────────────────
log "Configuring unattended upgrades"
run apt install -y unattended-upgrades

# The stock 50unattended-upgrades origins apply. No Automatic-Reboot: reboots stay manual and the
# health ping surfaces a pending one.
write_file /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

log "Installing hourly health ping"
if [[ "$DRY_RUN" == "true" ]]; then
  dry "install the verified report-health.sh as /usr/local/bin/report-health (executable)"
else
  install -m 0755 "$REPORT_HEALTH_TMP" /usr/local/bin/report-health
fi

# The URL is a secret: anyone holding it can fake a healthy ping.
if [[ -n "$HEALTH_PING_URL" ]]; then
  write_file /etc/default/report-health <<EOF
HEALTH_PING_URL="$HEALTH_PING_URL"
EOF
  run chmod 600 /etc/default/report-health
elif [[ -f /etc/default/report-health ]]; then
  echo "  HEALTH_PING_URL not set — keeping the URL in /etc/default/report-health."
else
  echo "  HEALTH_PING_URL not set — installing script + cron, but no URL persisted; set /etc/default/report-health later to enable pings."
fi

write_file /etc/cron.d/report-health <<'EOF'
# Hourly dead-man health ping (see /usr/local/bin/report-health).
0 * * * * root /usr/local/bin/report-health
EOF
run chmod 644 /etc/cron.d/report-health

# ── Done ─────────────────────────────────────────────────────────────────────
log "Setup complete"
echo ""
echo "  Role:     $HOST_ROLE (in /etc/handbook-role)"
echo "  User:     $USERNAME"
if [[ "$PASSWORDLESS_SUDO" == "true" ]]; then
  echo "  Sudo:     passwordless (NOPASSWD)"
else
  echo "  Sudo:     password-prompted"
fi
echo "  SSH:      key-only, root login disabled"
echo "  Locales:  ${EXTRA_LOCALES:-stock}"
if [[ "$(awk 'NR > 1' /proc/swaps | wc -l)" -gt 0 ]]; then
  echo "  Swap:     $(awk 'NR > 1 { printf "%s (%d MB)", $1, $3 / 1024 }' /proc/swaps)"
else
  echo "  Swap:     none — the kernel has no reclaim path under memory pressure"
fi
echo "  Firewall: UFW active (ssh + ${EXTRA_UFW_PORTS:-no extra ports})"
echo "  fail2ban: active"
echo "  Docker:   $(docker --version 2>/dev/null || echo 'not installed (dry-run)')"
echo "  Upgrades: unattended (distro stock origins, no auto-reboot)"
if [[ -n "$HEALTH_PING_URL" || -f /etc/default/report-health ]]; then
  echo "  Health:   hourly ping (URL in /etc/default/report-health)"
else
  echo "  Health:   hourly check installed (no ping URL — set /etc/default/report-health to enable)"
fi
echo ""
# The route lookup returns the source of real outbound traffic, so docker0's 172.17.0.1 never wins.
# IPv6-only hosts have no IPv4 route and fall back to the IPv6 source.
SERVER_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || true)"
[[ -n "$SERVER_IP" ]] || SERVER_IP="$(ip -6 route get 2606:4700:4700::1111 2>/dev/null | grep -oP 'src \K\S+' || true)"
echo "  → Log in:  ssh $USERNAME@${SERVER_IP:-<server-ip>}"
echo "  → Reboot recommended."
