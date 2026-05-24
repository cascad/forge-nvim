-- IDE-feel слой. Ничего бизнес-критичного, но без него ощущение
-- «модальный текстовый редактор», а не «среда».
--
--   trouble    — постоянная панель Problems / References / Quickfix
--   aerial     — outline текущего файла (Structure window)
--   glance     — peek definition / references / implementations
--   fidget     — индикатор LSP-progress (rust-analyzer indexing…)
--   illuminate — подсветка вхождений символа под курсором
--   navic      — символ-путь (для barbecue breadcrumbs)
--   barbecue   — VS Code-стайл breadcrumbs сверху буфера
--   satellite  — VS Code-стайл overview ruler справа (диагностика, git, search)

return {
    -- =========================================================
    -- trouble.nvim — Problems-tab из VS Code
    -- =========================================================
    {
        "folke/trouble.nvim",
        cmd = "Trouble",
        opts = {
            focus = true,
            warn_no_results = false,
            open_no_results = true,
            modes = {
                diagnostics = { auto_open = false },
            },
        },
        keys = {
            { "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>",                         desc = "Trouble: workspace diagnostics" },
            { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>",            desc = "Trouble: buffer diagnostics" },
            { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<CR>",                 desc = "Trouble: symbols" },
            { "<leader>xr", "<cmd>Trouble lsp toggle focus=false win.position=right<CR>",  desc = "Trouble: LSP refs/defs/impls" },
            { "<leader>xL", "<cmd>Trouble loclist toggle<CR>",                             desc = "Trouble: location list" },
            { "<leader>xQ", "<cmd>Trouble qflist toggle<CR>",                              desc = "Trouble: quickfix" },
            -- Навигация по диагностикам
            { "]d",         function() vim.diagnostic.jump({ count = 1, float = true }) end,  desc = "Diag: next" },
            { "[d",         function() vim.diagnostic.jump({ count = -1, float = true }) end, desc = "Diag: prev" },
        },
    },

    -- =========================================================
    -- aerial.nvim — outline (Structure)
    -- =========================================================
    {
        "stevearc/aerial.nvim",
        cmd = { "AerialToggle", "AerialOpen", "AerialNavToggle" },
        opts = {
            backends = { "treesitter", "lsp", "markdown", "man" },
            layout = {
                default_direction = "right",
                width = 36,
                placement = "edge",
                resize_to_content = false,
            },
            attach_mode = "global",
            show_guides = true,
            highlight_on_jump = 200,
            autojump = true,
            -- Не attach'имся к гигантским файлам (stdlib и vendored
            -- deps). Aerial для rust использует treesitter-бэкенд,
            -- но если файл совсем огромный (std/fs.rs ≈ 3300 строк
            -- — попадает) — даже treesitter parse тормозит.
            disable_max_lines = 3000,
            disable_max_size = 500 * 1024,
            on_attach = function(buf)
                vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = buf, desc = "Aerial: prev symbol" })
                vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = buf, desc = "Aerial: next symbol" })
            end,
        },
        keys = {
            { "<leader>so", "<cmd>AerialToggle!<CR>", desc = "Outline: toggle (aerial)" },
            { "<leader>sn", "<cmd>AerialNavToggle<CR>", desc = "Outline: nav popup" },
        },
    },

    -- =========================================================
    -- glance.nvim — peek definition / references (Ctrl+Click аналог)
    -- =========================================================
    {
        "dnlhc/glance.nvim",
        cmd = "Glance",
        opts = {
            border = { enable = true, top_char = "─", bottom_char = "─" },
            theme = { enable = true, mode = "darken" },
            mappings = {
                list = {
                    ["j"] = "next",
                    ["k"] = "previous",
                    ["<CR>"] = "jump",
                    ["v"] = "jump_vsplit",
                    ["s"] = "jump_split",
                    ["<Esc>"] = "close",
                    ["q"] = "close",
                },
            },
        },
        keys = {
            { "gpd", "<cmd>Glance definitions<CR>",      desc = "Peek: definitions" },
            { "gpr", "<cmd>Glance references<CR>",       desc = "Peek: references" },
            { "gpt", "<cmd>Glance type_definitions<CR>", desc = "Peek: type defs" },
            { "gpi", "<cmd>Glance implementations<CR>",  desc = "Peek: implementations" },
        },
    },

    -- =========================================================
    -- fidget.nvim — LSP progress индикатор + notify
    -- =========================================================
    {
        "j-hui/fidget.nvim",
        event = "LspAttach",
        opts = {
            progress = {
                display = {
                    progress_icon = { pattern = "dots" },
                    done_icon = "✓",
                },
            },
            notification = {
                window = { winblend = 0, border = "rounded" },
            },
        },
    },

    -- =========================================================
    -- vim-illuminate — highlight всех вхождений символа под курсором.
    --
    -- ВАЖНО: на Neovim 0.12+ убран `vim.treesitter.has_parser()`, а
    -- vim-illuminate его дёргает в treesitter-провайдере (engine.lua:73).
    -- Каскадно ломает FileType autocmd и :checkhealth. Поэтому выключаем
    -- treesitter-провайдер. lsp+regex покрывают 95% сценариев — LSP-
    -- источник всё равно был основным, TS — supplementary.
    -- =========================================================
    {
        "RRethy/vim-illuminate",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            local rust_external = require("config.rust_external")
            rust_external.mark(0)
            require("illuminate").configure({
                providers = { "lsp", "regex" },
                -- 250мс вместо 120 — illuminate шлёт LSP documentHighlight
                -- на каждое движение курсора. На rust-analyzer это
                -- заметная фоновая нагрузка. 250мс = практически
                -- не отстаёт визуально, но дебаунсит при беглом hjkl.
                delay = 250,
                -- В очень больших файлах (stdlib, vendored deps) —
                -- regex вместо LSP. Лимит щедрый.
                large_file_cutoff = 5000,
                large_file_overrides = { providers = { "regex" } },
                filetypes_denylist = { "neo-tree", "Trouble", "trouble", "lazy", "mason", "dap-repl", "dap-view", "dap-view-term", "dap-view-help", "aerial", "OverseerList", "overseer", "overseer-list" },
                under_cursor = true,
                -- Не дёргаем LSP documentHighlight для буферов из
                -- stdlib / ~/.cargo / ~/.rustup — там это блокирует ra
                -- (см. lsp.lua: vim.b[buf].rust_external = true).
                -- Подсветка через regex остаётся.
                should_enable = function(bufnr)
                    if rust_external.mark(bufnr) then return false end
                    return true
                end,
            })
            -- Прыжки по референсам (когда illuminate уже подсветил)
            vim.keymap.set("n", "<A-n>", function() require("illuminate").goto_next_reference(true) end,
                { desc = "Illuminate: next reference" })
            vim.keymap.set("n", "<A-p>", function() require("illuminate").goto_prev_reference(true) end,
                { desc = "Illuminate: prev reference" })
        end,
    },

    -- =========================================================
    -- navic + barbecue — breadcrumbs сверху буфера
    -- =========================================================
    {
        "SmiteshP/nvim-navic",
        lazy = true,
        opts = {
            highlight = true,
            depth_limit = 5,
            separator = "  ",
            icons = {
                File = " ", Module = " ", Namespace = " ", Package = " ",
                Class = " ", Method = " ", Property = " ", Field = " ",
                Constructor = " ", Enum = " ", Interface = " ", Function = " ",
                Variable = " ", Constant = " ", String = " ", Number = " ",
                Boolean = " ", Array = " ", Object = " ", Key = " ",
                Null = " ", EnumMember = " ", Struct = " ", Event = " ",
                Operator = " ", TypeParameter = " ",
            },
        },
    },
    {
        "utilyre/barbecue.nvim",
        event = { "BufReadPost", "BufNewFile" },
        dependencies = {
            "SmiteshP/nvim-navic",
            "nvim-tree/nvim-web-devicons",
        },
        opts = {
            attach_navic = true,
            -- Кастомный autocmd: для rust_external буферов (stdlib
            -- и ~/.cargo/registry) НЕ запрашиваем documentSymbol —
            -- иначе после `gd` в std/fs.rs barbecue/navic шлют
            -- запрос на 3300 строк, ra их жуёт 5-15 сек, и наш
            -- следующий gd/<C-o> стоит в очереди.
            create_autocmd = false,
            include_buftypes = { "" },
            exclude_filetypes = { "neo-tree", "Trouble", "lazy", "mason", "help", "dap-view", "dap-view-term", "dap-view-help", "OverseerList", "overseer", "overseer-list" },
            theme = "auto",
            symbols = { separator = "" },
        },
        config = function(_, opts)
            local rust_external = require("config.rust_external")
            require("barbecue").setup(opts)
            vim.api.nvim_create_autocmd({
                "WinScrolled", "BufWinEnter", "CursorHold",
                "InsertLeave", "BufModifiedSet",
            }, {
                group = vim.api.nvim_create_augroup("BarbecueUpdate", { clear = true }),
                callback = function(args)
                    if rust_external.mark(args.buf) then return end
                    require("barbecue.ui").update()
                end,
            })
        end,
    },

    -- =========================================================
    -- satellite.nvim — overview ruler как в VS Code: тонкая полоса
    -- справа, на которой цветными засечками показано распределение
    -- по файлу:
    --   • красные/жёлтые точки — diagnostic errors/warnings;
    --   • зелёные/красные полосы слева полосы — gitsigns hunks;
    --   • засечки — результаты последнего поиска;
    --   • marks (a-z, A-Z);
    --   • позиция курсора и видимый viewport.
    -- Сразу видно, есть ли ошибка где-то в конце файла, и можно
    -- быстро ткнуть мышью / прокрутить туда.
    --
    -- Async, лёгкий, без зависимостей. Автор — lewis6991 (gitsigns).
    -- =========================================================
    {
        "lewis6991/satellite.nvim",
        event = { "BufReadPost", "BufNewFile" },
        opts = {
            -- false = показывать ruler во всех окнах, не только в активном.
            -- Для split-режима (3-way merge, side-by-side) полезно видеть
            -- диагностику обоих буферов сразу.
            current_only = false,
            -- Чуть прозрачнее, чтобы не отвлекало от кода.
            winblend = 50,
            zindex = 40,
            excluded_filetypes = {
                "neo-tree", "Trouble", "trouble", "lazy", "mason",
                "alpha", "help", "man", "qf", "aerial", "dap-repl",
                "dap-view", "dap-view-term", "dap-view-help",
                "OverseerList", "overseer", "overseer-list",
                "TelescopePrompt", "TelescopeResults",
            },
            handlers = {
                cursor = {
                    enable = true,
                    -- Маленькая стрелка в позиции курсора, чтобы было
                    -- видно где ты в общей карте файла.
                    overlap = true,
                    priority = 100,
                },
                search = {
                    enable = true,
                    overlap = true,
                    priority = 50,
                },
                diagnostic = {
                    enable = true,
                    -- Не показываем hint'ы — слишком шумно, оставляем
                    -- только error/warn/info. Min severity = INFO.
                    min_severity = vim.diagnostic.severity.INFO,
                    overlap = true,
                    priority = 50,
                },
                gitsigns = {
                    enable = true,
                    overlap = false,
                    priority = 20,
                },
                marks = {
                    enable = true,
                    show_builtins = false, -- не показывать [`'<>"^.] и т.п.
                    overlap = true,
                    priority = 30,
                },
                quickfix = {
                    enable = true,
                    overlap = true,
                    priority = 10,
                },
            },
        },
    },
}
