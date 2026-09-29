# Provision a New Debian / Ubuntu VPS

Provision and harden a fresh VPS with [`scripts/setup-server.sh`](../scripts/setup-server.sh).
An IPv6-only server continues with [ipv6-only-vps.md](ipv6-only-vps.md).
Apps then ship through [deploy.md](deploy.md).

## Prerequisites

Collect a value for every variable in the Configuration block at the top of
[`scripts/setup-server.sh`](../scripts/setup-server.sh) before running. The steps
also use placeholders not in that block:

- `<host>` — server IP or hostname (SSH target)
- `<username>` — the `USERNAME` the script creates
- Hetzner cloud-init path only: `<name>`, `<type>`, `<key-name>` — server name, server
  type, and the name of the SSH key to inject

## Provision with cloud-init

The preferred path, on Hetzner Cloud: the server provisions itself on first boot.

1. **Hash the user password.** `mkpasswd` ships in the `whois` package:

   ```bash
   mkpasswd -m yescrypt
   ```

   Expected: a prompt for the password, then one `$y$…` line, the `<user-password-hash>`.

2. **Fill the template.** Copy [`templates/cloud-init.yml`](../templates/cloud-init.yml)
   to `cloud-init.yml` and replace every `<angle-bracket>` placeholder. Adjust
   `EXTRA_UFW_PORTS` if the app needs more than 80 and 443.

   Expected: `grep -n '<' cloud-init.yml` prints only commented lines.

3. **Create the server,** here with `hcloud`; the console's **Cloud config** field takes the same file:

   ```bash
   hcloud server create \
     --name <name> --type <type> --image debian-13 \
     --ssh-key <key-name> \
     --user-data-from-file cloud-init.yml
   ```

   Expected: `hcloud` prints the server's IPv4 and IPv6 addresses.

4. **Wait for cloud-init to finish:**

   ```bash
   ssh <username>@<host> "cloud-init status --wait"
   ssh -t <username>@<host> "sudo tail -n 40 /var/log/cloud-init-output.log"
   ```

   Expected: `status: done`, and the log shows the script's `Setup complete` summary.

## Provision over SSH

The fallback for a provider with no user-data field, such as netcup. Netcup supports only SSH-key injection at image install.

1. **Install the image with root key access.** In the netcup image dialog, pick your SSH key.
   Leave **Create additional user** off, so the key goes to root.

   Expected: `ssh root@<host> true` succeeds without a password prompt.

2. **Pipe the script to root over SSH.** The invocation is in the header comment of
   [`scripts/setup-server.sh`](../scripts/setup-server.sh). The script creates `<username>` and disables root login.

   Expected: the run prints the `Setup complete` summary.

## Turn on lingering

Lingering keeps the user manager, and every tmux session under it, alive after the last logout.
Why that matters: [maintenance.md](maintenance.md#after-an-oom-kill).

1. **Log in as `<username>` and enable it:**

   ```bash
   ssh <username>@<host>
   sudo loginctl enable-linger "$USER"
   ```

   Expected: no output; the Verify row below confirms it.

## Install tmux and the CLI tools

Without bat, eza, fd-find or fzf, their aliases in
[dotfiles/.bash_aliases](../dotfiles/.bash_aliases) stay inactive. All ship in Debian 13 `main`.

1. **Install them:**

   ```bash
   sudo apt install -y tmux bat eza fzf fd-find ripgrep git-delta
   ```

   Expected: apt ends without errors. Long work runs in a named session, see [reference/tmux.md](../reference/tmux.md).

## Verify

[linux-services.md](../reference/linux-services.md) explains each command.

```bash
ssh <username>@<host>
sudo ufw status verbose
# listening sockets: only 22, 80 and 443 may be public
sudo ss -tlnp
sudo sshd -T | grep -E '^(passwordauthentication|permitrootlogin|kbdinteractiveauthentication) '
sudo systemctl is-active fail2ban
sudo fail2ban-client get sshd journalmatch
docker run --rm hello-world
cat /etc/docker/daemon.json
# the dry run applies no changes; LC_ALL=C keeps the grep locale-proof
sudo env LC_ALL=C unattended-upgrade --dry-run --debug 2>&1 | grep -i 'allowed origins'
systemctl list-timers 'apt-daily*' --no-pager
swapon --show
cat /etc/cron.d/report-health
systemctl is-active cron
loginctl show-user "$USER" -p Linger
```

| Check | Expected |
| --- | --- |
| SSH login | Succeeds as `<username>`, fails as `root` |
| `ufw status verbose` | `Status: active` with `22/tcp (LIMIT)` |
| `ss -tlnp` | Only 22, 80 and 443 on `0.0.0.0`/`[::]`; everything else on loopback |
| `sshd -T` | `no` three times: password, root login, keyboard-interactive |
| `fail2ban` | Reports `active` |
| `fail2ban-client get sshd journalmatch` | Includes `_COMM=sshd-session` |
| `hello-world` | Prints the Docker confirmation message |
| `daemon.json` | Contains `"max-size": "10m"`, plus the IPv6 keys on IPv6-only hosts |
| `unattended-upgrade` dry run | Lists the stock `Allowed origins`, one containing `-security` |
| `systemctl list-timers` | `apt-daily.timer` and `apt-daily-upgrade.timer` appear |
| `swapon --show` | One swap row, so the kernel can reclaim memory before the OOM killer runs |
| `/etc/cron.d/report-health` | Prints the `0 * * * * root /usr/local/bin/report-health` line |
| `systemctl is-active cron` | `active` |
| `loginctl show-user` | `Linger=yes` |

The script adds no upgrade origins; the stock `50unattended-upgrades` ones apply.
On Debian they include the `label=Debian` stable point releases.
