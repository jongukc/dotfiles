-- ~/.config/nvim/syntax/sail.lua

-- 1. Boilerplate: Stop if syntax is already loaded, but allow force reloading
if vim.b.current_syntax then
	return
end

-- 2. Clear existing syntax (Crucial for reloading)
vim.cmd("syntax clear")

-- 3. Set 'iskeyword' to ensure _, numbers, and @ are treated as word parts
vim.opt_local.iskeyword = "@,48-57,_,192-255"

-- 4. Define Keywords
-- We rename 'identifier' to 'sailKeyword' to avoid conflict with the built-in 'Identifier' group.
local keywords = {
	sailKeyword = [[
    val function type struct union enum let var if then by
    else match in return register ref forall operator effect
    overload cast sizeof constant constraint default assert newtype from
    pure impure infixl infixr infix scattered end try catch and to
    throw clause as repeat until while do foreach bitfield
    mapping where with implicit outcome instantiation impl
    private mutual termination_measure forwards backwards
  ]],
	sailKind = [[
    Int Nat Type Order Bool inc dec
    barr depend rreg wreg rmem rmemt wmv wmvt eamem wmem
    exmem undef unspec nondet escape configuration
  ]],
	sailType = [[
    vector bitvector int nat atom range unit bit real list bool string bits option
    uint64_t int64_t bv_t mpz_t
  ]],
	sailSpecial = [[
    _prove _not_prove create kill convert undefined exit
  ]],
	sailConstant = [[
    true false bitzero bitone
  ]],
	sailTodo = [[
    TODO FIXME XXX
  ]],
}

-- Apply keywords: We use "%s+" to replace ALL whitespace (newlines, tabs) with single spaces
for group, words in pairs(keywords) do
	local flat_words = words:gsub("%s+", " ")
	vim.cmd(string.format("syntax keyword %s %s", group, flat_words))
end

-- 5. Define Matches (Regex)
local matches = {
	[[syntax match sailNumber "\<0b[0-1_]\+\>"]],
	[[syntax match sailNumber "\<0x[0-9a-fA-F_]\+\>"]],
	[[syntax match sailNumber "\<[-+]\?[0-9]\+\>"]],
	[[syntax match sailNumber "\<[+-]\=[0-9]\+\(\.[0-9]*\|\)\>"]],

	-- Matches must be carefully ordered if they overlap, but these are distinct.
	[[syntax match sailConstant "\<[A-Z][A-Z0-9_]\+\>"]],
	[[syntax match sailPragma "$[a-zA-Z0-9_]\+\>"]],
	[[syntax match sailPragma "$include .*"]],

	-- Comments and Strings
	[[syntax region sailComment start="/\*" end="\*/" contains=sailTodo]],
	[[syntax match sailComment "//.*" contains=sailTodo]],

	[[syntax match sailEscape +\\[nt"\\]+ contained]],
	[[syntax match sailEscape "\\\o\o\=\o\=" contained]],
	[[syntax region sailString start=+"+ skip=+\\"+ end=+"+ contains=sailEscape]],
	[[syntax region sailFilename start=+<+ end=+>+ contained]],
}

for _, rule in ipairs(matches) do
	vim.cmd(rule)
end

-- 6. Linking Highlights
-- We map our custom 'sail...' groups to standard Neovim groups (Keyword, Type, etc.)
local highlights = {
	sailKeyword = "Keyword", -- Was 'identifier', now correctly mapped to Keyword color
	sailKind = "Type",
	sailType = "Type",
	sailNumber = "Number",
	sailComment = "Comment",
	sailPragma = "PreProc",
	sailString = "String",
	sailConstant = "Constant",
	sailTodo = "Todo",
	sailFilename = "String",
	sailSpecial = "PreProc",
	sailEscape = "Special",
}

for group, link in pairs(highlights) do
	-- 'default = true' prevents overriding if a theme explicitly supports 'sailKeyword' (rare)
	vim.api.nvim_set_hl(0, group, { link = link, default = true })
end

vim.b.current_syntax = "sail"
