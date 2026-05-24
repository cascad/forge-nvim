-- Editor utilities: autopairs, surround, comment, todo-comments,
-- flash (better f/F/t/T + remote), guess-indent.

return {
    -- Auto-close brackets/quotes, integrated with treesitter for context.
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        opts = {
            check_ts = true,
            ts_config = {
                lua = { "string" },
                javascript = { "template_string" },
            },
            fast_wrap = { map = "<M-e>" },
        },
    },

    -- ys/cs/ds — add/change/delete surroundings.
    {
        "kylechui/nvim-surround",
        event = { "BufReadPre", "BufNewFile" },
        version = "*",
        opts = {},
    },

    -- mini.comment — gcc / gc{motion}.
    {
        "echasnovski/mini.comment",
        event = "VeryLazy",
        opts = {
            options = {
                custom_commentstring = function()
                    return require("ts_context_commentstring.internal").calculate_commentstring()
                        or vim.bo.commentstring
                end,
            },
        },
        dependencies = { "JoosepAlviste/nvim-ts-context-commentstring" },
    },
    {
        "JoosepAlviste/nvim-ts-context-commentstring",
        lazy = true,
        opts = { enable_autocmd = false },
    },

    -- TODO / FIXME / NOTE / HACK / WARN — highlights + Telescope picker.
    {
        "folke/todo-comments.nvim",
        event = { "BufReadPost", "BufNewFile" },
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = {
            { "]t", function() require("todo-comments").jump_next() end, desc = "Next TODO" },
            { "[t", function() require("todo-comments").jump_prev() end, desc = "Prev TODO" },
            { "<leader>st", "<cmd>TodoTelescope<CR>", desc = "Search: TODOs" },
            { "<leader>xt", "<cmd>Trouble todo toggle<CR>", desc = "Trouble: TODOs" },
        },
        opts = {},
    },

    -- flash.nvim — supercharged f/F/t/T + remote operations (jump to
    -- a place, do an action without leaving the start cursor).
    {
        "folke/flash.nvim",
        event = "VeryLazy",
        opts = {},
        keys = {
            { "s",     mode = { "n", "x", "o" }, function() require("flash").jump()        end, desc = "Flash" },
            { "S",     mode = { "n", "x", "o" }, function() require("flash").treesitter()  end, desc = "Flash Treesitter" },
            { "r",     mode = "o",               function() require("flash").remote()      end, desc = "Remote Flash" },
            { "R",     mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Treesitter search" },
            { "<C-s>", mode = "c",               function() require("flash").toggle()      end, desc = "Toggle Flash search" },
        },
    },

    -- guess-indent — auto-detect tab vs spaces / shiftwidth.
    {
        "NMAC427/guess-indent.nvim",
        event = { "BufReadPost", "BufNewFile" },
        opts = {},
    },
}
