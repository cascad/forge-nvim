-- File explorer. То, чего в Helix нет в принципе.

local ru_keys = require("config.ru_keys")

local function normal_move(keys)
    return function()
        vim.cmd("normal! " .. keys)
    end
end

local function neo_tree_window()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
            local ok, buf = pcall(vim.api.nvim_win_get_buf, win)
            if ok and vim.bo[buf].filetype == "neo-tree" then
                return win
            end
        end
    end
    return nil
end

local function safe_tree_node(state)
    if not state or not state.tree then
        return nil
    end

    local ok, node = pcall(function()
        return state.tree:get_node()
    end)
    if ok then
        return node
    end

    local win = neo_tree_window()
    if not win then
        return nil
    end

    local ok_cursor, cursor = pcall(vim.api.nvim_win_get_cursor, win)
    if not ok_cursor then
        return nil
    end

    ok, node = pcall(function()
        return state.tree:get_node(cursor[1])
    end)

    if ok then
        return node
    end
    return nil
end

local function selected_node_dir(state)
    local node = safe_tree_node(state)
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

    -- ide.show трогает ТОЛЬКО left slot, не снося bottom/right — панели
    -- живут независимо (VS Code-инвариант). НЕ apply_layout("files"), который
    -- закрыл бы остальные слоты.
    require("ide").show("explorer")
end

local function safe_rename(state)
    local node = safe_tree_node(state)
    if not node or node.type == "message" or not node.path then
        vim.notify("Neo-tree rename: focus a file or folder first", vim.log.levels.WARN, { title = "Neo-tree" })
        return
    end

    local ok_actions, fs_actions = pcall(require, "neo-tree.sources.filesystem.lib.fs_actions")
    if not ok_actions or type(fs_actions.rename_node) ~= "function" then
        vim.notify("Neo-tree rename action unavailable", vim.log.levels.ERROR, { title = "Neo-tree" })
        return
    end

    local ok_rename, err = pcall(fs_actions.rename_node, node.path, function()
        local ok_commands, commands = pcall(require, "neo-tree.sources.filesystem.commands")
        if ok_commands and type(commands.refresh) == "function" then
            pcall(commands.refresh, state)
        end
    end)

    if not ok_rename then
        vim.notify("Neo-tree rename failed: " .. tostring(err), vim.log.levels.ERROR, { title = "Neo-tree" })
    end
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
            -- ide.toggle/show трогает строго один слот (left) — не закрывает
            -- остальные панели (VS Code-инвариант "панели независимы").
            --
            -- `explorer` зарегистрирован с filesystem source (см. ide/
            -- init.lua), это решает проблему "neo-tree v3.x last_used":
            -- даже после работы в Git/Buffers <leader>e всегда возвращает
            -- к Files.
            { "<leader>e",  function() require("ide").toggle("explorer") end, desc = "Explorer: toggle (Files)" },
            { "<leader>E",  function()
                -- Reveal current file: ide.show идемпотентен, поэтому если
                -- explorer уже открыт на filesystem и НЕ показывает текущий
                -- файл — нужен прямой :Neotree reveal вызов.
                require("ide").show("explorer")
                pcall(vim.cmd, "Neotree filesystem reveal left")
            end, desc = "Explorer: reveal current file" },
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
            { "<leader>gS", function() require("ide").toggle("git_status") end, desc = "Git: side panel" },
            { "<leader>bB", function() require("ide").show("buffers")    end, desc = "Explorer: buffers panel" },
        },
        deactivate = function() vim.cmd("Neotree close") end,
        init = function()
            -- Открыть neo-tree автоматически, если nvim запущен на каталоге.
            -- ВАЖНО: VimEnter + once=true (а НЕ BufEnter без once). BufEnter
            -- срабатывает на каждом входе в буфер, и когда edgy.nvim
            -- перехватывает окно neo-tree через nvim_win_set_buf, наша
            -- автокоманда триггерится повторно ДО того, как neo-tree
            -- успел выставить buf-local var 'neo_tree_position' на
            -- новом буфере. neo-tree.command.init:156 падает с
            -- "Key not found: neo_tree_position" в этой реентерабельной
            -- ситуации. См. инцидент 21.05.2026 в DEBUG_SETUP_JOURNEY.md.
            --
            -- Явно `filesystem`, чтобы не подхватить last_used source
            -- (Git/Buffers) из state-файла neo-tree между сессиями.
            vim.api.nvim_create_autocmd("VimEnter", {
                group = vim.api.nvim_create_augroup("UserNeoTreeStart", { clear = true }),
                once = true,
                desc = "Open Neo-tree when starting on a directory",
                callback = function()
                    local arg = vim.fn.argv(0)
                    if not arg or arg == "" then return end
                    local stats = vim.uv.fs_stat(arg)
                    if not (stats and stats.type == "directory") then return end

                    require("neo-tree")

                    -- ВАЖНО: при `nvim D:\some-dir` Neovim открывает
                    -- буфер-директорию в исходном окне. Если оставить
                    -- его как есть и просто запустить Neotree сбоку,
                    -- то клик по файлу в neo-tree (которая делает
                    -- `wincmd p` + `:edit file`) попадает в это окно
                    -- с directory buffer — и команда либо игнорируется,
                    -- либо создаёт неименованный scratch ("Noname")
                    -- из-за взаимодействия с edgy.nvim auto-capture.
                    --
                    -- Поэтому ДО открытия neo-tree подменяем directory
                    -- buffer на пустой scratch в main window — у neo-tree
                    -- появляется чистая цель для :edit.
                    local dir_buf = vim.api.nvim_get_current_buf()
                    pcall(vim.cmd, "cd " .. vim.fn.fnameescape(arg))
                    vim.cmd("enew")
                    pcall(vim.api.nvim_buf_delete, dir_buf, { force = true })

                    -- `reveal left` создаёт боковой split, который
                    -- edgy подхватывает в left edgebar.
                    vim.cmd("Neotree filesystem reveal left")
                    -- Вернуть фокус в main (вправо от neo-tree), чтобы
                    -- пользователь начинал работу в редакторе, а не
                    -- внутри дерева.
                    pcall(vim.cmd, "wincmd l")
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
                    rename = safe_rename,
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
