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

local osc52 = require("vim.ui.clipboard.osc52")
local last = {}

local function wayland_live()
	local sock, dir = vim.env.WAYLAND_DISPLAY, vim.env.XDG_RUNTIME_DIR
	if not sock or sock == "" or not dir then
		return false
	end
	return vim.uv.fs_stat(dir .. "/" .. sock) ~= nil
end

local function copier(reg, cmd)
	local emit = osc52.copy(reg)
	return function(lines, regtype)
		emit(lines, regtype)
		last[reg] = { lines, regtype }
		if wayland_live() and vim.fn.executable(cmd[1]) == 1 then
			vim.system(cmd, { stdin = table.concat(lines, "\n") })
		end
	end
end

local function paster(reg, cmd)
	return function()
		if wayland_live() and vim.fn.executable(cmd[1]) == 1 then
			local r = vim.system(cmd, { text = true }):wait()
			if r.code == 0 then
				return vim.split(r.stdout or "", "\n")
			end
		end
		return last[reg] or {}
	end
end

vim.g.clipboard = {
	name = "osc52+wl-clipboard",
	copy = {
		["+"] = copier("+", { "wl-copy" }),
		["*"] = copier("*", { "wl-copy", "--primary" }),
	},
	paste = {
		["+"] = paster("+", { "wl-paste", "--no-newline" }),
		["*"] = paster("*", { "wl-paste", "--primary", "--no-newline" }),
	},
}
