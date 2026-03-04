# Docker Setup (Debian / Ubuntu)

## Install Docker on Debian 13 (Trixie)

Guide: https://linuxiac.com/how-to-install-docker-on-debian-13-trixie/

```bash
# install prerequisites
sudo apt update
sudo apt install -y ca-certificates curl gnupg

# add Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# add Docker repo
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

## Verify

```bash
docker --version
docker compose version
docker run hello-world
```

For common Docker Compose commands see [cheatsheets/docker-compose.md](../cheatsheets/docker-compose.md).
