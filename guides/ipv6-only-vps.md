# IPv6-only VPS (DNS64/NAT64 + Docker IPv6)

Makes an IPv6-only Debian/Ubuntu VPS, such as netcup's IPv6-only tariff, fully usable.
Two gaps need closing:

- Some services are still IPv4-only.
- Docker's default bridge gives containers IPv4-only NAT. With no IPv4 route on the host, containers have **no egress at all**.

[Provisioning](provision-server.md) itself runs without the DNS64 resolvers.

## Prerequisites

- IPv6-only Debian/Ubuntu VPS with sudo access
- Provisioned via [provision-server.md](provision-server.md)
- [`setup-server.sh`](../scripts/setup-server.sh) configures Docker IPv6 itself when it detects no IPv4 route (its step 6b)
- The DNS64 resolvers stay manual, since they are a third-party trust decision

## Set DNS64 resolvers

The free public DNS64/NAT64 service at <https://nat64.net> reaches IPv4-only services.
Its resolvers synthesize AAAA records for IPv4-only hosts and relay traffic through a NAT64 gateway.

1. **Write the three resolvers to `resolv.conf`:**

   ```bash
   printf 'nameserver 2a01:4f9:c010:3f02::1\nnameserver 2a01:4f8:c2c:123f::1\nnameserver 2a00:1098:2c::1\n' \
     | sudo tee /etc/resolv.conf
   ```

   Expected: `tee` echoes the three `nameserver` lines.

2. **Optional: lock the file** against future DNS managers:

   ```bash
   sudo chattr +i /etc/resolv.conf
   ```

   Expected: no output. The netcup Debian image does not regenerate `resolv.conf` at boot, so this guards only against later installs.

IPv4-bound traffic transits a best-effort third-party gateway; TLS keeps its content protected.
For full control, tunnel via WireGuard to one of your dual-stack hosts instead.

## Check Docker IPv6

[`setup-server.sh`](../scripts/setup-server.sh) already enabled IPv6 in the Docker daemon.
Its `default-network-opts` make every new network, Compose's included, IPv6-only.

- ULA subnets are NAT66-masqueraded; `ip6tables` is on by default (Docker 27+).
- Container DNS goes through the host, so the DNS64 resolvers also cover IPv4-only registries and APIs inside containers.
- The **default bridge keeps IPv4**, which Docker cannot disable there.
- Plain `docker run` without `--network` still prefers the dead IPv4 path against dual-stack targets. The step 6b comment in [setup-server.sh](../scripts/setup-server.sh) explains why.
- Use a user-defined network for anything real. In Compose, `enable_ipv6: true` + `enable_ipv4: false` set the same per network.

Source: <https://docs.docker.com/engine/daemon/ipv6/>

1. **Confirm the daemon config:**

   ```bash
   cat /etc/docker/daemon.json
   ```

   Expected: `"ipv6": true` and the `default-network-opts` block beside `"max-size": "10m"`.
   If the file predates the script, merge the keys from its step 6b by hand.

## Limits (no on-box workaround)

- **Inbound from IPv4-only clients:** the box is invisible to them.
  Front HTTP(S) with Cloudflare proxying (free tier); other ports have no easy equivalent.
- **GitHub-hosted Actions runners have no outbound IPv6**, so CI cannot SSH or rsync to the box directly.
  Use a self-hosted runner or a tunnel such as Tailscale or Cloudflare Tunnel.
- **netcup cannot add IPv4 later:** an IPv6-only server stays IPv6-only.
  Real IPv4 requires the IPv4+IPv6 tariff from the start (<https://helpcenter.netcup.com/en/wiki/server/ip>).

## Verify

```bash
cat /etc/resolv.conf
curl -sI https://github.com | head -1
docker network create v6check > /dev/null
docker run --rm --network v6check alpine wget -qO- https://deb.debian.org > /dev/null && echo container-net-ok
docker network rm v6check > /dev/null
```

| Check | Expected |
| --- | --- |
| `resolv.conf` | The three `nameserver` lines from [Set DNS64 resolvers](#set-dns64-resolvers) |
| `curl github.com` | `HTTP/2 200`, reached via NAT64 |
| `docker run` | `container-net-ok`: the container reached a dual-stack host from an IPv6-only user-defined network |

The `v6check` network has the same shape Compose creates.
