#!/usr/bin/env bash
# setup-server.sh – provision a fresh Debian / Ubuntu VPS
#
# Usage (run as root on the new server):
#   ssh root@host 'bash -s' < setup-server.sh
#
# What it does:
#   1. System update & base packages
#   2. Create non-root user with sudo
#   3. SSH hardening (pubkey only, no root login)
#   4. UFW firewall
#   5. fail2ban
#   6. Docker + Compose
#
# Before running:
#   - Generate an SSH key pair locally:   ssh-keygen -t ed25519
#   - Set SSH_PUBLIC_KEY below (or pass it as env var)

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
USERNAME="${USERNAME:-nico}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"              # paste your pubkey here or export before running
EXTRA_UFW_PORTS="${EXTRA_UFW_PORTS:-80/tcp 443/tcp}"  # space-separated
# ─────────────────────────────────────────────────────────────────────────────

log() { printf '\n\033[1;34m▸ %s\033[0m\n' "$1"; }

# ── Pre-flight checks ───────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root." >&2
  exit 1
fi

if [[ -z "$SSH_PUBLIC_KEY" ]]; then
  echo "ERROR: SSH_PUBLIC_KEY is not set. Export it or edit the script." >&2
  exit 1
fi

# ── 1. System update & base packages ────────────────────────────────────────
log "Updating system"
apt update -y
apt upgrade -y
apt dist-upgrade -y
apt install -y \
  curl wget git make vim unzip \
  ca-certificates gnupg \
  ufw fail2ban

# ── 2. Create non-root user ─────────────────────────────────────────────────
log "Creating user '$USERNAME'"
if id "$USERNAME" &>/dev/null; then
  echo "User '$USERNAME' already exists – skipping."
else
  adduser --disabled-password --gecos "" "$USERNAME"
fi
usermod -aG sudo "$USERNAME"

# allow sudo without password (optional – remove if you prefer password prompt)
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME"
chmod 440 "/etc/sudoers.d/$USERNAME"

# ── 3. SSH hardening ────────────────────────────────────────────────────────
log "Setting up SSH key for '$USERNAME'"
USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"
mkdir -p "$SSH_DIR"
echo "$SSH_PUBLIC_KEY" >> "$SSH_DIR/authorized_keys"
sort -u "$SSH_DIR/authorized_keys" -o "$SSH_DIR/authorized_keys"
chmod 700 "$SSH_DIR"
chmod 600 "$SSH_DIR/authorized_keys"
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

log "Hardening sshd_config"
SSHD_CONFIG="/etc/ssh/sshd_config"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

# apply settings idempotently
set_sshd() {
  local key="$1" value="$2"
  if grep -qE "^#?${key}\b" "$SSHD_CONFIG"; then
    sed -i "s|^#*${key}.*|${key} ${value}|" "$SSHD_CONFIG"
  else
    echo "${key} ${value}" >> "$SSHD_CONFIG"
  fi
}

set_sshd "PubkeyAuthentication"  "yes"
set_sshd "PasswordAuthentication" "no"
set_sshd "PermitRootLogin"       "no"

systemctl restart sshd

# ── 4. UFW firewall ─────────────────────────────────────────────────────────
log "Configuring UFW"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw limit ssh

for port in $EXTRA_UFW_PORTS; do
  ufw allow "$port"
done

ufw --force enable
systemctl enable ufw

# ── 5. fail2ban ─────────────────────────────────────────────────────────────
log "Configuring fail2ban"
cat > /etc/fail2ban/jail.local <<EOF
[sshd]
backend  = systemd
enabled  = true
maxretry = 5
bantime  = 3600
EOF

systemctl enable fail2ban
systemctl restart fail2ban

# ── 6. Docker ───────────────────────────────────────────────────────────────
log "Installing Docker"
install -m 0755 -d /etc/apt/keyrings

if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

# determine distro base (works for Debian and Ubuntu)
. /etc/os-release
REPO_URL="https://download.docker.com/linux/${ID}"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${REPO_URL} ${VERSION_CODENAME} stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update -y
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

usermod -aG docker "$USERNAME"

# ── Done ─────────────────────────────────────────────────────────────────────
log "Setup complete"
echo ""
echo "  User:     $USERNAME"
echo "  SSH:      key-only, root login disabled"
echo "  Firewall: UFW active (ssh + ${EXTRA_UFW_PORTS:-no extra ports})"
echo "  fail2ban: active"
echo "  Docker:   $(docker --version)"
echo ""
echo "  → Log in:  ssh $USERNAME@$(hostname -I | awk '{print $1}')"
echo "  → Reboot recommended."
