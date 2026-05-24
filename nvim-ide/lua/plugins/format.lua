-- Format: conform.nvim. Routes external formatters per filetype.

return {
    {
        "stevearc/conform.nvim",
        event = { "BufWritePre" },
        cmd = { "ConformInfo" },
        keys = {
            { "<leader>cF", function() require("conform").format({ async = true, lsp_fallback = true }) end,
              mode = { "n", "v" }, desc = "Format buffer/selection" },
            { "<leader>uF", function()
                vim.g.disable_autoformat = not vim.g.disable_autoformat
                vim.notify("Autoformat " .. (vim.g.disable_autoformat and "OFF" or "ON"))
            end, desc = "Toggle: autoformat" },
        },
        opts = {
            notify_on_error = true,
            formatters_by_ft = {
                lua        = { "stylua" },
                python     = { "ruff_format", "ruff_organize_imports" },
                rust       = { "rustfmt", lsp_format = "fallback" },
                go         = { "goimports", "gofumpt" },
                javascript = { "prettierd", "prettier", stop_after_first = true },
                typescript = { "prettierd", "prettier", stop_after_first = true },
                json       = { "prettierd", "prettier", stop_after_first = true },
                jsonc      = { "prettierd", "prettier", stop_after_first = true },
                yaml       = { "prettierd", "prettier", stop_after_first = true },
                markdown   = { "prettierd", "prettier", stop_after_first = true },
                toml       = { "taplo" },
                sh         = { "shfmt" },
            },
            format_on_save = function(buf)
                if vim.g.disable_autoformat or vim.b[buf].disable_autoformat then
                    return
                end
                return { timeout_ms = 1500, lsp_fallback = true }
            end,
        },
    },
}
