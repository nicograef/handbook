# Plan: Setup cleanup

> Source PRD: n/a. Source: the 2026-10-05 cleanup review, decided by the owner.

## Goal

Remove what the setup and the handbook carry without use. Fix the overbroad `rm -rf` deny.

## Resolved decisions

- Plugins kept: playwright only, at user scope. jotti drops its project plugin block.
- Skills removed: reflect, mentor, testing. audiobook stays.
- Content removed: the nginx + Certbot TLS path, the Hetzner cloud-init path, `docs/UBIQUITOUS_LANGUAGE.md`, `reference/tmux.md`. `templates/nginx-spa.conf` stays: it is the SPA container's server block.
- Caddy is the one production TLS path.
- `prod-init.sh` and `backup-postgres.sh` move to `templates/`; every reference follows.
- Allow rules, Go rules and `~/.claude/settings.local.json` stay as they are.
- Laptop Node moves to the `26/stable` snap channel (owner runs the sudo step).

## Phase 1: Settings and skills

**Depends on**: none

### What to build

`claude/settings.json`: enabledPlugins keeps playwright only. The `Bash(rm -rf /*)` deny becomes exact denies for `rm -rf /`, `rm -rf ~` and `rm -rf ~/*`. `web-researcher.md` drops the context7 tools.

Delete the reflect, mentor and testing skills. The testing skill's Keep/Refactor/Delete/Merge table moves into cleanup. prune loses its duplicate sweep bullet. plan merges its repeated self-review steps.

### Acceptance criteria

- [ ] `jq -r '.enabledPlugins | keys | join(",")' claude/settings.json` prints `playwright@claude-plugins-official`
- [ ] `jq -r '.permissions.deny[]' claude/settings.json | grep -c 'rm -rf /\*'` prints 0
- [ ] `grep -rnE 'skills/(reflect|mentor|testing)\b|/(reflect|mentor)\b|context7' --include='*.md' --include='*.json' . | grep -v docs/plans/` prints nothing
- [ ] `make check` passes

## Phase 2: Content

**Depends on**: none

### What to build

Delete the nginx + Certbot TLS templates and their branches in scripts and guides. Delete `templates/cloud-init.yml` and its guide branch. Delete `docs/UBIQUITOUS_LANGUAGE.md` and `reference/tmux.md`; the tmux commands move into the `.tmux.conf` header. Shrink `reference/system-resources.md` to its live-usage table.

Move `prod-init.sh` and `backup-postgres.sh` to `templates/`. `guides/new-project.md` ends at 150 lines or fewer. Remove neovim's never-installed optional parts and the `init.lua` loader loop. Drop the `unalias pci` shim. Fix AGENTS.md's English exceptions to match `check-repo.sh`.

### Acceptance criteria

- [ ] `git ls-files | grep -cE 'nginx-tls|nginx-initial-cert|initial-cert|cloud-init|UBIQUITOUS|reference/tmux.md|scripts/(prod-init|backup-postgres)'` prints 0
- [ ] `wc -l < guides/new-project.md` prints 150 or less
- [ ] `grep -c 'unalias pci' dotfiles/.bash_aliases` prints 0
- [ ] `make check` and `make test-dockerfiles` pass

## Phase 3: Machine and account

**Depends on**: none

Nothing here is committed in the handbook.

### What to build

Uninstall context7, frontend-design, typescript-lsp and gopls-lsp at user scope. Remove the `nicograef` marketplace and the plugin trash. In jotti, uninstall the project-scope plugins and drop the block from its settings. The owner disconnects Claude Docs and disables the unused account skills. Node moves to 26; `machine.md` follows.

### Acceptance criteria

- [ ] `claude plugin list` shows playwright as the only plugin
- [ ] `claude plugin marketplace list` does not list `nicograef`
- [ ] `node --version` prints `v26`
