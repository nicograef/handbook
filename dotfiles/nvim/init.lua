-- init.lua – Neovim for prose and code on vim.pack: tokyonight, snacks picker and explorer,
-- which-key, lualine. Install and use: guides/neovim.md.
-- Only non-defaults are set: `:help nvim-defaults` lists what is already on.

-- ── Editing ──────────────────────────────────────────────────────────────────
vim.o.number = true
vim.o.relativenumber = true      -- the count for motions like 5j / 3dd is visible
vim.o.scrolloff = 5
vim.o.confirm = true             -- :q on unsaved changes asks instead of erroring
vim.o.linebreak = true           -- wrap at word boundaries
vim.o.breakindent = true         -- wrapped lines keep their indent
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.undofile = true            -- undo history survives closing the file
if vim.fn.executable('rg') == 1 then
  vim.o.grepprg = 'rg --vimgrep'   -- the default adds -uu, which searches ignored files
end

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
-- OSC 52 by itself, but only while 'clipboard' stays unset. Ptyxis ignores OSC 52,
-- so a yank over SSH from Ptyxis never reaches the desktop clipboard.
if vim.env.DISPLAY and vim.fn.executable('xclip') == 1 then
  vim.g.clipboard = 'xclip'
  vim.o.clipboard = 'unnamedplus'
end

-- ── German keyboard (xkb de) ─────────────────────────────────────────────────
-- 'langmap' covers built-in commands and text objects (diö = di[); the keymaps cover
-- mapped commands such as [<Space>, hence remap = true. f, t, r and marks still take
-- the literal umlaut, and Insert mode is untouched. Key table: guides/neovim.md.
local de = { ['ö'] = '[', ['ä'] = ']', ['Ö'] = '{', ['Ä'] = '}', ['ß'] = '/' }
local from, to = '', ''
for lhs, rhs in pairs(de) do
  from, to = from .. lhs, to .. rhs
  vim.keymap.set({ 'n', 'x', 'o' }, lhs, rhs, { remap = true })
end
vim.o.langmap = from .. ';' .. to

-- ── Plugins ──────────────────────────────────────────────────────────────────
-- vim.pack installs on first start and pins revisions in nvim-pack-lock.json beside
-- this file; vim.pack.update() updates them. Keys follow LazyVim for these plugins.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.pack.add({
  'https://github.com/folke/tokyonight.nvim',
  'https://github.com/folke/snacks.nvim',
  'https://github.com/folke/which-key.nvim',
  'https://github.com/nvim-lualine/lualine.nvim',
})

vim.cmd.colorscheme('tokyonight-moon')
require('snacks').setup({ picker = {}, explorer = {} })
require('which-key').setup({
  spec = { { '<leader>f', group = 'file' }, { '<leader>s', group = 'search' } },
})
require('lualine').setup()

local pick = function(name) return function() Snacks.picker[name]() end end
for lhs, map in pairs({
  ['<leader><space>'] = { pick('files'), 'Find files' },
  ['<leader>/'] = { pick('grep'), 'Grep' },
  ['<leader>,'] = { pick('buffers'), 'Buffers' },
  ['<leader>fr'] = { pick('recent'), 'Recent files' },
  ['<leader>e'] = { function() Snacks.explorer() end, 'Explorer' },
  ['<leader>sh'] = { pick('help'), 'Help pages' },
  ['<leader>sk'] = { pick('keymaps'), 'Keymaps' },
  ['<leader>sd'] = { pick('diagnostics'), 'Diagnostics' },
  ['<leader>ss'] = { pick('lsp_symbols'), 'LSP symbols' },
  gd = { pick('lsp_definitions'), 'Go to definition' },
}) do
  vim.keymap.set('n', lhs, map[1], { desc = map[2] })
end
