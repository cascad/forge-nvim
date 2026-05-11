-- UI: тема, statusline, табы, which-key, иконки.

return {
    -- =========================================================
    -- catppuccin (тема)
    -- =========================================================
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,           -- грузится раньше всех — нужен перед остальными UI
        opts = {
            flavour = "mocha",     -- latte / frappe / macchiato / mocha
            transparent_background = false,
            term_colors = true,
            integrations = {
                cmp = true,
                gitsigns = true,
                neotree = true,
                telescope = { enabled = true, style = "nvchad" },
                treesitter = true,
                mason = true,
                dap = true,
                dap_ui = true,
                fidget = true,
                illuminate = { enabled = true },
                native_lsp = {
                    enabled = true,
                    underlines = {
                        errors      = { "underline" },
                        hints       = { "underline" },
                        warnings    = { "underline" },
                        information = { "underline" },
                    },
                },
                navic = { enabled = true, custom_bg = "NONE" },
                aerial = true,
                which_key = true,
                indent_blankline = { enabled = true },
            },
            -- Контрастная подсветка fuzzy-матчей в Telescope
            -- (закрывает боль №3 из helix\PROBLEMS.md) + яркий курсор,
            -- чтобы всегда было видно где он стоит (см. options.lua →
            -- guicursor).
            highlight_overrides = {
                mocha = function(c)
                    return {
                        TelescopeMatching  = { fg = c.peach, bold = true },
                        TelescopeSelection = { bg = c.surface0, bold = true },

                        -- Курсор: яркий персиковый блок с тёмным fg,
                        -- хорошо видно на любом фоне catppuccin-mocha.
                        Cursor       = { bg = c.peach, fg = c.base, bold = true },
                        lCursor      = { bg = c.peach, fg = c.base, bold = true },
                        TermCursor   = { bg = c.peach, fg = c.base, bold = true },
                        TermCursorNC = { bg = c.overlay0, fg = c.base },

                        -- Усилить cursorline и подсветку номера строки
                        CursorLine   = { bg = c.surface0 },
                        CursorLineNr = { fg = c.peach, bold = true },
                    }
                end,
            },
        },
        config = function(_, opts)
            require("catppuccin").setup(opts)
            vim.cmd.colorscheme("catppuccin")
        end,
    },

    -- =========================================================
    -- which-key — всплывающие подсказки по leader
    -- =========================================================
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            preset = "modern",
            delay = 300,
            spec = {
                -- Группы (helix space.X + наши добавки)
                { "<leader>f", group = "Files" },
                { "<leader>s", group = "Search" },
                { "<leader>l", group = "LSP" },
                { "<leader>d", group = "Debug" },
                { "<leader>g", group = "Git" },
                { "<leader>gh", group = "Git: hunk" },
                { "<leader>j", group = "Jobs/Tasks" },
                { "<leader>w", group = "Window" },
                { "<leader>b", group = "Buffer" },
                { "<leader>t", group = "Toggle" },
                { "<leader>T", group = "Tests" },
                { "<leader>m", group = "Modes/Layout" },
                { "<leader>x", group = "Trouble" },
                { "<leader>r", group = "Rust" },
                { "<leader>q", group = "Quit" },
                { "<leader>c", group = "Code" },
                { "<leader>o", group = "Open" },
                { "g",         group = "Goto" },
                { "gp",        group = "Peek (glance)" },
                { "]",         group = "Next" },
                { "[",         group = "Prev" },
            },
        },
    },

    -- =========================================================
    -- lualine — statusline
    -- =========================================================
    {
        "nvim-lualine/lualine.nvim",
        event = "VeryLazy",
        dependencies = {
            "nvim-tree/nvim-web-devicons",
            "catppuccin/nvim",
        },
        opts = {
            options = {
                theme = "catppuccin-mocha",
                globalstatus = true,
                component_separators = { left = "│", right = "│" },
                section_separators   = { left = "", right = "" },
                disabled_filetypes = { statusline = { "dashboard", "alpha" } },
            },
            sections = {
                lualine_a = { "mode" },
                lualine_b = { "branch", { "diff", symbols = { added = "+", modified = "~", removed = "-" } } },
                lualine_c = {
                    {
                        "diagnostics",
                        symbols = { error = " ", warn = " ", info = " ", hint = " " },
                    },
                    { "filename", path = 1, symbols = { modified = " ●", readonly = " ", unnamed = "[No Name]" } },
                    -- LSP-сервер-индикатор
                    {
                        function()
                            local clients = vim.lsp.get_clients({ bufnr = 0 })
                            if #clients == 0 then return "" end
                            local names = {}
                            for _, c in ipairs(clients) do table.insert(names, c.name) end
                            return " " .. table.concat(names, ",")
                        end,
                    },
                },
                lualine_x = { "encoding", "fileformat", "filetype" },
                lualine_y = { "progress" },
                lualine_z = { "location" },
            },
            extensions = { "neo-tree", "lazy", "mason", "trouble", "quickfix", "aerial" },
        },
    },

    -- =========================================================
    -- bufferline — VS Code-style табы
    -- =========================================================
    {
        "akinsho/bufferline.nvim",
        version = "*",
        event = "VeryLazy",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {
            options = {
                mode = "buffers",
                diagnostics = "nvim_lsp",
                diagnostics_indicator = function(_, _, diag)
                    local s = " "
                    if diag.error then s = s .. " " .. diag.error end
                    if diag.warning then s = s .. " " .. diag.warning end
                    return s
                end,
                offsets = {
                    {
                        filetype = "neo-tree",
                        text = "Explorer",
                        text_align = "center",
                        separator = true,
                    },
                },
                show_buffer_close_icons = false,
                show_close_icon = false,
                always_show_bufferline = true,
            },
        },
    },

    -- =========================================================
    -- nvim-web-devicons (общая зависимость)
    -- =========================================================
    {
        "nvim-tree/nvim-web-devicons",
        lazy = true,
    },
}
