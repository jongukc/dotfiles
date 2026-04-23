return {
	"git@github.com:jongukc/tree-sitter-palmer.git",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter").install({ "palmer" })
	end,
}
