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
vim.o.timeoutlen = 300           -- which-key opens after 300 ms instead of 1 s
vim.o.cursorline = true
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.laststatus = 3             -- one status line for all windows
vim.o.jumpoptions = 'view'       -- Ctrl-o restores the scroll position too
vim.o.virtualedit = 'block'      -- Ctrl-v selects past the end of short lines
vim.o.smoothscroll = true
vim.o.spelllang = 'en,de'
vim.o.foldlevel = 99             -- folds start open
vim.o.foldtext = ''              -- a fold shows its first line, highlighted
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

-- ── Autocmds ─────────────────────────────────────────────────────────────────
local group = vim.api.nvim_create_augroup('config', {})
local function autocmd(event, opts)
  vim.api.nvim_create_autocmd(event, vim.tbl_extend('force', { group = group }, opts))
end
autocmd('TextYankPost', { callback = function() vim.hl.on_yank() end })
-- 'autoread' reloads a file changed outside Neovim only when something runs :checktime.
autocmd({ 'FocusGained', 'TermClose', 'TermLeave' }, {
  callback = function() if vim.o.buftype ~= 'nofile' then vim.cmd.checktime() end end,
})
autocmd('BufReadPost', {
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    if vim.bo[ev.buf].filetype ~= 'gitcommit' and mark[1] > 0
      and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
autocmd('FileType', {
  pattern = { 'help', 'qf', 'man', 'checkhealth' },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = ev.buf, desc = 'Close window' })
  end,
})
autocmd('BufWritePre', {
  callback = function(ev)
    if ev.match:match('^%w%w+:[\\/][\\/]') then return end   -- scp:// and other URLs
    vim.fn.mkdir(vim.fn.fnamemodify(ev.match, ':p:h'), 'p')
  end,
})
autocmd('FileType', {
  pattern = { 'markdown', 'text', 'gitcommit' },
  callback = function() vim.opt_local.spell = true end,
})

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

vim.cmd.colorscheme('tokyonight-night')
require('snacks').setup({
  picker = {}, explorer = {}, indent = {}, scope = {}, words = {}, notifier = {},
  input = {}, bigfile = {}, quickfile = {},
})
require('which-key').setup({
  spec = {
    { '<leader>f', group = 'file' }, { '<leader>s', group = 'search' }, { '<leader>u', group = 'ui' },
  },
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
  ['<leader>n'] = { function() Snacks.notifier.show_history() end, 'Notification history' },
}) do
  vim.keymap.set('n', lhs, map[1], { desc = map[2] })
end

-- ]d and [d jump to any diagnostic; these skip to one severity.
local function jump(count, severity)
  return function() vim.diagnostic.jump({ count = count, severity = severity }) end
end
local sev = vim.diagnostic.severity
vim.keymap.set('n', ']e', jump(1, sev.ERROR), { desc = 'Next error' })
vim.keymap.set('n', '[e', jump(-1, sev.ERROR), { desc = 'Previous error' })
vim.keymap.set('n', ']w', jump(1, sev.WARN), { desc = 'Next warning' })
vim.keymap.set('n', '[w', jump(-1, sev.WARN), { desc = 'Previous warning' })

-- Format on save runs unless b:autoformat or g:autoformat is false.
local function flag(scope, name)
  return Snacks.toggle.new({
    name = name,
    get = function() return vim[scope].autoformat ~= false end,
    set = function(on) vim[scope].autoformat = on end,
  })
end
flag('b', 'Autoformat (buffer)'):map('<leader>uf')
flag('g', 'Autoformat (global)'):map('<leader>uF')
Snacks.toggle.inlay_hints():map('<leader>uh')
Snacks.toggle.diagnostics():map('<leader>ud')
Snacks.toggle.option('spell', { name = 'Spelling' }):map('<leader>us')
Snacks.toggle.option('wrap', { name = 'Wrap' }):map('<leader>uw')

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
    if lang and vim.treesitter.language.add(lang) then
      vim.treesitter.start(ev.buf, lang)
      vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      vim.wo[0][0].foldmethod = 'expr'
      vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    end
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
          if vim.b[ev.buf].autoformat == false or vim.g.autoformat == false then return end
          organize_imports(client, ev.buf)
          vim.lsp.buf.format({ bufnr = ev.buf, id = client.id })
        end,
      })
    end
  end,
})
