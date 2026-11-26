-- =============================================================================
--  Neovim 0.12 configuration (single file)
--
--  Plugins are managed by the built-in |vim.pack|:
--    update   :lua vim.pack.update()      review, then :write to apply (:q to abort)
--    remove   delete the spec below, :restart, then :lua vim.pack.del({ "name" })
--  The lockfile nvim-pack-lock.json next to this file pins every revision.
--
--  Sections
--     1. Leader & UI             9. LSP & Mason
--     2. Options                10. Formatting & linting (none-ls)
--     3. Clipboard              11. Completion & snippets (built-in)
--     4. Keymaps                12. Telescope
--     5. Diagnostics            13. UI: statusline, indent guides
--     6. Filetypes              14. Git
--     7. Plugins (vim.pack)     15. Editing
--     8. Treesitter             16. Tools
-- =============================================================================

-- =============================================================================
-- 1. Leader & UI
-- =============================================================================
-- Byte-compile and cache Lua modules (lazy.nvim used to do this for us)
vim.loader.enable()

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- New message/cmdline UI (experimental in 0.12): no "Press ENTER" prompts,
-- and it renders the native progress messages used for LSP progress below.
require("vim._core.ui2").enable({})

-- =============================================================================
-- 2. Options  (see `:help vim.o`, `:help vim.opt`)
-- =============================================================================

-- Line numbers
vim.o.number = true
vim.o.relativenumber = true

-- Wrapping / scrolling
vim.o.wrap = false
vim.o.linebreak = true
vim.o.breakindent = true
vim.o.scrolloff = 4
vim.o.sidescrolloff = 8
vim.o.whichwrap = "bs<>[]hl"

-- Mouse / cursor
vim.o.mouse = "a"
vim.o.cursorline = true
vim.o.guicursor = ""

-- Indentation (vim-sleuth adjusts these per file)
vim.o.smartindent = true
vim.o.shiftwidth = 4
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.expandtab = true

-- Whitespace
vim.o.list = true
vim.opt.listchars = { lead = "·", tab = "→ ", trail = "-", nbsp = "+" }

-- Search
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.hlsearch = false

-- Windows / UI
vim.o.splitbelow = true
vim.o.splitright = true
vim.o.showmode = false -- lualine shows the mode
vim.o.signcolumn = "yes"
vim.o.colorcolumn = "80"
vim.o.pumheight = 10
vim.o.termguicolors = true -- auto-detection can miss truecolor inside tmux

-- Files
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false
vim.o.undofile = true

-- Timing
vim.o.updatetime = 250
vim.o.timeoutlen = 300

-- Completion (behaviour is configured in section 11)
vim.o.completeopt = "menuone,noselect,popup,fuzzy"
vim.o.complete = ".^10,w^5,b^5,u^5" -- buffer-word sources for 'autocomplete'
vim.opt.shortmess:append("c") -- no ins-completion-menu messages

-- Word / format behaviour
vim.opt.iskeyword:append("-")
vim.opt.formatoptions:remove({ "c", "r", "o" })

-- Keep Vim's system runtimepath out of Neovim
vim.opt.runtimepath:remove("/usr/share/vim/vimfiles")

-- =============================================================================
-- 3. Clipboard
-- =============================================================================
--
-- The hard part here is not *how* to copy but *where* to: a tmux pane outlives
-- the client that created it, so the same nvim gets looked at from a foot
-- window on this box one hour and from an SSH client on a laptop the next.
-- Panes here routinely carry a stale SSH_CONNECTION while being displayed by
-- local foot, so no environment variable can answer "am I remote?", and a
-- provider hardwired to wl-copy always targets the machine nvim *runs* on
-- instead of the one being looked at.
--
-- So route the copy through the terminal, which is by definition the one in
-- front of the user, and mirror it to this host's compositor as well:
--
--   * OSC 52 (vim.api.nvim_ui_send) reaches whichever terminal is currently
--     displaying the pane -- foot locally, the laptop's terminal over SSH.
--     Inside tmux this needs `set -g set-clipboard on`; the default
--     "external" silently discards application OSC 52.
--   * wl-copy additionally puts it on this machine's Wayland clipboard, so
--     `"+p` round-trips and VNC/GUI apps see the yank too.
--
-- Paste reads wl-paste (fast, local) and falls back to the last thing we
-- copied. Nvim's OSC 52 *paste* is deliberately not used: it blocks up to 10s
-- waiting for a terminal reply, and with clipboard=unnamedplus every `p` would
-- pay that. To pull the laptop's clipboard into a remote nvim, use the
-- terminal's own paste (Ctrl+Shift+V), which arrives as normal keystrokes.
vim.o.clipboard = "unnamedplus"

do
	local osc52 = require("vim.ui.clipboard.osc52")
	local last = {}

	local function wayland_live()
		local sock, dir = vim.env.WAYLAND_DISPLAY, vim.env.XDG_RUNTIME_DIR
		if not sock or sock == "" or not dir then
			return false
		end
		return vim.uv.fs_stat(dir .. "/" .. sock) ~= nil
	end

	local function copier(reg, cmd)
		local emit = osc52.copy(reg)
		return function(lines, regtype)
			emit(lines, regtype)
			last[reg] = { lines, regtype }
			if wayland_live() and vim.fn.executable(cmd[1]) == 1 then
				vim.system(cmd, { stdin = table.concat(lines, "\n") })
			end
		end
	end

	local function paster(reg, cmd)
		return function()
			if wayland_live() and vim.fn.executable(cmd[1]) == 1 then
				local r = vim.system(cmd, { text = true }):wait()
				if r.code == 0 then
					return vim.split(r.stdout or "", "\n")
				end
			end
			return last[reg] or {}
		end
	end

	vim.g.clipboard = {
		name = "osc52+wl-clipboard",
		copy = {
			["+"] = copier("+", { "wl-copy" }),
			["*"] = copier("*", { "wl-copy", "--primary" }),
		},
		paste = {
			["+"] = paster("+", { "wl-paste", "--no-newline" }),
			["*"] = paster("*", { "wl-paste", "--primary", "--no-newline" }),
		},
	}
end

-- =============================================================================
-- 4. Keymaps (general; plugin keymaps live with their plugin)
-- =============================================================================
local map = vim.keymap.set
local silent = { silent = true }

-- Disable the spacebar's default behaviour in Normal and Visual modes
map({ "n", "v" }, "<Space>", "<Nop>", silent)

-- Save / quit
map("n", "<C-s>", "<cmd>w<CR>", silent)
map("n", "<leader>sn", "<cmd>noautocmd w<CR>", { silent = true, desc = "Save without formatting" })
map("n", "<C-q>", "<cmd>q<CR>", silent)

-- Delete a single character without copying it into a register
map("n", "x", '"_x', silent)

-- Scroll / search and keep the cursor centred
map("n", "<C-d>", "<C-d>zz", silent)
map("n", "<C-u>", "<C-u>zz", silent)
map("n", "n", "nzzzv", silent)
map("n", "N", "Nzzzv", silent)

-- Resize with arrows
map("n", "<Up>", "<cmd>resize -2<CR>", silent)
map("n", "<Down>", "<cmd>resize +2<CR>", silent)
map("n", "<Left>", "<cmd>vertical resize -2<CR>", silent)
map("n", "<Right>", "<cmd>vertical resize +2<CR>", silent)

-- Buffers
map("n", "<Tab>", "<cmd>bnext<CR>", silent)
map("n", "<S-Tab>", "<cmd>bprevious<CR>", silent)
map("n", "<leader>x", "<cmd>bdelete!<CR>", { silent = true, desc = "Close buffer" })
map("n", "<leader>b", "<cmd>enew<CR>", { silent = true, desc = "New buffer" })

-- Windows
map("n", "<leader>\\", "<C-w>v", { silent = true, desc = "Split vertically" })
map("n", "<leader>-", "<C-w>s", { silent = true, desc = "Split horizontally" })
map("n", "<leader>se", "<C-w>=", { silent = true, desc = "Equalize splits" })
map("n", "<leader>xs", "<cmd>close<CR>", { silent = true, desc = "Close split" })

-- Tabs
map("n", "<leader>to", "<cmd>tabnew<CR>", { silent = true, desc = "New tab" })
map("n", "<leader>tx", "<cmd>tabclose<CR>", { silent = true, desc = "Close tab" })
map("n", "<leader>tn", "<cmd>tabn<CR>", { silent = true, desc = "Next tab" })
map("n", "<leader>tp", "<cmd>tabp<CR>", { silent = true, desc = "Previous tab" })

-- Terminal
map("n", "<leader>t", "<cmd>terminal<CR>", { silent = true, desc = "Terminal" })
-- map("t", "<Esc>", "<C-\\><C-n>", silent)

-- Toggle line wrapping
map("n", "<leader>lw", "<cmd>set wrap!<CR>", { silent = true, desc = "Toggle wrap" })

-- Stay in indent mode
map("v", "<", "<gv", silent)
map("v", ">", ">gv", silent)

-- Keep the last yank when pasting over a selection
map("v", "p", '"_dP', silent)

-- Quickfix
map("n", "<leader>cn", "<cmd>cnext<CR>", { desc = "Quickfix: Next" })
map("n", "<leader>cp", "<cmd>cprev<CR>", { desc = "Quickfix: Previous" })

-- Comments: built-in `gc` (replaces Comment.nvim). <C-_> is what most
-- terminals send for <C-/>.
for _, lhs in ipairs({ "<C-_>", "<C-/>", "<C-c>" }) do
	map("n", lhs, "gcc", { remap = true, desc = "Toggle comment" })
	map("v", lhs, "gc", { remap = true, desc = "Toggle comment" })
end

-- =============================================================================
-- 5. Diagnostics
-- =============================================================================
-- The built-in [d / ]d jump to the previous/next diagnostic; on_jump makes them
-- also open the float (this used to be the `float = true` jump option).
vim.diagnostic.config({
	jump = {
		on_jump = function(_, bufnr)
			vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
		end,
	},
})
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostics list" })

-- =============================================================================
-- 6. Filetypes
-- =============================================================================
-- ---- TeX: hard-wrap prose at 80 columns, but not inside tables/math/code ----
-- Environments where auto-wrapping is suppressed
local tex_no_wrap_envs = {}
for env in
	([[
	tabular tabular* tabularx tabulary longtable array table
	align align* equation equation* gather gather* multline multline*
	flalign flalign* split aligned gathered
	lstlisting verbatim verbatim* minted tikzpicture
	matrix bmatrix pmatrix vmatrix Bmatrix Vmatrix
]]):gmatch("%S+")
do
	tex_no_wrap_envs[env] = true
end

-- Name of a `generic_environment` treesitter node, e.g. "align*"
local function tex_env_name(env_node)
	for child in env_node:iter_children() do
		if child:type() == "begin" then
			for sub in child:iter_children() do
				if sub:type() == "curly_group_text" then
					return vim.treesitter.get_node_text(sub, 0):match("{(.+)}")
				end
			end
		end
	end
end

-- 'formatexpr': return 0 ("handled", i.e. do nothing) inside no-wrap
-- structures, 1 to fall back to Vim's internal formatting.
function _G.TexFormatExpr()
	local ok, node = pcall(vim.treesitter.get_node, { pos = { vim.v.lnum - 1, 0 } })
	while ok and node do
		local t = node:type()
		if t == "generic_environment" then
			local name = tex_env_name(node)
			if name and tex_no_wrap_envs[name] then
				return 0
			end
		elseif t == "inline_formula" or t == "displayed_equation" or t == "math_environment" then
			return 0
		end
		node = node:parent()
	end
	return 1
end

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("user.tex", {}),
	pattern = "tex",
	callback = function(ev)
		vim.bo[ev.buf].textwidth = 80
		vim.opt_local.formatoptions:append("tc") -- auto-wrap text and comments
		vim.opt_local.formatoptions:remove("l") -- also wrap already-long lines
		vim.bo[ev.buf].formatexpr = "v:lua.TexFormatExpr()"
	end,
})

-- =============================================================================
-- 7. Plugins (vim.pack)
-- =============================================================================
-- Build hooks. Must be defined before vim.pack.add() so they also fire on a
-- fresh install.
vim.api.nvim_create_autocmd("PackChanged", {
	group = vim.api.nvim_create_augroup("user.pack", {}),
	callback = function(ev)
		local name, kind = ev.data.spec.name, ev.data.kind
		if kind == "delete" then
			return
		end
		if name == "telescope-fzf-native.nvim" then
			vim.system({ "make" }, { cwd = ev.data.path }):wait()
		elseif kind == "update" and name == "nvim-treesitter" then
			if not ev.data.active then
				vim.cmd.packadd("nvim-treesitter")
			end
			vim.cmd("TSUpdate")
		elseif kind == "update" and (name == "tree-sitter-palmer" or name == "tree-sitter-pasm") then
			-- Own grammars: rebuild the parser from the new checkout
			require("nvim-treesitter").install({ (name:gsub("^tree%-sitter%-", "")) }, { force = true })
		end
	end,
})

local function gh(repo)
	return "https://github.com/" .. repo
end

vim.pack.add({
	-- Colorscheme & icons
	gh("jongukc/dalbit.nvim"),
	gh("nvim-tree/nvim-web-devicons"),

	-- Library (telescope, todo-comments)
	gh("nvim-lua/plenary.nvim"),

	-- Treesitter: Neovim does the highlighting; nvim-treesitter is still
	-- needed to install parsers + queries (0.12 bundles only a handful).
	{ src = gh("nvim-treesitter/nvim-treesitter"), version = "main" },
	gh("nvim-treesitter/nvim-treesitter-context"),
	"git@github.com:jongukc/tree-sitter-palmer.git",
	"git@github.com:jongukc/tree-sitter-pasm.git",

	-- Fuzzy finder
	gh("nvim-telescope/telescope.nvim"),
	gh("nvim-telescope/telescope-fzf-native.nvim"),
	gh("nvim-telescope/telescope-ui-select.nvim"),

	-- LSP server installer, formatters & linters
	gh("mason-org/mason.nvim"),
	gh("nvimtools/none-ls.nvim"),
	gh("nvimtools/none-ls-extras.nvim"),

	-- UI
	gh("nvim-lualine/lualine.nvim"),
	gh("lukas-reineke/indent-blankline.nvim"),
	gh("folke/which-key.nvim"),
	gh("folke/todo-comments.nvim"),
	gh("catgoose/nvim-colorizer.lua"),
	gh("OXY2DEV/markview.nvim"),

	-- Git
	gh("lewis6991/gitsigns.nvim"),
	gh("tpope/vim-fugitive"),
	gh("tpope/vim-rhubarb"),

	-- Editing
	gh("tpope/vim-sleuth"),
	gh("windwp/nvim-autopairs"),
	{ src = gh("jake-stewart/multicursor.nvim"), version = "1.0" },
	gh("kiyoon/Korean-IME.nvim"),

	-- Tools
	gh("christoomey/vim-tmux-navigator"),
	gh("stevearc/oil.nvim"),
	gh("lervag/vimtex"),
}, { confirm = false })

vim.cmd.colorscheme("dalbit")

-- =============================================================================
-- 8. Treesitter
-- =============================================================================
local ts_parsers = {
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
	"palmer",
	"pasm", -- own grammars (registered by their plugin/ files)
}
local ts_no_indent = { tex = true, palmer = true, pasm = true }

-- Install missing parsers (async; no-op when all are present). Deferred to
-- VimEnter so plugin/ files -- which register palmer/pasm -- have been sourced.
vim.api.nvim_create_autocmd("VimEnter", {
	group = vim.api.nvim_create_augroup("user.ts_install", {}),
	once = true,
	callback = function()
		require("nvim-treesitter").install(ts_parsers)
	end,
})

-- Start highlighting (+ indentation) for every filetype these parsers serve,
-- e.g. `typescriptreact` -> tsx, `tex` -> latex. The language is resolved
-- when the event fires: nvim-treesitter registers those filetype mappings in
-- its plugin/ file, which is sourced only after init.lua.
local ts_langs = {}
for _, lang in ipairs(ts_parsers) do
	ts_langs[lang] = true
end
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("user.ts_start", {}),
	callback = function(ev)
		if not ts_langs[vim.treesitter.language.get_lang(ev.match)] then
			return
		end
		if pcall(vim.treesitter.start, ev.buf) and not ts_no_indent[ev.match] then
			vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end
	end,
})

-- Sticky scroll: pin the enclosing function/class header at the top
local ts_context = require("treesitter-context")
ts_context.setup({
	max_lines = 3, -- cap context height so it doesn't steal the screen
	min_window_height = 20, -- disable on very short windows
	multiline_threshold = 1, -- collapse multi-line signatures into one line
})
map("n", "<leader>tc", ts_context.toggle, { desc = "[T]oggle [C]ontext" })
map("n", "[c", function()
	ts_context.go_to_context(vim.v.count1)
end, { desc = "Jump to context" })

-- =============================================================================
-- 9. LSP & Mason
-- =============================================================================
-- Mason only installs the binaries (and puts them on $PATH); Neovim's own
-- vim.lsp.config()/vim.lsp.enable() run them. Server definitions that used to
-- come from nvim-lspconfig are inlined below.
require("mason").setup()

local mason_packages = {
	-- LSP servers
	"clangd",
	"typescript-language-server",
	"basedpyright",
	"ruff",
	"html-lsp",
	"css-lsp",
	"tailwindcss-language-server",
	"dockerfile-language-server",
	"sqlls",
	"terraform-ls",
	"json-lsp",
	"yaml-language-server",
	"lua-language-server",
	-- Formatters & linters (used by none-ls)
	"stylua",
	"prettier",
	"eslint_d",
	"shfmt",
	"checkmake",
}
vim.api.nvim_create_autocmd("VimEnter", {
	group = vim.api.nvim_create_augroup("user.mason_install", {}),
	once = true,
	callback = function()
		local registry = require("mason-registry")
		registry.refresh(function()
			for _, name in ipairs(mason_packages) do
				local ok, pkg = pcall(registry.get_package, name)
				if ok and not pkg:is_installed() and not pkg:is_installing() then
					pkg:install()
				end
			end
		end)
	end,
})

-- Is there a package.json above `bufnr` that depends on tailwindcss?
local function tailwind_pkg_root(bufnr)
	local pkg = vim.fs.find("package.json", { path = vim.api.nvim_buf_get_name(bufnr), upward = true })[1]
	if pkg then
		local f = io.open(pkg)
		if f then
			local text = f:read("*a")
			f:close()
			if text:find('"tailwindcss"') then
				return vim.fs.dirname(pkg)
			end
		end
	end
end

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
		filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
		root_markers = {
			".clangd",
			".clang-tidy",
			".clang-format",
			"compile_commands.json",
			"compile_flags.txt",
			"configure.ac",
			".git",
		},
		get_language_id = function(_, ft)
			return ({ objc = "objective-c", objcpp = "objective-cpp", cuda = "cuda-cpp" })[ft] or ft
		end,
		init_options = {
			usePlaceholders = true,
			completeUnimported = true,
			clangdFileStatus = true,
		},
	},
	ts_ls = {
		cmd = { "typescript-language-server", "--stdio" },
		filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
		root_markers = {
			{ "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" },
			{ ".git" },
		},
		init_options = { hostInfo = "neovim" },
	},
	-- Python: basedpyright handles types/hover/definitions/workspace-symbols;
	-- ruff handles linting + formatting.
	basedpyright = {
		cmd = { "basedpyright-langserver", "--stdio" },
		filetypes = { "python" },
		root_markers = {
			"pyrightconfig.json",
			"pyproject.toml",
			"setup.py",
			"setup.cfg",
			"requirements.txt",
			"Pipfile",
			".git",
		},
		settings = {
			basedpyright = { analysis = { typeCheckingMode = "standard" } },
		},
	},
	ruff = {
		cmd = { "ruff", "server" },
		filetypes = { "python" },
		root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
	},
	html = {
		cmd = { "vscode-html-language-server", "--stdio" },
		filetypes = { "html", "twig", "hbs" },
		root_markers = { "package.json", ".git" },
		init_options = {
			provideFormatter = true,
			embeddedLanguages = { css = true, javascript = true },
			configurationSection = { "html", "css", "javascript" },
		},
	},
	cssls = {
		cmd = { "vscode-css-language-server", "--stdio" },
		filetypes = { "css", "scss", "less" },
		root_markers = { "package.json", ".git" },
		init_options = { provideFormatter = true },
		settings = {
			css = { validate = true },
			scss = { validate = true },
			less = { validate = true },
		},
	},
	-- Only starts inside a Tailwind project (config file, or a package.json
	-- that depends on tailwindcss for v4).
	tailwindcss = {
		cmd = { "tailwindcss-language-server", "--stdio" },
		filetypes = {
			"html",
			"htmldjango",
			"markdown",
			"mdx",
			"php",
			"twig",
			"handlebars",
			"hbs",
			"css",
			"less",
			"postcss",
			"sass",
			"scss",
			"javascript",
			"javascriptreact",
			"typescript",
			"typescriptreact",
			"vue",
			"svelte",
			"astro",
			"templ",
		},
		workspace_required = true,
		root_dir = function(bufnr, on_dir)
			local root = vim.fs.root(bufnr, {
				"tailwind.config.js",
				"tailwind.config.cjs",
				"tailwind.config.mjs",
				"tailwind.config.ts",
				"postcss.config.js",
				"postcss.config.cjs",
				"postcss.config.mjs",
				"postcss.config.ts",
			}) or tailwind_pkg_root(bufnr)
			if root then
				on_dir(root)
			end
		end,
		settings = {
			tailwindCSS = {
				validate = true,
				classAttributes = { "class", "className", "class:list", "classList", "ngClass" },
			},
		},
	},
	dockerls = {
		cmd = { "docker-langserver", "--stdio" },
		filetypes = { "dockerfile" },
		root_markers = { "Dockerfile" },
	},
	sqlls = {
		cmd = { "sql-language-server", "up", "--method", "stdio" },
		filetypes = { "sql", "mysql" },
		root_markers = { ".sqllsrc.json" },
	},
	terraformls = {
		cmd = { "terraform-ls", "serve" },
		filetypes = { "terraform", "terraform-vars" },
		root_markers = { ".terraform", ".git" },
	},
	jsonls = {
		cmd = { "vscode-json-language-server", "--stdio" },
		filetypes = { "json", "jsonc" },
		root_markers = { ".git" },
		init_options = { provideFormatter = true },
	},
	yamlls = {
		cmd = { "yaml-language-server", "--stdio" },
		filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab", "yaml.helm-values" },
		root_markers = { ".git" },
		settings = { redhat = { telemetry = { enabled = false } } },
	},
	lua_ls = {
		cmd = { "lua-language-server" },
		filetypes = { "lua" },
		root_markers = {
			{ ".emmyrc.json", ".luarc.json", ".luarc.jsonc" },
			{ ".luacheckrc", ".stylua.toml", "stylua.toml", "selene.toml", "selene.yml" },
			{ ".git" },
		},
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

for name, cfg in pairs(servers) do
	vim.lsp.config(name, cfg)
end
vim.lsp.enable(vim.tbl_keys(servers))

-- LSP progress -> native progress messages (replaces fidget.nvim)
vim.api.nvim_create_autocmd("LspProgress", {
	group = vim.api.nvim_create_augroup("user.lsp_progress", {}),
	callback = function(ev)
		local value = ev.data.params.value
		if type(value) ~= "table" or not value.kind then
			return -- not a work-done progress report
		end
		vim.api.nvim_echo({ { value.message or (value.kind == "end" and "done" or "") } }, false, {
			id = ("lsp.%d.%s"):format(ev.data.client_id, ev.data.params.token),
			kind = "progress",
			source = "vim.lsp",
			title = value.title,
			status = value.kind == "end" and "success" or "running",
			percent = value.percentage,
		})
	end,
})

-- Keymaps & behaviour on attach. Neovim also provides these defaults:
--   grn rename · gra code action · grr references · gri implementation
--   grt type definition · gO document symbols · K hover · <C-s> signature help
local lsp_on_attach -- set up in section 11 (completion)
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("user.lsp_attach", {}),
	callback = function(ev)
		local buf = ev.buf
		local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
		local tb = require("telescope.builtin")
		local function lmap(keys, func, desc, mode)
			map(mode or "n", keys, func, { buf = buf, desc = "LSP: " .. desc })
		end

		lmap("gd", tb.lsp_definitions, "[G]oto [D]efinition")
		lmap("gr", tb.lsp_references, "[G]oto [R]eferences")
		lmap("gI", tb.lsp_implementations, "[G]oto [I]mplementation")
		lmap("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
		lmap("<leader>D", tb.lsp_type_definitions, "Type [D]efinition")
		lmap("<leader>ds", tb.lsp_document_symbols, "[D]ocument [S]ymbols")
		lmap("<leader>ws", tb.lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")
		lmap("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
		lmap("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction", { "n", "x" })

		-- Highlight references of the word under the cursor
		if client:supports_method("textDocument/documentHighlight", buf) then
			local hl_group = vim.api.nvim_create_augroup("user.lsp_highlight", { clear = false })
			vim.api.nvim_clear_autocmds({ group = hl_group, buf = buf })
			vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
				group = hl_group,
				buf = buf,
				callback = vim.lsp.buf.document_highlight,
			})
			vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				group = hl_group,
				buf = buf,
				callback = vim.lsp.buf.clear_references,
			})
			vim.api.nvim_create_autocmd("LspDetach", {
				group = hl_group,
				buf = buf,
				callback = function()
					vim.lsp.buf.clear_references()
					vim.api.nvim_clear_autocmds({ group = hl_group, buf = buf })
				end,
			})
		end

		if client:supports_method("textDocument/inlayHint", buf) then
			lmap("<leader>th", function()
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }), { bufnr = buf })
			end, "[T]oggle Inlay [H]ints")
		end

		-- Keep `gq` driven by textwidth (not the LSP formatter) for prose.
		local ft = vim.bo[buf].filetype
		if ft == "tex" or ft == "plaintex" then
			vim.bo[buf].formatexpr = "v:lua.TexFormatExpr()"
		elseif ft == "markdown" or ft == "text" then
			vim.bo[buf].formatexpr = ""
		end

		lsp_on_attach(client, buf)
	end,
})

-- =============================================================================
-- 10. Formatting & linting (none-ls)
-- =============================================================================
do
	local null_ls = require("null-ls")
	local formatting = null_ls.builtins.formatting
	local diagnostics = null_ls.builtins.diagnostics
	local format_group = vim.api.nvim_create_augroup("user.format_on_save", {})

	null_ls.setup({
		sources = {
			diagnostics.checkmake,
			formatting.prettier.with({ filetypes = { "html", "json", "yaml", "markdown" } }),
			formatting.stylua,
			formatting.shfmt.with({ args = { "-i", "4" } }),
			formatting.terraform_fmt,
			require("none-ls.formatting.ruff").with({ extra_args = { "--extend-select", "I" } }),
			require("none-ls.formatting.ruff_format"),
		},
		-- Format on save wherever none-ls attaches (<leader>sn saves without)
		on_attach = function(client, bufnr)
			if client:supports_method("textDocument/formatting") then
				vim.api.nvim_clear_autocmds({ group = format_group, buf = bufnr })
				vim.api.nvim_create_autocmd("BufWritePre", {
					group = format_group,
					buf = bufnr,
					callback = function()
						vim.lsp.buf.format({ async = false })
					end,
				})
			end
		end,
	})
end

-- =============================================================================
-- 11. Completion & snippets (built-in; replaces nvim-cmp + LuaSnip)
-- =============================================================================
-- * LSP buffers: vim.lsp.completion pops up the menu as you type and, on
--   accept, applies snippets (vim.snippet), auto-imports and other edits.
-- * Other file buffers: 'autocomplete' offers words from open buffers.
-- Paths: <C-x><C-f>.  All ins-completion modes still work via <C-x>.
local kind_icons = {
	Text = "󰉿",
	Method = "m",
	Function = "󰊕",
	Constructor = "",
	Field = "",
	Variable = "󰆧",
	Class = "󰌗",
	Interface = "",
	Module = "",
	Property = "",
	Unit = "",
	Value = "󰎠",
	Enum = "",
	Keyword = "󰌋",
	Snippet = "",
	Color = "󰏘",
	File = "󰈙",
	Reference = "",
	Folder = "󰉋",
	EnumMember = "",
	Constant = "󰇽",
	Struct = "",
	Event = "",
	Operator = "󰆕",
	TypeParameter = "󰊄",
}

local function has_lsp_completion(buf)
	return #vim.lsp.get_clients({ bufnr = buf, method = "textDocument/completion" }) > 0
end

-- Word-buffer autocompletion for regular files without an LSP completer
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("user.autocomplete", {}),
	callback = function(ev)
		if vim.bo[ev.buf].buftype == "" and not has_lsp_completion(ev.buf) then
			vim.bo[ev.buf].autocomplete = true
		end
	end,
})

lsp_on_attach = function(client, buf)
	if not client:supports_method("textDocument/completion", buf) then
		return
	end
	-- Trigger on every identifier character, not just the server's own
	-- trigger characters such as "." -- like nvim-cmp did.
	local provider = client.server_capabilities.completionProvider
	local triggers = provider.triggerCharacters or {}
	for c in ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"):gmatch(".") do
		if not vim.list_contains(triggers, c) then
			triggers[#triggers + 1] = c
		end
	end
	provider.triggerCharacters = triggers

	vim.lsp.completion.enable(true, client.id, buf, {
		autotrigger = true,
		convert = function(item)
			local kind = vim.lsp.protocol.CompletionItemKind[item.kind] or ""
			return { kind = kind_icons[kind] or kind, menu = "[LSP]" }
		end,
	})
	vim.bo[buf].autocomplete = false -- LSP menu takes over from word completion
end

local function pum_visible()
	return vim.fn.pumvisible() == 1
end
local expr = { expr = true, silent = true }

-- Navigate the menu
map("i", "<C-j>", function()
	return pum_visible() and "<C-n>" or "<C-j>"
end, expr)
map("i", "<C-k>", function()
	return pum_visible() and "<C-p>" or "<C-k>"
end, expr)

-- Accept (the first item if none is selected yet)
map("i", "<C-e>", function()
	if not pum_visible() then
		return "<C-e>"
	end
	return vim.fn.complete_info({ "selected" }).selected == -1 and "<C-n><C-y>" or "<C-y>"
end, expr)

-- Open the menu manually
map("i", "<C-Space>", function()
	if has_lsp_completion(0) then
		vim.lsp.completion.get()
	else
		vim.api.nvim_feedkeys(vim.keycode("<C-n>"), "n", false)
	end
end, { desc = "Trigger completion" })

-- <Tab>/<S-Tab>: next/prev item, else jump through snippet placeholders
map({ "i", "s" }, "<Tab>", function()
	if pum_visible() then
		return "<C-n>"
	elseif vim.snippet.active({ direction = 1 }) then
		return "<Cmd>lua vim.snippet.jump(1)<CR>"
	end
	return "<Tab>"
end, expr)
map({ "i", "s" }, "<S-Tab>", function()
	if pum_visible() then
		return "<C-p>"
	elseif vim.snippet.active({ direction = -1 }) then
		return "<Cmd>lua vim.snippet.jump(-1)<CR>"
	end
	return "<S-Tab>"
end, expr)

-- <C-l>/<C-h>: jump forward/backward through snippet placeholders
map({ "i", "s" }, "<C-l>", function()
	if vim.snippet.active({ direction = 1 }) then
		vim.snippet.jump(1)
	end
end, { desc = "Snippet: next placeholder" })
map({ "i", "s" }, "<C-h>", function()
	if vim.snippet.active({ direction = -1 }) then
		vim.snippet.jump(-1)
	end
end, { desc = "Snippet: previous placeholder" })

-- =============================================================================
-- 12. Telescope
-- =============================================================================
do
	local telescope = require("telescope")
	local actions = require("telescope.actions")
	local themes = require("telescope.themes")
	local builtin = require("telescope.builtin")

	telescope.setup({
		defaults = {
			mappings = {
				i = {
					["<C-k>"] = actions.move_selection_previous,
					["<C-j>"] = actions.move_selection_next,
					["<C-l>"] = actions.select_default,
				},
			},
		},
		pickers = {
			find_files = {
				-- every file, also the ones .gitignore lists; not those inside .git
				file_ignore_patterns = { "node_modules", "%.git/", "%.venv" },
				hidden = true,
				no_ignore = true,
			},
			live_grep = {
				file_ignore_patterns = { "node_modules", "%.git", "%.venv" },
				additional_args = { "--hidden" },
			},
		},
		extensions = {
			["ui-select"] = { themes.get_dropdown() },
		},
	})
	pcall(telescope.load_extension, "fzf")
	pcall(telescope.load_extension, "ui-select")

	map("n", "<leader>sh", builtin.help_tags, { desc = "[S]earch [H]elp" })
	map("n", "<leader>sk", builtin.keymaps, { desc = "[S]earch [K]eymaps" })
	map("n", "<leader>sf", builtin.find_files, { desc = "[S]earch [F]iles" })
	map("n", "<leader>ss", builtin.builtin, { desc = "[S]earch [S]elect Telescope" })
	map("n", "<leader>sw", builtin.grep_string, { desc = "[S]earch current [W]ord" })
	map("n", "<leader>sg", builtin.live_grep, { desc = "[S]earch by [G]rep" })
	map("n", "<leader>sd", builtin.diagnostics, { desc = "[S]earch [D]iagnostics" })
	map("n", "<leader>sr", builtin.resume, { desc = "[S]earch [R]esume" })
	map("n", "<leader>s.", builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
	map("n", "<leader><leader>", builtin.buffers, { desc = "[ ] Find existing buffers" })
	map("n", "<leader>/", function()
		builtin.current_buffer_fuzzy_find(themes.get_dropdown({ winblend = 10, previewer = false }))
	end, { desc = "[/] Fuzzily search in current buffer" })
	map("n", "<leader>s/", function()
		builtin.live_grep({ grep_open_files = true, prompt_title = "Live Grep in Open Files" })
	end, { desc = "[S]earch [/] in Open Files" })
end

-- =============================================================================
-- 13. UI: statusline, indent guides, misc
-- =============================================================================
-- ---- lualine -----------------------------------------------------------------
do
	local function wide()
		return vim.fn.winwidth(0) > 100
	end

	-- Korean-IME mode, once the IME has been loaded (first <F12>)
	local function ime_mode()
		if not package.loaded["korean_ime"] then
			return ""
		end
		return ({ en = "A ", ko = "한" })[require("korean_ime").get_mode()] or ""
	end

	require("lualine").setup({
		options = {
			theme = "auto",
			section_separators = { left = "", right = "" },
			component_separators = { left = "", right = "" },
		},
		sections = {
			lualine_a = { "mode" },
			lualine_b = { "branch" },
			lualine_c = { { "filename", path = 0 } },
			lualine_x = {
				{
					"diagnostics",
					sections = { "error", "warn" },
					symbols = { error = " ", warn = " ", info = " ", hint = " " },
					colored = false,
					cond = wide,
				},
				{
					"diff",
					colored = false,
					symbols = { added = " ", modified = " ", removed = " " },
					cond = wide,
				},
				{ "encoding", cond = wide },
				{ "filetype", cond = wide },
			},
			lualine_y = { "location" },
			lualine_z = { "progress", ime_mode },
		},
		inactive_sections = {
			lualine_a = {},
			lualine_b = {},
			lualine_c = { { "filename", path = 1 } },
			lualine_x = { { "location", padding = 0 } },
			lualine_y = {},
			lualine_z = {},
		},
		extensions = { "fugitive" },
	})
end

-- ---- indent guides -----------------------------------------------------------
require("ibl").setup({
	indent = { char = "▏" },
	scope = { show_start = false, show_end = false, show_exact_scope = false },
})

-- ---- which-key, todo-comments, colorizer -------------------------------------
require("which-key").setup({})
require("todo-comments").setup({ signs = false })
require("colorizer").setup()

-- ---- markview ----------------------------------------------------------------
require("markview").setup({ preview = { enable = true, wrap = true } })
map("n", "<leader>m", "<cmd>Markview<CR>", { desc = "Toggle markview previews globally" })
map("n", "<leader>ms", "<cmd>Markview splitToggle<CR>", { desc = "Toggle markview splitview" })

-- =============================================================================
-- 14. Git
-- =============================================================================
map("n", "<leader>gs", vim.cmd.Git, { desc = "Fugitive status" })

do
	local signs = {
		add = { text = "+" },
		change = { text = "~" },
		delete = { text = "_" },
		topdelete = { text = "‾" },
		changedelete = { text = "~" },
	}
	require("gitsigns").setup({
		signs = signs,
		signs_staged = signs,
		current_line_blame = true,
		on_attach = function(bufnr)
			local gs = require("gitsigns")
			map("n", "<leader>hp", gs.preview_hunk, { buf = bufnr, desc = "Preview git hunk" })
			map("n", "<leader>hb", gs.blame_line, { buf = bufnr, desc = "Blame line" })
		end,
	})
end

-- =============================================================================
-- 15. Editing
-- =============================================================================
require("nvim-autopairs").setup({})

-- ---- undotree (built-in since 0.12; replaces jiaoshijie/undotree) ------------
vim.cmd.packadd("nvim.undotree")
map("n", "<leader>u", function()
	require("undotree").open()
end, { desc = "Toggle undotree" })

-- ---- multicursor -------------------------------------------------------------
do
	local mc = require("multicursor-nvim")
	mc.setup()

	-- Add or skip a cursor above/below the main cursor
	map({ "n", "x" }, "<leader><up>", function()
		mc.lineSkipCursor(-1)
	end)
	map({ "n", "x" }, "<leader><down>", function()
		mc.lineSkipCursor(1)
	end)

	-- Add a cursor at the next/previous match of the word/selection
	map({ "n", "x" }, "<leader>n", function()
		mc.matchAddCursor(1)
	end, { desc = "Add cursor to next match" })
	map({ "n", "x" }, "<leader>p", function()
		mc.matchAddCursor(-1)
	end, { desc = "Add cursor to previous match" })

	-- Add and remove cursors with control + left click
	map("n", "<C-LeftMouse>", mc.handleMouse)
	map("n", "<C-LeftDrag>", mc.handleMouseDrag)
	map("n", "<C-LeftRelease>", mc.handleMouseRelease)

	-- These only apply while there are multiple cursors
	mc.addKeymapLayer(function(layer)
		layer({ "n", "x" }, "<Left>", mc.prevCursor)
		layer({ "n", "x" }, "<Right>", mc.nextCursor)
		layer({ "n", "x" }, "<leader>x", mc.deleteCursor)
		layer("n", "<Esc>", function()
			if not mc.cursorsEnabled() then
				mc.enableCursors()
			else
				mc.clearCursors()
			end
		end)
	end)

	local hl = vim.api.nvim_set_hl
	hl(0, "MultiCursorCursor", { reverse = true })
	hl(0, "MultiCursorVisual", { link = "Visual" })
	hl(0, "MultiCursorSign", { link = "SignColumn" })
	hl(0, "MultiCursorMatchPreview", { link = "Search" })
	hl(0, "MultiCursorDisabledCursor", { reverse = true })
	hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
	hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
end

-- ---- Korean IME (loaded on the first <F12>) ----------------------------------
do
	local ready = false
	local function ime()
		local korean_ime = require("korean_ime")
		if not ready then
			ready = true
			korean_ime.setup()
			map("i", "<F9>", korean_ime.convert_hanja, { silent = true, desc = "한자" })
		end
		return korean_ime
	end
	map({ "i", "n", "x", "s" }, "<F12>", function()
		ime().change_mode()
	end, { desc = "한/영" })
end

-- =============================================================================
-- 16. Tools
-- =============================================================================
-- ---- tmux / split navigation -------------------------------------------------
vim.g.tmux_navigator_no_mappings = 1
map({ "n", "t" }, "<M-h>", "<cmd>TmuxNavigateLeft<CR>", silent)
map({ "n", "t" }, "<M-j>", "<cmd>TmuxNavigateDown<CR>", silent)
map({ "n", "t" }, "<M-k>", "<cmd>TmuxNavigateUp<CR>", silent)
map({ "n", "t" }, "<M-l>", "<cmd>TmuxNavigateRight<CR>", silent)

-- ---- oil (file explorer; replaces netrw) -------------------------------------
do
	local oil = require("oil")
	oil.setup({
		default_file_explorer = true,
		view_options = { show_hidden = true },
		columns = { "icon", "permissions", "size", "mtime" },
	})

	-- Apply changes on :w without the confirmation popup -- for every kind of
	-- edit, deletes included. (`skip_confirm_for_simple_edits` still asks for
	-- deletes and multi-file moves.) Oil's :w handler calls oil.save(nil, ...),
	-- so default `confirm` to false there; an explicit value still wins.
	local save = oil.save
	oil.save = function(opts, cb)
		return save(vim.tbl_extend("keep", opts or {}, { confirm = false }), cb)
	end
end
map("n", "<leader>e", "<cmd>Oil<CR>", { desc = "Open Oil" })

-- ---- vimtex ------------------------------------------------------------------
vim.g.vimtex_syntax_enabled = 1
vim.g.vimtex_quickfix_mode = 0

-- Use paperhere-forward for remote sessions, zathura directly for local
do
	local forward = vim.env.HOME .. "/bin/paperhere-forward"
	if vim.fn.filereadable(forward) == 1 and vim.env.PAPERHERE_SESSION then
		vim.g.vimtex_view_method = "general"
		vim.g.vimtex_view_general_viewer = forward
		vim.g.vimtex_view_general_options = "@line:@col:@tex @pdf"
	else
		vim.g.vimtex_view_method = "zathura_simple"
	end

	-- Auto-rebuild on save when PAPERHERE_BUILD_CMD is set
	local build_cmd = vim.env.PAPERHERE_BUILD_CMD
	if build_cmd then
		vim.api.nvim_create_autocmd("BufWritePost", {
			group = vim.api.nvim_create_augroup("user.paperhere", {}),
			pattern = "*.tex",
			callback = function()
				vim.fn.jobstart(build_cmd)
			end,
		})
	end
end
