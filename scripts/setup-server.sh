#!/usr/bin/env bash
# setup-server.sh – provision a fresh Debian / Ubuntu VPS
#
# Usage (run as root on the new server, passing config inline over SSH):
#   ssh root@host "SSH_PUBLIC_KEY='ssh-ed25519 AAAA...' USERNAME=nico bash -s" < setup-server.sh
#   ssh root@host "SSH_PUBLIC_KEY='ssh-ed25519 AAAA...' bash -s -- --dry-run" < setup-server.sh   # preview only
#   Hands-off alternative: templates/cloud-init.yml fetches and runs this script at first boot.
#
# What it does:
#   1. System update & base packages
#   1b. Swapfile (auto-sized from RAM, capped at 8G); appends it to /etc/fstab
#   2. Create non-root user with sudo
#   3. SSH hardening (pubkey only, no root login) via a drop-in
#   4. UFW firewall
#   5. fail2ban
#   6. Docker + Compose, container-log rotation (IPv6 networking auto-enabled on IPv6-only hosts)
#   7. Unattended security upgrades + daily health ping

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
USERNAME="${USERNAME:-nico}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"              # paste your pubkey here or export before running
EXTRA_UFW_PORTS="${EXTRA_UFW_PORTS:-80/tcp 443/tcp}"  # space-separated
PASSWORDLESS_SUDO="${PASSWORDLESS_SUDO:-false}"  # "true" grants NOPASSWD sudo (convenience over prompts)
USER_PASSWORD="${USER_PASSWORD:-}"               # required unless PASSWORDLESS_SUDO=true; enables sudo prompts
HEALTH_PING_URL="${HEALTH_PING_URL:-}"           # optional: daily dead-man health-ping URL (e.g. a Better Stack heartbeat)
SWAP_SIZE_GB="${SWAP_SIZE_GB:-auto}"             # swapfile size in GB; "auto" = RAM capped at 8; "0" skips swap
DRY_RUN="${DRY_RUN:-false}"                      # set to "true" or pass --dry-run
# ─────────────────────────────────────────────────────────────────────────────

log() { printf '\n\033[1;34m▸ %s\033[0m\n' "$1"; }

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '  \033[0;33m[DRY-RUN]\033[0m %s\n' "$*"
  else
    "$@"
  fi
}

# write_file <path> — write stdin to <path>, previewing (not writing) in dry-run.
write_file() {
  local path="$1"
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '  \033[0;33m[DRY-RUN]\033[0m write %s\n' "$path"
    cat >/dev/null
  else
    cat > "$path"
  fi
}

# ── Parse flags ──────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="true" ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

if [[ "$DRY_RUN" == "true" ]]; then
  printf '\n\033[1;33m⚠ DRY-RUN MODE — no changes will be made\033[0m\n'
fi

# ── Pre-flight checks ───────────────────────────────────────────────────────
# Root is required for real runs; a dry-run only previews, so allow it anywhere.
if [[ $EUID -ne 0 && "$DRY_RUN" != "true" ]]; then
  echo "ERROR: This script must be run as root." >&2
  exit 1
fi

if [[ -z "$SSH_PUBLIC_KEY" ]]; then
  echo "ERROR: SSH_PUBLIC_KEY is not set. Export it or edit the script." >&2
  exit 1
fi

# Password-prompted sudo needs an account password; abort now, before any writes,
# if the operator opted out of NOPASSWD but did not supply one.
if [[ "$PASSWORDLESS_SUDO" != "true" && -z "$USER_PASSWORD" ]]; then
  echo "ERROR: USER_PASSWORD is not set. Set it, or pass PASSWORDLESS_SUDO=true for NOPASSWD sudo." >&2
  exit 1
fi

# ── 1. System update & base packages ────────────────────────────────────────
log "Updating system"
run apt update -y
run apt upgrade -y
run apt dist-upgrade -y
run apt install -y \
  curl wget git make vim unzip \
  ca-certificates gnupg \
  jq lsof \
  ufw fail2ban

# ── 1b. Swap ────────────────────────────────────────────────────────────────
# A stock VPS image ships with no swap, which leaves the kernel no reclaim path:
# under memory pressure its only move is to kill the largest process. That is how
# a box loses every session at once rather than one — the OOM killer lands on the
# user manager's dbus, systemd stops user@.service, and every process in its slice
# (every tmux server included) goes with it.
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
  grep -q '^/swapfile ' /etc/fstab 2>/dev/null \
    || run bash -c "echo '/swapfile none swap sw 0 0' >> /etc/fstab"
fi

# A tmpfs /tmp is RAM, and systemd's tmp.mount sizes it at half of it. Everything
# written there — build caches, virtualenvs, git worktrees, downloads — is memory
# that cannot be evicted, which on a CI or agent box is gigabytes. Report it and
# leave it: moving /tmp to disk makes it survive a reboot, and that is a behaviour
# change the operator should choose.
if findmnt -no FSTYPE /tmp 2>/dev/null | grep -q tmpfs; then
  echo "  NOTE: /tmp is a tmpfs — everything written there is RAM."
  echo "        For build or agent workloads: systemctl mask tmp.mount && reboot"
fi

# ── 2. Create non-root user ─────────────────────────────────────────────────
log "Creating user '$USERNAME'"
if id "$USERNAME" &>/dev/null; then
  echo "User '$USERNAME' already exists – skipping."
else
  run adduser --disabled-password --gecos "" "$USERNAME"
fi
run usermod -aG sudo "$USERNAME"

if [[ "$PASSWORDLESS_SUDO" == "true" ]]; then
  # Convenience: sudo never prompts. The account stays passwordless.
  write_file "/etc/sudoers.d/$USERNAME" <<< "$USERNAME ALL=(ALL) NOPASSWD:ALL"
  run chmod 440 "/etc/sudoers.d/$USERNAME"
else
  # Default: password-prompted sudo. Set the account password so prompts work
  # (adduser --disabled-password leaves it unset, which locks sudo out).
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '  \033[0;33m[DRY-RUN]\033[0m set password for %s via chpasswd\n' "$USERNAME"
  else
    echo "$USERNAME:$USER_PASSWORD" | chpasswd
  fi
fi

# ── 3. SSH hardening ────────────────────────────────────────────────────────
log "Setting up SSH key for '$USERNAME'"
USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"
run mkdir -p "$SSH_DIR"
if [[ "$DRY_RUN" == "true" ]]; then
  printf '  \033[0;33m[DRY-RUN]\033[0m append SSH_PUBLIC_KEY to %s (deduplicated)\n' "$SSH_DIR/authorized_keys"
else
  echo "$SSH_PUBLIC_KEY" >> "$SSH_DIR/authorized_keys"
  sort -u "$SSH_DIR/authorized_keys" -o "$SSH_DIR/authorized_keys"
fi
run chmod 700 "$SSH_DIR"
run chmod 600 "$SSH_DIR/authorized_keys"
run chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

log "Hardening sshd via drop-in"
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_DROPIN="/etc/ssh/sshd_config.d/00-hardening.conf"

# sshd uses first-obtained-value semantics; cloud images ship 50-cloud-init.conf,
# so the 00- prefix guarantees our hardening wins. Ensure the main config actually
# includes the drop-in dir — some minimal images omit the Include directive.
INCLUDE_LINE="Include /etc/ssh/sshd_config.d/*.conf"
if [[ "$DRY_RUN" == "true" ]]; then
  printf '  \033[0;33m[DRY-RUN]\033[0m ensure %s contains "%s"\n' "$SSHD_CONFIG" "$INCLUDE_LINE"
elif ! grep -qxF "$INCLUDE_LINE" "$SSHD_CONFIG"; then
  printf '%s\n' "$INCLUDE_LINE" >> "$SSHD_CONFIG"
fi

run install -m 0755 -d /etc/ssh/sshd_config.d
write_file "$SSHD_DROPIN" <<'EOF'
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin no
KbdInteractiveAuthentication no
EOF
run chmod 644 "$SSHD_DROPIN"

# The canonical service unit is 'ssh' on Debian/Ubuntu; 'sshd' is only an alias.
run systemctl restart ssh

# ── 4. UFW firewall ─────────────────────────────────────────────────────────
log "Configuring UFW"
run ufw default deny incoming
run ufw default allow outgoing
run ufw allow ssh
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
backend  = systemd
enabled  = true
maxretry = 5
bantime  = 3600
EOF

run systemctl enable fail2ban
run systemctl restart fail2ban

# ── 6. Docker ───────────────────────────────────────────────────────────────
log "Installing Docker"

# determine distro base (works for Debian and Ubuntu) — needed for both the
# keyring URL and the apt source, so resolve it before either write.
# shellcheck source=/dev/null
. /etc/os-release
REPO_URL="https://download.docker.com/linux/${ID}"

run install -m 0755 -d /etc/apt/keyrings

if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '  \033[0;33m[DRY-RUN]\033[0m fetch %s/gpg and write /etc/apt/keyrings/docker.gpg\n' "$REPO_URL"
  else
    curl -fsSL "$REPO_URL/gpg" \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi
fi

DOCKER_LIST="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${REPO_URL} ${VERSION_CODENAME} stable"
write_file /etc/apt/sources.list.d/docker.list <<< "$DOCKER_LIST"

run apt update -y
run apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

run usermod -aG docker "$USERNAME"

# ── 6b. Docker daemon config ────────────────────────────────────────────────
# Every host gets container-log rotation (see guides/docker-setup.md — unbounded
# json-file logs fill the disk). IPv6-only hosts additionally need IPv6 container
# networking: without an IPv4 default route, the default bridge (IPv4 NAT only)
# leaves containers with no egress at all. New networks (Compose) become
# IPv6-only: keeping a dead IPv4 in the container makes RFC 6724 address
# selection prefer it over a ULA source for dual-stack targets, so IPv4 must go
# entirely. ULA subnets are NAT66-masqueraded by default. See guides/ipv6-only-vps.md.
if [[ -f /etc/docker/daemon.json ]]; then
  echo "  /etc/docker/daemon.json already exists — merge the log-rotation (and on IPv6-only hosts the IPv6) keys manually (see guides/docker-setup.md, guides/ipv6-only-vps.md)."
elif ! ip -4 route get 1.1.1.1 &>/dev/null; then
  log "No IPv4 route — enabling IPv6-only container networking + log rotation"
  write_file /etc/docker/daemon.json <<'EOF'
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:d0c:1::/64",
  "default-network-opts": {
    "bridge": {
      "com.docker.network.enable_ipv6": "true",
      "com.docker.network.enable_ipv4": "false"
    }
  },
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
  run systemctl restart docker
else
  log "Configuring Docker log rotation"
  write_file /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
  run systemctl restart docker
fi

# ── 7. Unattended upgrades & health ping ─────────────────────────────────────
log "Configuring unattended security upgrades"
run apt install -y unattended-upgrades

# Run apt's update + unattended-upgrade steps every day.
write_file /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Add the security origin for the detected distro. This extends (not replaces)
# the stock Origins-Pattern list — Debian's 50unattended-upgrades also enables
# stable point-release updates by default, so Debian boxes auto-apply those too.
# $ID is already resolved from /etc/os-release by the Docker step above. Debian
# and Ubuntu name their security suite differently, so branch on the distro.
# The ${distro_id}/${distro_codename} placeholders are apt-config variables, not
# shell ones — they must land in the file verbatim, hence single quotes.
# shellcheck disable=SC2016
case "$ID" in
  ubuntu)  SECURITY_ORIGIN='"${distro_id}:${distro_codename}-security";' ;;
  debian)  SECURITY_ORIGIN='"${distro_id}:${distro_codename}-security";
        "${distro_id}Security:${distro_codename}-security";' ;;
  *)       echo "ERROR: unsupported distro for unattended-upgrades: $ID" >&2; exit 1 ;;
esac

# No Automatic-Reboot — reboots stay manual; the health ping surfaces the pending one.
write_file /etc/apt/apt.conf.d/51unattended-upgrades-security <<EOF
Unattended-Upgrade::Allowed-Origins {
    $SECURITY_ORIGIN
};
EOF

log "Installing daily health ping"
if [[ "$DRY_RUN" == "true" ]]; then
  printf '  \033[0;33m[DRY-RUN]\033[0m fetch report-health.sh and write /usr/local/bin/report-health (executable)\n'
else
  curl -fsSL "https://raw.githubusercontent.com/nicograef/handbook/main/scripts/report-health.sh" \
    -o /usr/local/bin/report-health
  chmod +x /usr/local/bin/report-health
fi

# Persist HEALTH_PING_URL so the cron job finds it; the script+cron install either way.
if [[ -n "$HEALTH_PING_URL" ]]; then
  write_file /etc/default/report-health <<EOF
HEALTH_PING_URL="$HEALTH_PING_URL"
EOF
else
  echo "  HEALTH_PING_URL not set — installing script + cron, but no URL persisted; set /etc/default/report-health later to enable pings."
fi

write_file /etc/cron.d/report-health <<'EOF'
# Daily dead-man health ping (see /usr/local/bin/report-health).
0 8 * * * root /usr/local/bin/report-health
EOF
run chmod 644 /etc/cron.d/report-health

# ── Done ─────────────────────────────────────────────────────────────────────
log "Setup complete"
echo ""
echo "  User:     $USERNAME"
if [[ "$PASSWORDLESS_SUDO" == "true" ]]; then
  echo "  Sudo:     passwordless (NOPASSWD)"
else
  echo "  Sudo:     password-prompted"
fi
echo "  SSH:      key-only, root login disabled"
if [[ "$(awk 'NR > 1' /proc/swaps | wc -l)" -gt 0 ]]; then
  echo "  Swap:     $(awk 'NR > 1 { printf "%s (%d MB)", $1, $3 / 1024 }' /proc/swaps)"
else
  echo "  Swap:     none — the kernel has no reclaim path under memory pressure"
fi
echo "  Firewall: UFW active (ssh + ${EXTRA_UFW_PORTS:-no extra ports})"
echo "  fail2ban: active"
echo "  Docker:   $(docker --version 2>/dev/null || echo 'not installed (dry-run)')"
echo "  Upgrades: unattended (security origin + distro stock defaults, no auto-reboot)"
if [[ -n "$HEALTH_PING_URL" ]]; then
  echo "  Health:   daily ping to $HEALTH_PING_URL"
else
  echo "  Health:   daily check installed (no ping URL — set /etc/default/report-health to enable)"
fi
echo ""
# Route-based lookup returns the source address of real outbound traffic, so
# virtual bridges (e.g. docker0's 172.17.0.1) can never win; IPv6-only hosts
# have no IPv4 route, so fall back to the IPv6 source address.
SERVER_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || true)"
[[ -n "$SERVER_IP" ]] || SERVER_IP="$(ip -6 route get 2606:4700:4700::1111 2>/dev/null | grep -oP 'src \K\S+' || true)"
echo "  → Log in:  ssh $USERNAME@${SERVER_IP:-<server-ip>}"
echo "  → Reboot recommended."
