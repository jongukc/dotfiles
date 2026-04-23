return {
	"OXY2DEV/markview.nvim",
	lazy = false,

	-- Completion for `blink.cmp`
	-- dependencies = { "saghen/blink.cmp" },
	config = function()
		require("markview").setup({
			preview = {
				enable = true,
				wrap = true,
			},
		})
		vim.keymap.set("n", "<leader>m", "<CMD>Markview<CR>", { desc = "Toggles `markview` previews globally." })
		vim.keymap.set(
			"n",
			"<leader>ms",
			"<CMD>Markview splitToggle<CR>",
			{ desc = "Toggles `splitview` for current buffer." }
		)
	end,
}
