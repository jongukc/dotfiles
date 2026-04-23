return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		local parsers = {
			"c",
			"cpp",
			"lua",
			"luadoc",
			"python",
			"javascript",
			"typescript",
			"tsx",
			"vim",
			"vimdoc",
			"query",
			"regex",
			"dockerfile",
			"json",
			"java",
			"go",
			"gitignore",
			"yaml",
			"make",
			"cmake",
			"markdown",
			"markdown_inline",
			"bash",
			"css",
			"html",
			"latex",
		}

		require("nvim-treesitter").install(parsers)

		-- Collect all filetypes served by the installed parsers
		-- (e.g. the `tsx` parser serves `typescriptreact`).
		local filetypes = {}
		for _, parser in ipairs(parsers) do
			for _, ft in ipairs(vim.treesitter.language.get_filetypes(parser)) do
				filetypes[#filetypes + 1] = ft
			end
		end

		-- Ruby depends on Vim's regex highlighting system for correct indent; skip.
		local disable_ft = { ruby = true }
		local disable_indent_ft = { ruby = true, tex = true }

		vim.api.nvim_create_autocmd("FileType", {
			pattern = filetypes,
			callback = function(ev)
				if not disable_ft[ev.match] then
					pcall(vim.treesitter.start, ev.buf)
				end
				if not disable_indent_ft[ev.match] then
					vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end
			end,
		})
	end,
}
