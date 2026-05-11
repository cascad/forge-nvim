-- Git: inline hunk actions plus a Magit-like status UI.

return {
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            signs = {
                add          = { text = "│" },
                change       = { text = "│" },
                delete       = { text = "_" },
                topdelete    = { text = "‾" },
                changedelete = { text = "~" },
                untracked    = { text = "┆" },
            },
            current_line_blame = false,
            current_line_blame_opts = { delay = 500, virt_text_pos = "eol" },
            on_attach = function(buf)
                local gs = require("gitsigns")
                local function nm(lhs, rhs, desc)
                    vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc, silent = true })
                end

                -- Hunk-навигация
                nm("]h", function() gs.nav_hunk("next") end, "Git: next hunk")
                nm("[h", function() gs.nav_hunk("prev") end, "Git: prev hunk")

                -- helix space.g — git
                nm("<leader>ghs", gs.stage_hunk,        "Git: stage hunk")
                nm("<leader>ghr", gs.reset_hunk,        "Git: reset hunk")
                nm("<leader>ghp", gs.preview_hunk,      "Git: preview hunk")
                nm("<leader>ghb", function() gs.blame_line({ full = true }) end, "Git: blame line")
                nm("<leader>ghd", gs.diffthis,          "Git: diff buffer")
                nm("<leader>ghD", function() gs.diffthis("~") end, "Git: diff buffer vs HEAD~")
                nm("<leader>ghu", gs.undo_stage_hunk,   "Git: undo stage")
                nm("<leader>ghB", gs.toggle_current_line_blame, "Git: toggle line blame")
            end,
        },
    },
    {
        "sindrets/diffview.nvim",
        cmd = {
            "DiffviewOpen",
            "DiffviewClose",
            "DiffviewFileHistory",
            "DiffviewToggleFiles",
            "DiffviewFocusFiles",
        },
        keys = {
            { "<leader>gd", "<cmd>DiffviewOpen<CR>",            desc = "Git: diff view" },
            { "<leader>gD", "<cmd>DiffviewFileHistory %<CR>",  desc = "Git: file history" },
        },
    },
    {
        "NeogitOrg/neogit",
        cmd = "Neogit",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "sindrets/diffview.nvim",
            "nvim-telescope/telescope.nvim",
        },
        keys = {
            { "<leader>gg", function() require("neogit").open({ kind = "tab" }) end,   desc = "Git: status tab" },
            { "<leader>gG", function() require("neogit").open({ kind = "split" }) end, desc = "Git: status split" },
        },
        opts = {
            kind = "tab",
            integrations = {
                diffview = true,
                telescope = true,
            },
        },
    },
}
