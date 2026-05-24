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
            { "<leader>gd", "<cmd>DiffviewOpen<CR>",           desc = "Git: changed files diff" },
            { "<leader>gD", "<cmd>DiffviewFileHistory %<CR>", desc = "Git: current file history" },
            { "<leader>gq", "<cmd>DiffviewClose<CR>",         desc = "Git: close diff view" },
            { "<leader>gF", "<cmd>DiffviewFocusFiles<CR>",    desc = "Git: focus diff files" },
        },
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = function()
            local actions = require("diffview.actions")
            local diff_modes = { "n", "i", "v", "x" }
            local function termcodes(keys)
                return vim.api.nvim_replace_termcodes(keys, true, false, true)
            end

            local function after_normal_mode(fn)
                return function()
                    local mode = vim.api.nvim_get_mode().mode
                    if mode:sub(1, 1) == "i" or mode:sub(1, 1) == "R" then
                        vim.cmd("stopinsert")
                    elseif mode ~= "n" then
                        vim.api.nvim_feedkeys(termcodes("<Esc>"), "n", false)
                    end

                    vim.schedule(fn)
                end
            end

            local function open_file_explorer()
                pcall(vim.cmd, "DiffviewClose")
                vim.schedule(function()
                    -- ide.show("explorer") вместо panels.mode_files —
                    -- последний дёргает close_activity и убил бы bottom
                    -- (debug/tests/jobs), даже если они не связаны с
                    -- Diffview. Здесь нужен ТОЛЬКО переход в explorer.
                    local ok, ide = pcall(require, "ide")
                    if ok then ide.show("explorer") end
                end)
            end

            local function apply_diff_highlights()
                local add = { bg = "#16462f", fg = "#d8ffe0" }
                local delete = { bg = "#5a1d2a", fg = "#ffd5dd" }
                local change = { bg = "#44370f", fg = "#fff1b8" }
                local text = { bg = "#b46a00", fg = "#fff7cf", bold = true }

                vim.api.nvim_set_hl(0, "DiffviewDiffAdd", add)
                vim.api.nvim_set_hl(0, "DiffviewDiffAddAsDelete", delete)
                vim.api.nvim_set_hl(0, "DiffviewDiffDelete", delete)
                vim.api.nvim_set_hl(0, "DiffviewDiffDeleteDim", { bg = "#35131b", fg = "#f38ba8" })
                vim.api.nvim_set_hl(0, "DiffviewDiffChange", change)
                vim.api.nvim_set_hl(0, "DiffviewDiffText", text)
            end

            local function set_diff_window_opts(win)
                if not win or not vim.api.nvim_win_is_valid(win) then return end

                -- Diffview uses native vim diff buffers; by default those can
                -- fold unchanged lines. For IDE-style review we keep the whole
                -- file visible and let the color highlights mark changed areas.
                vim.wo[win].foldenable = false
                vim.wo[win].foldcolumn = "0"
                vim.wo[win].wrap = false
                vim.wo[win].list = false
                vim.wo[win].relativenumber = false

                -- Keep old/new diff panes moving together, like IDE diff
                -- editors. scrollbind is native Vim behavior used by diff mode.
                vim.wo[win].scrollbind = true
                vim.wo[win].cursorbind = true
            end

            local function list_tab_wins(tab)
                local ok, wins = pcall(vim.api.nvim_tabpage_list_wins, tab or 0)
                if ok then return wins end
                return {}
            end

            local function sync_diff_windows(view)
                local scroll_opts = {}
                for opt in vim.o.scrollopt:gmatch("[^,]+") do
                    scroll_opts[opt] = true
                end
                scroll_opts.ver = true
                scroll_opts.jump = true

                local ordered = {}
                for _, opt in ipairs({ "ver", "hor", "jump" }) do
                    if scroll_opts[opt] then
                        ordered[#ordered + 1] = opt
                    end
                end
                vim.o.scrollopt = table.concat(ordered, ",")

                local tab = view and view.tabpage or 0
                for _, win in ipairs(list_tab_wins(tab)) do
                    if vim.api.nvim_win_is_valid(win) and vim.wo[win].diff then
                        set_diff_window_opts(win)
                    end
                end

                pcall(vim.cmd, "syncbind")
            end

            local function diff_window_opts()
                set_diff_window_opts(vim.api.nvim_get_current_win())
            end

            local function focus_diff_side(side)
                local wins = {}
                for _, win in ipairs(list_tab_wins(0)) do
                    if vim.api.nvim_win_is_valid(win) and vim.wo[win].diff then
                        local ok, pos = pcall(vim.api.nvim_win_get_position, win)
                        if not ok then pos = { 0, 0 } end
                        wins[#wins + 1] = { win = win, col = pos[2] or 0 }
                    end
                end

                table.sort(wins, function(a, b) return a.col < b.col end)
                local target = side == "left" and wins[1] or wins[#wins]
                if target then
                    vim.api.nvim_set_current_win(target.win)
                end
            end

            return {
                enhanced_diff_hl = true,
                show_help_hints = false,
                watch_index = true,
                view = {
                    default = {
                        layout = "diff2_horizontal",
                        disable_diagnostics = false,
                        winbar_info = true,
                    },
                    file_history = {
                        layout = "diff2_horizontal",
                        disable_diagnostics = false,
                        winbar_info = true,
                    },
                    merge_tool = {
                        layout = "diff3_horizontal",
                        disable_diagnostics = true,
                        winbar_info = true,
                    },
                },
                file_panel = {
                    listing_style = "tree",
                    tree_options = {
                        flatten_dirs = false,
                        folder_statuses = "always",
                    },
                    win_config = {
                        position = "left",
                        width = 42,
                        win_opts = {
                            cursorline = true,
                            wrap = false,
                        },
                    },
                },
                default_args = {
                    DiffviewOpen = { "--untracked-files=true" },
                },
                hooks = {
                    view_opened = function(view)
                        apply_diff_highlights()
                        vim.schedule(function()
                            sync_diff_windows(view)
                        end)
                    end,
                    view_post_layout = function(view)
                        apply_diff_highlights()
                        vim.schedule(function()
                            sync_diff_windows(view)
                        end)
                    end,
                    diff_buf_read = function()
                        apply_diff_highlights()
                        diff_window_opts()
                    end,
                    diff_buf_win_enter = function()
                        apply_diff_highlights()
                        diff_window_opts()
                    end,
                },
                keymaps = {
                    view = {
                        { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close diff view" } },
                        { "n", "<leader>e", open_file_explorer, { desc = "Close diff view and open Explorer" } },
                        { "n", "<leader>b", actions.toggle_files, { desc = "Toggle changed files tree" } },
                        { diff_modes, "<C-e>", after_normal_mode(actions.toggle_files), { desc = "Diff: toggle changed files list" } },
                        { diff_modes, "<A-j>", after_normal_mode(actions.select_next_entry), { desc = "Diff: next changed file" } },
                        { diff_modes, "<A-k>", after_normal_mode(actions.select_prev_entry), { desc = "Diff: previous changed file" } },
                        { diff_modes, "<C-PageDown>", after_normal_mode(actions.select_next_entry), { desc = "Diff: next changed file" } },
                        { diff_modes, "<C-PageUp>", after_normal_mode(actions.select_prev_entry), { desc = "Diff: previous changed file" } },
                        { diff_modes, "<A-h>", after_normal_mode(function() focus_diff_side("left") end), { desc = "Diff: focus old side" } },
                        { diff_modes, "<A-l>", after_normal_mode(function() focus_diff_side("right") end), { desc = "Diff: focus new side" } },
                        { diff_modes, "<A-e>", after_normal_mode(function() focus_diff_side("right") end), { desc = "Diff: focus editable side" } },
                    },
                    file_panel = {
                        { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close diff view" } },
                        { "n", "<leader>e", open_file_explorer, { desc = "Close diff view and open Explorer" } },
                        { diff_modes, "<C-e>", after_normal_mode(actions.toggle_files), { desc = "Diff: toggle changed files list" } },
                        { diff_modes, "<A-j>", after_normal_mode(actions.select_next_entry), { desc = "Diff: next changed file" } },
                        { diff_modes, "<A-k>", after_normal_mode(actions.select_prev_entry), { desc = "Diff: previous changed file" } },
                        { diff_modes, "<C-PageDown>", after_normal_mode(actions.select_next_entry), { desc = "Diff: next changed file" } },
                        { diff_modes, "<C-PageUp>", after_normal_mode(actions.select_prev_entry), { desc = "Diff: previous changed file" } },
                        { diff_modes, "<A-h>", after_normal_mode(function() focus_diff_side("left") end), { desc = "Diff: focus old side" } },
                        { diff_modes, "<A-l>", after_normal_mode(function() focus_diff_side("right") end), { desc = "Diff: focus new side" } },
                        { diff_modes, "<A-e>", after_normal_mode(function() focus_diff_side("right") end), { desc = "Diff: focus editable side" } },
                    },
                    file_history_panel = {
                        { diff_modes, "<C-e>", after_normal_mode(actions.toggle_files), { desc = "Diff history: toggle commit list" } },
                        { diff_modes, "<A-j>", after_normal_mode(actions.select_next_entry), { desc = "Diff history: next entry" } },
                        { diff_modes, "<A-k>", after_normal_mode(actions.select_prev_entry), { desc = "Diff history: previous entry" } },
                    },
                },
            }
        end,
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
