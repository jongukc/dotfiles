-- Adds git related signs to the gutter, as well as utilities for managing changes
return {
	"lewis6991/gitsigns.nvim",
	opts = {
		signs = {
			add = { text = "+" },
			change = { text = "~" },
			delete = { text = "_" },
			topdelete = { text = "‾" },
			changedelete = { text = "~" },
		},
		signs_staged = {
			add = { text = "+" },
			change = { text = "~" },
			delete = { text = "_" },
			topdelete = { text = "‾" },
			changedelete = { text = "~" },
		},
	},
	config = function()
		local opts = { noremap = true, silent = true }
		local gitsigns = require("gitsigns")
		vim.keymap.set("n", "<leader>hp", gitsigns.preview_hunk, { desc = "Preview git hunk" })
		vim.keymap.set("n", "<leader>hb", gitsigns.blame_line, { desc = "Blame line" })
	end,
}
