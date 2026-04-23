-- Pin the enclosing function/class/if-block header at the top of the
-- viewport while scrolling — VSCode-style sticky scroll.
return {
	"nvim-treesitter/nvim-treesitter-context",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		enable = true,
		max_lines = 3, -- cap context height so it doesn't steal the screen
		min_window_height = 20, -- disable context on very short windows
		line_numbers = true,
		multiline_threshold = 1, -- collapse multi-line signatures into a single line
		trim_scope = "outer", -- if scopes exceed max_lines, drop outermost first
		mode = "cursor", -- follow the cursor, not just the viewport top
		separator = nil, -- "─" for a thin separator; nil = none
		zindex = 20,
	},
	keys = {
		{ "<leader>tc", function() require("treesitter-context").toggle() end, desc = "[T]oggle [C]ontext" },
		-- Jump to the currently shown context (function header, etc.)
		{ "[c", function() require("treesitter-context").go_to_context(vim.v.count1) end, desc = "Jump to context" },
	},
}
