return {
	"git@github.com:jongukc/tree-sitter-pasm.git",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter.install").ensure_installed_sync({ "pasm" })
	end,
}
