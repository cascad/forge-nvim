-- grug-far — workspace-wide find/replace with preview and history.

return {
    {
        "MagicDuck/grug-far.nvim",
        cmd = { "GrugFar", "GrugFarWithin" },
        keys = {
            { "<leader>sg", function() require("grug-far").open() end,            desc = "Search: grug-far" },
            { "<leader>sr", function() require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } }) end,
              desc = "Search: replace word under cursor" },
            { "<leader>sf", function() require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } }) end,
              desc = "Search: in current file" },
        },
        opts = {
            headerMaxWidth = 80,
            windowCreationCommand = "botright vsplit",
        },
    },
}
