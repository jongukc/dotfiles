require("core.keybindings")
require("core.options")
require("core.filetype")

vim.g.have_nerd_font = true

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	-- require("plugins.neotree"),
	require("plugins.treesitter"),
	require("plugins.treesitter-context"),
	-- require("plugins.palmer"),
	-- require("plugins.pasm"),
	require("plugins.bufferline"),
	require("plugins.lualine"),
	require("plugins.telescope"),
	require("plugins.lsp"),
	require("plugins.autocompletion"),
	require("plugins.none-ls"),
	require("plugins.gitsigns"),
	require("plugins.indent-blankline"),
	require("plugins.comment"),
	require("plugins.misc"),
	-- require("plugins.alpha"),
	require("plugins.undotree"),
	require("plugins.markview"),
	require("plugins.multicursor"),
	require("plugins.vimtex"),
	require("plugins.oil"),
	-- Colorschemes
	require("plugins.themes.tokyonight"),
	require("plugins.themes.nord"),
	require("plugins.themes.kanagawa"),
	require("plugins.themes.monokai"),
	require("plugins.themes.modus"),
	require("plugins.themes.gruvbox-material"),
	require("plugins.themes.gruber-darker"),
	require("plugins.themes.catpuccin"),
	require("plugins.themes.dalbit"),
})

-- Set colorscheme
-- vim.cmd.colorscheme("gruvbox-material")
vim.cmd.colorscheme("dalbit")

vim.g.clipboard = {
	name = "wl-clipboard",
	copy = {
		["+"] = { "wl-copy" },
		["*"] = { "wl-copy", "--primary" },
	},
	paste = {
		["+"] = { "wl-paste", "--no-newline" },
		["*"] = { "wl-paste", "--primary", "--no-newline" },
	},
	cache_enabled = 1,
}
