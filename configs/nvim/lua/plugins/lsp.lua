-- LSP for Neovim 0.11+ using vim.lsp.config() + vim.lsp.enable().
-- nvim-lspconfig still ships the built-in server definitions that
-- vim.lsp.config reads from, but we do NOT call require("lspconfig").
return {
	"neovim/nvim-lspconfig",
	dependencies = {
		-- Automatically install LSPs and related tools to stdpath for Neovim
		{ "mason-org/mason.nvim", opts = {} },

		-- mason-lspconfig v2.x:
		-- - Bridges LSP names (e.g. "lua_ls") ↔ Mason package names.
		-- - With `automatic_enable = true` (default), it calls
		--   `vim.lsp.enable` on every installed server, so we do NOT
		--   use the removed `handlers = {...}` API.
		{ "mason-org/mason-lspconfig.nvim" },

		-- mason-tool-installer:
		-- - Installs LSPs, linters, formatters by Mason package name.
		"WhoIsSethDaniel/mason-tool-installer.nvim",

		-- LSP status UI
		{
			"j-hui/fidget.nvim",
			opts = {
				notification = {
					window = { winblend = 0 },
				},
			},
		},

		-- Extra capabilities provided by nvim-cmp
		"hrsh7th/cmp-nvim-lsp",
	},
	config = function()
		-- -----------------------------------------------------------
		-- Keymaps / behaviour on LSP attach
		-- -----------------------------------------------------------
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
			callback = function(event)
				local map = function(keys, func, desc, mode)
					mode = mode or "n"
					vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
				end

				map("gd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")
				map("gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
				map("gI", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")
				map("<leader>D", require("telescope.builtin").lsp_type_definitions, "Type [D]efinition")
				map("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")
				map("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")
				map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
				map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction", { "n", "x" })
				map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

				local client = vim.lsp.get_client_by_id(event.data.client_id)

				-- Highlight references of the word under the cursor
				if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
					local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
					vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
						buffer = event.buf,
						group = highlight_augroup,
						callback = vim.lsp.buf.document_highlight,
					})

					vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
						buffer = event.buf,
						group = highlight_augroup,
						callback = vim.lsp.buf.clear_references,
					})

					vim.api.nvim_create_autocmd("LspDetach", {
						group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
						callback = function(event2)
							vim.lsp.buf.clear_references()
							vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event2.buf })
						end,
					})
				end

				-- Toggle inlay hints
				if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
					map("<leader>th", function()
						vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
					end, "[T]oggle Inlay [H]ints")
				end
			end,
		})

		-- -----------------------------------------------------------
		-- Capabilities (broadcast cmp + default capabilities)
		-- -----------------------------------------------------------
		local capabilities = vim.tbl_deep_extend(
			"force",
			vim.lsp.protocol.make_client_capabilities(),
			require("cmp_nvim_lsp").default_capabilities()
		)

		-- -----------------------------------------------------------
		-- Per-server configuration (merged on top of nvim-lspconfig's
		-- built-in defaults, which vim.lsp.config reads from the
		-- `lsp/<name>.lua` files that nvim-lspconfig installs into
		-- &runtimepath).
		-- -----------------------------------------------------------
		local servers = {
			clangd = {
				cmd = {
					"clangd",
					"--background-index",
					"--clang-tidy",
					"--header-insertion=iwyu",
					"--completion-style=detailed",
					"--function-arg-placeholders",
					"--fallback-style=llvm",
				},
				init_options = {
					usePlaceholders = true,
					completeUnimported = true,
					clangdFileStatus = true,
				},
			},
			ts_ls = {},
			-- Python: basedpyright handles types/hover/definitions/workspace-symbols;
			-- ruff handles linting + formatting. (pylsp intentionally dropped:
			-- it does not implement workspace/symbol as of 1.14.)
			basedpyright = {
				settings = {
					basedpyright = {
						analysis = {
							typeCheckingMode = "standard",
							autoSearchPaths = true,
							useLibraryCodeForTypes = true,
							diagnosticMode = "openFilesOnly",
						},
					},
				},
			},
			ruff = {},
			html = { filetypes = { "html", "twig", "hbs" } },
			cssls = {},
			tailwindcss = {},
			dockerls = {},
			sqlls = {},
			terraformls = {},
			jsonls = {},
			yamlls = {},
			lua_ls = {
				settings = {
					Lua = {
						completion = { callSnippet = "Replace" },
						runtime = { version = "LuaJIT" },
						workspace = {
							checkThirdParty = false,
							library = vim.api.nvim_get_runtime_file("", true),
						},
						diagnostics = {
							globals = { "vim" },
							disable = { "missing-fields" },
						},
						format = { enable = false },
					},
				},
			},
		}

		-- Register every server's config with vim.lsp; attach capabilities.
		for name, cfg in pairs(servers) do
			cfg.capabilities = vim.tbl_deep_extend("force", {}, capabilities, cfg.capabilities or {})
			vim.lsp.config(name, cfg)
		end

		-- -----------------------------------------------------------
		-- Ensure tools are installed via Mason
		-- -----------------------------------------------------------
		local ensure_installed = vim.tbl_keys(servers)
		vim.list_extend(ensure_installed, {
			"stylua", -- Lua formatter
		})
		require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

		-- mason-lspconfig v2: restrict automatic_enable to exactly the
		-- servers we configure here, so leftover Mason-installed servers
		-- (e.g. an old pylsp) don't auto-attach.
		require("mason-lspconfig").setup({
			ensure_installed = vim.tbl_keys(servers),
			automatic_enable = vim.tbl_keys(servers),
		})
	end,
}
