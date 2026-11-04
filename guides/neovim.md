# Neovim

Neovim for prose and code: Markdown, YAML and JSON, plus TypeScript, Python and Go with LSP.
Eleven plugins on the built-in `vim.pack`; everything else is a Neovim built-in.

- [dotfiles/nvim/init.lua](../dotfiles/nvim/init.lua) is the config; it sets only non-defaults.
- [dotfiles/nvim/nvim-pack-lock.json](../dotfiles/nvim/nvim-pack-lock.json) pins each plugin's revision.
- [dotfiles/nvim/parsers.txt](../dotfiles/nvim/parsers.txt) lists the tree-sitter parsers to build.
- [scripts/install-dotfiles.sh](../scripts/install-dotfiles.sh) links the directory to `~/.config/nvim`.

| Plugin | Role |
| --- | --- |
| catppuccin | Colour scheme: Mocha with darker, less blue backgrounds |
| snacks.nvim | File, grep and LSP picker; file explorer |
| which-key | Shows the keys that follow a typed prefix |
| lualine | Status line |
| nvim-lspconfig | Server configs that `vim.lsp.enable` starts |
| nvim-treesitter | Builds parsers for highlighting, indent and folds |
| hardtime.nvim | Blocks a key repeated too often and names the better motion |
| nui.nvim | Popup for `:Hardtime report` |
| gitsigns.nvim | Marks changed lines; stages, resets and previews hunks |
| nvim-treesitter-textobjects | Function, class and argument text objects and jumps |
| mini.icons | File-type icons for the explorer, picker and status line |

| Language | Servers |
| --- | --- |
| TypeScript, JavaScript | `tsc` (TypeScript 7), oxlint |
| Python | ruff, ty |
| Go | gopls, installed with `go install golang.org/x/tools/gopls@latest` |
| Shell, YAML, JSON | bashls, yamlls, jsonls |
| Markdown | marksman |

- Completion is `vim.lsp.completion` with autotrigger.
- Diagnostic messages show at the end of their line.
- `<leader>cf` and every save format the buffer. ruff and gopls format where they attach; both also sort imports.
- Elsewhere prettier formats JSON, YAML, Markdown, CSS, HTML, TypeScript and JavaScript, unsaved buffers included.
- oxlint comes from the project's `node_modules` and attaches only where the project configures it.

On a dev machine, [setup-dev-machine.sh](../scripts/setup-dev-machine.sh) does Steps 1–3 and installs `xclip` and a Nerd Font.
It takes Neovim from the snap on Ubuntu and Step 1's tarball on Debian. The steps below are for servers.

## Prerequisites

- The latest Neovim release; `vim.pack` needs 0.12. apt lags a major version behind and is not used.
- The handbook cloned and [`install.sh`](../install.sh) run.
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

2. **Install the language servers and the tree-sitter CLI.** Only TypeScript 7 has `tsc --lsp`,
   so the global one serves projects that pin an older one. npm must allow tree-sitter-cli's install script, which fetches its binary.
   marksman has no package; take its release binary, not the snap, which cannot read `~/.config/marksman`.

   ```bash
   uv tool install ruff && uv tool install ty
   npm install -g --allow-scripts=tree-sitter-cli typescript bash-language-server \
     yaml-language-server vscode-langservers-extracted prettier tree-sitter-cli
   curl -fsSL https://github.com/artempyanykh/marksman/releases/latest/download/marksman-linux-x64 \
     -o ~/.local/bin/marksman && chmod +x ~/.local/bin/marksman
   ```

3. **Start Neovim once.** `vim.pack` clones the plugins at the lockfile's revisions,
   then nvim-treesitter builds the parsers in `parsers.txt` in the background.

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
| `<Space>fr` / `<Space>e` / `<Space>sh` / `<Space>sk` | Recent files / file explorer / help pages / keymaps |
| `<Space>sd` / `<Space>ss` | Diagnostics / LSP symbols |
| `gd` / `grr` / `gri` | Definition / references / implementations |
| `K` / `grn` / `gra` | Hover / rename / code action |
| `]d` / `[d`, `]e` / `[e`, `]w` / `[w` | Next / previous diagnostic, error, warning |
| `<Space>u` + `f` `F` `h` `d` `s` `w` `k` `H` `G` | Toggle autoformat (buffer, global), inlay hints, diagnostics, spell, wrap, cheat sheet, hardtime, git signs |
| `<Space>n` | Notification history |
| `]h` / `[h`, `ih` | Next / previous hunk, hunk text object |
| `<Space>gh` + `s` `r` `p` | Stage / reset / preview hunk |
| `<Space>gb` / `<Space>gB` / `<Space>gg` | Blame line / open in browser / lazygit |
| `af` `if`, `ac` `ic`, `aa` `ia` | Function, class, argument text objects |
| `]f` / `[f`, `]c` / `[c` | Next / previous function, class (`]c` is the next change in diff mode) |
| `Ctrl-Y` / `Ctrl-E` | Accept / dismiss a completion |

The cheat sheet down the right edge is [dotfiles/nvim/cheatsheet.md](../dotfiles/nvim/cheatsheet.md).
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
| `0` or `_`, `'a` | instead of `^`, `` `a `` | `^` and the backtick are dead keys on `de`       |
| `Ctrl-6`    | `Ctrl-^`            | previous file                                             |
| `K` in help | `Ctrl-]`            | follows the help tag under the cursor                     |

Sources: [`:help 'langmap'`](https://neovim.io/doc/user/options.html#'langmap'), [`:help CTRL-^`](https://neovim.io/doc/user/editing.html#CTRL-%5E),
[Vim Tips Wiki: map extra keys on non-US keyboards](https://web.archive.org/web/2023/https://vim.fandom.com/wiki/Map_extra_keys_on_non_US_keyboards).

## Verify

`<py>` is a Python file in a uv project; `<ts>` is a TypeScript file in an npm project.

```bash
readlink -f ~/.config/nvim                                           # → <clone>/dotfiles/nvim
nvim --headless -c 'lua print(vim.g.colors_name, #vim.pack.get(), vim.fn.maparg("<Space><Space>", "n") ~= "", vim.o.shiftwidth, vim.o.clipboard)' -c q
# → catppuccin-mocha 11 true 2 unnamedplus (desktop) / catppuccin-mocha 11 true 2 (server)
nvim --headless x.py +'lua print(vim.wo.foldmethod, vim.fn.maparg("]e", "n") ~= "", vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil)' +q   # → expr true true
nvim --headless <py> +'sleep 3' +'lua print(vim.iter(vim.lsp.get_clients({bufnr=0})):map(function(c) return c.name end):join(","))' +q   # → ruff,ty
nvim --headless <ts> +'sleep 3' +'lua print(vim.iter(vim.lsp.get_clients({bufnr=0})):map(function(c) return c.name end):join(","))' +q   # → tsc
d=$(mktemp -d) && printf 'x=1\n' > "$d/f.py" && nvim --headless "$d/f.py" +'sleep 2' +w +q && cat "$d/f.py"   # → x = 1
```
