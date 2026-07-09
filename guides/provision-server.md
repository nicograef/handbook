# Provision a New Debian / Ubuntu VPS

Automated setup using [`scripts/setup-server.sh`](../scripts/setup-server.sh).

## What it does

1. System update & base packages (curl, git, make, vim, …)
2. Create non-root user with sudo (passwordless)
3. SSH hardening – pubkey auth only, root login disabled
4. UFW firewall – deny all, allow & rate-limit SSH
5. fail2ban for SSH brute-force protection
6. Docker + Compose plugin

## Prerequisites

- A fresh VPS with root SSH access
- An SSH key pair on your local machine

```bash
# generate key if needed
ssh-keygen -t ed25519 -C "you@machine"
```

## Usage

Pass configuration inline to the remote shell — the vars are consumed on the
server, not your local machine:

```bash
# preview first (no changes made)
ssh root@<host> "SSH_PUBLIC_KEY='$(cat ~/.ssh/id_ed25519.pub)' bash -s -- --dry-run" \
  < scripts/setup-server.sh

# then run for real, optionally overriding USERNAME / EXTRA_UFW_PORTS
ssh root@<host> \
  "SSH_PUBLIC_KEY='$(cat ~/.ssh/id_ed25519.pub)' USERNAME=nico EXTRA_UFW_PORTS='80/tcp 443/tcp' bash -s" \
  < scripts/setup-server.sh
```

## Verify

```bash
# log in as the new user (root login is now disabled)
ssh nico@<host>

# firewall is active and rate-limiting SSH
sudo ufw status verbose

# fail2ban is running
sudo systemctl is-active fail2ban

# docker works without sudo
docker run --rm hello-world
```

Expected: SSH login succeeds as `nico` but fails as `root`; `ufw status`
shows `Status: active` with `22/tcp (LIMIT)`; `fail2ban` reports `active`;
`hello-world` prints the Docker confirmation message.

## Configuration

Edit the variables at the top of `setup-server.sh`:

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `USERNAME` | `nico` | Non-root user to create |
| `SSH_PUBLIC_KEY` | *(required)* | Your public SSH key |
| `EXTRA_UFW_PORTS` | `80/tcp 443/tcp` | Additional ports to open (space-separated) |

## Manual Reference

The script automates everything below. Use these commands when debugging or
tightening an existing server by hand.

### SSH hardening (sshd_config)

```diff
- #PubkeyAuthentication yes
+ PubkeyAuthentication yes

- PasswordAuthentication yes
+ PasswordAuthentication no

- PermitRootLogin yes
+ PermitRootLogin no
```

```bash
sudo systemctl restart sshd
```

### UFW firewall

See step 4 (`── 4. UFW firewall`) in
[`scripts/setup-server.sh`](../scripts/setup-server.sh) for the exact `ufw`
commands (default deny incoming, rate-limited SSH, extra ports from
`EXTRA_UFW_PORTS`).

### fail2ban

See step 5 (`── 5. fail2ban`) in
[`scripts/setup-server.sh`](../scripts/setup-server.sh) for the
`/etc/fail2ban/jail.local` contents and the enable/restart commands (uses the
`systemd` backend, which fixes fail2ban errors on systemd-based distros).

## After provisioning

- Open extra firewall ports as needed: `sudo ufw allow 443/tcp`
- Deploy apps via Docker Compose – see [docker-setup.md](docker-setup.md)

---

See also:
- [scripts/setup-server.sh](../scripts/setup-server.sh) — automated server provisioning script
- [guides/docker-setup.md](docker-setup.md) — Docker installation
- [guides/letsencrypt-docker.md](letsencrypt-docker.md) — TLS certificates
