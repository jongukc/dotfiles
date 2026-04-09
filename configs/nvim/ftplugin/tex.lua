-- Auto-wrap text and comments at 80 columns, but not inside
-- tables, math environments, listings, or other structures.

vim.opt_local.textwidth = 80
vim.opt_local.formatoptions:append("t") -- auto-wrap text using textwidth
vim.opt_local.formatoptions:append("c") -- auto-wrap comments using textwidth
vim.opt_local.formatoptions:remove("l") -- allow wrapping of already-long lines

vim.bo.formatexpr = "v:lua.TexFormatExpr()"

-- Environments where auto-wrapping should be suppressed
local no_wrap_envs = {
	tabular = true, ["tabular*"] = true, tabularx = true, tabulary = true,
	longtable = true, array = true, table = true,
	align = true, ["align*"] = true,
	equation = true, ["equation*"] = true,
	gather = true, ["gather*"] = true,
	multline = true, ["multline*"] = true,
	flalign = true, ["flalign*"] = true,
	split = true, aligned = true, gathered = true,
	lstlisting = true, verbatim = true, ["verbatim*"] = true, minted = true,
	tikzpicture = true,
	matrix = true, bmatrix = true, pmatrix = true, vmatrix = true, Bmatrix = true, Vmatrix = true,
}

-- Extract the environment name from a generic_environment treesitter node
local function get_env_name(env_node)
	for child in env_node:iter_children() do
		if child:type() == "begin" then
			for subchild in child:iter_children() do
				if subchild:type() == "curly_group_text" then
					local text = vim.treesitter.get_node_text(subchild, 0)
					return text:match("{(.+)}")
				end
			end
		end
	end
	return nil
end

function _G.TexFormatExpr()
	local lnum = vim.v.lnum

	local ok, node = pcall(vim.treesitter.get_node, { pos = { lnum - 1, 0 } })
	if ok and node then
		local cur = node
		while cur do
			local ntype = cur:type()
			if ntype == "generic_environment" then
				local name = get_env_name(cur)
				if name and no_wrap_envs[name] then
					return 0 -- we "handled" it (by doing nothing)
				end
			elseif ntype == "inline_formula"
				or ntype == "displayed_equation"
				or ntype == "math_environment" then
				return 0
			end
			cur = cur:parent()
		end
	end

	-- Normal text or comments: fall back to Vim's internal formatting
	return 1
end
