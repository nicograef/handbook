# Provision a New Debian / Ubuntu VPS

Automated setup using [`scripts/setup-server.sh`](../scripts/setup-server.sh).

## Inputs

Collect a value for every variable in the Configuration block at the top of
[`scripts/setup-server.sh`](../scripts/setup-server.sh) before running. The steps
also use placeholders not in that block:

- `<host>` — server IP or hostname (SSH target)
- Hetzner cloud-init path only: `<name>`, `<type>`, `<key-name>` — server name, server
  type, and the name of the SSH key to inject

## Usage

- **cloud-init** (preferred, Hetzner Cloud) — the server provisions itself on first
  boot. Copy [`templates/cloud-init.yml`](../templates/cloud-init.yml), fill the
  `<angle-bracket>` placeholders (`<ssh-public-key>`, `<username>`, `<user-password-hash>`,
  `<heartbeat-url>`; adjust `EXTRA_UFW_PORTS`), then create the server with it — via
  the console **Cloud config** field, or:

  ```bash
  # <user-password-hash>: prompts for the password (mkpasswd ships in the whois package)
  mkpasswd -m yescrypt

  hcloud server create \
    --name <name> --type <type> --image debian-13 \
    --ssh-key <key-name> \
    --user-data-from-file cloud-init.yml

  # wait for cloud-init to finish
  ssh <username>@<host> "sudo cloud-init status --wait"   # → status: done
  ssh <username>@<host> "sudo tail -n 40 /var/log/cloud-init-output.log"
  ```

- **manual SSH pipe** (netcup) — the fallback for a provider with no user-data
  field. Netcup supports only SSH-key injection at image install; see
  [`scripts/setup-server.sh`](../scripts/setup-server.sh)'s header comment for the
  invocation. In the netcup image dialog, pick your SSH key. Leave **Create
  additional user** off, so the key goes to root. The script creates the user
  and disables root login.

## Verify

```bash
ssh nico@<host>

sudo ufw status verbose

# listening sockets: only 22, 80 and 443 may be public
sudo ss -tlnp

# sshd hardening is effective
sudo sshd -T | grep -E '^(passwordauthentication|permitrootlogin|kbdinteractiveauthentication) '

sudo systemctl is-active fail2ban
sudo fail2ban-client get sshd journalmatch

# docker works without sudo
docker run --rm hello-world

cat /etc/docker/daemon.json

# unattended-upgrades is configured (dry run applies no changes; LC_ALL=C keeps the grep locale-proof)
sudo env LC_ALL=C unattended-upgrade --dry-run --debug 2>&1 | grep -i 'allowed origins'

systemctl list-timers 'apt-daily*' --no-pager

# swap is active, so the kernel has a reclaim path instead of only the OOM killer
swapon --show

cat /etc/cron.d/report-health
```

| Check | Expected |
| --- | --- |
| SSH login | Succeeds as `nico`, fails as `root` |
| `ufw status verbose` | `Status: active` with `22/tcp (LIMIT)` |
| `ss -tlnp` | Only 22, 80 and 443 on `0.0.0.0`/`[::]`; everything else on loopback |
| `sshd -T` | `no` three times: password, root login, keyboard-interactive |
| `fail2ban` | Reports `active` |
| `fail2ban-client get sshd journalmatch` | Includes `_COMM=sshd-session` |
| `hello-world` | Prints the Docker confirmation message |
| `daemon.json` | Contains `"max-size": "10m"`, plus the IPv6 keys on IPv6-only hosts |
| `unattended-upgrade` dry run | Lists the stock `Allowed origins`, one containing `-security` |
| `systemctl list-timers` | `apt-daily.timer` and `apt-daily-upgrade.timer` appear |
| `/etc/cron.d/report-health` | Prints the `0 8 * * * root /usr/local/bin/report-health` line |

- The stock `50unattended-upgrades` origins apply; the script adds none.
- On Debian they also include `label=Debian` stable point releases.

## After provisioning

- IPv6-only server? Set up DNS64 resolvers (and check the limits) —
  see [ipv6-only-vps.md](ipv6-only-vps.md)
- Deploy apps via Docker Compose – see [letsencrypt-docker.md](letsencrypt-docker.md)
- Install tmux and the modern CLI tools the shell aliases expect, all in Debian 13
  `main`. Without bat, eza, fd-find or fzf, their aliases in
  [templates/.bash_aliases](../templates/.bash_aliases) silently stay inactive:

  ```bash
  sudo apt install -y tmux bat eza fzf fd-find ripgrep git-delta
  ```

- Work in a named tmux session: `tmux new -A -s <project>` — see
  [cheatsheets/tmux.md](../cheatsheets/tmux.md).
