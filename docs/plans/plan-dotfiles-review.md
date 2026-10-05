# Plan: Dotfiles review

## Goal

Fix the bugs found in `dotfiles/.bash_aliases`, track the dotfiles the laptop has but the handbook lacks, document the server install, and roll it out to the laptop, staging, gyva-prod and gyva-backup.

## Decisions

- **History**: `.bash_aliases` sets `HISTFILE="$HOME/.local/state/bash_history"` (dir created) before `HISTFILESIZE`. The stock `.bashrc` assignment then truncates only the old file. Rollout copies `~/.bash_history` to the new path once.
- **ls/eza**: `ls` stays GNU ls. `ll`/`la` call eza directly when installed, else `ls -la`/`ls -A`.
- **pci**: keeps its name and purpose (manual trial of a clean upgrade to latest). Becomes a function: refuses without `package.json`, removes every `node_modules` and the lockfile, keeps the global store, runs `pnpm update --latest --ignore-scripts`, then `pnpm audit`. Git restores the lockfile if the trial fails.
- **sss**: deleted.
- **gfp**: `git pull --all`. **gfpp**: pulls with `--all` only when `@{u}` exists, then pushes with the one retry.
- **gcm**: `git switch main`.
- **update**: unchanged.
- **gct**: deleted. **gbvv**: renamed `gba`. puli, glg, gbv stay.
- **p/m**: kept, with bash-completion's pnpm/make completers registered for them.
- **diffi**: `delta --side-by-side` where delta exists, else the diff version.
- **New**: `gp='git push'`, `gs='git status'`, `gd='git diff'`.
- **Comments**: trimmed to the 2-sentence rule (fzf block, history block).
- **Git ignore**: `dotfiles/gitignore-global` linked to `~/.config/git/ignore`; the manual `core.excludesfile` is unset (git reads that path by default).
- **inputrc**: `dotfiles/.inputrc` linked: `$include /etc/inputrc`, prefix history search on Up/Down, completion-ignore-case, show-all-if-ambiguous, colored-stats, mark-symlinked-directories.
- **SSH**: `templates/ssh_config` holds the generic `Host *` block; dev-machine.md copies it once. Host entries never enter the public repo.
- **EDITOR**: `EDITOR`/`VISUAL` = nvim where installed, else nano. The installer stops setting `core.editor`; rollout unsets it per machine.
- **Laptop `.bashrc`**: the hand-added PATH line goes; `~/.claude/rules/machine.md` follows.
- **Servers**: provision-server.md gains a step: https clone of the handbook, `install.sh`. It applies to every server, gyva-backup included.
- **gyva-backup base**: apt installs git and the provision-server CLI list, then clone and `install.sh`.
- **Out of scope**: gyva-backup's admin-host role (GitHub key, Claude Code, netcup monitoring app); the user drives it. Plaintext secrets in `~` (user handles them).

## Files

- `dotfiles/.bash_aliases`, `dotfiles/.inputrc` (new), `dotfiles/gitignore-global` (new)
- `scripts/install-dotfiles.sh` (links, header, drop `core.editor`)
- `templates/ssh_config` (new)
- `guides/dev-machine.md`, `guides/provision-server.md`, `README.md`
- Machine-local: `~/.bashrc`, `~/.claude/rules/machine.md`

## Checklist

- [x] History fix in `.bash_aliases` (own commit: `fix(bash)`)
- [x] Alias changes: ls/ll/la, pci, sss, gfp, gfpp, gcm, gct, gba, p/m completion, diffi, gp/gs/gd, comments
- [x] EDITOR/VISUAL in `.bash_aliases`; `core.editor` removed from installer; grep repo for `nano` references
- [x] `dotfiles/.inputrc` + link
- [x] `dotfiles/gitignore-global` + link
- [x] `templates/ssh_config` + dev-machine.md step
- [x] provision-server.md install step; guide stays 50–150 lines
- [x] README index, installer header updated
- [x] `make check` green; shellcheck on `.bash_aliases`; `bash -ic` smoke test of every alias
- [ ] Laptop: migrate history, unset `core.editor` and `core.excludesfile`, re-run `install.sh`, remove `.bashrc` PATH line, update machine.md
- [ ] staging, gyva-prod: pull, `install.sh`, history copy, unset `core.editor`; verify links and line counts
- [ ] gyva-backup: apt install (user runs the sudo line), https clone, `install.sh`, verify
- [ ] Delete this plan
