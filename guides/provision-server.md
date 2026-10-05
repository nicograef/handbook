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
- netcup path only: `<server>` — the server's id or name in the SCP, for [`scripts/netcup.sh`](../scripts/netcup.sh)

## Provision over SSH

Netcup supports only SSH-key injection at image install, so the script runs as root over SSH.

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
   sudo apt install -y git jq tmux bat eza fzf fd-find ripgrep git-delta
   ```

   Expected: apt ends without errors. Long work runs in a named session, `tmux new -A -s <project>`.

## Link the handbook dotfiles

A read-only https clone supplies the aliases, prompt and tmux config; the [install-dotfiles.sh](../scripts/install-dotfiles.sh) header lists the rest.

1. **Clone the handbook and run install.sh:**

   ```bash
   mkdir -p ~/r && git clone https://github.com/nicograef/handbook.git ~/r/handbook
   ~/r/handbook/install.sh
   ```

   Expected: it ends with `Done – restart your shell`. A later `git -C ~/r/handbook pull` updates every linked file.

## Verify

[`scripts/host-audit.sh`](../scripts/host-audit.sh) reads every setting the steps above apply, and changes nothing.
Prefix `bash` with any Configuration value the setup ran with other than its default, such as `EXTRA_UFW_PORTS=`.
Keep the output: each [maintenance pass](maintenance.md#verify) compares against it.

```bash
ssh <username>@<host>
curl -fsSL https://raw.githubusercontent.com/nicograef/handbook/main/scripts/host-audit.sh -o host-audit.sh
sudo bash host-audit.sh | tee "audit-$(hostname)-$(date +%F).txt"
readlink ~/.bash_aliases
docker run --rm hello-world
exit
# from the laptop
ssh root@<host> true
# netcup only, from a handbook clone
scripts/netcup.sh firewall-get <server>
```

| Check | Expected |
| --- | --- |
| `host-audit.sh` | Ends with `no FAIL`; read every `note` and raw list once |
| `readlink` | `<home>/r/handbook/dotfiles/.bash_aliases` |
| `hello-world` | Prints the Docker confirmation message |
| `ssh root@<host>` | `Permission denied (publickey)` |
| netcup `firewall-get` | The netcup default policies, then the user policy; `"consistent": true` |

The audit's checks are in [host-audit.sh](../scripts/host-audit.sh).
On Debian the stock `50unattended-upgrades` origins include the `label=Debian` stable point releases.
