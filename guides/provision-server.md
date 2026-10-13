# Provision a New Debian / Ubuntu VPS

Provision and harden a fresh VPS with [`scripts/setup-server.sh`](../scripts/setup-server.sh).
An IPv6-only server runs [Set DNS64 resolvers](ipv6-only-vps.md#set-dns64-resolvers) before [Link the handbook dotfiles](#link-the-handbook-dotfiles), and the rest of [ipv6-only-vps.md](ipv6-only-vps.md) after [Verify](#verify).
Apps then ship through [deploy.md](deploy.md).

## Prerequisites

Collect a value for every variable in the Configuration block at the top of
[`scripts/setup-server.sh`](../scripts/setup-server.sh) before running. The steps
also use placeholders not in that block:

- A handbook clone on your laptop, at a commit pushed to GitHub
- `<host>` — server IP or hostname (SSH target)
- `<username>` — the `USERNAME` the script creates
- `<name>` and `<fqdn>` — the host's short name and domain, such as `staging` and `staging.example.com`
- netcup path only: `<server>` — the server's id or name in the SCP, for [`scripts/netcup.sh`](../scripts/netcup.sh)

## Provision over SSH

Netcup supports only SSH-key injection at image install, so the script runs as root over SSH.

1. **Install the image with root key access.** In the netcup image dialog, pick your SSH key.
   Leave **Create additional user** off, so the key goes to root.

   Expected: `ssh root@<host> true` succeeds without a password prompt.

2. **Pipe the script to root over SSH from the clone.** The invocation is in the header comment of
   [`scripts/setup-server.sh`](../scripts/setup-server.sh). The script creates `<username>` and disables root login.
   It installs `report-health.sh` from the clone's commit, `HANDBOOK_REF`, after a sha256 check.

   Expected: the run prints the `Setup complete` summary.

3. **Close the netcup firewall from your laptop**, in a handbook clone ([why](../reference/netcup.md#firewall-model)). A host serving nothing applies `netcup-firewall-ssh.json` and attaches `ssh-only`:

   ```bash
   scripts/netcup.sh login
   scripts/netcup.sh policy-apply templates/netcup-firewall-web.json
   scripts/netcup.sh firewall-attach <server> web-server
   ```

   Expected: the firewall JSON lists `web-server` under `userPolicies`, with `"ingressImplicitRule": "DROP_ALL"`.

## Name the host

netcup images ship a generated name such as `v2202510308862394466`, which the prompt and the health pings show.

1. **Set the `/etc/hosts` lines first, then the name**, so sudo still resolves the host:

   ```bash
   ssh <username>@<host>
   old=$(hostname)
   sudo sed -i "s/$old\.\S* $old\$/<fqdn> <name>/" /etc/hosts
   sudo hostnamectl set-hostname <name>
   echo <fqdn> | sudo tee /etc/mailname
   ```

   Expected: `hostname` prints `<name>`, and a new login shows it in the prompt.

## Install tmux and the CLI tools

Without bat, eza, fd-find or fzf, their aliases in
[dotfiles/.bash_aliases](../dotfiles/.bash_aliases) stay inactive. All ship in Debian 13 `main`.

1. **Log in as `<username>` and install them:**

   ```bash
   ssh <username>@<host>
   sudo apt install -y tmux bat eza fzf fd-find ripgrep git-delta
   ```

   Expected: apt ends without errors. Long work runs in a named session, `tmux new -A -s <project>`.

## Link the handbook dotfiles

A read-only https clone supplies the aliases, prompt and tmux config; the [install-dotfiles.sh](../scripts/install-dotfiles.sh) header lists the rest.
github.com has no IPv6 address, so an IPv6-only server sets the [DNS64 resolvers](ipv6-only-vps.md#set-dns64-resolvers) first.

A server gets these dotfiles, never [setup-dev-machine.sh](../scripts/setup-dev-machine.sh), unless its `HOST_ROLE` is `dev`.
The handbook clone stays https; project repos clone with the read-only deploy keys of [deploy.md](deploy.md#first-deploy).

1. **Clone the handbook and run install.sh:**

   ```bash
   mkdir -p ~/r && git clone https://github.com/nicograef/handbook.git ~/r/handbook
   ~/r/handbook/install.sh
   ```

   Expected: it ends with `Done – restart your shell`. A later `git -C ~/r/handbook pull` updates every linked file.

## Rerun

The script reruns on a set-up host as maintenance; the rerun invocation is in its header comment.
It keeps the authorized keys and the password. It upgrades every package, so run it in a maintenance window.
Every run records its Configuration in `/etc/handbook-host.env`, and a rerun reuses it. A passed value replaces the recorded one.

## Verify

[`scripts/host-audit.sh`](../scripts/host-audit.sh) reads every setting the steps above apply, and changes nothing.
It expects the Configuration recorded in `/etc/handbook-host.env`, and FAILs without that file.
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
| `hello-world` | Prints the Docker confirmation message; a host with `INSTALL_DOCKER=false` skips it |
| `ssh root@<host>` | `Permission denied (publickey)` |
| netcup `firewall-get` | The netcup default policies, then the user policy; `"consistent": true` |

The audit's checks are in [host-audit.sh](../scripts/host-audit.sh).
On Debian the stock `50unattended-upgrades` origins include the `label=Debian` stable point releases.
