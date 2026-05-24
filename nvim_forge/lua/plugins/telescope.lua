-- Telescope — основной picker. fzf-native собираем через cmake (clang
-- уже стоит в C:\Program Files\LLVM). Если cmake не найден — Telescope
-- продолжит работать на Lua-сортировщике, просто медленнее.

local function open_buffer_picker()
    require("telescope.builtin").buffers({
        prompt_title = "Open Buffers",
        sort_mru = true,
        show_all_buffers = true,
        ignore_current_buffer = true,
        previewer = false,
    })
end

return {
    {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && "
            .. "cmake --build build --config Release && "
            .. "cmake --install build --prefix build",
        cond = function()
            return vim.fn.executable("cmake") == 1
        end,
    },

    {
        "nvim-telescope/telescope.nvim",
        cmd = "Telescope",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
            "nvim-telescope/telescope-fzf-native.nvim",
        },
        keys = {
            -- VS Code Ctrl+P / Ctrl+Shift+P
            { "<C-p>",       "<cmd>Telescope find_files<CR>",  desc = "Find file" },
            { "<C-S-p>",     "<cmd>Telescope commands<CR>",    desc = "Command palette" },
            -- helix space.f — files
            { "<leader>ff",  "<cmd>Telescope find_files<CR>",  desc = "Files: find" },
            { "<leader>fr",  "<cmd>Telescope oldfiles<CR>",    desc = "Files: recent" },
            { "<leader>fg",  "<cmd>Telescope live_grep<CR>",   desc = "Files: grep" },
            { "<leader>fb",  open_buffer_picker,               desc = "Files: buffers" },
            { "<leader>fc",  "<cmd>Telescope git_status<CR>",  desc = "Files: changed" },
            { "<leader>fj",  "<cmd>Telescope jumplist<CR>",    desc = "Files: jumplist" },
            { "<leader>fh",  "<cmd>Telescope help_tags<CR>",   desc = "Files: help" },
            { "<leader>bb",  open_buffer_picker,               desc = "Buffers: switch" },
            -- <C-b> теперь зарезервирован под IDE: toggle left panel
            -- (см. config/keymaps.lua, секция "Slot TOGGLE"). Для
            -- buffers picker используй <leader>bb / <leader>fb.

            -- helix space.s — search
            { "<leader>ss",  "<cmd>Telescope live_grep<CR>",                desc = "Search: workspace grep" },
            { "<leader>sw",  "<cmd>Telescope grep_string<CR>",              desc = "Search: word under cursor" },
            { "<leader>sb",  "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Search: buffer fuzzy" },
            { "<leader>sd",  "<cmd>Telescope diagnostics bufnr=0<CR>",      desc = "Search: buf diagnostics" },
            { "<leader>sD",  "<cmd>Telescope diagnostics<CR>",              desc = "Search: workspace diagnostics" },
            { "<leader>sS",  "<cmd>Telescope lsp_document_symbols<CR>",     desc = "Search: doc symbols" },
            { "<leader>sW",  "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", desc = "Search: workspace symbols" },
            { "<leader>sk",  "<cmd>Telescope keymaps<CR>",                  desc = "Search: keymaps" },
            { "<leader>sr",  "<cmd>Telescope resume<CR>",                   desc = "Search: resume last" },

            -- LSP-pickers — telescope даёт quickfix-подобный UI с
            -- preview, что лучше чем дефолтный jump в один файл.
            { "<leader>lR",  "<cmd>Telescope lsp_references<CR>",      desc = "LSP: references (telescope)" },
            { "<leader>lI",  "<cmd>Telescope lsp_implementations<CR>", desc = "LSP: implementations (telescope)" },
            { "<leader>lT",  "<cmd>Telescope lsp_type_definitions<CR>", desc = "LSP: type defs (telescope)" },
        },
        opts = function()
            local actions = require("telescope.actions")
            local ru_keys = require("config.ru_keys")
            return {
                defaults = {
                    prompt_prefix = "  ",
                    selection_caret = " ",
                    path_display = { "truncate" },
                    sorting_strategy = "ascending",
                    layout_strategy = "horizontal",
                    layout_config = {
                        horizontal = {
                            prompt_position = "top",
                            preview_width = 0.55,
                        },
                        width = 0.9,
                        height = 0.85,
                    },
                    file_ignore_patterns = {
                        -- Та же защита от мусора, которую в Helix мы вешали
                        -- через .ignore — здесь декларативно.
                        "%.git/", "node_modules/", "venv/", "%.venv/",
                        "__pycache__/", "%.pytest_cache/", "%.mypy_cache/",
                        "target/", "dist/", "build/", "%.next/", "%.cache/",
                        "%.lock", "%.pyc",
                    },
                    mappings = {
                        i = ru_keys.extend_mappings({
                            ["<C-j>"] = actions.move_selection_next,
                            ["<C-k>"] = actions.move_selection_previous,
                            ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist,
                            ["<Esc>"] = actions.close,
                        }),
                        n = ru_keys.extend_mappings({ ["q"] = actions.close }),
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
                        show_all_buffers = true,
                        ignore_current_buffer = true,
                        previewer = false,
                    },
                    lsp_references = { fname_width = 50, show_line = false },
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
