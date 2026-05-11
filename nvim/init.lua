-- Neovim configuration: minimal, no plugins, no LSP.

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Display
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = 'yes'

-- Indent
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true

-- UX
vim.opt.clipboard = 'unnamedplus'
vim.opt.undofile = true
vim.opt.mouse = 'a'
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Keymaps
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.keymap.set('n', '<leader>w', '<cmd>w<CR>', { desc = 'Save' })
vim.keymap.set('n', '<leader>q', '<cmd>q<CR>', { desc = 'Quit' })
