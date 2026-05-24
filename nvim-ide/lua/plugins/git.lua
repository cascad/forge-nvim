-- Git: gitsigns (gutter + hunks), diffview (diff/merge), neogit (UI).
-- The nvim-ide right panel already has Changes/Commits/Branches/Timeline
-- components — these plugins complement that with editor-area UI.

return {
    -- =========================================================
    -- Gitsigns — signs in gutter + hunk operations.
    -- =========================================================
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            signs = {
                add          = { text = "▎" },
                change       = { text = "▎" },
                delete       = { text = "_" },
                topdelete    = { text = "‾" },
                changedelete = { text = "~" },
                untracked    = { text = "▎" },
            },
            current_line_blame = false,
            on_attach = function(buffer)
                local gs = package.loaded.gitsigns
                local function map(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, { buffer = buffer, desc = desc })
                end

                map("n", "]h", function()
                    if vim.wo.diff then vim.cmd.normal({ "]c", bang = true })
                    else gs.nav_hunk("next") end
                end, "Git: next hunk")
                map("n", "[h", function()
                    if vim.wo.diff then vim.cmd.normal({ "[c", bang = true })
                    else gs.nav_hunk("prev") end
                end, "Git: prev hunk")

                map({ "n", "v" }, "<leader>ghs", ":Gitsigns stage_hunk<CR>",  "Git: stage hunk")
                map({ "n", "v" }, "<leader>ghr", ":Gitsigns reset_hunk<CR>",  "Git: reset hunk")
                map("n",         "<leader>ghS", gs.stage_buffer,             "Git: stage buffer")
                map("n",         "<leader>ghu", gs.undo_stage_hunk,          "Git: undo stage")
                map("n",         "<leader>ghR", gs.reset_buffer,             "Git: reset buffer")
                map("n",         "<leader>ghp", gs.preview_hunk,             "Git: preview hunk")
                map("n",         "<leader>ghb", function() gs.blame_line({ full = true }) end, "Git: blame line")
                map("n",         "<leader>gtb", gs.toggle_current_line_blame, "Git: toggle blame")
                map("n",         "<leader>ghd", gs.diffthis,                  "Git: diff this")
                map("n",         "<leader>ghD", function() gs.diffthis("~") end, "Git: diff ~")
            end,
        },
    },

    -- =========================================================
    -- Diffview — side-by-side diff and merge tool.
    -- =========================================================
    {
        "sindrets/diffview.nvim",
        cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles" },
        keys = {
            { "<leader>gdd", "<cmd>DiffviewOpen<CR>",              desc = "Diff: open" },
            { "<leader>gdc", "<cmd>DiffviewClose<CR>",             desc = "Diff: close" },
            { "<leader>gdf", "<cmd>DiffviewFileHistory %<CR>",     desc = "Diff: file history" },
            { "<leader>gdF", "<cmd>DiffviewFileHistory<CR>",       desc = "Diff: repo history" },
        },
        opts = {
            enhanced_diff_hl = true,
            view = {
                merge_tool = { layout = "diff3_mixed" },
            },
        },
    },

    -- =========================================================
    -- Neogit — Magit-like git UI.
    -- =========================================================
    {
        "NeogitOrg/neogit",
        cmd = "Neogit",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "sindrets/diffview.nvim",
            "nvim-telescope/telescope.nvim",
        },
        keys = {
            { "<leader>gg", "<cmd>Neogit kind=tab<CR>", desc = "Neogit (tab)" },
            { "<leader>gG", "<cmd>Neogit<CR>",         desc = "Neogit (split)" },
        },
        opts = {
            integrations = { diffview = true, telescope = true },
            graph_style  = "unicode",
        },
    },

    -- =========================================================
    -- Conflict markers (=======, <<<<<<, >>>>>>).
    -- =========================================================
    {
        "akinsho/git-conflict.nvim",
        event = "BufReadPre",
        version = "*",
        opts = { default_mappings = true, disable_diagnostics = true },
        keys = {
            { "]x", "<cmd>GitConflictNextConflict<CR>",  desc = "Git: next conflict" },
            { "[x", "<cmd>GitConflictPrevConflict<CR>",  desc = "Git: prev conflict" },
            { "<leader>gco", "<cmd>GitConflictChooseOurs<CR>",  desc = "Conflict: take ours" },
            { "<leader>gct", "<cmd>GitConflictChooseTheirs<CR>", desc = "Conflict: take theirs" },
            { "<leader>gcb", "<cmd>GitConflictChooseBoth<CR>",   desc = "Conflict: take both" },
            { "<leader>gc0", "<cmd>GitConflictChooseNone<CR>",   desc = "Conflict: take none" },
        },
    },
}
