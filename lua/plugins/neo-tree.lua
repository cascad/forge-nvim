-- File explorer. То, чего в Helix нет в принципе.

local panels = require("config.panels")
local ru_keys = require("config.ru_keys")

local function normal_move(keys)
    return function()
        vim.cmd("normal! " .. keys)
    end
end

local function selected_node_dir(state)
    local node = state.tree and state.tree:get_node()
    if not node or not node.path then
        return nil
    end
    if node.type == "directory" then
        return node.path
    end
    return vim.fn.fnamemodify(node.path, ":h")
end

local function open_node_as_project(state)
    local path = selected_node_dir(state)
    if not path then
        return
    end

    vim.schedule(function()
        require("config.start").open_project(path)
    end)
end

local function focus_or_unfocus_explorer()
    if vim.bo.filetype == "neo-tree" then
        vim.cmd("wincmd p")
        return
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == "neo-tree" then
            vim.api.nvim_set_current_win(win)
            return
        end
    end

    panels.open_files()
end

return {
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        cmd = "Neotree",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
            "MunifTanjim/nui.nvim",
        },
        keys = {
            -- ВАЖНО: явно указываем `filesystem` source. `Neotree toggle`
            -- без source открывает ПОСЛЕДНИЙ использованный (neo-tree
            -- v3.x запоминает state между сессиями) — поэтому если в
            -- прошлый раз сидел в Git tab, при следующем запуске
            -- `<leader>e` открывал бы Git_status. С явным filesystem —
            -- всегда дерево файлов; на Git/Buffers — отдельные шорткаты
            -- ниже + клавиши `bf/bb/bg` внутри neo-tree.
            { "<leader>e",  panels.toggle_files,                   desc = "Explorer: toggle (Files)" },
            { "<leader>E",  panels.open_files,                     desc = "Explorer: reveal current file" },
            -- TODO: после теста в Windows terminal/Cursor почистить лишние
            -- варианты. Разные терминалы по-разному кодируют Shift/Ctrl/Alt
            -- с буквами, поэтому временно держим несколько aliases на одно
            -- VS Code-style действие: focus explorer / return to editor.
            { "<C-e>",      focus_or_unfocus_explorer,             desc = "Explorer: focus/unfocus" },
            { "<C-S-e>",    focus_or_unfocus_explorer,             desc = "Explorer: focus/unfocus" },
            { "<C-E>",      focus_or_unfocus_explorer,             desc = "Explorer: focus/unfocus" },
            { "<C-A-e>",    focus_or_unfocus_explorer,             desc = "Explorer: focus/unfocus" },
            { "<C-A-E>",    focus_or_unfocus_explorer,             desc = "Explorer: focus/unfocus" },
            { "<A-C-e>",    focus_or_unfocus_explorer,             desc = "Explorer: focus/unfocus" },
            { "<A-C-E>",    focus_or_unfocus_explorer,             desc = "Explorer: focus/unfocus" },
            { "<A-E>",      focus_or_unfocus_explorer,             desc = "Explorer: focus/unfocus" },
            { "<S-A-e>",    focus_or_unfocus_explorer,             desc = "Explorer: focus/unfocus" },
            { "<leader>gS", panels.toggle_git_status,             desc = "Git: side panel" },
            { "<leader>bB", "<cmd>Neotree buffers<CR>",           desc = "Explorer: buffers panel" },
        },
        deactivate = function() vim.cmd("Neotree close") end,
        init = function()
            -- Открыть neo-tree автоматически, если nvim запущен на каталоге.
            -- Явно `filesystem`, чтобы не подхватить last_used source
            -- (Git/Buffers) из state-файла neo-tree между сессиями.
            vim.api.nvim_create_autocmd("BufEnter", {
                group = vim.api.nvim_create_augroup("UserNeoTreeStart", { clear = true }),
                desc = "Open Neo-tree when starting on a directory",
                callback = function()
                    local stats = vim.uv.fs_stat(vim.fn.argv(0))
                    if stats and stats.type == "directory" then
                        require("neo-tree")
                        vim.cmd("Neotree filesystem current")
                    end
                end,
            })
        end,
        opts = {
            sources = { "filesystem", "buffers", "git_status" },
            -- Дефолтный source при `Neotree` без аргумента — Files.
            -- Без этого neo-tree берёт last_used из своего state-файла
            -- (~/.local/share/nvim/neo-tree/...), и после работы в Git
            -- tab при следующем запуске nvim открывает Git, а не Files.
            default_source = "filesystem",
            close_if_last_window = true,
            popup_border_style = "rounded",
            enable_git_status = true,
            enable_diagnostics = true,

            -- VS Code-style табы сверху neo-tree: переключение между
            -- "Files" (filesystem), "Buffers" (все открытые, включая
            -- внешние из ~/.cargo, stdlib и т.п.) и "Git" (изменённые).
            -- Полезно когда `gd` уводит в std::fs::File и хочется быстро
            -- увидеть, какие внешние файлы у тебя сейчас открыты.
            source_selector = {
                winbar = true,
                statusline = false,
                show_scrolled_off_parent_node = true,
                content_layout = "center",
                sources = {
                    { source = "filesystem", display_name = "  Files " },
                    { source = "buffers", display_name = "  Buffers " },
                    { source = "git_status", display_name = "  Git " },
                },
                separator = { left = "▏", right = "▕" },
            },
            default_component_configs = {
                indent = { padding = 0 },
                icon = {
                    folder_closed = "",
                    folder_open = "",
                    folder_empty = "",
                },
                git_status = {
                    symbols = {
                        added     = "✚",
                        modified  = "",
                        deleted   = "✖",
                        renamed   = "",
                        untracked = "",
                        ignored   = "",
                        unstaged  = "",
                        staged    = "",
                        conflict  = "",
                    },
                },
            },
            window = {
                width = 32,
                mappings = ru_keys.extend_mappings({
                    ["<space>"] = "none",   -- освобождаем — у нас лидер
                    ["j"]       = normal_move("j"),
                    ["k"]       = normal_move("k"),
                    ["l"]       = "open",
                    ["h"]       = "close_node",
                    ["<2-LeftMouse>"] = "open",
                    ["<CR>"]    = "open",
                    ["o"]       = "open",
                    ["v"]       = "open_vsplit",
                    ["s"]       = "open_split",
                    ["<Esc>"]   = "close_window",
                    ["P"]       = { "toggle_preview", config = { use_float = true } },
                    ["a"]       = { "add", config = { show_path = "relative" } },
                    ["A"]       = "add_directory",
                    ["d"]       = "delete",
                    ["r"]       = "rename",
                    ["y"]       = "copy_to_clipboard",
                    ["x"]       = "cut_to_clipboard",
                    ["p"]       = "paste_from_clipboard",
                    ["c"]       = "copy",
                    ["m"]       = "move",
                    ["?"]       = "show_help",
                    ["R"]       = "refresh",
                    -- ["H"] = "toggle_hidden" перенесён ВНИЗ в
                    -- filesystem.window.mappings — эта команда есть
                    -- только в filesystem-source. В git_status/buffers
                    -- она невалидна и даёт WARN "invalid mapping for H"
                    -- при открытии не-filesystem таба.

                    -- Переключение между табами (Files / Buffers / Git)
                    -- сверху neo-tree:
                    --   < и > — встроены в neo-tree (prev/next source)
                    -- Дополнительно — прямые шорткаты на конкретный таб:
                    ["bf"]      = function() vim.cmd("Neotree filesystem reveal left") end,
                    ["bb"]      = function() vim.cmd("Neotree buffers reveal left") end,
                    ["bg"]      = function() vim.cmd("Neotree git_status reveal left") end,
                }),
            },
            filesystem = {
                commands = {
                    open_folder_as_project = open_node_as_project,
                },
                follow_current_file = { enabled = true },
                use_libuv_file_watcher = true,
                filtered_items = {
                    visible = false,
                    hide_dotfiles = false,
                    hide_gitignored = true,
                    hide_by_name = { "node_modules", "__pycache__", "target", ".venv", "venv" },
                    never_show = { ".DS_Store", "thumbs.db" },
                },
                window = {
                    mappings = ru_keys.extend_mappings({
                        -- toggle_hidden — только в filesystem source
                        -- (см. комментарий выше в общих window.mappings).
                        ["H"] = "toggle_hidden",
                        ["O"] = "open_folder_as_project",
                        ["u"] = "navigate_up",
                        ["-"] = "navigate_up",
                    }),
                },
            },
            buffers = {
                follow_current_file = { enabled = true },
                show_unloaded = true,
            },
            git_status = {
                window = { position = "left" },
            },
        },
    },
}
