# Neovim

Neovim for prose and code: Markdown, YAML and JSON, plus TypeScript and Python with LSP.
Twelve plugins on the built-in `vim.pack`; everything else is a Neovim built-in.

- [dotfiles/nvim/init.lua](../dotfiles/nvim/init.lua) is the whole config; it sets only non-defaults.
- [dotfiles/nvim/nvim-pack-lock.json](../dotfiles/nvim/nvim-pack-lock.json) pins each plugin's revision.
- [scripts/install-dotfiles.sh](../scripts/install-dotfiles.sh) links the directory to `~/.config/nvim`.

| Plugin | Role |
| --- | --- |
| tokyonight | Colour scheme, `night` style |
| snacks.nvim | File, grep and LSP picker; file explorer |
| which-key | Shows the keys that follow a typed prefix |
| lualine | Status line |
| nvim-lspconfig | Server configs that `vim.lsp.enable` starts |
| nvim-treesitter | Builds parsers for highlighting, indent and folds |
| precognition.nvim | Shows the motions reachable from the cursor |
| hardtime.nvim | Blocks a key repeated too often and names the better motion |
| nui.nvim | Popup for `:Hardtime report` |
| gitsigns.nvim | Marks changed lines; stages, resets and previews hunks |
| nvim-treesitter-textobjects | Function, class and argument text objects and jumps |
| mini.icons | File-type icons for the explorer, picker and status line |

| Language | Servers |
| --- | --- |
| TypeScript, JavaScript | `tsc` (TypeScript 7), Biome, oxlint, oxfmt |
| Python | ruff, ty |
| Shell, YAML, JSON | bashls, yamlls, jsonls |

Completion is `vim.lsp.completion` with autotrigger. ruff, Biome and oxfmt format on save; ruff and Biome also sort imports.
Diagnostic messages show at the end of their line.
Biome, oxlint and oxfmt come from the project's `node_modules` and attach only where it configures them.

On an Ubuntu desktop, [setup-dev-machine.sh](../scripts/setup-dev-machine.sh) does Steps 1–3.
It installs the Neovim snap, the servers, the tree-sitter CLI, `xclip`, a Nerd Font and the parsers.
The steps below are for Debian and servers.

## Prerequisites

- The latest Neovim release; `vim.pack` needs 0.12. apt lags a major version behind and is not used.
- The handbook cloned and [`install.sh`](../install.sh) run. It is idempotent; re-run it when the clone predates the Neovim link.
- Node with an npm prefix of `~/.local`, uv, and a C compiler (`build-essential`).
- A desktop clipboard needs `xclip`; the clipboard comment in [dotfiles/nvim/init.lua](../dotfiles/nvim/init.lua) says why.
- A Nerd Font where the terminal renders, for picker and status line icons. The symbols-only one is enough.

## Steps

1. **Install Neovim.** The pre-built tarball, unpacked into `~/.local` — no sudo.

   ```bash
   curl -fsSLO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
   rm -rf ~/.local/nvim-linux-x86_64 && tar -C ~/.local -xzf nvim-linux-x86_64.tar.gz
   ln -sfn ~/.local/nvim-linux-x86_64/bin/nvim ~/.local/bin/nvim && rm nvim-linux-x86_64.tar.gz
   ```

   The tarball does not refresh itself; the [release page](https://github.com/neovim/neovim/releases/latest)
   shows when a re-run is due. Source: [INSTALL.md](https://github.com/neovim/neovim/blob/master/INSTALL.md).

2. **Install the language servers and the tree-sitter CLI.** The global TypeScript 7 serves
   projects that pin an older one, since only 7 has `tsc --lsp`.

   ```bash
   uv tool install ruff && uv tool install ty
   npm install -g --allow-scripts=tree-sitter-cli typescript bash-language-server \
     yaml-language-server vscode-langservers-extracted tree-sitter-cli
   ```

   tree-sitter-cli's install script fetches its binary, so npm must allow it.

3. **Start Neovim once.** `vim.pack` clones the plugins at the lockfile's revisions,
   then nvim-treesitter builds ten parsers in the background.

   ```bash
   nvim
   ```

4. **Update plugins.** `vim.pack.update()` opens a review tab; `:write` applies it.
   An nvim-treesitter update rebuilds the parsers. Commit the changed lockfile.

   ```bash
   nvim +'lua vim.pack.update()'
   git -C <clone> commit -m 'chore(nvim): update plugins' dotfiles/nvim/nvim-pack-lock.json
   ```

## Keys

The leader is Space. LSP keys are Neovim's defaults (`:help lsp-defaults`).
Plugin management: [`:help vim.pack`](https://neovim.io/doc/user/pack.html).

| Press | Does |
| --- | --- |
| `<Space><Space>` / `<Space>/` / `<Space>,` | Find files / grep / buffers |
| `<Space>fr` / `<Space>e` | Recent files / file explorer |
| `<Space>sh` / `<Space>sk` | Help pages / keymaps |
| `<Space>sd` / `<Space>ss` | Diagnostics / LSP symbols |
| `gd` / `grr` / `gri` | Definition / references / implementations |
| `K` / `grn` / `gra` | Hover / rename / code action |
| `]d` / `[d` | Next / previous diagnostic |
| `]e` / `[e`, `]w` / `[w` | Next / previous error, warning |
| `<Space>u` + `f` `F` `h` `d` `s` `w` | Toggle autoformat (buffer, global), inlay hints, diagnostics, spell, wrap |
| `<Space>n` | Notification history |
| `<Space>u` + `k` `p` `H` `G` | Toggle cheat sheet, motion hints, hardtime, git signs |
| `]h` / `[h`, `ih` | Next / previous hunk, hunk text object |
| `<Space>gh` + `s` `r` `p` | Stage / reset / preview hunk |
| `<Space>gb` / `<Space>gB` / `<Space>gg` | Blame line / open in browser / lazygit |
| `af` `if`, `ac` `ic`, `aa` `ia` | Function, class, argument text objects |
| `]f` / `[f`, `]c` / `[c` | Next / previous function, class (`]c` is the next change in diff mode) |
| `Ctrl-Y` / `Ctrl-E` | Accept / dismiss a completion |

The cheat sheet in the top-right corner is [dotfiles/nvim/cheatsheet.md](../dotfiles/nvim/cheatsheet.md).
Replace a line once its key sticks; the float picks the change up on the next start.
`:Hardtime report` lists the habits hardtime blocked most.

## German keyboard

`[ ] { } /` sit behind AltGr or Shift. The config moves them to the umlaut keys in Normal,
Visual and Operator-pending mode. Insert mode and `f`, `t`, `r` still get the umlaut.
The mechanism is the German-keyboard comment in [dotfiles/nvim/init.lua](../dotfiles/nvim/init.lua).

| Press       | Acts as             | Example                                                   |
| ----------- | ------------------- | --------------------------------------------------------- |
| `ö` / `ä`   | `[` / `]`           | `diö` deletes inside brackets; `ö<Space>` adds a blank line above |
| `Ö` / `Ä`   | `{` / `}`           | `Ä` jumps a paragraph down; `dÄ` deletes to the paragraph end |
| `ß`         | `/`                 | `ßword` searches for word                                 |
| `0` or `_`  | instead of `^`      | `^` is a dead key on `de`                                 |
| `'a`        | instead of `` `a `` | the backtick is a dead key on `de`                        |
| `Ctrl-6`    | `Ctrl-^`            | previous file                                             |
| `K` in help | `Ctrl-]`            | follows the help tag under the cursor                     |

Sources: [`:help 'langmap'`](https://neovim.io/doc/user/options.html#'langmap'),
[`:help CTRL-^`](https://neovim.io/doc/user/editing.html#CTRL-%5E),
[Vim Tips Wiki: map extra keys on non-US keyboards](https://web.archive.org/web/2023/https://vim.fandom.com/wiki/Map_extra_keys_on_non_US_keyboards).

## Verify

`<py>` is a Python file in a uv project; `<ts>` is a TypeScript file in an npm project with Biome.

```bash
readlink -f ~/.config/nvim                                           # → <clone>/dotfiles/nvim
nvim --headless -c 'lua print(vim.g.colors_name, #vim.pack.get())' -c q   # → tokyonight-night 12
nvim --headless -c 'lua print(vim.fn.maparg("<Space><Space>", "n") ~= "")' -c q   # → true
nvim --headless -c 'lua print(vim.o.shiftwidth, vim.o.clipboard)' -c q   # → 2 unnamedplus (desktop) / 2 (server)
nvim --headless x.py +'lua print(vim.wo.foldmethod, vim.fn.maparg("]e", "n") ~= "")' +q   # → expr true
nvim --headless <py> +'sleep 3' +'lua print(vim.iter(vim.lsp.get_clients({bufnr=0})):map(function(c) return c.name end):join(","))' +q   # → ruff,ty
nvim --headless <ts> +'sleep 3' +'lua print(vim.iter(vim.lsp.get_clients({bufnr=0})):map(function(c) return c.name end):join(","))' +q   # → biome,tsc
nvim --headless x.py +'lua print(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil)' +q   # → true
d=$(mktemp -d) && printf 'x=1\n' > "$d/f.py" && nvim --headless "$d/f.py" +'sleep 2' +w +q && cat "$d/f.py"   # → x = 1
```
