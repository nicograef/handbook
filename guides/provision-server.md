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
- netcup path only: `<server>` — the server's id or name in the SCP, for [`scripts/netcup.sh`](../scripts/netcup.sh)

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

3. **Close the netcup firewall from your laptop**, in a handbook clone ([why](../reference/netcup.md#firewall-model)). A host serving nothing applies `netcup-firewall-ssh.json` and attaches `ssh-only`:

   ```bash
   scripts/netcup.sh login
   scripts/netcup.sh policy-apply templates/netcup-firewall-web.json
   scripts/netcup.sh firewall-attach <server> web-server
   ```

   Expected: the firewall JSON lists `web-server` under `userPolicies`, with `"ingressImplicitRule": "DROP_ALL"`.

## Turn on lingering

Lingering keeps the user manager, and every tmux session under it, alive after the last logout.
Why that matters: [maintenance.md](maintenance.md#after-an-oom-kill).

1. **Log in as `<username>` and enable it:**

   ```bash
   ssh <username>@<host>
   sudo loginctl enable-linger "$USER"
   ```

   Expected: no output; the audit's `linger` line in [Verify](#verify) confirms it.

## Install tmux and the CLI tools

Without bat, eza, fd-find or fzf, their aliases in
[dotfiles/.bash_aliases](../dotfiles/.bash_aliases) stay inactive. All ship in Debian 13 `main`.

1. **Install them:**

   ```bash
   sudo apt install -y tmux bat eza fzf fd-find ripgrep git-delta
   ```

   Expected: apt ends without errors. Long work runs in a named session, see [reference/tmux.md](../reference/tmux.md).

## Verify

[`scripts/host-audit.sh`](../scripts/host-audit.sh) reads every setting the steps above apply, and changes nothing.
Prefix `bash` with any Configuration value the setup ran with other than its default, such as `EXTRA_UFW_PORTS=`.
Keep the output: each [maintenance pass](maintenance.md#verify) compares against it.

```bash
ssh <username>@<host>
curl -fsSL https://raw.githubusercontent.com/nicograef/handbook/main/scripts/host-audit.sh -o host-audit.sh
sudo bash host-audit.sh | tee "audit-$(hostname)-$(date +%F).txt"
docker run --rm hello-world
exit
# from the laptop
ssh root@<host> true
# netcup only, from a handbook clone
scripts/netcup.sh firewall-get <server>
```

| Check | Expected |
| --- | --- |
| `host-audit.sh` | Ends with `no FAIL`. Each `FAIL` names the expected and the read value; read every `note` and raw list once |
| `hello-world` | Prints the Docker confirmation message |
| `ssh root@<host>` | `Permission denied (publickey)` |
| netcup `firewall-get` | The netcup default policies, then the user policy; `"consistent": true` |

[linux-services.md](../reference/linux-services.md) explains the commands the audit runs.
The script adds no upgrade origins; the stock `50unattended-upgrades` ones apply.
On Debian they include the `label=Debian` stable point releases.
