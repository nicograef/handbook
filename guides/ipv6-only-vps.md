# IPv6-only VPS (DNS64/NAT64 + Docker IPv6)

Makes an IPv6-only Debian/Ubuntu VPS (e.g. netcup's IPv6-only tariff) fully usable.
Two gaps to close: some services are still IPv4-only, and Docker's default bridge
gives containers IPv4-only NAT — no IPv4 route on the host means **no container
egress at all**.

Who lacks IPv6 (verified 2026-07-22): `github.com` (HTTPS **and** SSH),
`api.github.com`, `codeload.github.com`, `ghcr.io`, `objects.githubusercontent.com`.
Native IPv6 works for: Debian mirrors, `download.docker.com`,
`raw.githubusercontent.com`, npm, Docker Hub, Better Stack — so
[provisioning](provision-server.md) itself runs without step 1.

## Prerequisites

- IPv6-only Debian/Ubuntu VPS with sudo access
- Provisioned via [provision-server.md](provision-server.md) —
  [`setup-server.sh`](../scripts/setup-server.sh) applies step 2 automatically when
  it detects no IPv4 route (step 6b); step 1 stays manual (third-party trust decision)

## 1. DNS64 resolvers (reach IPv4-only services)

Use the free public DNS64/NAT64 service at <https://nat64.net>. Its resolvers
synthesize AAAA records for IPv4-only hosts and relay traffic through a NAT64
gateway:

```bash
printf 'nameserver 2a01:4f9:c010:3f02::1\nnameserver 2a00:1098:2c::1\nnameserver 2a00:1098:2b::1\n' \
  | sudo tee /etc/resolv.conf
```

- The netcup Debian image does not regenerate `resolv.conf` at boot (verified
  2026-07-22). Guard against future DNS managers with
  `sudo chattr +i /etc/resolv.conf` if wanted.
- Trust trade-off: IPv4-bound traffic transits a best-effort third-party gateway.
  TLS content stays protected; for full control, tunnel via WireGuard to one of
  your dual-stack hosts instead.

## 2. Docker IPv6 (container networking)

Write `/etc/docker/daemon.json` (this merges the log-rotation block from
[docker-setup.md](docker-setup.md) — on IPv6-only hosts use this version, not that
one):

```bash
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:d0c:1::/64",
  "default-network-opts": {
    "bridge": { "com.docker.network.enable_ipv6": "true" }
  },
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
sudo systemctl restart docker
```

- `ipv6` + `fixed-cidr-v6` cover the default bridge; `default-network-opts` makes
  new networks (what Compose creates) IPv6-enabled with auto-allocated ULA subnets.
  Explicit per-network alternative in Compose: `enable_ipv6: true`.
- ULA subnets are NAT66-masqueraded; `ip6tables` is on by default (Docker 27+).
- Container DNS goes through the host, so the DNS64 path from step 1 covers
  IPv4-only registries and APIs inside containers too.
- Source: <https://docs.docker.com/engine/daemon/ipv6/>

## Limits (no on-box workaround)

- **Inbound from IPv4-only clients:** the box is invisible to them. Front HTTP(S)
  with Cloudflare proxying (free tier); other ports have no easy equivalent.
- **GitHub-hosted Actions runners have no outbound IPv6** — CI cannot SSH/rsync to
  the box directly; use a self-hosted runner or a tunnel (e.g. Tailscale,
  Cloudflare Tunnel).
- **netcup cannot add IPv4 later:** an IPv6-only server stays IPv6-only; real IPv4
  requires the IPv4+IPv6 tariff from the start
  (<https://helpcenter.netcup.com/en/wiki/server/ip>).

## Verify

```bash
cat /etc/resolv.conf                                   # three nat64.net resolvers
curl -sI https://github.com | head -1                  # HTTP/2 200 (via NAT64)
docker run --rm alpine wget -qO- https://deb.debian.org > /dev/null && echo container-net-ok
docker network create v6check > /dev/null \
  && docker network inspect v6check --format 'compose-default-ipv6: {{.EnableIPv6}}' \
  ; docker network rm v6check > /dev/null
```

Expected: the three `2a01:4f9...`/`2a00:1098...` nameservers; `HTTP/2 200`;
`container-net-ok` (container pulled the page over IPv6); and
`compose-default-ipv6: true` (new networks get IPv6 without per-file config).

---

See also:

- [guides/provision-server.md](provision-server.md) — server provisioning (runs step 2 automatically)
- [guides/docker-setup.md](docker-setup.md) — Docker install & dual-stack post-install config
- [scripts/setup-server.sh](../scripts/setup-server.sh) — step 6b is the automated form of step 2
