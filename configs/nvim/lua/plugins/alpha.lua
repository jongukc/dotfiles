return {
    "goolord/alpha-nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        local alpha = require("alpha")
        local dashboard = require("alpha.themes.dashboard")

        -- 1. Define Gruvbox Material Colors
        local colors = {
            orange = "#e78a4e", -- Warm header
            green  = "#a9b665", -- Chill text
            aqua   = "#89b482", -- Chill text alternative
            red    = "#ea6962", -- Pop color for keys
            grey   = "#928374", -- Subtlety
        }

        -- 2. Create Custom Highlight Groups
        vim.api.nvim_set_hl(0, "AlphaHeader",   { fg = colors.orange, bold = true })
        vim.api.nvim_set_hl(0, "AlphaButtons",  { fg = colors.aqua })
        vim.api.nvim_set_hl(0, "AlphaShortcut", { fg = colors.red, bold = true })
        vim.api.nvim_set_hl(0, "AlphaFooter",   { fg = colors.grey, italic = true })

        -- 3. The Minimalist Header
        dashboard.section.header.val = {
            [[           ]],
            [[  NEOVIM   ]],
            [[           ]],
        }
        -- Apply the orange color
        dashboard.section.header.opts.hl = "AlphaHeader"

        -- 4. The Buttons
        dashboard.section.buttons.val = {
            dashboard.button("f", "  Find File", ":Telescope find_files <CR>"),
            dashboard.button("r", "  Recent",    ":Telescope oldfiles <CR>"),
            dashboard.button("g", "  Grep Text", ":Telescope live_grep <CR>"),
            dashboard.button("u", "  Update",    ":Lazy sync <CR>"),
            dashboard.button("q", "  Quit",      ":qa<CR>"),
        }

        -- Apply colors to buttons
        for _, button in ipairs(dashboard.section.buttons.val) do
            button.opts.hl = "AlphaButtons"
            button.opts.hl_shortcut = "AlphaShortcut"
        end

        -- 5. Layout Tuning (Center it vertically)
        -- We add extra padding to the top so it feels more 'centered' and zen
        dashboard.config.layout = {
            { type = "padding", val = 8 },
            dashboard.section.header,
            { type = "padding", val = 2 },
            dashboard.section.buttons,
            { type = "padding", val = 1 },
            dashboard.section.footer,
        }

        -- 6. Setup
        alpha.setup(dashboard.opts)
    end,
}
