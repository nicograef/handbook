# Provision a New Debian / Ubuntu VPS

Automated setup using [`scripts/setup-server.sh`](../scripts/setup-server.sh).

## What it does

1. System update & base packages (curl, git, make, vim, …)
2. Create non-root user with sudo (password-prompted by default; NOPASSWD opt-in)
3. SSH hardening via `/etc/ssh/sshd_config.d/00-hardening.conf` – pubkey auth only, root login disabled
4. UFW firewall – deny all, allow & rate-limit SSH
5. fail2ban for SSH brute-force protection
6. Docker + Compose plugin
7. Unattended security upgrades (security origin only, **no** auto-reboot) + a daily
   dead-man health ping via [`scripts/report-health.sh`](../scripts/report-health.sh)

## Prerequisites

- A fresh VPS with root SSH access
- An SSH key pair on your local machine

```bash
# generate key if needed
ssh-keygen -t ed25519 -C "you@machine"
```

## Usage

Two paths. Prefer **cloud-init** (the server provisions itself on first boot);
fall back to the **manual SSH pipe** when the provider has no user-data field.

> **Security:** user-data — including `USER_PASSWORD` — stays readable from the
> instance metadata endpoint. Rotate the password at first login (`passwd`) or
> use `PASSWORDLESS_SUDO=true` and omit `USER_PASSWORD` entirely.

### Primary: cloud-init (Hetzner)

Reference provider: Hetzner Cloud, which exposes a user-data field (verified
2026-07-09).

1. Copy [`templates/cloud-init.yml`](../templates/cloud-init.yml) and fill the
   `<angle-bracket>` placeholders (`<ssh-public-key>`, `<username>`,
   `<user-password>`, `<health-ping-url>`; adjust `EXTRA_UFW_PORTS`). To skip
   `USER_PASSWORD`, switch to the commented passwordless-sudo block.
2. Create the server with it — via the console **Cloud config** field, or the CLI:

   ```bash
   hcloud server create \
     --name <name> --type <type> --image debian-12 \
     --ssh-key <key-name> \
     --user-data-from-file cloud-init.yml
   ```

3. Wait for cloud-init to finish, then verify it ran cleanly:

   ```bash
   ssh <username>@<host> "sudo cloud-init status --wait"   # → status: done
   ssh <username>@<host> "sudo tail -n 40 /var/log/cloud-init-output.log"
   ```

   Then run the [Verify](#verify) block below.

### Fallback: manual SSH pipe (netcup)

Use this when the provider has no user-data field. netcup officially supports
only SSH-key injection at image install — no user-data field (verified
2026-07-09) — so netcup servers take this path.

Pass configuration inline to the remote shell — the vars are consumed on the
server, not your local machine:

```bash
# preview first (no changes made)
ssh root@<host> "SSH_PUBLIC_KEY='$(cat ~/.ssh/id_ed25519.pub)' bash -s -- --dry-run" \
  < scripts/setup-server.sh

# then run for real — USER_PASSWORD is required unless you opt into passwordless sudo
ssh root@<host> \
  "SSH_PUBLIC_KEY='$(cat ~/.ssh/id_ed25519.pub)' USERNAME=nico USER_PASSWORD='<pw>' EXTRA_UFW_PORTS='80/tcp 443/tcp' bash -s" \
  < scripts/setup-server.sh

# or opt into passwordless (NOPASSWD) sudo instead of setting a password
ssh root@<host> \
  "SSH_PUBLIC_KEY='$(cat ~/.ssh/id_ed25519.pub)' PASSWORDLESS_SUDO=true bash -s" \
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

# unattended-upgrades is configured (dry run applies no changes)
sudo unattended-upgrade --dry-run --debug 2>&1 | grep -i 'allowed origins'

# apt's periodic update/upgrade timers are active
systemctl list-timers 'apt-daily*' --no-pager

# the daily health-ping cron entry is installed
cat /etc/cron.d/report-health
```

Expected: SSH login succeeds as `nico` but fails as `root`; `ufw status`
shows `Status: active` with `22/tcp (LIMIT)`; `fail2ban` reports `active`;
`hello-world` prints the Docker confirmation message; the `unattended-upgrade`
dry run lists an `Allowed origins` line containing `-security`;
`apt-daily.timer` and `apt-daily-upgrade.timer` appear in the timer list; and
`/etc/cron.d/report-health` prints the `0 8 * * * root /usr/local/bin/report-health`
line.

## Configuration

Edit the variables at the top of `setup-server.sh`:

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `USERNAME` | `nico` | Non-root user to create |
| `SSH_PUBLIC_KEY` | *(required)* | Your public SSH key |
| `PASSWORDLESS_SUDO` | `false` | `true` grants NOPASSWD sudo; otherwise sudo prompts for a password |
| `USER_PASSWORD` | *(required unless `PASSWORDLESS_SUDO=true`)* | Account password so sudo prompts work |
| `EXTRA_UFW_PORTS` | `80/tcp 443/tcp` | Additional ports to open (space-separated) |
| `HEALTH_PING_URL` | *(optional)* | Daily dead-man health-ping URL (e.g. a Better Stack heartbeat, see [monitoring guide](monitoring.md)). Persisted to `/etc/default/report-health`; the script + cron install even when unset |

> **Sudo trade-off:** `PASSWORDLESS_SUDO=true` is convenient (sudo never prompts)
> but any process running as the user can escalate to root without a secret. The
> default prompts for a password, so the account **must** have one — `adduser
> --disabled-password` leaves it unset, which would lock the user out of sudo.
> The script sets `USER_PASSWORD` via `chpasswd` for exactly this reason.

## Manual Reference

The script automates everything below. Use these commands when debugging or
tightening an existing server by hand.

### SSH hardening (drop-in)

Write a drop-in instead of editing `/etc/ssh/sshd_config`. sshd uses
first-obtained-value semantics and cloud images ship `50-cloud-init.conf`, so the
`00-` prefix guarantees these settings win:

```bash
# ensure the main config includes the drop-in dir (some minimal images omit this)
grep -qxF 'Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config \
  || echo 'Include /etc/ssh/sshd_config.d/*.conf' | sudo tee -a /etc/ssh/sshd_config

sudo tee /etc/ssh/sshd_config.d/00-hardening.conf > /dev/null <<'EOF'
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin no
KbdInteractiveAuthentication no
EOF

sudo systemctl restart ssh   # 'ssh' is the canonical unit on Debian/Ubuntu
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
