-- init.lua – minimal Neovim for prose, Markdown, YAML and JSON. Latest Neovim release.
-- scripts/install-dotfiles.sh links it to ~/.config/nvim/init.lua; guides/neovim.md
-- covers install and use. Only non-defaults are set: `:help nvim-defaults` lists what
-- is already on (syntax, filetype detection, incsearch, hlsearch, mouse, editorconfig).

-- ── Editing ──────────────────────────────────────────────────────────────────
vim.o.number = true
vim.o.relativenumber = true      -- the count for motions like 5j / 3dd is visible
vim.o.scrolloff = 5
vim.o.confirm = true             -- :q on unsaved changes asks instead of erroring
vim.o.linebreak = true           -- wrap at word boundaries
vim.o.breakindent = true         -- wrapped lines keep their indent
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.grepprg = "rg --vimgrep"
vim.o.grepformat = "%f:%l:%c:%m"
vim.o.undofile = true            -- undo history survives closing the file

-- ── Indentation: two spaces, as in .editorconfig ─────────────────────────────
vim.o.expandtab = true
vim.o.shiftwidth = 2
vim.o.softtabstop = 2
vim.o.tabstop = 2
vim.g.markdown_recommended_style = 0   -- the Markdown ftplugin would force 4 spaces

-- ── Providers ────────────────────────────────────────────────────────────────
-- Remote-plugin hosts for Node, Perl, Python and Ruby; unused here, and each one
-- would otherwise raise a :checkhealth warning.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- ── Clipboard ────────────────────────────────────────────────────────────────
-- y and p use the system clipboard. On GNOME Wayland the tool is xclip through
-- XWayland: wl-copy must open a hidden window there, which steals focus and raises
-- a "wl-clipboard is ready" notification on every yank. Over SSH, Neovim picks
-- OSC 52 by itself, but only while 'clipboard' stays unset.
if vim.env.DISPLAY and vim.fn.executable('xclip') == 1 then
  vim.g.clipboard = 'xclip'
  vim.o.clipboard = 'unnamedplus'
end

-- ── German keyboard (xkb de) ─────────────────────────────────────────────────
-- [ ] { } / sit behind AltGr or Shift; the umlaut keys are free in Normal mode and
-- take over. 'langmap' covers built-in commands and text objects (diö = di[); the
-- keymaps cover mapped commands such as [<Space>, hence remap = true. f, t, r and
-- marks still take the literal umlaut, and Insert mode is untouched.
local de = { ['ö'] = '[', ['ä'] = ']', ['Ö'] = '{', ['Ä'] = '}', ['ß'] = '/' }
local from, to = '', ''
for lhs, rhs in pairs(de) do
  from, to = from .. lhs, to .. rhs
  vim.keymap.set({ 'n', 'x', 'o' }, lhs, rhs, { remap = true })
end
vim.o.langmap = from .. ';' .. to

-- ── Plugins ──────────────────────────────────────────────────────────────────
-- Loaded when cloned into ~/.local/share/nvim/site/pack/plugins/start/
-- (guides/neovim.md → Plugins); absent plugins are skipped.
for _, name in ipairs({ 'precognition', 'hardtime' }) do
  local ok, plugin = pcall(require, name)
  if ok then plugin.setup() end
end
