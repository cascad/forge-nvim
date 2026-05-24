-- Default colorscheme: tokyonight (moon variant).
-- Loaded early with priority so it wins over any plugin that touches highlights.

return {
    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        opts = {
            style = "moon",        -- "night" | "storm" | "moon" | "day"
            transparent = false,
            terminal_colors = true,
            styles = {
                comments = { italic = true },
                keywords = { italic = true },
            },
            on_highlights = function(hl, c)
                -- Nicer sidebar background to match nvim-ide panels.
                hl.NormalSB = { bg = c.bg_dark }
                hl.WinSeparator = { fg = c.bg_dark }
            end,
        },
        config = function(_, opts)
            require("tokyonight").setup(opts)
            vim.cmd.colorscheme("tokyonight-moon")
        end,
    },
}
