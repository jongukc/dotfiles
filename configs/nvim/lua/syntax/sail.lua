-- Location: ~/.config/nvim/syntax/sail.lua

-- 1. Boilerplate: Stop if syntax is already loaded for this buffer
if vim.b.current_syntax then
	return
end

-- 2. Set 'iskeyword' (local to buffer)
vim.opt_local.iskeyword = "@,48-57,_,192-255"

-- 3. Define Keywords
local keywords = {
	identifier = [[
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

for group, words in pairs(keywords) do
	local flat_words = words:gsub("\n", " ")
	vim.cmd(string.format("syntax keyword %s %s", group, flat_words))
end

-- 4. Define Matches and Regions (Regex)
local matches = {
	[[syntax match sailNumber "\<0b[0-1_]\+\>"]],
	[[syntax match sailNumber "\<0x[0-9a-fA-F_]\+\>"]],
	[[syntax match sailNumber "\<[-+]\?[0-9]\+\>"]],
	[[syntax match sailNumber "\<[+-]\=[0-9]\+\(\.[0-9]*\|\)\>"]],
	[[syntax match sailConstant "\<[A-Z][A-Z0-9_]\+\>"]],
	[[syntax match sailPragma "$[a-zA-Z0-9_]\+\>"]],
	[[syntax match sailPragma "$include .*"]],
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

-- 5. Linking Highlights
local highlights = {
	sailNumber = "Number",
	sailComment = "Comment",
	sailPragma = "PreProc",
	sailString = "String",
	sailConstant = "Constant",
	sailTodo = "Todo",
	sailFilename = "String",
	sailKind = "Type",
	sailType = "Type",
	sailSpecial = "PreProc",
	identifier = "Keyword",
	sailEscape = "Special",
}

for group, link in pairs(highlights) do
	vim.api.nvim_set_hl(0, group, { link = link, default = true })
end

vim.b.current_syntax = "sail"
