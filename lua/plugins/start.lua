-- Startup greeter: recent projects / sessions / fast open.

return {
    {
        "goolord/alpha-nvim",
        event = "VimEnter",
        cmd = "Alpha",
        keys = {
            { "<leader>oh", function() require("config.start").open_home() end, desc = "Open: home" },
        },
        dependencies = {
            "ahmedkhalf/project.nvim",
            "folke/persistence.nvim",
            "nvim-tree/nvim-web-devicons",
        },
        opts = function()
            local dashboard = require("alpha.themes.dashboard")
            local start = require("config.start")

            dashboard.section.header.val = {
                "NVIM IDE",
                "",
                "Recent projects",
            }
            dashboard.section.buttons.val = start.buttons(dashboard)
            dashboard.section.footer.val = start.footer()

            dashboard.config.opts.noautocmd = true
            -- alpha-nvim keeps its own window id for resize redraws. On fast
            -- jumps/window changes that id can already be gone; disabling this
            -- official redraw hook avoids noisy WinResized errors.
            dashboard.config.opts.redraw_on_resize = false
            return dashboard.config
        end,
        config = function(_, opts)
            require("alpha").setup(opts)
        end,
    },
}
