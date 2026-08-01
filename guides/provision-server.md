# Provision a New Debian / Ubuntu VPS

Automated setup using [`scripts/setup-server.sh`](../scripts/setup-server.sh).

## Prerequisites

- A fresh VPS with root SSH access
- An SSH key pair on your local machine

### Inputs

Collect a value for every variable in the Configuration block at the top of
[`scripts/setup-server.sh`](../scripts/setup-server.sh) before running. The steps
also use placeholders not in that block:

- `<host>` — server IP or hostname (SSH target)
- Hetzner cloud-init path only: `<name>`, `<type>`, `<key-name>` — server name, server
  type, and the name of the SSH key to inject

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

# container-log rotation is configured
cat /etc/docker/daemon.json

# unattended-upgrades is configured (dry run applies no changes)
sudo unattended-upgrade --dry-run --debug 2>&1 | grep -i 'allowed origins'

# apt's periodic update/upgrade timers are active
systemctl list-timers 'apt-daily*' --no-pager

# the daily health-ping cron entry is installed
cat /etc/cron.d/report-health
```

Expected: SSH login succeeds as `nico` but fails as `root`; `ufw status`
shows `Status: active` with `22/tcp (LIMIT)`; `fail2ban` reports `active`;
`hello-world` prints the Docker confirmation message; `daemon.json` contains
`"max-size": "10m"` (plus the IPv6 keys on IPv6-only hosts); the `unattended-upgrade`
dry run lists an `Allowed origins` line containing `-security` (on Debian it
also carries `label=Debian` stable origins from the stock `50unattended-upgrades`
`Origins-Pattern` — expected, our drop-in extends rather than replaces it);
`apt-daily.timer` and `apt-daily-upgrade.timer` appear in the timer list; and
`/etc/cron.d/report-health` prints the `0 8 * * * root /usr/local/bin/report-health`
line.

## SSH hardening (drop-in)

The script automates this (step 3). Run it by hand when debugging or tightening
an existing server.

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

## After provisioning

- IPv6-only server? Set up DNS64 resolvers (and check the limits) —
  see [ipv6-only-vps.md](ipv6-only-vps.md)
- Open extra firewall ports as needed: `sudo ufw allow 443/tcp`
- Deploy apps via Docker Compose – see [docker-setup.md](docker-setup.md)
- Install tmux and the modern CLI tools the shell aliases expect (all in
  Debian 13 `main`, verified 2026-07; without them the aliases in
  [templates/.bash_aliases](../templates/.bash_aliases) silently stay inactive):

  ```bash
  sudo apt install -y tmux bat eza fzf fd-find ripgrep git-delta
  ```

- Install personal dotfiles (shell aliases, history + git prompt, tmux config,
  git defaults, gh CLI; idempotent to re-run; the Claude config symlinks it
  also creates are inert on servers without Claude Code – see
  [dotfiles-codespaces.md](dotfiles-codespaces.md) for what the installer does
  in detail):

  ```bash
  git clone https://github.com/nicograef/handbook.git ~/handbook && ~/handbook/install.sh
  ```

- Work in a named tmux session so an ssh disconnect only detaches instead of
  killing running processes (Claude Code, builds):
  `tmux new -A -s <project>` — see [cheatsheets/tmux.md](../cheatsheets/tmux.md).

---

See also:
- [scripts/setup-server.sh](../scripts/setup-server.sh) — automated server provisioning script
- [guides/ipv6-only-vps.md](ipv6-only-vps.md) — IPv6-only servers (DNS64/NAT64, Docker IPv6)
- [guides/docker-setup.md](docker-setup.md) — Docker installation
- [guides/letsencrypt-docker.md](letsencrypt-docker.md) — TLS certificates
