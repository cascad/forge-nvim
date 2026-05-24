-- LSP layer: mason (binary installs) + nvim-lspconfig (server bridge).
--
-- All servers are configured via `vim.lsp.config(name, opts)` (Neovim
-- 0.11+ API). lspconfig provides the default opts; we extend them with
-- capabilities from blink.cmp and per-server settings.
--
-- Buffer-local LSP keymaps are attached in an `LspAttach` autocmd so
-- they only exist where an LSP is actually live.

local ensure_installed = {
    "lua-language-server",
    "rust-analyzer",
    "gopls",
    "pyright",
    "ruff",
    "typescript-language-server",
    "json-lsp",
    "yaml-language-server",
    "taplo",        -- TOML
    "bash-language-server",
    "marksman",     -- Markdown
}

return {
    -- =========================================================
    -- Mason: install LSP/DAP/formatter binaries.
    -- =========================================================
    {
        "williamboman/mason.nvim",
        cmd = { "Mason", "MasonInstall", "MasonUpdate" },
        build = ":MasonUpdate",
        keys = {
            { "<leader>cm", "<cmd>Mason<CR>", desc = "Mason" },
        },
        opts = {
            ui = {
                border = "rounded",
                icons = { package_installed = "✓", package_pending = "➜", package_uninstalled = "✗" },
            },
        },
    },

    -- mason-tool-installer keeps a declarative list of tools that must
    -- exist; auto-installs missing ones on startup.
    {
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        dependencies = { "williamboman/mason.nvim" },
        event = "VeryLazy",
        opts = {
            ensure_installed = ensure_installed,
            auto_update = false,
            run_on_start = true,
            start_delay = 3000,
        },
    },

    -- =========================================================
    -- LSP servers
    -- =========================================================
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "williamboman/mason.nvim",
            "saghen/blink.cmp",   -- capabilities source
        },
        config = function()
            -- nvim-lspconfig нужен ТОЛЬКО как поставщик дефолтных
            -- конфигов через `lsp/<name>.lua` runtime files. Сам плагин
            -- больше не предоставляет `lspconfig.<name>.setup{}` —
            -- регистрация делается через `vim.lsp.config` + `vim.lsp.enable`.
            local blink = require("blink.cmp")
            local capabilities = blink.get_lsp_capabilities()

            -- Buffer-local maps on attach.
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("user_lsp_attach", { clear = true }),
                callback = function(args)
                    local buf = args.buf
                    local map = function(lhs, rhs, desc, mode)
                        vim.keymap.set(mode or "n", lhs, rhs, { buffer = buf, desc = desc })
                    end

                    map("gd",         vim.lsp.buf.definition,      "LSP: definition")
                    map("gD",         vim.lsp.buf.declaration,     "LSP: declaration")
                    map("gr",         vim.lsp.buf.references,      "LSP: references")
                    map("gi",         vim.lsp.buf.implementation,  "LSP: implementation")
                    map("gy",         vim.lsp.buf.type_definition, "LSP: type definition")
                    map("K",          vim.lsp.buf.hover,           "LSP: hover")
                    map("gK",         vim.lsp.buf.signature_help,  "LSP: signature help")
                    map("<leader>ln", vim.lsp.buf.rename,          "LSP: rename")
                    map("<leader>la", vim.lsp.buf.code_action,     "LSP: code action", { "n", "v" })
                    map("<leader>lf", function() vim.lsp.buf.format({ async = true }) end, "LSP: format")
                end,
            })

            -- Per-server settings. Anything not listed falls back to
            -- lspconfig defaults via `mason-tool-installer` install.
            local servers = {
                lua_ls = {
                    settings = {
                        Lua = {
                            workspace = { checkThirdParty = false },
                            telemetry = { enable = false },
                            diagnostics = { globals = { "vim" } },
                            completion = { callSnippet = "Replace" },
                        },
                    },
                },
                rust_analyzer = {
                    settings = {
                        ["rust-analyzer"] = {
                            cargo = { allFeatures = true, loadOutDirsFromCheck = true },
                            checkOnSave = { command = "clippy" },
                            procMacro = { enable = true },
                            inlayHints = {
                                parameterHints = { enable = true },
                                typeHints      = { enable = true },
                            },
                        },
                    },
                },
                gopls = {
                    settings = {
                        gopls = {
                            usePlaceholders   = true,
                            completeUnimported = true,
                            analyses          = { unusedparams = true, shadow = true },
                            staticcheck       = true,
                            gofumpt           = true,
                            hints = {
                                assignVariableTypes    = true,
                                compositeLiteralFields = true,
                                constantValues         = true,
                                functionTypeParameters = true,
                                parameterNames         = true,
                                rangeVariableTypes     = true,
                            },
                        },
                    },
                },
                pyright = {
                    settings = {
                        python = {
                            analysis = {
                                typeCheckingMode = "basic",
                                autoSearchPaths  = true,
                                useLibraryCodeForTypes = true,
                                diagnosticMode   = "openFilesOnly",
                            },
                        },
                    },
                },
                ruff = {},
                ts_ls = {},
                jsonls = {},
                yamlls = {},
                taplo = {},
                bashls = {},
                marksman = {},
            }

            local server_names = {}
            for name, opts in pairs(servers) do
                opts.capabilities = vim.tbl_deep_extend("force", {}, capabilities, opts.capabilities or {})
                vim.lsp.config(name, opts)
                table.insert(server_names, name)
            end

            vim.lsp.enable(server_names)
        end,
    },

    -- =========================================================
    -- LSP UX helpers
    -- =========================================================
    {
        "stevearc/aerial.nvim",
        cmd = { "AerialToggle", "AerialOpen" },
        opts = {
            backends = { "treesitter", "lsp", "markdown" },
            layout = { default_direction = "prefer_right", min_width = 30 },
            attach_mode = "global",
            show_guides = true,
        },
        keys = {
            { "<leader>lo", "<cmd>AerialToggle<CR>", desc = "LSP: outline (aerial)" },
        },
    },

    -- LSP progress notifications (tiny floating window).
    {
        "j-hui/fidget.nvim",
        event = "LspAttach",
        opts = {
            progress = {
                display = { done_icon = "✓", progress_icon = { pattern = "dots" } },
            },
            notification = {
                window = { winblend = 0, border = "rounded" },
            },
        },
    },
}
