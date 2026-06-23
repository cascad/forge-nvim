-- Editor mechanics: autopairs, surround, comment, autosave, sessions.

return {
    -- =========================================================
    -- autopairs
    -- =========================================================
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        opts = {
            -- check_ts = false НАМЕРЕННО. С check_ts=true автопары спрашивают
            -- у treesitter контекст (строка/коммент), но когда файл не
            -- парсится (синтаксическая ошибка → дерево в состоянии ERROR),
            -- запрос ноды срывается и закрывающая скобка перестаёт
            -- подставляться. Без TS-проверки пары работают всегда —
            -- предсказуемо, даже в "сломанном" коде.
            check_ts = false,
            disable_filetype = { "TelescopePrompt", "vim" },
            fast_wrap = {
                map = "<M-e>",
                chars = { "{", "[", "(", '"', "'" },
                pattern = [=[[%'%"%>%]%)%}%,]]=],
                end_key = "$",
                keys = "qwertyuiopzxcvbnmasdfghjkl",
                check_comma = true,
                highlight = "Search",
                highlight_grey = "Comment",
            },
        },
        config = function(_, opts)
            local ap = require("nvim-autopairs")
            ap.setup(opts)
            -- Интеграция с cmp: вставка `(` после функции
            local ok_cmp, cmp = pcall(require, "cmp")
            if ok_cmp then
                local ok_ap_cmp, cmp_ap = pcall(require, "nvim-autopairs.completion.cmp")
                if ok_ap_cmp then
                    cmp.event:on("confirm_done", cmp_ap.on_confirm_done())
                end
            end
        end,
    },

    -- =========================================================
    -- nvim-surround
    -- =========================================================
    {
        "kylechui/nvim-surround",
        version = "*",
        event = "VeryLazy",
        opts = {},
    },

    -- =========================================================
    -- Comment.nvim — gcc / gc{motion} / gc в visual.
    -- Ctrl+/ маппится в keymaps.lua поверх gcc.
    -- =========================================================
    {
        "numToStr/Comment.nvim",
        event = { "BufReadPost", "BufNewFile" },
        opts = {
            padding = true,
            sticky = true,
            toggler = { line = "gcc", block = "gbc" },
            opleader = { line = "gc",  block = "gb" },
            mappings = { basic = true, extra = true },
        },
    },

    -- =========================================================
    -- auto-save 500мс. Набор/навигация НЕ должны фризить (жёсткое
    -- правило юзера). Гарантия: на autosave-записи нет НИ ОДНОЙ
    -- синхронной внешней операции —
    --   * формат: conform теперь format_after_save (АСИНХРОННО) и к тому
    --     же пропускает autosave (см. format.lua) → ничего не блокирует;
    --   * линтер: rust-analyzer checkOnSave=clippy крутится в ОТДЕЛЬНОМ
    --     процессе cargo и шлёт диагностики асинхронно → главный цикл
    --     nvim не ждёт его;
    --   * сам write — дёшев, по текущему буферу (write_all_buffers=false).
    -- Итог: autosave работает (персист + фоновые диагностики), но печать
    -- и движение по файлу не подвисают.
    -- =========================================================
    {
        "okuuva/auto-save.nvim",
        cmd = { "ASToggle" },
        event = { "InsertLeave", "TextChanged" },
        opts = {
            enabled = true,
            trigger_events = {
                immediate_save = { "BufLeave", "FocusLost" },
                defer_save     = { "InsertLeave", "TextChanged" },
                cancel_deferred_save = { "InsertEnter" },
            },
            -- Маркируем write как фоновый autosave. conform.nvim смотрит
            -- этот флаг и НЕ форматирует такие сохранения, но autocmd'ы
            -- остаются включены, поэтому rust-analyzer checkOnSave/clippy
            -- продолжает запускаться автоматически.
            callbacks = {
                before_saving = function()
                    vim.g.user_auto_save_active = true
                end,
                after_saving = function()
                    vim.defer_fn(function()
                        vim.g.user_auto_save_active = false
                    end, 50)
                end,
            },
            condition = function(buf)
                local ft = vim.bo[buf].filetype
                local bt = vim.bo[buf].buftype
                if bt ~= "" then return false end                  -- не терминалы / qflist / help
                if vim.bo[buf].readonly then return false end
                if vim.bo[buf].modifiable == false then return false end
                if ft == "" or ft == "neo-tree" or ft == "lazy" or ft == "mason" then
                    return false
                end
                -- Autosave должен работать даже когда в коде есть ошибки:
                -- это нужно LSP/линтерам, test discovery и привычному IDE-flow.
                -- Форматирование фоновых autosave-записей отключено в
                -- conform.nvim через vim.g.user_auto_save_active.
                return true
            end,
            write_all_buffers = false,
            debounce_delay = 500,
            noautocmd = false,
        },
    },

    -- =========================================================
    -- project.nvim — recent projects picker (à la JetBrains).
    -- Детектит project root по маркерам (.git, Cargo.toml, go.mod, ...),
    -- ведёт history. При выборе проекта — меняет cwd, и дальше Telescope/
    -- neo-tree автоматически переориентируются на новую папку.
    --
    -- Биндинг: <leader>fp (внутри группы Files). Дублируется на
    -- <leader>op для симметрии с VS Code "Open Folder".
    -- =========================================================
    {
        "ahmedkhalf/project.nvim",
        main = "project_nvim",            -- модуль называется иначе, чем репо
        event = "VeryLazy",
        keys = {
            { "<leader>fp", function() require("config.start").open_projects_picker() end, desc = "Files: recent projects" },
            { "<leader>op", function() require("config.start").open_projects_picker() end, desc = "Open: recent project" },
            { "<leader>ow", function() require("config.start").work_in_current_folder() end, desc = "Open: work in current folder" },
            { "<leader>of", function() require("config.start").open_path_prompt() end, desc = "Open: folder path" },
            { "<leader>oP", function() require("config.start").open_path_prompt() end, desc = "Open: folder path" },
        },
        opts = {
            detection_methods = { "lsp", "pattern" },
            patterns = {
                ".git",
                "Cargo.toml",
                "go.mod",
                "pyproject.toml",
                "package.json",
                "setup.py",
                ".project-root",
                "Makefile",
            },
            -- false = автодетект project root на BufEnter и автосмена cwd.
            -- Если хочется ручного контроля — поставить true и звать
            -- :ProjectRoot руками.
            manual_mode = false,
            show_hidden = false,
            silent_chdir = true,
            scope_chdir = "global",       -- глобальный cwd, не tab/window
            datapath = vim.fn.stdpath("data"),
            exclude_dirs = {
                "~/.cargo/*",
                "~/.rustup/*",
                "*/.cargo/*",
                "*/.rustup/*",
                "*/rustlib/src/*",
                "~/.cache/*",
                "*/node_modules/*",
                "*/.venv/*",
                "*/venv/*",
                "*/__pycache__/*",
                "*/target/*",
            },
        },
        config = function(_, opts)
            require("project_nvim").setup(opts)

            local ok, project = pcall(require, "project_nvim.project")
            if ok and vim.lsp.get_clients then
                project.find_lsp_root = function()
                    local buf_ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })
                    local clients = vim.lsp.get_clients({ bufnr = 0 })
                    if #clients == 0 then
                        return nil
                    end

                    local config = require("project_nvim.config")
                    for _, client in ipairs(clients) do
                        local filetypes = client.config.filetypes
                        if filetypes and vim.tbl_contains(filetypes, buf_ft) then
                            if not vim.tbl_contains(config.options.ignore_lsp, client.name) then
                                return client.config.root_dir, client.name
                            end
                        end
                    end
                end
            end
        end,
    },

    -- =========================================================
    -- persistence — auto-save / restore session per cwd
    -- =========================================================
    {
        "folke/persistence.nvim",
        event = "BufReadPre",
        opts = {
            branch = true,
            need = 1,
        },
        config = function(_, opts)
            require("persistence").setup(opts)

            -- После КАЖДОГО успешного восстановления сессии (recent project,
            -- <leader>qs, <leader>ql) принудительно открываем file explorer
            -- слева. Без этого session.load восстанавливает только окна с
            -- кодом, и explorer остаётся закрытым даже если в прошлой
            -- сессии он был открыт (persistence не сохраняет edgebar-окна).
            vim.api.nvim_create_autocmd("User", {
                group = vim.api.nvim_create_augroup("UserPersistenceExplorer", { clear = true }),
                pattern = "PersistenceLoadPost",
                callback = function()
                    vim.schedule(function()
                        local ok, ide = pcall(require, "ide")
                        if ok then
                            -- Вход в проект (restore) → дерево файлов
                            -- (ide/triggers.lua: project:open).
                            pcall(function() ide.triggers.fire("project:open") end)
                            -- Фокус обратно в editor: explorer открывается, но
                            -- курсор остаётся на редактируемом файле.
                            if type(ide.focus_main) == "function" then
                                pcall(ide.focus_main)
                            end
                        end
                    end)
                end,
            })

            vim.api.nvim_create_autocmd("User", {
                group = vim.api.nvim_create_augroup("UserPersistenceCleanSession", { clear = true }),
                pattern = "PersistenceSavePre",
                callback = function()
                    local ok, ide = pcall(require, "ide")
                    if ok and type(ide.cleanup_for_session) == "function" then
                        ide.cleanup_for_session()
                    end
                end,
            })
        end,
        keys = {
            { "<leader>qs", function() require("persistence").load() end,                        desc = "Session: restore for cwd" },
            { "<leader>qS", function() require("persistence").select() end,                      desc = "Session: select" },
            { "<leader>ql", function() require("persistence").load({ last = true }) end,         desc = "Session: restore last" },
            { "<leader>qd", function() require("persistence").stop() end,                        desc = "Session: don't save current" },
        },
    },

    -- =========================================================
    -- todo-comments — подсвечивает TODO/FIXME/NOTE/HACK + Telescope
    -- =========================================================
    {
        "folke/todo-comments.nvim",
        event = { "BufReadPost", "BufNewFile" },
        dependencies = { "nvim-lua/plenary.nvim" },
        opts = {
            signs = false,
        },
        keys = {
            { "<leader>st", "<cmd>TodoTelescope<CR>", desc = "Search: TODOs" },
            { "]t", function() require("todo-comments").jump_next() end, desc = "TODO: next" },
            { "[t", function() require("todo-comments").jump_prev() end, desc = "TODO: prev" },
        },
    },

    -- =========================================================
    -- indent-blankline — guides
    -- =========================================================
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        event = { "BufReadPost", "BufNewFile" },
        opts = {
            indent = { char = "▏" },
            scope = { enabled = true, show_start = false, show_end = false },
            exclude = {
                filetypes = {
                    "help", "lazy", "mason", "neo-tree", "Trouble", "trouble",
                    "dashboard", "alpha", "checkhealth", "dap-repl",
                },
            },
        },
    },
}
