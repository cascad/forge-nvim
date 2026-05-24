-- UI: statusline (lualine), bufferline, which-key, notifications, icons.

return {
    -- =========================================================
    -- Icons. mini.icons is a drop-in replacement for nvim-web-devicons
    -- that lazyloads icons on demand. Many plugins still ask for
    -- nvim-web-devicons by name, so we also register the shim.
    -- =========================================================
    {
        "echasnovski/mini.icons",
        lazy = true,
        opts = {},
        init = function()
            package.preload["nvim-web-devicons"] = function()
                require("mini.icons").mock_nvim_web_devicons()
                return package.loaded["nvim-web-devicons"]
            end
        end,
    },

    -- =========================================================
    -- Statusline
    -- =========================================================
    {
        "nvim-lualine/lualine.nvim",
        event = "VeryLazy",
        dependencies = { "echasnovski/mini.icons" },
        opts = function()
            return {
                options = {
                    theme = "tokyonight",
                    globalstatus = true,
                    section_separators = "",
                    component_separators = "",
                    disabled_filetypes = {
                        statusline = {
                            "alpha", "lazy", "mason", "TelescopePrompt",
                            "Outline", "Explorer", "BufferList", "Bookmarks",
                            "CallHierarchy", "TerminalBrowser",
                            "Changes", "Commits", "Branches", "Timeline",
                        },
                    },
                },
                sections = {
                    lualine_a = { "mode" },
                    lualine_b = { "branch", "diff", "diagnostics" },
                    lualine_c = {
                        { "filename", path = 1, symbols = { modified = " ", readonly = " " } },
                    },
                    lualine_x = {
                        { require("lazy.status").updates, cond = require("lazy.status").has_updates, color = { fg = "#ff9e64" } },
                        "encoding", "fileformat", "filetype",
                    },
                    lualine_y = { "progress" },
                    lualine_z = { "location" },
                },
                extensions = { "lazy", "mason", "neo-tree", "quickfix", "trouble" },
            }
        end,
    },

    -- =========================================================
    -- Bufferline (tabs across the top)
    -- =========================================================
    {
        "akinsho/bufferline.nvim",
        event = "VeryLazy",
        dependencies = { "echasnovski/mini.icons" },
        keys = {
            { "<leader>bp", "<cmd>BufferLineTogglePin<CR>",         desc = "Buffer: pin" },
            { "<leader>bo", "<cmd>BufferLineCloseOthers<CR>",       desc = "Buffer: close others" },
            { "<leader>br", "<cmd>BufferLineCloseRight<CR>",        desc = "Buffer: close right" },
            { "<leader>bl", "<cmd>BufferLineCloseLeft<CR>",         desc = "Buffer: close left" },
            { "[B",         "<cmd>BufferLineMovePrev<CR>",          desc = "Buffer: move prev" },
            { "]B",         "<cmd>BufferLineMoveNext<CR>",          desc = "Buffer: move next" },
            { "<leader>1",  "<cmd>BufferLineGoToBuffer 1<CR>",      desc = "Buffer 1" },
            { "<leader>2",  "<cmd>BufferLineGoToBuffer 2<CR>",      desc = "Buffer 2" },
            { "<leader>3",  "<cmd>BufferLineGoToBuffer 3<CR>",      desc = "Buffer 3" },
            { "<leader>4",  "<cmd>BufferLineGoToBuffer 4<CR>",      desc = "Buffer 4" },
            { "<leader>5",  "<cmd>BufferLineGoToBuffer 5<CR>",      desc = "Buffer 5" },
        },
        opts = {
            options = {
                mode = "buffers",
                diagnostics = "nvim_lsp",
                always_show_bufferline = false,
                show_buffer_close_icons = false,
                offsets = {
                    { filetype = "Explorer", text = "Explorer", separator = true, text_align = "left" },
                    { filetype = "Outline",  text = "Outline",  separator = true, text_align = "left" },
                },
            },
        },
    },

    -- =========================================================
    -- Which-key — keymap hints. v3 API.
    -- =========================================================
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            preset = "modern",
            spec = {
                { "<leader>b", group = "buffer" },
                { "<leader>c", group = "code" },
                { "<leader>d", group = "debug" },
                { "<leader>f", group = "find" },
                { "<leader>g", group = "git" },
                { "<leader>l", group = "lsp" },
                { "<leader>o", group = "open" },
                { "<leader>q", group = "quit/session" },
                { "<leader>r", group = "run/task" },
                { "<leader>s", group = "search" },
                { "<leader>t", group = "tab/panel" },
                { "<leader>u", group = "ui toggle" },
                { "<leader>x", group = "diagnostics/trouble" },
            },
        },
        keys = {
            { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "Buffer keymaps" },
        },
    },

    -- =========================================================
    -- Notifications + cmdline replacement
    -- =========================================================
    {
        "folke/noice.nvim",
        event = "VeryLazy",
        dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
        opts = {
            lsp = {
                override = {
                    ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                    ["vim.lsp.util.stylize_markdown"]                = true,
                    ["cmp.entry.get_documentation"]                  = true,
                },
            },
            routes = {
                {
                    filter = { event = "msg_show", any = { { find = "%d+L, %d+B" }, { find = "; after #%d+" }, { find = "; before #%d+" } } },
                    view = "mini",
                },
            },
            presets = {
                bottom_search   = true,
                command_palette = true,
                long_message_to_split = true,
                lsp_doc_border  = true,
            },
        },
    },

    {
        "rcarriga/nvim-notify",
        lazy = true,
        opts = {
            timeout = 3000,
            max_height = function() return math.floor(vim.o.lines * 0.75) end,
            max_width  = function() return math.floor(vim.o.columns * 0.5) end,
            render = "wrapped-compact",
            stages = "fade",
        },
    },

    -- =========================================================
    -- Indent guides (visual only)
    -- =========================================================
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        event = "BufReadPost",
        opts = {
            indent  = { char = "│", tab_char = "│" },
            scope   = { enabled = false },
            exclude = {
                filetypes = {
                    "help", "alpha", "dashboard", "lazy", "mason", "notify",
                    "Outline", "Explorer", "BufferList", "Bookmarks",
                    "CallHierarchy", "TerminalBrowser",
                    "Changes", "Commits", "Branches", "Timeline",
                },
            },
        },
    },

    -- =========================================================
    -- Highlight word under cursor
    -- =========================================================
    {
        "RRethy/vim-illuminate",
        event = "BufReadPost",
        opts = {
            delay = 200,
            -- nvim-treesitter (main branch) выпилил старый locals API,
            -- из-за чего treesitter-провайдер illuminate падает
            -- "attempt to call method 'parent' (a nil value)".
            -- Оставляем LSP (document highlight) + regex fallback —
            -- этого хватает для подсветки одинаковых идентификаторов.
            providers = { "lsp", "regex" },
            filetypes_denylist = {
                "alpha", "lazy", "mason", "TelescopePrompt", "help", "qf",
                "Outline", "Explorer", "BufferList", "Bookmarks",
                "CallHierarchy", "TerminalBrowser",
                "Changes", "Commits", "Branches", "Timeline",
            },
        },
        config = function(_, opts) require("illuminate").configure(opts) end,
    },

    -- =========================================================
    -- Trouble — pretty diagnostics / quickfix / refs list
    -- =========================================================
    {
        "folke/trouble.nvim",
        cmd = "Trouble",
        opts = { focus = true },
        keys = {
            { "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>",              desc = "Diagnostics (Trouble)" },
            { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Buf Diagnostics" },
            { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<CR>",      desc = "Symbols (Trouble)" },
            { "<leader>xl", "<cmd>Trouble lsp toggle focus=false win.position=right<CR>", desc = "LSP refs/defs/impls" },
            { "<leader>xL", "<cmd>Trouble loclist toggle<CR>",                  desc = "Location list" },
            { "<leader>xQ", "<cmd>Trouble qflist toggle<CR>",                   desc = "Quickfix list" },
        },
    },
}
