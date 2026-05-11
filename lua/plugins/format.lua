-- conform.nvim — форматирование. Реплицирует:
--   * editor.formatOnSave: true (settings.json)
--   * [go] organizeImports + formatOnSave + go.formatTool: goimports
--   * Rust → rustfmt (через rust-analyzer), Python → ruff format + ruff isort.

return {
    {
        "stevearc/conform.nvim",
        event = { "BufWritePre" },
        cmd = { "ConformInfo", "Format" },
        keys = {
            -- Для Rust clippy запускается АВТО на каждый :w
            -- (rust_analyzer.checkOnSave = true в lsp.lua).
            -- Здесь — просто rustfmt + LSP-format fallback.
            {
                "<S-A-f>",
                function()
                    require("conform").format({ async = true, lsp_format = "fallback" })
                end,
                mode = { "n", "v" },
                desc = "Format buffer/range",
            },
            {
                "<leader>lf",
                function()
                    require("conform").format({ async = true, lsp_format = "fallback" })
                end,
                desc = "LSP: format",
            },
        },
        opts = {
            formatters_by_ft = {
                rust   = { "rustfmt", lsp_format = "fallback" },
                go     = { "goimports", "gofumpt" },
                python = { "ruff_organize_imports", "ruff_format" },
                lua    = { "stylua" },

                json   = { "prettierd", "prettier", stop_after_first = true },
                yaml   = { "prettierd", "prettier", stop_after_first = true },
                markdown = { "prettierd", "prettier", stop_after_first = true },
                toml   = {},
                ["*"]  = { "trim_whitespace", "trim_newlines" },
            },
            format_on_save = function(bufnr)
                -- Не блокируем сохранение, если форматтер отвалился — просто
                -- ругаемся в :messages.
                if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
                    return
                end
                -- auto-save.nvim нужен Rust'у для быстрого checkOnSave/clippy,
                -- но форматировать каждые 500мс нельзя: это дёргает rustfmt
                -- во время набора. Явный <C-s>/:w и hotkey форматируют как раньше.
                if vim.g.user_auto_save_active then
                    return
                end
                return { timeout_ms = 1000, lsp_format = "fallback" }
            end,
            formatters = {
                stylua = {
                    prepend_args = { "--indent-type", "Spaces", "--indent-width", "4", "--column-width", "120" },
                },
            },
            notify_on_error = true,
        },
        init = function()
            -- Toggle для autoformat (бывает нужно в legacy-проектах с шумной диффой)
            vim.api.nvim_create_user_command("FormatDisable", function(args)
                if args.bang then vim.b.disable_autoformat = true
                else vim.g.disable_autoformat = true end
            end, { desc = "Disable autoformat-on-save", bang = true })
            vim.api.nvim_create_user_command("FormatEnable", function()
                vim.b.disable_autoformat = false
                vim.g.disable_autoformat = false
            end, { desc = "Re-enable autoformat-on-save" })
        end,
    },
}
