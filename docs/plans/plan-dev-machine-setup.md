# Plan: dev-machine setup script

Goal: `sudo scripts/setup-dev-machine.sh` checks a dev machine against the handbook's target, then installs, updates and configures what differs. `--check` reports read-only.

## Files

- `scripts/setup-dev-machine.sh`, `scripts/test-setup-dev-machine.sh` (new)
- `guides/dev-machine.md`, `guides/neovim.md`, `README.md`, `scripts/check-repo.sh` (edit)

## Checklist

- [ ] Script: `--check`, interactive, `--yes`; root parts as root, home parts as the sudo user
- [ ] Fixture test: complete and fresh fixtures, `--yes` command order, root guard
- [ ] `dev-machine.md` runs the script; `neovim.md` keeps only the server path
- [ ] Contract: the tool lists in `neovim.md` match the script's arrays
- [ ] README rows; `make check` and `make test` pass
- [ ] `--check` on this laptop shows the expected state
