-- Treesitter: syntax-aware highlighting, indent, textobjects, folding.

return {
    {
        "nvim-treesitter/nvim-treesitter",
        -- Pin to `master`. The new `main` branch is a ground-up rewrite
        -- (TS 1.0) that drops `nvim-treesitter.configs`, the incremental
        -- selection module, and the textobjects integration. The setup
        -- below uses the classic API that `master` still ships.
        branch = "master",
        event = { "BufReadPost", "BufNewFile" },
        build = ":TSUpdate",
        dependencies = {
            { "nvim-treesitter/nvim-treesitter-textobjects", branch = "master" },
        },
        cmd = { "TSUpdate", "TSInstall", "TSUpdateSync" },
        opts = {
            ensure_installed = {
                "bash", "c", "cmake", "cpp", "css", "diff", "dockerfile",
                "go", "gomod", "gosum", "gowork",
                "html", "javascript", "typescript", "tsx",
                "json", "jsonc", "yaml", "toml", "ini",
                "lua", "luadoc", "luap", "vim", "vimdoc", "query", "regex",
                "markdown", "markdown_inline",
                "python", "rust", "sql",
                "gitcommit", "gitignore", "git_config", "git_rebase",
            },
            auto_install = true,
            highlight = { enable = true },
            indent    = { enable = true },
            incremental_selection = {
                enable = true,
                keymaps = {
                    init_selection    = "<C-space>",
                    node_incremental  = "<C-space>",
                    node_decremental  = "<bs>",
                    scope_incremental = "<C-s>",
                },
            },
            textobjects = {
                select = {
                    enable = true,
                    lookahead = true,
                    keymaps = {
                        ["af"] = "@function.outer",
                        ["if"] = "@function.inner",
                        ["ac"] = "@class.outer",
                        ["ic"] = "@class.inner",
                        ["aa"] = "@parameter.outer",
                        ["ia"] = "@parameter.inner",
                    },
                },
                move = {
                    enable = true,
                    set_jumps = true,
                    goto_next_start    = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
                    goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
                },
            },
        },
        config = function(_, opts)
            require("nvim-treesitter.configs").setup(opts)
        end,
    },

    -- Sticky scope context at the top of the window.
    {
        "nvim-treesitter/nvim-treesitter-context",
        event = "BufReadPost",
        opts = { max_lines = 3, multiline_threshold = 1 },
        keys = {
            { "<leader>uc", function() require("treesitter-context").toggle() end, desc = "Toggle: TS context" },
        },
    },
}
