-- init.lua – Neovim for prose and code on vim.pack: catppuccin, snacks picker and explorer,
-- which-key, lualine, gitsigns, mini.icons, precognition, hardtime; LSP, format on save, treesitter.
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
vim.o.foldmethod = 'expr'
vim.o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'   -- no folds where no parser runs
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
    -- filetype is still unset here: this group runs before filetype detection.
    if vim.filetype.match({ buf = ev.buf }) ~= 'gitcommit' and mark[1] > 0
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
  { src = 'https://github.com/catppuccin/nvim', name = 'catppuccin' },
  'https://github.com/folke/snacks.nvim',
  'https://github.com/folke/which-key.nvim',
  'https://github.com/nvim-lualine/lualine.nvim',
  'https://github.com/neovim/nvim-lspconfig',
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'main' },
  'https://github.com/tris203/precognition.nvim',
  'https://github.com/m4xshen/hardtime.nvim',
  'https://github.com/MunifTanjim/nui.nvim',
  'https://github.com/lewis6991/gitsigns.nvim',
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter-textobjects', version = 'main' },
  'https://github.com/nvim-mini/mini.icons',
})

-- Mocha with neutral greys of equal luminance in place of its blue-tinted backgrounds.
-- dotfiles/ptyxis/catppuccin-mocha-grey.palette and .tmux.conf use the same greys.
require('catppuccin').setup({
  flavour = 'mocha',
  color_overrides = {
    mocha = {
      crust = '#121212', mantle = '#191919', base = '#1f1f1f',
      surface0 = '#333333', surface1 = '#484848', surface2 = '#5c5c5c',
    },
  },
})
vim.cmd.colorscheme('catppuccin')
require('mini.icons').setup()
MiniIcons.mock_nvim_web_devicons()   -- lualine asks for nvim-web-devicons
require('snacks').setup({
  picker = {}, explorer = {}, indent = {}, scope = {}, words = {}, notifier = {},
  input = {}, bigfile = {}, quickfile = {},
})
require('which-key').setup({
  spec = {
    { '<leader>f', group = 'file' }, { '<leader>s', group = 'search' }, { '<leader>u', group = 'ui' },
    { '<leader>g', group = 'git' }, { '<leader>gh', group = 'hunks' },
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

-- ── Git ──────────────────────────────────────────────────────────────────────
require('gitsigns').setup({
  on_attach = function(buf)
    local gs = require('gitsigns')
    local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc }) end
    map('n', ']h', function() gs.nav_hunk('next') end, 'Next hunk')
    map('n', '[h', function() gs.nav_hunk('prev') end, 'Previous hunk')
    map('n', '<leader>ghs', gs.stage_hunk, 'Stage hunk')
    map('n', '<leader>ghr', gs.reset_hunk, 'Reset hunk')
    map('n', '<leader>ghp', gs.preview_hunk, 'Preview hunk')
    map({ 'o', 'x' }, 'ih', gs.select_hunk, 'Hunk')
  end,
})
Snacks.toggle.new({
  name = 'Git signs',
  get = function() return require('gitsigns.config').config.signcolumn end,
  set = function(on) require('gitsigns').toggle_signs(on) end,
}):map('<leader>uG')
vim.keymap.set('n', '<leader>gb', function() Snacks.git.blame_line() end, { desc = 'Blame line' })
vim.keymap.set('n', '<leader>gB', function() Snacks.gitbrowse() end, { desc = 'Open in browser' })
vim.keymap.set('n', '<leader>gg', function() Snacks.lazygit() end, { desc = 'Lazygit' })

-- ── Learning ─────────────────────────────────────────────────────────────────
-- precognition shows the motions reachable from the cursor. hardtime blocks a key
-- repeated too often and names the better motion; :Hardtime report needs nui.
require('precognition').setup({})
require('hardtime').setup({
  disabled_filetypes = { snacks_picker_list = true, snacks_picker_input = true, snacks_input = true },
})
Snacks.toggle.new({
  name = 'Motion hints',
  get = function() return require('precognition').is_visible() end,
  set = function(on) require('precognition')[on and 'show' or 'hide']() end,
}):map('<leader>up')
Snacks.toggle.new({
  name = 'Hardtime',
  get = function() return require('hardtime').is_plugin_enabled end,
  set = function(on) require('hardtime')[on and 'enable' or 'disable']() end,
}):map('<leader>uH')

-- The keys being learned (cheatsheet.md) stay in a float in the top-right corner.
-- It takes no focus and hides below 100 columns.
local sheet = { path = vim.fn.stdpath('config') .. '/cheatsheet.md', on = true }
local function sheet_update()
  local valid = sheet.win and vim.api.nvim_win_is_valid(sheet.win)
  if not sheet.on or vim.o.columns < 100 or vim.fn.filereadable(sheet.path) == 0 then
    if valid then vim.api.nvim_win_close(sheet.win, true) end
    return
  end
  if not sheet.buf then
    sheet.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(sheet.buf, 0, -1, false, vim.fn.readfile(sheet.path))
    vim.treesitter.start(sheet.buf, 'markdown')   -- no filetype, so no FileType autocmds
  end
  local lines = vim.api.nvim_buf_get_lines(sheet.buf, 0, -1, false)
  local width = math.max(unpack(vim.tbl_map(vim.fn.strdisplaywidth, lines)))
  local config = {
    relative = 'editor', anchor = 'NE', row = 0, col = vim.o.columns, zindex = 10,
    width = width, height = #lines, style = 'minimal', focusable = false,
    border = 'rounded', title = ' Learning ',
  }
  -- A float lives in one tab page; follow the user into a new one.
  if valid and vim.api.nvim_win_get_tabpage(sheet.win) ~= vim.api.nvim_get_current_tabpage() then
    vim.api.nvim_win_close(sheet.win, true)
    valid = false
  end
  if valid then vim.api.nvim_win_set_config(sheet.win, config)
  else sheet.win = vim.api.nvim_open_win(sheet.buf, false, config) end
end
sheet_update()
autocmd({ 'VimResized', 'WinEnter' }, { callback = sheet_update })
-- :only closes floats too; reopen once the close is done.
autocmd('WinClosed', {
  callback = function(ev)
    if tonumber(ev.match) == sheet.win then vim.schedule(sheet_update) end
  end,
})
Snacks.toggle.new({
  name = 'Cheat sheet',
  get = function() return sheet.on end,
  set = function(on) sheet.on = on; sheet_update() end,
}):map('<leader>uk')

-- ── Code ─────────────────────────────────────────────────────────────────────
-- Server binaries live outside Neovim (guides/neovim.md); a missing one leaves its
-- server off. nvim-lspconfig supplies the configs, vim.lsp.enable starts them.
vim.o.signcolumn = 'yes:2'       -- a diagnostic and a git sign side by side; text never shifts
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
      if vim.treesitter.query.get(lang, 'indents') then
        vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end
  end,
})

-- Function, class and argument text objects. Linewise outer objects leave no empty line.
require('nvim-treesitter-textobjects').setup({
  select = { lookahead = true, selection_modes = { ['@function.outer'] = 'V', ['@class.outer'] = 'V' } },
  move = { set_jumps = true },
})
for lhs, obj in pairs({
  af = '@function.outer', ['if'] = '@function.inner', ac = '@class.outer',
  ic = '@class.inner', aa = '@parameter.outer', ia = '@parameter.inner',
}) do
  vim.keymap.set({ 'x', 'o' }, lhs, function()
    require('nvim-treesitter-textobjects.select').select_textobject(obj, 'textobjects')
  end, { desc = obj })
end
-- ]c and [c keep their built-in meaning in diff mode: next and previous change.
for lhs, move in pairs({
  [']f'] = { 'goto_next_start', '@function.outer' }, ['[f'] = { 'goto_previous_start', '@function.outer' },
  [']c'] = { 'goto_next_start', '@class.outer' }, ['[c'] = { 'goto_previous_start', '@class.outer' },
}) do
  vim.keymap.set({ 'n', 'x', 'o' }, lhs, function()
    if vim.wo.diff and lhs:sub(2) == 'c' then return vim.cmd.normal({ vim.v.count1 .. lhs, bang = true }) end
    require('nvim-treesitter-textobjects.move')[move[1]](move[2], 'textobjects')
  end, { desc = move[2] })
end

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
