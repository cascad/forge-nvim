-- Project search/replace panel.

local panels = require("config.panels")

return {
    {
        "MagicDuck/grug-far.nvim",
        cmd = { "GrugFar", "GrugFarWithin" },
        keys = {
            { "<C-S-f>",    panels.open_search,      desc = "Search: panel" },
            { "<leader>sF", panels.open_search,      desc = "Search: panel" },
            { "<leader>sR", panels.open_search,      desc = "Search: replace panel" },
            { "<leader>sV", function() vim.cmd("'<,'>GrugFarWithin") end, desc = "Search: within visual selection", mode = "v" },
        },
    },
}
