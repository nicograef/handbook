-- init.lua – Neovim for prose and code on vim.pack: tokyonight, snacks picker and explorer,
-- which-key, lualine; LSP with built-in completion and format on save, treesitter highlighting.
-- Install and use: guides/neovim.md.
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

-- Parsers must match nvim-treesitter's revision, so an update rebuilds them.
vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    if ev.data.spec.name == 'nvim-treesitter' and ev.data.kind == 'update' then
      if not ev.data.active then vim.cmd.packadd('nvim-treesitter') end
      vim.cmd('TSUpdate')
    end
  end,
})

vim.pack.add({
  'https://github.com/folke/tokyonight.nvim',
  'https://github.com/folke/snacks.nvim',
  'https://github.com/folke/which-key.nvim',
  'https://github.com/nvim-lualine/lualine.nvim',
  'https://github.com/neovim/nvim-lspconfig',
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'main' },
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

-- ── Code ─────────────────────────────────────────────────────────────────────
-- Server binaries live outside Neovim (guides/neovim.md); a missing one leaves its
-- server off. nvim-lspconfig supplies the configs, vim.lsp.enable starts them.
vim.o.signcolumn = 'yes'         -- diagnostics do not shift the text sideways
vim.o.winborder = 'rounded'
vim.o.completeopt = 'menuone,noselect,popup,fuzzy'
vim.diagnostic.config({ virtual_text = true })   -- the message shows at the end of its line

-- Building a parser needs the tree-sitter CLI and a C compiler; installed ones are skipped.
require('nvim-treesitter').install({
  'bash', 'css', 'html', 'javascript', 'json', 'python', 'toml', 'tsx', 'typescript', 'yaml',
})
vim.api.nvim_create_autocmd('FileType', {
  callback = function(ev)
    local lang = vim.treesitter.language.get_lang(ev.match)
    if lang and vim.treesitter.language.add(lang) then vim.treesitter.start(ev.buf, lang) end
  end,
})

-- tsc is TypeScript 7's native server. Biome and the oxc tools attach only where the project
-- configures them; lspconfig would start the oxc ones rootless everywhere else.
for _, name in ipairs({ 'oxlint', 'oxfmt' }) do vim.lsp.config(name, { workspace_required = true }) end
vim.lsp.enable({ 'tsc', 'ty', 'ruff', 'biome', 'oxlint', 'oxfmt', 'bashls', 'yamlls', 'jsonls' })

-- Formatting leaves import order alone; ruff and Biome sort imports through this code action.
local function organize_imports(client, buf)
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(buf),
    range = { start = { line = 0, character = 0 }, ['end'] = { line = vim.api.nvim_buf_line_count(buf), character = 0 } },
    context = { only = { 'source.organizeImports' }, diagnostics = {} },
  }
  local res = client:request_sync('textDocument/codeAction', params, 1000, buf)
  for _, action in ipairs(res and res.result or {}) do
    if not action.edit and client:supports_method('codeAction/resolve') then
      local resolved = client:request_sync('codeAction/resolve', action, 1000, buf)
      action = resolved and resolved.result or action
    end
    if action.edit then vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding) end
  end
end

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    if client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
    -- Only the formatters format; tsc and the others would fight them.
    if vim.list_contains({ 'ruff', 'biome', 'oxfmt' }, client.name) then
      vim.api.nvim_create_autocmd('BufWritePre', {
        group = vim.api.nvim_create_augroup('format.' .. ev.buf, {}),
        buffer = ev.buf,
        callback = function()
          organize_imports(client, ev.buf)
          vim.lsp.buf.format({ bufnr = ev.buf, id = client.id })
        end,
      })
    end
  end,
})
