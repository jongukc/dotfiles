-- See `:help vim.o`, `:help vim.opt`
local o = vim.o
local opt = vim.opt

-- Line numbers
o.number = true
o.relativenumber = true
o.numberwidth = 4

-- Wrapping / scrolling
o.linebreak = true
o.breakindent = true
o.scrolloff = 4
o.sidescrolloff = 8
o.whichwrap = "bs<>[]hl"

-- Mouse / cursor
o.mouse = "a"
o.cursorline = true
o.guicursor = ""

-- Indentation
o.autoindent = true
o.smartindent = true
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4
o.expandtab = true

-- List
opt.list = true
opt.listchars = {
	lead = "·",
	tab = "→ ",
	trail = "-",
	nbsp = "+",
}

-- Search
o.ignorecase = true
o.smartcase = true
o.hlsearch = false
o.incsearch = true

-- Windows / splits / tabs
o.splitbelow = true
o.splitright = true
o.showmode = false
o.showtabline = 0
o.cmdheight = 1
o.pumheight = 10
o.signcolumn = "yes"

-- Colors
o.termguicolors = true
opt.colorcolumn = "80"

-- Editing
o.backspace = "indent,eol,start"
o.conceallevel = 0

-- Files
o.swapfile = false
o.backup = false
o.writebackup = false
o.undofile = true
o.fileencoding = "utf-8"

-- Timing
o.updatetime = 250
o.timeoutlen = 300

-- Completion
o.completeopt = "menuone,noselect"
opt.shortmess:append("c") -- suppress ins-completion-menu messages

-- Word / format behavior
opt.iskeyword:append("-")
opt.formatoptions:remove({ "c", "r", "o" })

-- Clipboard
o.clipboard = "unnamedplus"

-- Keep Vim's system runtimepath out of Neovim
opt.runtimepath:remove("/usr/share/vim/vimfiles")
