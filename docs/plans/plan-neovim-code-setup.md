# Plan: Neovim code setup on vim.pack

> Source PRD: n/a

## Goal

Grow the plugin-free prose config into a small LazyVim-like code editor for gyva's TypeScript and Python work.
Six plugins, built-ins first, every line chosen. It replaces the LazyVim install on this laptop.

## Architectural decisions

- **Plugin manager**: Neovim 0.12's built-in `vim.pack`; no lazy.nvim, no LazyVim.
- **Layout**: `dotfiles/nvim/init.lua` plus `dotfiles/nvim/nvim-pack-lock.json`; the directory links to `~/.config/nvim`, because `vim.pack` writes its lockfile there.
- **Plugins**: tokyonight, snacks.nvim (picker and explorer only), which-key, lualine, nvim-lspconfig, nvim-treesitter (`main` branch).
- **Language servers**: `ts_ls`, `ty`, `ruff`, `biome`, `bashls`, `yamlls`, `jsonls`, enabled through `vim.lsp.enable`.
- **Server binaries**: `uv tool install` for ruff and ty; `npm install -g` (prefix `~/.local`, as pnpm is installed) for the npm servers and `tree-sitter-cli`; Biome from the project's `node_modules`. No Mason.
- **Completion**: built-in `vim.lsp.completion` with autotrigger; no blink.cmp, no snippets.
- **Formatting**: format on save through the LSP, for `ruff` and `biome` clients only; no conform, no nvim-lint.
- **Servers**: same config on every machine; a missing server binary leaves that server off.

## Inventory

- `dotfiles/init.lua` — current config; moves to `dotfiles/nvim/init.lua` and keeps every section.
- `scripts/install-dotfiles.sh — LINKS` — link entry for the Neovim config.
- `README.md` — dotfiles index row for the config; `check-repo.sh` requires every tracked `dotfiles/*` file indexed.
- `AGENTS.md` — umlaut exception names `dotfiles/init.lua`.
- `guides/neovim.md` — guide; its framing is "no plugins, no IDE layer".
- `scripts/check-repo.sh — LANG_ALLOW, INDEX_DIRS` — the gate both files must pass.
- `~/.claude/rules/machine.md` — machine-local; names the init.lua link and the toolchain.
- `~/.config/nvim`, `~/.local/share/nvim/{lazy,mason,snacks}`, `~/.local/state/nvim/lazy` — the LazyVim install to retire.

## Resolved decisions

| Area | Decision | Dropped from LazyVim |
| --- | --- | --- |
| Base | vim.pack, own config | lazy.nvim, LazyVim |
| Theme | tokyonight | catppuccin |
| Find | snacks picker + explorer | dashboard, notifier, scroll, indent, words, input |
| UI | which-key, lualine | bufferline, noice, nui, mini.icons |
| Code | lspconfig, treesitter, built-in completion | mason ×2, blink.cmp, friendly-snippets, conform, nvim-lint, lazydev |
| Git | none (git CLI, `nvim.difftool`) | gitsigns |
| Editing | built-ins | flash, mini.ai, mini.pairs, ts-autotag, ts-comments, treesitter-textobjects |
| Project | quickfix, `:cdo`, `:mksession` | grug-far, trouble, todo-comments, persistence |

- **Keymaps**: Space leader; LazyVim's keys for the kept plugins only: `<leader><space>` files, `<leader>/` grep, `<leader>,` buffers, `<leader>fr` recent, `<leader>e` explorer, `<leader>sh` help, `<leader>sk` keymaps, `<leader>sd` diagnostics, `<leader>ss` LSP symbols, `gd` definition. LSP keys stay Neovim's defaults (`grn`, `gra`, `grr`, `gri`, `K`, `]d`).
- **Options added**: `signcolumn=yes` (no jitter from diagnostics), `winborder=rounded`, `completeopt=menuone,noselect,popup,fuzzy`. All current options and the German-keyboard remaps stay.
- **Icons**: no icon plugin; the Nerd Font reaches Ptyxis through fontconfig fallback.

## Open questions / Risks

- nvim-treesitter's `main` branch needs the `tree-sitter` CLI and a C compiler; verify its install API against the upstream README at implementation.
- `ty` is beta; a crash shows as an LSP error, and `vim.lsp.enable('ty', false)` disables it.
- lspconfig's `biome` config must resolve `node_modules/.bin/biome`; check its `cmd` at implementation.

## Phase 1: vim.pack base with picker and UI

**Depends on**: none

### Context

- `dotfiles/init.lua` — moves via `git mv` to `dotfiles/nvim/init.lua`.
- `scripts/install-dotfiles.sh — LINKS` — entry becomes `dotfiles/nvim .config/nvim`.
- `README.md`, `AGENTS.md`, `guides/neovim.md` — links to `dotfiles/init.lua`; `check_links` fails on a dead one.

### What to build

Move the config into `dotfiles/nvim/`, link the directory and re-run `install.sh`. The installer moves the LazyVim directory to `~/.config/nvim.bak`.
Add a Plugins section with `vim.pack.add` for tokyonight, snacks, which-key and lualine. Set the leader before it; add the picker and explorer keymaps.
Start Neovim once so `vim.pack` writes the lockfile; commit it. Index both files in `README.md`; update `AGENTS.md` and the guide's links.
Rewrite the init.lua header comment and the README row to name the plugins.
Delete `~/.config/nvim.bak`, `~/.local/share/nvim/{lazy,mason,snacks}`, `~/.local/share/nvim/site/{parser,parser-info,queries}` and `~/.local/state/nvim/{lazy,blink,mason.log}`.

### Acceptance criteria

- [x] `readlink -f ~/.config/nvim` prints `<clone>/dotfiles/nvim`.
- [x] `nvim --headless -c 'lua print(vim.g.colors_name, #vim.pack.get())' -c q` prints `tokyonight-moon 4`.
- [x] `nvim --headless -c 'lua print(vim.fn.maparg("<Space><Space>", "n") ~= "")' -c q` prints `true`.
- [x] `ls -d ~/.config/nvim.bak ~/.local/share/nvim/{lazy,mason,snacks} ~/.local/share/nvim/site/parser ~/.local/state/nvim/lazy 2>&1 | grep -c 'No such file'` prints `6`.
- [x] `make check` passes.

## Phase 2: LSP, treesitter, completion and format on save

**Depends on**: 1

### Context

- `dotfiles/nvim/init.lua` — gains the code sections.
- `dotfiles/nvim/nvim-pack-lock.json` — gains nvim-lspconfig and nvim-treesitter.

### What to build

Install the binaries: `uv tool install ruff ty`; `cd ~/r/gyva/web && npm ci` for Biome; `npm install -g typescript typescript-language-server bash-language-server yaml-language-server vscode-langservers-extracted tree-sitter-cli`.
Add nvim-lspconfig and nvim-treesitter to `vim.pack.add`. Install parsers for bash, css, html, javascript, json, python, toml, tsx, typescript and yaml. A FileType autocmd starts treesitter highlighting where a parser exists.
`vim.lsp.enable` the seven servers. One LspAttach autocmd enables completion with autotrigger. For `ruff` and `biome` it also formats on `BufWritePre`.
Extend the init.lua header comment and the README row to name the code features.

### Acceptance criteria

- [x] `cd ~/r/gyva && nvim --headless src/gyva/__init__.py +'sleep 3' +'lua print(vim.iter(vim.lsp.get_clients({bufnr=0})):map(function(c) return c.name end):join(","))' +q` prints `ruff` and `ty`.
- [x] The same command on a `.ts` file under `~/r/gyva/web/src` prints `ts_ls` and `biome`.
- [x] `nvim --headless x.py +'lua print(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil)' +q` prints `true`.
- [x] `d=$(mktemp -d) && printf 'x=1\n' > "$d/f.py" && nvim --headless "$d/f.py" +'sleep 2' +w +q && cat "$d/f.py"` prints `x = 1`.
- [x] On a `.ts` file under `~/r/gyva/web/src`: `nvim --headless <file> +'sleep 3' +'lua print(#vim.api.nvim_get_autocmds({group="nvim.lsp.completion_"..vim.api.nvim_get_current_buf(), event="InsertCharPre"}) > 0)' +q` prints `true` (autotrigger is on).
- [x] `make check` passes.

## Phase 3: Guide and machine record

**Depends on**: 1, 2

### Context

- `guides/neovim.md` — framing, prerequisites, steps, keymap table, Verify block.
- `~/.claude/rules/machine.md` — Neovim link line and Toolchain state.

### What to build

Rewrite the guide for prose and code. Cover the plugin list, the language-server install commands, plugin updates (`vim.pack.update()`, commit the lockfile) and a keymap table. Its Verify block carries the Phase 1 and 2 checks, with the plugin count at 6. Update `machine.md` with the directory link, the uv tools and the npm globals.

### Acceptance criteria

- [x] `git grep -n 'dotfiles/init.lua' -- ':!docs/plans'; grep -rn 'dotfiles/init.lua' ~/.claude/rules` prints nothing.
- [x] Every command in the guide's Verify block prints its stated result.
- [x] `make check` passes.
