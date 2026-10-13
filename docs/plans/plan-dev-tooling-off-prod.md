# Plan: Keep developer tooling and credentials off production servers

> Source PRD: n/a (task from the 2026-10-13 jotti.rocks session)

## Goal

A production host never receives the laptop toolchain or developer credentials by accident, and `host-audit.sh` fails when it has them. A dev or agent server such as gyva-staging declares its role once and keeps working.

## Architectural decisions

- **No strip script.** Prevention in `setup-dev-machine.sh`, detection in `host-audit.sh`; a cleanup stays a one-off.
- **Role file:** `/etc/handbook-role` holds `prod` or `dev`. `setup-server.sh` gets `HOST_ROLE="${HOST_ROLE:-prod}"` in its Configuration block and writes the file on every run; a rerun with `HOST_ROLE=dev` changes it. `host-audit.sh` shares the same default line, so `check-repo.sh — server_audit_contract` holds.
- **Role readers:** `setup-dev-machine.sh` reads `$ETC_DIR/handbook-role`. A file that says `prod`, or a server marker `$ETC_DIR/ssh/sshd_config.d/00-hardening.conf` without the file, refuses every mode, `--check` included, with exit 1 before any item row. `dev`, or neither file (a laptop), runs as today. `host-audit.sh` expects the role it is given (default `prod`) and FAILs when the file says otherwise.
- **Invalid role:** an env value other than `prod` or `dev` exits 2 with usage in all three scripts; an invalid file value is a FAIL in `host-audit.sh` and a refusal in `setup-dev-machine.sh`.
- **Dev residue** (paths under the home `getent passwd "$USERNAME"` names): credentials `.config/gh/hosts.yml` and `.claude/.credentials.json`; private keys `.ssh/id_*` without `.pub`; toolchains `gcc` (dpkg), `/usr/local/go`, `/usr/local/bin/node`, `.local/bin/nvim`, `.local/lib/node_modules`. Present under `prod` is FAIL, under `dev` a note; absent is ok under both. Deploy keys (`.ssh/<project>-deploy`) are not `id_*` and stay allowed.
- **Remotes:** the handbook clone on a server stays https; project repos use the read-only deploy keys of `guides/deploy.md`.

## Inventory

- `scripts/setup-server.sh — Configuration block, SSHD_DROPIN` — writes the marker; gains `HOST_ROLE` and the role file
- `scripts/setup-dev-machine.sh — Configuration block, the root guard` — the refusal lands before the checks
- `scripts/test-setup-dev-machine.sh` — fixture harness with `ETC_DIR`
- `scripts/host-audit.sh — section(), verdict(), needs_root(), Configuration block` — new sections
- `scripts/check-repo.sh — server_audit_contract` — compares the two Configuration blocks
- `guides/dev-machine.md`, `guides/provision-server.md` — scope and role statements

## Resolved decisions

- The role persists in a file, so `setup-dev-machine.sh` and `host-audit.sh` need no flag; a `setup-server.sh` rerun on a dev server repeats `HOST_ROLE=dev`, and a forgotten flag resets to `prod`, which refuses rather than leaks.
- No GitHub API check for registered keys: the audit stays offline; the private-key check covers the same risk.
- No fixture test for `host-audit.sh`: it reads live system paths; Phase 2 verifies on two real hosts by piping the working-tree script over ssh.
- The gh binary that `install.sh` places in `~/.local/bin` is not residue: without `hosts.yml` it holds no credential.

## Open questions / Risks

- gyva-staging needs one `HOST_ROLE=dev` rerun of `setup-server.sh` (or writing the file) before Phase 1 lands there; Phase 3 does it.

## Phase 1: Role file and the setup-dev-machine.sh guard

**Depends on**: none

### Context

- `scripts/setup-server.sh — Configuration block` — add `HOST_ROLE`, validate it, write `/etc/handbook-role` (0644), print the role in the summary
- `scripts/setup-dev-machine.sh — Configuration block, root guard` — read the file, refuse per the decisions
- `scripts/test-setup-dev-machine.sh` — the four role cases
- `guides/dev-machine.md` — the script serves laptops and `dev`-role servers; how a server declares `dev`

### What to build

`setup-server.sh` records the host's role on every run. `setup-dev-machine.sh` refuses on a `prod` host or an unmarked server, naming `/etc/handbook-role` and the `HOST_ROLE=dev` rerun of `setup-server.sh` in its error. The fixture test covers: role `prod` refuses; marker without role file refuses; role `dev` runs `--check` as before; no marker and no file runs as today; role `staging` exits 2.

### Acceptance criteria

- [x] `make test-setup-dev-machine 2>&1 | rg -c 'role (prod refuses|missing refuses|dev runs|absent runs|invalid exits 2)'` prints 5, from five named `log` lines in the test.
- [x] `sudo HANDBOOK_REF=$(git rev-parse HEAD) bash scripts/setup-server.sh --dry-run 2>&1 | rg 'handbook-role'` shows the write.
- [x] `rg -c 'HOST_ROLE=dev' guides/dev-machine.md` prints at least 1.
- [x] `make check` passes.

## Phase 2: Role and dev-residue sections in host-audit.sh

**Depends on**: 1

### Context

- `scripts/host-audit.sh — Configuration block` — `HOST_ROLE` default line identical to setup-server.sh's; print it on the `expected:` line
- `scripts/host-audit.sh — section(), verdict(), needs_root()` — sections `role` and `dev residue` before `summary`
- `guides/provision-server.md` — one paragraph: servers get `install.sh` dotfiles only, never `setup-dev-machine.sh` unless the role is `dev`; the handbook clone stays https

### What to build

Section `role` FAILs when `/etc/handbook-role` is missing or differs from `HOST_ROLE`. Section `dev residue` reports each reading from the decisions list. It runs as root or as `$USERNAME`; any other caller gets `needs_root` notes, because the home is 0750 and its secrets 0600.

### Acceptance criteria

- [x] `shellcheck scripts/host-audit.sh` is clean.
- [x] `ssh gyva-staging 'HOST_ROLE=prod bash -s' < scripts/host-audit.sh | sed -n '/== dev residue/,/== summary/p'` shows FAIL rows for its gh token and private key.
- [ ] `ssh gyva-staging 'HOST_ROLE=dev bash -s' < scripts/host-audit.sh | sed -n '/== role/,/== summary/p'` shows no FAIL once Phase 3 wrote its role file.
- [x] `make check` passes.

## Phase 3: Declare the roles on jotti and gyva-staging

**Depends on**: 1, 2

### Context

- jotti.rocks VPS (`ssh jotti`) — prod; holds leftovers of the 2026-10-13 dev run: `~/.claude/.credentials.json`, `~/.npmrc`, `~/.local/lib/node_modules`, `~/.local/bin/bash-language-server`, `~/.local/share/pipx`, `~/.local/share/org.gnome.Ptyxis`
- gyva-staging — dev and agent box

### What to build

Nico reruns `setup-server.sh` on both hosts after Phase 1 lands: default role on jotti, `HOST_ROLE=dev` on gyva-staging. He removes the jotti leftovers and logs Claude Code out there.

### Acceptance criteria

- [ ] `ssh jotti cat /etc/handbook-role; ssh gyva-staging cat /etc/handbook-role` prints `prod` then `dev`.
- [ ] `ssh jotti 'bash -s' < scripts/host-audit.sh | sed -n '/== role/,/== summary/p'` shows no FAIL.
- [x] `ssh jotti 'ls ~/.claude/.credentials.json ~/.npmrc ~/.local/lib/node_modules ~/.local/share/pipx 2>&1'` reports every path missing.
