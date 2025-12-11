require 'core.keybindings'
require 'core.options'

vim.g.have_nerd_font = true

-- [[ Install `lazy.nvim` plugin manager ]]
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
    local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
    if vim.v.shell_error ~= 1 then
        error('Error cloning lazy.nvim:\n' .. out)
    end
end

vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
    require 'plugins.neotree',
    require 'plugins.treesitter',
    require 'plugins.gruvbox-material',
    require 'plugins.bufferline',
    require 'plugins.lualine',
    require 'plugins.telescope',
    require 'plugins.lsp',
    require 'plugins.autocompletion',
    require 'plugins.none-ls',
    require 'plugins.gitsigns',
    require 'plugins.indent-blankline',
    require 'plugins.comment',
    require 'plugins.misc',
})

