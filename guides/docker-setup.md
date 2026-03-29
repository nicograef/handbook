# Docker Setup (Debian / Ubuntu)

## Prerequisites

- Debian 12+ or Ubuntu 22.04+
- Root or sudo access
- Internet access

## Install Docker on Debian / Ubuntu

Source: https://docs.docker.com/engine/install/debian/

```bash
# install prerequisites
sudo apt update
sudo apt install -y ca-certificates curl gnupg

# add Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# add Docker repo (works for Debian and Ubuntu — uses $VERSION_CODENAME)
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# run without sudo
sudo usermod -aG docker $USER
newgrp docker
```

## Post-Install Configuration

### Log rotation (prevent disk fill)

```bash
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
sudo systemctl restart docker
```

### Prune unused resources

```bash
docker system prune -af --volumes    # remove all unused images, containers, volumes
docker system df                     # check disk usage
```

## Verify

```bash
docker --version               # Docker version 28.x+
docker compose version         # Docker Compose v2.x+
docker run hello-world         # pull + run test container
docker info | grep 'Logging Driver'  # confirm json-file
```

## Troubleshooting

```bash
# "permission denied" after usermod → log out and back in, or:
newgrp docker

# daemon won't start
sudo systemctl status docker
sudo journalctl -u docker --since '10 min ago'

# DNS issues inside containers
# add to /etc/docker/daemon.json: "dns": ["8.8.8.8", "1.1.1.1"]
```

---

See also:
- [cheatsheets/docker-compose.md](../cheatsheets/docker-compose.md) — Compose commands
- [guides/docker-multi-stage-builds.md](docker-multi-stage-builds.md) — minimal production images
- [guides/letsencrypt-docker.md](letsencrypt-docker.md) — TLS with Compose
- [templates/docker-compose.yml](../templates/docker-compose.yml) — local dev template
- [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml) — production template
