# Plan: Close the useful LazyVim gaps in the Neovim config

> Source PRD: n/a

## Goal

Add the LazyVim behaviour that improves daily editing without leaving the lean `vim.pack` setup.
Options, autocmds, snacks modules, treesitter indent and folds, keymaps, a learning panel, and gitsigns.
Code text objects and lazygit follow. The goal behind every phase: learning Vim properly, with no shortcuts that hide the built-ins.

## Architectural decisions

- **Config shape**: `dotfiles/nvim/init.lua` stays the single config file. No `lua/` modules.
- **Keys**: no mapping replaces or shortcuts a built-in key; the user learns the built-ins. New keys only add what Vim lacks, with LazyVim's lhs where one exists. They reach `[`/`]` through the German-keyboard remaps.
- **Toggles**: `Snacks.toggle`. It sets each key's which-key label; the `<leader>u` (ui) and `<leader>g` (git) groups go into the which-key spec.
- **New plugins**: gitsigns.nvim, nvim-treesitter-textobjects (`main` branch), precognition.nvim, hardtime.nvim and nui.nvim. Nothing else.
- **Checks**: run every `nvim --headless` criterion as `XDG_CONFIG_HOME=$PWD/dotfiles nvim …` from the tree under work. `~/.config/nvim` links to the main clone, so a worktree would otherwise test the old config.
- **Out of scope**: screenkey.nvim, nvim-training, a learning-path guide section; mason, conform, nvim-lint, blink.cmp, trouble, todo-comments, bufferline, noice, dashboard, flash, mini.pairs, grug-far, persistence, lazydev.

## Inventory

- `dotfiles/nvim/init.lua — Editing section` — options
- `dotfiles/nvim/init.lua — require('snacks').setup()` — snacks modules
- `dotfiles/nvim/init.lua — FileType autocmd` — treesitter start; indent and folds go here
- `dotfiles/nvim/init.lua — LspAttach autocmd, BufWritePre callback` — format on save, gains the autoformat check
- `dotfiles/nvim/init.lua — keymap table after pick()` — picker keys; new keys go beside it
- `dotfiles/nvim/nvim-pack-lock.json` — plugin pins (choke file)
- `guides/neovim.md — intro, plugin table, Keys, Verify` — the plugin count, key table and `#vim.pack.get()` check
- `README.md — dotfiles/nvim/init.lua row` — names the plugins
- `scripts/setup-dev-machine.sh — APT_PACKAGES` — lazygit install (Phase 6)

## Resolved decisions

- `updatetime` stays at its default. snacks `words` has its own 200 ms debounce (`snacks/words.lua — config.debounce`).
- `wrap` stays on. The config is for prose too; LazyVim's `wrap=false` does not fit.
- `spelllang=en,de`; spell turns on only for markdown, text and gitcommit. Neovim offers the German spell file download on first use.
- No shortcuts over built-ins: no `<S-h>`/`<S-l>` (built-in `H`/`L`; buffers are `]b`/`[b`), no `<A-j>`/`<A-k>` (`:m`), no `<C-h/j/k/l>` (`Ctrl-w h/j/k/l`), no `<Esc>` hlsearch clear (`Ctrl-l`).
- Folds open by default: `foldlevel=99`, so treesitter folds never hide code on open.
- which-key cannot stay open while you edit: its popup reads the keys you type (`loop = true` holds it until `<Esc>`). The always-on hint is a separate non-focusable float.
- The learning panel is a float, shown on every start.
- `signcolumn=yes:2`, so a diagnostic sign and a git sign show side by side.
- hardtime runs in block mode. nui.nvim is loaded only by `:Hardtime report` (`hardtime/report.lua`), which counts the user's most frequent bad habits.
- lazygit comes from apt: Ubuntu 26.04 offers `lazygit` 0.57.

## Open questions / Risks

- nvim-treesitter `main` indentexpr is marked experimental upstream. If Python `o` indents wrongly, drop it for that language.

## Phase 1: Options and autocmds

**Depends on**: none

### Context

- `dotfiles/nvim/init.lua — Editing section` — options go here
- `guides/neovim.md — Verify` — gains one check

### What to build

- Options:
  - `timeoutlen=300`, `cursorline`, `splitright`, `splitbelow`
  - `laststatus=3`, `jumpoptions=view`, `virtualedit=block`, `smoothscroll`
- One `vim.api.nvim_create_augroup('config')` holding the autocmds:
  - highlight the yanked text with `vim.hl.on_yank()`
  - `:checktime` on FocusGained, TermClose and TermLeave
  - restore the last cursor position on BufReadPost, except for gitcommit
  - `q` closes help, qf, man and checkhealth buffers
  - BufWritePre creates missing parent directories
  - FileType markdown, text and gitcommit sets `spell` and `wrap`

### Acceptance criteria

- [ ] `nvim --headless +'lua print(vim.o.timeoutlen, vim.o.laststatus, vim.o.jumpoptions, vim.o.splitright)' +q` → `300 3 view true`
- [ ] `nvim --headless +'lua local e = {} for _, a in ipairs(vim.api.nvim_get_autocmds({ group = "config" })) do e[a.event] = true end print(vim.iter(vim.tbl_keys(e)):join(" "))' +q` lists BufReadPost, BufWritePre, FileType, FocusGained, TermClose, TermLeave, TextYankPost
- [ ] `d=$(mktemp -d) && nvim --headless +"w $d/a/b/c.txt" +q && test -f $d/a/b/c.txt` succeeds
- [ ] `make check` passes

## Phase 2: snacks modules, treesitter indent and folds

**Depends on**: 1 (same file)

### Context

- `dotfiles/nvim/init.lua — require('snacks').setup()` — gains the modules
- `dotfiles/nvim/init.lua — FileType autocmd` — gains indent and folds

### What to build

- Snacks setup enables these modules alongside picker and explorer:
  - `indent`, `scope`, `words`, `notifier`
  - `input`, `bigfile`, `quickfile`
- `<leader>n` opens the notification history.
- The FileType callback adds two things where a parser started:
  - `indentexpr` from nvim-treesitter
  - `foldmethod=expr` with `vim.treesitter.foldexpr()`
- `foldlevel=99` and `foldtext=''` are set globally.

### Acceptance criteria

- [ ] `nvim --headless +'lua print(Snacks.config.indent.enabled, Snacks.config.words.enabled, Snacks.config.notifier.enabled)' +q` → `true true true`
- [ ] `nvim --headless x.py +'lua print(vim.bo.indentexpr, vim.wo.foldmethod, vim.wo.foldlevel)' +q` → `v:lua.require'nvim-treesitter'.indentexpr() expr 99`
- [ ] `printf 'def f():\n    x = 1' > /tmp/i.py && nvim --headless /tmp/i.py +'normal! Gox' +'lua print(vim.fn.indent(3))' +'q!'` → `4`
- [ ] `make check` passes

## Phase 3: Keymaps and toggles

**Depends on**: 2 (same file; toggles need Snacks loaded)

### Context

- `dotfiles/nvim/init.lua — keymap table after pick()` — new keys go beside it
- `dotfiles/nvim/init.lua — LspAttach BufWritePre callback` — checks the autoformat flag
- `guides/neovim.md — Keys` — the key table

### What to build

- `]e`/`[e` and `]w`/`[w` jump to errors or warnings, through `vim.diagnostic.jump({ count, severity })`.
- The which-key spec gains `{ '<leader>u', group = 'ui' }`.
- Toggles in the `<leader>u` group: `uf` (buffer autoformat), `uF` (global autoformat), `uh` (inlay hints), `ud` (diagnostics), `us` (spell), `uw` (wrap).
- Format on save, organize imports included, is skipped while `vim.b.autoformat` or `vim.g.autoformat` is `false`.
- The guide's Keys table lists the new keys.

### Acceptance criteria

- [ ] `grep -c "'<leader>u', group = 'ui'" dotfiles/nvim/init.lua` → `1`
- [ ] `nvim --headless +'lua for _, k in ipairs({"]e","[w","<Space>uf","<Space>uh"}) do print(k, vim.fn.maparg(k, "n") ~= "") end' +q` → all `true`
- [ ] `nvim --headless +'lua for _, k in ipairs({"H","L","<C-H>","<M-j>","<Esc>"}) do print(k, vim.fn.maparg(k, "n") == "") end' +q` → all `true`
- [ ] `d=$(mktemp -d) && printf '[project]\nname="t"\nversion="0"\n' > $d/pyproject.toml && printf 'x=1\n' > $d/f.py && nvim --headless $d/f.py +'sleep 2' +'let b:autoformat = v:false' +w +q && cat $d/f.py` → `x=1`
- [ ] The same command without the `let` → `x = 1`
- [ ] `make check` passes

## Phase 4: Learning panel

**Depends on**: 3 (same file; `<leader>u` group)

### Context

- `dotfiles/nvim/init.lua — keymap and toggle section` — the panel and its toggle
- `dotfiles/nvim/cheatsheet.md` — new; the keys being learned
- `README.md — dotfiles table` — new row for the cheat sheet
- `guides/neovim.md — Keys` — names the panel and how to edit it

### What to build

- On start, a non-focusable float in the top-right corner shows `cheatsheet.md`.
  It is about 40 columns wide and as tall as the file; it never takes the cursor or keys.
- `<leader>uk` toggles it through `Snacks.toggle`. It hides in windows narrower than 100 columns and re-places itself on VimResized.
- `cheatsheet.md` holds about 15 keys, one per line as `key  meaning`. The user edits it as keys stick. The first set:
  - Motions: `w`/`b`/`e`, `f`/`t` with `;`, `%`, `*`, `Ctrl-d`/`Ctrl-u`, `Ctrl-o`/`Ctrl-i`
  - Edits: `ciw`, `ci"`, `dap`, `.`, `o`/`O`, `gcc`, `>>`
  - Built-ins in place of shortcuts: `]b`/`[b`, `Ctrl-w h/j/k/l`, `Ctrl-l`, `:m +1`
- Markdown highlighting in the float comes from the existing treesitter parser.

### Acceptance criteria

- [ ] `nvim --headless +'lua local n = 0 for _, w in ipairs(vim.api.nvim_list_wins()) do local c = vim.api.nvim_win_get_config(w) if c.relative ~= "" and not c.focusable then n = n + 1 end end print(n)' +q` → `1`
- [ ] `nvim --headless +'lua print(vim.fn.maparg("<Space>uk", "n") ~= "")' +q` → `true`
- [ ] `grep -c 'cheatsheet.md' README.md` → `1`
- [ ] `make check` passes

## Phase 5: Git signs, hunks and blame

**Depends on**: 4 (same file)

### Context

- `dotfiles/nvim/init.lua — vim.pack.add()` — gains gitsigns.nvim
- `dotfiles/nvim/nvim-pack-lock.json` — new pin
- `guides/neovim.md — intro, plugin table, Keys, Verify` — "Six plugins" becomes seven; `#vim.pack.get()` → 7
- `README.md — dotfiles/nvim/init.lua row` — gains gitsigns

### What to build

- gitsigns shows changed lines in the sign column; `signcolumn` becomes `yes:2`.
- Hunk keys:
  - `]h`/`[h` jump between hunks
  - `<leader>ghs` stages, `<leader>ghr` resets, `<leader>ghp` previews
  - `ih` is the hunk text object
- Snacks git keys: `<leader>gb` blames the line; `<leader>gB` opens the file in the browser.
- `<leader>uG` toggles the signs.
- The which-key spec gains the `<leader>g` group.

### Acceptance criteria

- [ ] `nvim --headless -c 'lua print(#vim.pack.get(), vim.o.signcolumn)' -c q` → `7 yes:2`
- [ ] `d=$(mktemp -d) && git -C $d init -q && echo a > $d/f && git -C $d add f && git -C $d -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm i && echo b >> $d/f && nvim --headless $d/f +'sleep 1' +'lua print(vim.b.gitsigns_status)' +q` → `+1`
- [ ] `grep -c gitsigns dotfiles/nvim/nvim-pack-lock.json` → `2`
- [ ] `make check` passes

## Phase 6: Code text objects

**Depends on**: 5 (same file and lockfile)

### Context

- `dotfiles/nvim/init.lua — vim.pack.add()` — gains nvim-treesitter-textobjects, `main` branch
- `dotfiles/nvim/nvim-pack-lock.json` — new pin
- `guides/neovim.md — plugin table, Keys, Verify` — count becomes eight
- `README.md — dotfiles/nvim/init.lua row` — gains text objects

### What to build

- `af`/`if` select a function, `ac`/`ic` a class, `aa`/`ia` an argument.
- `selection_modes` makes `@function.outer` and `@class.outer` linewise (`V`), so `daf` leaves no empty line.
- `]f`/`[f` move between function starts; `]c`/`[c` move between class starts outside diff mode.

### Acceptance criteria

- [ ] `printf 'def f():\n    return 1\n\nx = 2\n' > /tmp/t.py && nvim --headless /tmp/t.py +'normal 2Gdaf' +'lua print(vim.api.nvim_buf_line_count(0))' +'q!'` → `2`
- [ ] `nvim --headless -c 'lua print(#vim.pack.get())' -c q` → `8`
- [ ] `make check` passes

## Phase 7: lazygit

**Depends on**: 6 (same files)

### Context

- `scripts/setup-dev-machine.sh — APT_PACKAGES` — gains `lazygit`
- `dotfiles/nvim/init.lua — git keys` — gains `<leader>gg`
- `guides/neovim.md — Keys` — one row

### What to build

- `setup-dev-machine.sh` installs `lazygit` from apt.
- `<leader>gg` opens `Snacks.lazygit()` at the repo root.

### Acceptance criteria

- [ ] `scripts/setup-dev-machine.sh --check | grep lazygit` reports it missing; the `sudo` install is a manual step
- [ ] `nvim --headless +'lua print(vim.fn.maparg("<Space>gg", "n") ~= "")' +q` → `true`
- [ ] `make check` passes

## Phase 8: Learning plugins

**Depends on**: 7 (same files)

### Context

- `dotfiles/nvim/init.lua — vim.pack.add()` — gains precognition.nvim, hardtime.nvim, nui.nvim
- `dotfiles/nvim/nvim-pack-lock.json` — three pins
- `guides/neovim.md — intro, plugin table, Verify` — count becomes eleven
- `README.md — dotfiles/nvim/init.lua row` — names the learning plugins

### What to build

- precognition shows motion hints from the cursor, visible at start. `<leader>up` toggles it.
- hardtime runs in block mode with its defaults: repeats past `max_count`, arrow keys and the mouse are blocked; hints name the better motion.
- hardtime's `disabled_filetypes` adds the snacks picker and explorer list filetypes, so scrolling a picker list is never blocked.
- `<leader>uH` toggles hardtime. `:Hardtime report` opens the habit report through nui.
- `:checkhealth` shows no error for any of the three.

### Acceptance criteria

- [ ] `nvim --headless -c 'lua print(#vim.pack.get())' -c q` → `11`
- [ ] `nvim --headless +'lua print(require("hardtime.config").config.restriction_mode)' +q` → `block`
- [ ] `nvim --headless +'lua print(vim.fn.maparg("<Space>up", "n") ~= "", vim.fn.maparg("<Space>uH", "n") ~= "")' +q` → `true true`
- [ ] `nvim --headless +'lua require("nui.popup")' +q` exits without error
- [ ] `make check` passes
