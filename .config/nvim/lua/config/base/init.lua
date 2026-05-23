-- Global settings
vim.g.mapleader = " " -- Make sure to set `mapleader` before lazy so your mappings are correct
vim.g.maplocalleader = " "
-- Fix markdown indentation settings
vim.g.markdown_recommended_style = 0
-- Allow OSC 52 passthrough for cross machine clipboard operations
vim.g.clipboard = {
  name = 'OSC 52',
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
    ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
  },
  paste = {
    ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
    ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
  },
}

-- List & Map style settings
local opt = vim.opt

-- opt.cmdheight = 0 -- Make the line invisible but also will disturb workflow
opt.mouse = "a"
opt.number = true
opt.relativenumber = true
opt.scrolloff = 4
opt.sidescrolloff = 8
-- NOTE: No need to share clipboard since I am using builtin system clipboard access
-- opt.clipboard = "unnamedplus"
opt.confirm = true     -- Confirm to save changes before exiting modified buffer
opt.cursorline = false -- Enable highlighting of the current line
opt.ignorecase = true  -- Ignore case
opt.smartcase = true   -- Don't ignore case with capitals
opt.smartindent = true -- Insert indents automatically
opt.spell = true
opt.spelllang = { "en" }
opt.spelloptions = { "camel" }
opt.splitbelow = false   -- Put new windows below current
opt.splitright = true    -- Put new windows right of current
opt.tabstop = 2          -- Number of spaces tabs count for
opt.shiftwidth = 2       -- Fix shiftwidth 8 issue
opt.termguicolors = true -- True color support & override iterm color settings
opt.hlsearch = true      -- Remove highlight search on search
-- NOTE: No need to modify since I am using plugin to manage the fold
-- opt.foldenable = false
-- opt.foldmethod = 'indent'

if vim.fn.has("nvim-0.9.0") == 1 then
  opt.splitkeep = "screen"
  opt.shortmess:append({ C = true })
end

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank()
  end,
  group = highlight_group,
  pattern = "*",
})

-- NOTE: Prevent auto commenting on newline
vim.cmd("autocmd BufEnter * set formatoptions-=cro")
vim.cmd("autocmd BufEnter * setlocal formatoptions-=cro")

-- NOTE: Add mdx file type support
vim.filetype.add({
  extension = {
    mdx = "mdx",
  },
})

local icons = require("options.icons")
local signs = {
  Error = icons.diagnostics.Error,
  Warn = icons.diagnostics.Warn,
  Hint = icons.diagnostics.Hint,
  Info = icons.diagnostics.Info,
}
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "help", "man" },
  command = "wincmd H", -- Move the help window to far left
})

vim.diagnostic.config({ virtual_text = true })
