# Docker Setup (Debian / Ubuntu)

## Post-Install Configuration

> **IPv6-only host?** Use the merged `daemon.json` from
> [ipv6-only-vps.md](ipv6-only-vps.md) instead — a plain log-rotation
> `daemon.json` would overwrite its IPv6 keys.

### Prune unused resources

```bash
docker system prune -af              # unused images and containers, plus the build cache
docker system prune -af --volumes    # the above, plus every volume no container references
docker system df                     # check disk usage
```

> **`--volumes` and `postgres-data`.** A volume is safe while any container references it,
> stopped ones included.
> After `docker compose down` removes the containers, `postgres-data` is unreferenced and
> `--volumes` deletes it.
> Run the plain form inside a maintenance window, or bring the stack back up first.

## Verify

```bash
docker --version               # Docker version 28.x+
docker compose version         # Docker Compose v2.x+
docker run hello-world         # pull + run test container
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
- [guides/ipv6-only-vps.md](ipv6-only-vps.md) — Docker IPv6 on IPv6-only hosts
- [guides/docker-multi-stage-builds.md](docker-multi-stage-builds.md) — minimal production images
- [guides/letsencrypt-docker.md](letsencrypt-docker.md) — TLS with Compose
- [templates/docker-compose.yml](../templates/docker-compose.yml) — local dev template
- [templates/docker-compose.prod.yml](../templates/docker-compose.prod.yml) — production template
