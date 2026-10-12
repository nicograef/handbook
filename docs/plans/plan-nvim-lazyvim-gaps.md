# Plan: Close the useful LazyVim gaps in the Neovim config

> Source PRD: n/a

## Goal

Add the LazyVim behaviour that improves daily editing, keeping the lean `vim.pack` setup.
Every phase serves learning Vim properly: no shortcut hides a built-in.

## Architectural decisions

- **Config shape**: `dotfiles/nvim/init.lua` stays the single config file. No `lua/` modules.
- **Keys**: no mapping replaces or shortcuts a built-in key. Not mapped:
  - `<S-h>`/`<S-l>`: they would replace `H`/`L`; buffers stay on `]b`/`[b`.
  - `<A-j>`/`<A-k>`: moving lines stays `:m`.
  - `<C-h/j/k/l>`: window moves stay `Ctrl-w h/j/k/l`.
  - `<Esc>` hlsearch clear: that stays `Ctrl-l`.
- New keys add only what Vim lacks, with LazyVim's lhs. They reach `[`/`]` through the German-keyboard remaps.
- **Toggles**: `Snacks.toggle`. The which-key spec carries the `<leader>u` (ui) and `<leader>g` (git) groups.
- **New plugins**: precognition.nvim, hardtime.nvim, nui.nvim, gitsigns.nvim, nvim-treesitter-textobjects (`main`), mini.icons (`nvim-mini/mini.icons`).
- **Checks**: run every `nvim --headless` criterion as `XDG_CONFIG_HOME=$PWD/dotfiles nvim …`. `~/.config/nvim` links to the main clone, so a worktree would otherwise test the old config.
- **Out of scope**:
  - Learning extras: screenkey.nvim, nvim-training, a learning-path guide section.
  - LazyVim plugins: mason, conform, nvim-lint, blink.cmp, trouble, todo-comments, bufferline, noice, dashboard, flash, mini.pairs, grug-far, persistence, lazydev.

## Resolved decisions

- `updatetime` stays default: snacks `words` has its own 200 ms debounce.
- `wrap` stays on, for prose.
- `spelllang=en,de`, on for markdown, text and gitcommit only.
- `foldlevel=99`: treesitter folds never hide code on open.
- `signcolumn=yes:2`: a diagnostic sign and a git sign show side by side.
- The learning panel is a non-focusable float, shown on every start. which-key cannot stay open, since its popup reads typed keys.
- hardtime runs in block mode with its defaults. nui.nvim loads only for `:Hardtime report` (`hardtime/report.lua`).
- lazygit comes from apt (Ubuntu 26.04: 0.57). The `sudo` install is a manual step.

## Open questions / Risks

- nvim-treesitter `main` indentexpr is marked experimental. If Python `o` indents wrongly, drop it for Python.
- precognition and hardtime do not state Neovim 0.12 support. `:checkhealth` and a real-terminal session confirm them.

## Phase 1: Built-in behaviour

**Depends on**: none

### Context

- `dotfiles/nvim/init.lua` — the Editing section, `require('snacks').setup()`, the FileType and LspAttach autocmds, and the keymap table after `pick()`
- `guides/neovim.md — Keys, Verify` — new keys and checks

### What to build

- Options:
  - `timeoutlen=300`, `cursorline`, `splitright`, `splitbelow`, `laststatus=3`
  - `jumpoptions=view`, `virtualedit=block`, `smoothscroll`, `spelllang=en,de`
- An augroup `config` holds these autocmds:
  - highlight on yank (`vim.hl.on_yank()`)
  - `:checktime` on FocusGained, TermClose and TermLeave
  - restore the last cursor position, except in gitcommit
  - `q` closes help, qf, man and checkhealth buffers
  - create missing parent directories on write
  - `spell` and `wrap` for markdown, text and gitcommit
- Snacks modules join picker and explorer:
  - `indent`, `scope`, `words`, `notifier`
  - `input`, `bigfile`, `quickfile`
  - `<leader>n` shows the notification history
- Where a treesitter parser starts, the FileType callback sets two things:
  - the nvim-treesitter `indentexpr`
  - `foldmethod=expr` with `vim.treesitter.foldexpr()`
- `foldlevel=99` and `foldtext=''` are set globally.
- Keys:
  - `]e`/`[e` and `]w`/`[w` jump to errors and warnings via `vim.diagnostic.jump({ count, severity })`
  - `<leader>u` toggles: `uf`/`uF` autoformat (buffer/global), `uh` inlay hints, `ud` diagnostics, `us` spell, `uw` wrap
- Format on save, organize imports included, skips while `vim.b.autoformat` or `vim.g.autoformat` is `false`.

### Acceptance criteria

- [x] `nvim --headless +'lua print(vim.o.timeoutlen, vim.o.laststatus, vim.o.jumpoptions, vim.o.spelllang)' +q` → `300 3 view en,de`
- [x] `nvim --headless +'lua local e = {} for _, a in ipairs(vim.api.nvim_get_autocmds({ group = "config" })) do e[a.event] = true end print(vim.iter(vim.tbl_keys(e)):join(" "))' +q` lists BufReadPost, BufWritePre, FileType, FocusGained, TermClose, TermLeave, TextYankPost
- [x] `d=$(mktemp -d) && nvim --headless +"w $d/a/b/c.txt" +q && test -f $d/a/b/c.txt` succeeds
- [x] `nvim --headless +'lua print(Snacks.config.indent.enabled, Snacks.config.words.enabled, Snacks.config.notifier.enabled)' +q` → `true true true`
- [x] `nvim --headless x.py +'lua print(vim.bo.indentexpr, vim.wo.foldmethod, vim.wo.foldlevel)' +q` → `v:lua.require'nvim-treesitter'.indentexpr() expr 99`
- [x] `nvim --headless +'lua for _, k in ipairs({"]e","[w","<Space>uf","<Space>uh","<Space>n"}) do print(k, vim.fn.maparg(k, "n") ~= "") end' +q` → all `true`
- [x] `nvim --headless +'lua for _, k in ipairs({"H","L","<C-H>","<M-j>","<Esc>"}) do print(k, vim.fn.maparg(k, "n") == "") end' +q` → all `true`
- [x] `d=$(mktemp -d) && printf '[project]\nname="t"\nversion="0"\n' > $d/pyproject.toml && printf 'x=1\n' > $d/f.py && nvim --headless $d/f.py +'sleep 2' +'let b:autoformat = v:false' +w +q && cat $d/f.py` → `x=1`; without the `let` → `x = 1`
- [x] `make check` passes

## Phase 2: Learning aids

**Depends on**: 1 (same file; `<leader>u` group)

### Context

- `dotfiles/nvim/init.lua — vim.pack.add()`, toggle keys — panel, precognition, hardtime, nui
- `dotfiles/nvim/cheatsheet.md` — new; the keys being learned
- `dotfiles/nvim/nvim-pack-lock.json` — three pins
- `guides/neovim.md — intro, plugin table, Keys, Verify` — plugin count 9; the panel and how to edit it
- `README.md — dotfiles table` — `init.lua` row names the plugins; new `cheatsheet.md` row

### What to build

- Learning panel:
  - On start, a non-focusable float in the top-right corner shows `cheatsheet.md`, about 40 columns wide.
  - It hides below 100 columns and re-places itself on VimResized.
  - `<leader>uk` toggles it.
- `cheatsheet.md` holds about 15 keys, one per line as `key  meaning`. The user edits it as keys stick. The first set:
  - Motions: `w`/`b`/`e`, `f`/`t` with `;`, `%`, `*`, `Ctrl-d`/`Ctrl-u`, `Ctrl-o`/`Ctrl-i`
  - Edits: `ciw`, `ci"`, `dap`, `.`, `o`/`O`, `gcc`, `>>`
  - Built-ins in place of shortcuts: `]b`/`[b`, `Ctrl-w h/j/k/l`, `Ctrl-l`, `:m +1`
- precognition shows motion hints from the cursor, visible at start. `<leader>up` toggles it.
- hardtime runs in block mode:
  - its `disabled_filetypes` adds the snacks picker and explorer list filetypes
  - `<leader>uH` toggles it
  - `:Hardtime report` opens through nui

### Acceptance criteria

- [x] `nvim --headless +'lua local n = 0 for _, w in ipairs(vim.api.nvim_list_wins()) do local c = vim.api.nvim_win_get_config(w) if c.relative ~= "" and not c.focusable then n = n + 1 end end print(n)' +q` → `1`
- [x] `nvim --headless +'lua print(require("hardtime.config").config.restriction_mode, pcall(require, "nui.popup"))' +q` → `block true`
- [x] `nvim --headless +'lua for _, k in ipairs({"<Space>uk","<Space>up","<Space>uH"}) do print(k, vim.fn.maparg(k, "n") ~= "") end' +q` → all `true`
- [x] `nvim --headless -c 'lua print(#vim.pack.get())' -c q` → `9`
- [x] `make check` passes

## Phase 3: Git, code text objects, file icons

**Depends on**: 2 (same files)

### Context

- `dotfiles/nvim/init.lua — vim.pack.add()`, git keys — gitsigns, textobjects, mini.icons
- `dotfiles/nvim/nvim-pack-lock.json` — three pins
- `scripts/setup-dev-machine.sh — APT_PACKAGES` — gains `lazygit`
- `guides/neovim.md — intro, plugin table, Keys, Verify` — plugin count 12
- `README.md — dotfiles/nvim/init.lua row` — names the plugins

### What to build

- gitsigns marks changed lines; `signcolumn` becomes `yes:2`.
  - `]h`/`[h` jump between hunks; `ih` is the hunk text object.
  - `<leader>ghs` stages, `<leader>ghr` resets, `<leader>ghp` previews.
  - `<leader>uG` toggles the signs.
- Snacks git keys: `<leader>gb` blames the line, `<leader>gB` opens the browser, `<leader>gg` opens lazygit.
- `setup-dev-machine.sh` installs `lazygit` from apt.
- Text objects: `af`/`if` function, `ac`/`ic` class, `aa`/`ia` argument.
  - `]f`/`[f` and `]c`/`[c` jump to function and class starts.
  - `selection_modes` makes the function and class outer objects linewise.
- mini.icons gives per-format icons in the explorer and picker. `MiniIcons.mock_nvim_web_devicons()` serves lualine.

### Acceptance criteria

- [x] `nvim --headless -c 'lua print(#vim.pack.get(), vim.o.signcolumn)' -c q` → `12 yes:2`
- [x] `d=$(mktemp -d) && git -C $d init -q && echo a > $d/f && git -C $d add f && git -C $d -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm i && echo b >> $d/f && nvim --headless $d/f +'sleep 1' +'lua print(vim.b.gitsigns_status)' +q` → `+1`
- [x] `printf 'def f():\n    return 1\n\nx = 2\n' > /tmp/t.py && nvim --headless /tmp/t.py +'normal 2Gdaf' +'lua print(vim.api.nvim_buf_line_count(0))' +'q!'` → `2`
- [x] `nvim --headless +'lua print(Snacks.util.icon("x.py", "file") ~= "󰈔 ", require("nvim-web-devicons").get_icon("x.ts", "ts") ~= nil)' +q` → `true true`
- [x] `nvim --headless +'lua for _, k in ipairs({"<Space>gg","<Space>gb","<Space>gB"}) do print(k, vim.fn.maparg(k, "n") ~= "") end' +q` → all `true`
- [x] `scripts/setup-dev-machine.sh --check | grep lazygit` reports it missing
- [x] `make check` passes
