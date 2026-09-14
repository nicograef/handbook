# Neovim

Minimal Neovim for prose, Markdown, YAML and JSON: one config file, no plugins, no IDE layer.

- [templates/init.lua](../templates/init.lua) is the whole config; it sets only non-defaults.
- [scripts/install-dotfiles.sh](../scripts/install-dotfiles.sh) links it to `~/.config/nvim/init.lua`.
- Distributions (kickstart, LazyVim, NvChad, AstroNvim) ship LSP and completion machinery
  that text editing never uses.

## Prerequisites

- The latest Neovim release, from [github.com/neovim/neovim/releases](https://github.com/neovim/neovim/releases/latest).
  apt lags a major version behind (Debian 13 ships 0.10) and is not used.
- The handbook cloned and [`install.sh`](../install.sh) run — [bootstrap.md](bootstrap.md#new-dev-machine).
- A desktop clipboard needs `xclip`; the clipboard comment in [templates/init.lua](../templates/init.lua) says why.

## Steps

1. **Install.** Ubuntu desktop: the classic snap ships the latest release and refreshes
   itself. Debian and servers: the pre-built tarball from the release page, unpacked into
   `~/.local` — no sudo, and `~/.local/bin` precedes `/usr/bin` on `PATH`. Never the apt
   package beside the snap: `/usr/bin` precedes `/snap/bin`, so apt would shadow it.

   ```bash
   sudo snap install nvim --classic && sudo apt install xclip   # Ubuntu desktop

   # Debian desktop (add `sudo apt install xclip`) and servers; re-run to update
   curl -fsSLO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
   rm -rf ~/.local/nvim-linux-x86_64 && tar -C ~/.local -xzf nvim-linux-x86_64.tar.gz
   ln -sfn ~/.local/nvim-linux-x86_64/bin/nvim ~/.local/bin/nvim && rm nvim-linux-x86_64.tar.gz
   ```

   The tarball does not refresh itself; the [release page](https://github.com/neovim/neovim/releases/latest)
   shows when a re-run is due. Source: [INSTALL.md](https://github.com/neovim/neovim/blob/master/INSTALL.md).

2. **Link the config.** Run `./install.sh` from the handbook clone; it is idempotent, so re-run it when the clone predates the link.

3. **Check the providers.** A desktop lists `xclip`; a server reports no tool, which is expected.

   ```bash
   nvim +'checkhealth vim.provider'
   ```

4. **Start the tutorial.**

   ```bash
   nvim +Tutor
   ```

## German keyboard

`[ ] { } /` sit behind AltGr or Shift. The config moves them to the umlaut keys in Normal,
Visual and Operator-pending mode. Insert mode and `f`, `t`, `r` still get the umlaut.
The mechanism is the German-keyboard comment in [templates/init.lua](../templates/init.lua).

| Press       | Acts as             | Example                                                   |
| ----------- | ------------------- | --------------------------------------------------------- |
| `ö` / `ä`   | `[` / `]`           | `diö` deletes inside brackets; `ö<Space>` adds a blank line above |
| `Ö` / `Ä`   | `{` / `}`           | `Ä` jumps a paragraph down; `dÄ` deletes to the paragraph end |
| `ß`         | `/`                 | `ßword` searches for word                                 |
| `0` or `_`  | instead of `^`      | `^` is a dead key on `de`                                 |
| `'a`        | instead of `` `a `` | the backtick is a dead key on `de`                        |
| `Ctrl-6`    | `Ctrl-^`            | previous file                                             |
| `K` in help | `Ctrl-]`            | follows the help tag under the cursor                     |

Alternative — switch the layout to **German (US)**: the US layout with umlauts on AltGr+u/o/a
and eszett on AltGr+s. Every Vim key then sits in its US position, dead keys included.

```bash
gsettings set org.gnome.desktop.input-sources sources "[('xkb','de+us'),('xkb','de')]"   # Super+Space toggles
gsettings set org.gnome.desktop.input-sources sources "[('xkb','de')]"                    # revert
```

Sources: [`:help 'langmap'`](https://neovim.io/doc/user/options.html#'langmap'),
[`:help CTRL-^`](https://neovim.io/doc/user/editing.html#CTRL-%5E),
[Vim Tips Wiki: map extra keys on non-US keyboards](https://web.archive.org/web/2023/https://vim.fandom.com/wiki/Map_extra_keys_on_non_US_keyboards).

## Optional

| Change                     | Command                                                                              | Trade-off                                          |
| -------------------------- | ------------------------------------------------------------------------------------ | -------------------------------------------------- |
| Caps Lock as Esc           | `gsettings set org.gnome.desktop.input-sources xkb-options "['caps:escape']"`        | System-wide                                        |
| Commit messages in Neovim  | `git config --global core.editor nvim`                                               | Daily practice; `install.sh` resets it to `nano`   |

## Plugins

Later, one `git clone` each into Neovim's package path — no plugin manager
([`:help packages`](https://neovim.io/doc/user/repeat.html#packages)).
The config calls `setup()` for each one it finds.

```bash
P=~/.local/share/nvim/site/pack/plugins/start
git clone https://github.com/tris203/precognition.nvim "$P/precognition.nvim"   # motion hints
git clone https://github.com/MunifTanjim/nui.nvim      "$P/nui.nvim"            # hardtime dependency
git clone https://github.com/m4xshen/hardtime.nvim     "$P/hardtime.nvim"       # blocks key repeats

git -C "$P/precognition.nvim" pull                                              # update
```

## Verify

```bash
nvim --version | head -1                                             # → the tag of the latest release
readlink -f ~/.config/nvim/init.lua                                  # → <clone>/templates/init.lua
nvim --headless -c 'lua print(vim.o.shiftwidth, vim.o.clipboard)' -c q   # → 2 unnamedplus (desktop) / 2 (server)
nvim +'checkhealth vim.provider'                                     # Clipboard: xclip (desktop)
```
