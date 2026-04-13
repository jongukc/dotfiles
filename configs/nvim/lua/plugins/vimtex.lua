return {
	"lervag/vimtex",
	lazy = false, -- we don't want to lazy load VimTeX
	-- tag = "v2.15", -- uncomment to pin to a specific release
	init = function()
		vim.g.vimtex_syntax_enabled = 1
		vim.g.vimtex_compiler_method = "generic"
		vim.g.vimtex_compiler_generic = {
			command = "make -C paper all",
		}
		vim.g.vimtex_quickfix_mode = 0

		-- Use paperhere-forward for remote sessions, zathura directly for local
		local forward = os.getenv("HOME") .. "/bin/paperhere-forward"
		if vim.fn.filereadable(forward) == 1
		   and vim.fn.getenv("PAPERHERE_SESSION") ~= vim.NIL then
			vim.g.vimtex_view_method = "general"
			vim.g.vimtex_view_general_viewer = forward
			vim.g.vimtex_view_general_options = "@line:@col:@tex @pdf"
		else
			vim.g.vimtex_view_method = "zathura"
		end

		-- Auto-rebuild on save when PAPERHERE_BUILD_CMD is set
		local build_cmd = vim.fn.getenv("PAPERHERE_BUILD_CMD")
		if build_cmd ~= vim.NIL then
			vim.api.nvim_create_autocmd("BufWritePost", {
				pattern = "*.tex",
				callback = function()
					vim.fn.jobstart(build_cmd)
				end,
			})
		end
	end,
}
