# IPv6-only VPS (DNS64/NAT64 + Docker IPv6)

Makes an IPv6-only Debian/Ubuntu VPS (e.g. netcup's IPv6-only tariff) fully usable.
Two gaps to close:

- Some services are still IPv4-only.
- Docker's default bridge gives containers IPv4-only NAT.
  - No IPv4 route on the host means **no container egress at all**.

Native IPv6 per host:

| Host | Native IPv6 |
| --- | --- |
| `github.com` (HTTPS **and** SSH) | No |
| `api.github.com` | No |
| `codeload.github.com` | No |
| `ghcr.io` | No |
| `objects.githubusercontent.com` | No |
| Debian mirrors | Yes |
| `download.docker.com` | Yes |
| `raw.githubusercontent.com` | Yes |
| npm | Yes |
| Docker Hub | Yes |
| Better Stack | Yes |

So [provisioning](provision-server.md) itself runs without step 1.

## Prerequisites

- IPv6-only Debian/Ubuntu VPS with sudo access
- Provisioned via [provision-server.md](provision-server.md)
- [`setup-server.sh`](../scripts/setup-server.sh) applies step 2 automatically when it
  detects no IPv4 route (step 6b)
- Step 1 stays manual — it is a third-party trust decision

## 1. DNS64 resolvers (reach IPv4-only services)

Use the free public DNS64/NAT64 service at <https://nat64.net>. Its resolvers
synthesize AAAA records for IPv4-only hosts and relay traffic through a NAT64
gateway:

```bash
printf 'nameserver 2a01:4f9:c010:3f02::1\nnameserver 2a00:1098:2c::1\nnameserver 2a00:1098:2b::1\n' \
  | sudo tee /etc/resolv.conf
```

- The netcup Debian image does not regenerate `resolv.conf` at boot.
- Guard against future DNS managers with `sudo chattr +i /etc/resolv.conf` if wanted.
- Trust trade-off: IPv4-bound traffic transits a best-effort third-party gateway.
- TLS content stays protected.
- For full control, tunnel via WireGuard to one of your dual-stack hosts instead.

## 2. Docker IPv6 (container networking)

Write `/etc/docker/daemon.json`. It merges the log-rotation block from
[docker-setup.md](docker-setup.md); on IPv6-only hosts use this version, not that one:

```bash
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:d0c:1::/64",
  "default-network-opts": {
    "bridge": {
      "com.docker.network.enable_ipv6": "true",
      "com.docker.network.enable_ipv4": "false"
    }
  },
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
sudo systemctl restart docker
```

- `default-network-opts` makes new networks (what Compose creates) **IPv6-only**, with
  auto-allocated ULA subnets.
- IPv6-only is deliberate, not just enabled.
- With a dead IPv4 plus a ULA IPv6 in the container, RFC 6724 address selection prefers
  IPv4.
- That preference applies to dual-stack targets, and the IPv4 path black-holes.
- No IPv4, no wrong choice.
- Explicit per-network alternative in Compose: `enable_ipv6: true` + `enable_ipv4: false`.
- ULA subnets are NAT66-masqueraded; `ip6tables` is on by default (Docker 27+).
- Container DNS goes through the host.
- The DNS64 path from step 1 therefore covers IPv4-only registries and APIs inside
  containers too.
- The **default bridge keeps IPv4** — Docker cannot disable it there.
- Plain `docker run` without `--network` still hits the dead-IPv4 preference against
  dual-stack targets.
- Use a user-defined network for anything real.
- Source: <https://docs.docker.com/engine/daemon/ipv6/>

## Limits (no on-box workaround)

- **Inbound from IPv4-only clients:** the box is invisible to them.
- Front HTTP(S) with Cloudflare proxying (free tier); other ports have no easy equivalent.
- **GitHub-hosted Actions runners have no outbound IPv6** — CI cannot SSH/rsync to the box
  directly.
- Use a self-hosted runner or a tunnel (e.g. Tailscale, Cloudflare Tunnel).
- **netcup cannot add IPv4 later:** an IPv6-only server stays IPv6-only.
- Real IPv4 requires the IPv4+IPv6 tariff from the start
  (<https://helpcenter.netcup.com/en/wiki/server/ip>).

## Verify

```bash
cat /etc/resolv.conf                                   # three nat64.net resolvers
curl -sI https://github.com | head -1                  # HTTP/2 200 (via NAT64)
docker network create v6check > /dev/null
docker run --rm --network v6check alpine wget -qO- https://deb.debian.org > /dev/null && echo container-net-ok
docker network rm v6check > /dev/null
```

Expected:

- The three `2a01:4f9...`/`2a00:1098...` nameservers.
- `HTTP/2 200`.
- `container-net-ok` — the container reached a dual-stack host from an IPv6-only
  user-defined network.
- That network is the same shape Compose creates.

---

See also:

- [guides/docker-setup.md](docker-setup.md) — dual-stack post-install config
