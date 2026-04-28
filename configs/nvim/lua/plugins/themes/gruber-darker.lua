return {
	"blazkowolf/gruber-darker.nvim",
	opts = {},
	config = function()
		-- Apply the quartz override only when gruber-darker itself is active.
		-- Previously `pattern = "*"` clobbered every other colorscheme's struct-
		-- member highlights (including dalbit-light's #0e3a64 and dalbit-mono-light's
		-- fg1 gray), making them all look like gruber-darker's quartz #95a99f.
		local group = vim.api.nvim_create_augroup("CustomHighlights", { clear = true })
		local quartz = "#95a99f"
		vim.api.nvim_create_autocmd("ColorScheme", {
			pattern = "gruber-darker",
			group = group,
			callback = function()
				vim.api.nvim_set_hl(0, "@variable.member", { fg = quartz, bold = false })
				vim.api.nvim_set_hl(0, "@property", { fg = quartz, bold = false })
				vim.api.nvim_set_hl(0, "@field", { fg = quartz, bold = false })
			end,
		})
	end,
}
