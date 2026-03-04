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

```bash
# set your public key
export SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"

# optional: override defaults
export USERNAME="nico"
export EXTRA_UFW_PORTS="80/tcp 443/tcp"

# run on the remote server
ssh root@<host> 'bash -s' < scripts/setup-server.sh
```

After the script finishes:

```bash
# verify login with new user
ssh nico@<host>

# verify docker
docker run hello-world
```

## Configuration

Edit the variables at the top of `setup-server.sh`:

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `USERNAME` | `nico` | Non-root user to create |
| `SSH_PUBLIC_KEY` | *(required)* | Your public SSH key |
| `EXTRA_UFW_PORTS` | `80/tcp 443/tcp` | Additional ports to open (space-separated) |

## After provisioning

- Open extra firewall ports as needed: `sudo ufw allow 443/tcp`
- Deploy apps via Docker Compose – see [docker-setup.md](docker-setup.md)
- Review hardening steps in detail – see [secure-linux.md](secure-linux.md)
