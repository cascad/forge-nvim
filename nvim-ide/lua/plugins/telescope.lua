-- Telescope — fuzzy finder. fzf-native (CMake build) for fast sorting.

return {
    {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && "
            .. "cmake --build build --config Release && "
            .. "cmake --install build --prefix build",
        cond = function() return vim.fn.executable("cmake") == 1 end,
    },

    {
        "nvim-telescope/telescope.nvim",
        cmd = "Telescope",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "echasnovski/mini.icons",
            "nvim-telescope/telescope-fzf-native.nvim",
        },
        keys = {
            { "<C-p>",      "<cmd>Telescope find_files<CR>",                  desc = "Find file" },
            { "<C-S-p>",    "<cmd>Telescope commands<CR>",                    desc = "Command palette" },

            { "<leader>ff", "<cmd>Telescope find_files<CR>",                  desc = "Find: files" },
            { "<leader>fr", "<cmd>Telescope oldfiles<CR>",                    desc = "Find: recent files" },
            { "<leader>fg", "<cmd>Telescope live_grep<CR>",                   desc = "Find: live grep" },
            { "<leader>fb", "<cmd>Telescope buffers<CR>",                     desc = "Find: buffers" },
            { "<leader>fc", "<cmd>Telescope git_status<CR>",                  desc = "Find: changed files" },
            { "<leader>fh", "<cmd>Telescope help_tags<CR>",                   desc = "Find: help tags" },
            { "<leader>fk", "<cmd>Telescope keymaps<CR>",                     desc = "Find: keymaps" },
            { "<leader>fp", "<cmd>Telescope projects<CR>",                    desc = "Find: projects" },
            { "<leader>fj", "<cmd>Telescope jumplist<CR>",                    desc = "Find: jumplist" },
            { "<leader>fm", "<cmd>Telescope marks<CR>",                       desc = "Find: marks" },
            { "<leader>fR", "<cmd>Telescope resume<CR>",                      desc = "Find: resume last" },
            { "<leader>fT", "<cmd>TodoTelescope<CR>",                         desc = "Find: TODOs" },

            { "<leader>ss", "<cmd>Telescope live_grep<CR>",                   desc = "Search: grep" },
            { "<leader>sw", "<cmd>Telescope grep_string<CR>",                 desc = "Search: word under cursor" },
            { "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<CR>",   desc = "Search: buffer" },
            { "<leader>sd", "<cmd>Telescope diagnostics bufnr=0<CR>",         desc = "Search: buf diagnostics" },
            { "<leader>sD", "<cmd>Telescope diagnostics<CR>",                 desc = "Search: workspace diagnostics" },
            { "<leader>sS", "<cmd>Telescope lsp_document_symbols<CR>",        desc = "Search: doc symbols" },
            { "<leader>sW", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", desc = "Search: workspace symbols" },
        },
        opts = function()
            local actions = require("telescope.actions")
            return {
                defaults = {
                    prompt_prefix    = "  ",
                    selection_caret  = " ",
                    path_display     = { "truncate" },
                    sorting_strategy = "ascending",
                    layout_strategy  = "horizontal",
                    layout_config    = {
                        horizontal = { prompt_position = "top", preview_width = 0.55 },
                        width  = 0.9,
                        height = 0.85,
                    },
                    file_ignore_patterns = {
                        "%.git/", "node_modules/", "venv/", "%.venv/",
                        "__pycache__/", "%.pytest_cache/", "%.mypy_cache/",
                        "target/", "dist/", "build/", "%.next/", "%.cache/",
                        "%.lock", "%.pyc",
                    },
                    mappings = {
                        i = {
                            ["<C-j>"] = actions.move_selection_next,
                            ["<C-k>"] = actions.move_selection_previous,
                            ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist,
                            ["<Esc>"] = actions.close,
                        },
                        n = { ["q"] = actions.close },
                    },
                },
                pickers = {
                    find_files = {
                        hidden = true,
                        find_command = vim.fn.executable("fd") == 1
                            and { "fd", "--type", "f", "--strip-cwd-prefix", "--hidden", "--exclude", ".git" }
                            or nil,
                    },
                    live_grep = {
                        additional_args = function() return { "--hidden", "--glob", "!**/.git/*" } end,
                    },
                    buffers = {
                        sort_mru = true,
                        ignore_current_buffer = true,
                        previewer = false,
                    },
                },
                extensions = {
                    fzf = {
                        fuzzy = true,
                        override_generic_sorter = true,
                        override_file_sorter = true,
                        case_mode = "smart_case",
                    },
                },
            }
        end,
        config = function(_, opts)
            local telescope = require("telescope")
            telescope.setup(opts)
            pcall(telescope.load_extension, "fzf")
        end,
    },
}
