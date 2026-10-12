# Plan: Setup scripts on Debian and as periodic maintenance

> Source PRD: n/a

## Goal

`setup-dev-machine.sh` runs on Ubuntu and Debian and never dies without a message.
`install.sh`, `setup-dev-machine.sh` and `setup-server.sh` rerun safely as maintenance, also on a host that is both dev machine and server.

## Architectural decisions

- **One script**: `setup-dev-machine.sh` picks per-distro items from `/etc/os-release`; any other distro is refused.
- **Debian sources**: Node from NodeSource's apt repo, Go from the go.dev tarball, Neovim from the release tarball in `~/.local`.
- **Docker**: a host with Docker's `docker-ce` keeps it; otherwise the distro packages.
- **uv**: the dev machine's uv is pipx's, at PyPI's latest; projects pin a floor with `required-version`.
- **Server rerun**: an existing key and password satisfy `setup-server.sh`; the rerun runs on the host as `nico` with sudo.

## Files

- `scripts/setup-dev-machine.sh` — distro detection, Debian items, ERR trap, docker set, uv check
- `scripts/test-setup-dev-machine.sh` — Debian fixture, broken snap probe
- `scripts/install-dotfiles.sh` — quiet rerun, no rewrite of `~/.claude.json` when it matches
- `scripts/setup-server.sh` — rerun without `SSH_PUBLIC_KEY` and `USER_PASSWORD_HASH`
- `dotfiles/.bash_aliases` — `/usr/local/go/bin` on PATH
- `guides/dev-machine.md`, `guides/neovim.md`, `guides/provision-server.md`, `README.md` — Debian and rerun

## Checklist

- [ ] Dev script: distro detection, guarded probes, ERR trap
- [ ] Dev script: Debian node, go, neovim items; docker set; uv via pipx
- [ ] Fixture test: Debian path, broken snap probe
- [ ] install-dotfiles.sh rerun reports and `~/.claude.json`
- [ ] setup-server.sh rerun
- [ ] Docs and README
- [ ] `make check` green; `--check` on staging
