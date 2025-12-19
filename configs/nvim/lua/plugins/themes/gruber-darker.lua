return {
	"blazkowolf/gruber-darker.nvim",
	opts = {},
	config = function()
		local group = vim.api.nvim_create_augroup("CustomHighlights", { clear = true })
		local quartz = "#95a99f"
		vim.api.nvim_create_autocmd("ColorScheme", {
			pattern = "*",
			group = group,
			callback = function()
				vim.api.nvim_set_hl(0, "@variable.member", { fg = quartz, bold = false })
				vim.api.nvim_set_hl(0, "@property", { fg = quartz, bold = false })
				vim.api.nvim_set_hl(0, "@field", { fg = quartz, bold = false })
			end,
		})
	end,
}
