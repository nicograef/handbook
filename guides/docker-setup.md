# Docker Setup (Debian / Ubuntu)

## Post-Install Configuration

> **IPv6-only host?** Use the merged `daemon.json` from
> [ipv6-only-vps.md](ipv6-only-vps.md) instead — a plain log-rotation
> `daemon.json` would overwrite its IPv6 keys.

### Prune unused resources

```bash
docker system prune -af    # unused images and containers, plus the build cache
docker system df           # check disk usage
```

> **Never add `--volumes` on a stack with `postgres-data`.** It deletes every volume no
> container references.
> After `docker compose down` has removed the containers, that includes the database.
> Deleting a volume needs a human decision, never an agent's.

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
