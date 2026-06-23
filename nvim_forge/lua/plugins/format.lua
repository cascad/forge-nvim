-- conform.nvim — форматирование. Реплицирует:
--   * editor.formatOnSave: true (settings.json)
--   * Go     → gofumpt + LSP-fallback (gopls/gofmt). goimports НЕ ИСПОЛЬЗУЕМ —
--             эвристика выбора импорта ошибается на коллизиях (rand, log, parse).
--             Импорты добавляем через <leader>la / <leader>lO (gopls предлагает
--             ВЫБОР при неоднозначности, а не угадывает).
--   * Rust   → rustfmt (через rust-analyzer).
--   * Python → ruff format + ruff isort.
--   * Lua    → stylua.
--
-- ЕДИНЫЙ механизм для не-LSP-тулз — СИСТЕМНАЯ установка (mason-tool-installer
-- их больше НЕ держит, чтобы не было двух конкурирующих источников):
--   gofumpt  : go install mvdan.cc/gofumpt@latest      (в PATH)
--   golines  : go install github.com/segmentio/golines@latest
--   stylua   : cargo install stylua   |   winget install JohnnyMorganz.StyLua
--   prettier : npm i -g prettier      (или prettierd)
-- Если что-то unavailable, conform тихо пропустит этот форматтер и сделает
-- lsp_format = "fallback" (если LSP-сервер прицеплен) — без ошибок и фризов.

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
                -- Go: golines + gofumpt поверх gopls.
                --   * golines — РАЗБИВАЕТ длинные строки (gofmt/gofumpt
                --     этого НЕ делают: в стиле Go нет лимита длины строки,
                --     поэтому длинный fmt.Printf(...) официальные тулзы
                --     оставляют как есть). golines ломает по аргументам/
                --     цепочкам вызовов. Лимит = 100 (см. formatters.golines
                --     ниже, совпадает с colorcolumn). Требует системной
                --     установки: go install github.com/segmentio/golines@latest
                --     Если не установлен — conform тихо пропустит его,
                --     gofumpt/gopls отработают как раньше (без переносов).
                --   * gofumpt — строгий стиль поверх gofmt (убирает лишние
                --     пустые строки, выравнивает и т.п.).
                -- goimports НЕ используем — эвристика выбора пакета
                -- ошибается на коллизиях (rand, log, parse). Импорты —
                -- через <leader>la / <leader>lO (gopls предлагает ВЫБОР).
                go     = { "golines", "gofumpt", lsp_format = "fallback" },
                python = { "ruff_organize_imports", "ruff_format" },
                lua    = { "stylua", lsp_format = "fallback" },

                json   = { "prettierd", "prettier", stop_after_first = true },
                yaml   = { "prettierd", "prettier", stop_after_first = true },
                markdown = { "prettierd", "prettier", stop_after_first = true },
                toml   = {},
                ["*"]  = { "trim_whitespace", "trim_newlines" },
            },
            -- format_after_save (АСИНХРОННЫЙ), а НЕ format_on_save.
            --
            -- format_on_save — СИНХРОННЫЙ хук на BufWritePre: он блокирует
            -- главный цикл редактора, пока внешний форматтер (gofumpt/golines/
            -- rustfmt/prettier/stylua) не отработает — до timeout_ms (был 1000мс).
            -- То есть КАЖДЫЙ <C-s>/:w по ходу правки кода замораживал ввод на
            -- сотни мс. Это и были «фризы при написании» (problem 2 → опять).
            --
            -- Жёсткое правило юзера: набор кода НИКОГДА не должен подвисать;
            -- форматтер пусть «тормозит» в фоне. format_after_save запускает
            -- форматтер АСИНХРОННО уже ПОСЛЕ записи (на BufWritePost) и затем
            -- применяет дифф отдельной записью — ввод не блокируется ни на
            -- explicit :w, ни тем более на autosave.
            format_after_save = function(bufnr)
                -- Hard bypass — глобально / per-buffer.
                if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
                    return
                end

                -- НЕ форматируем фоновые autosave-записи (каждые 500мс).
                -- Форматируем ТОЛЬКО на явном сохранении (:w / Ctrl+S), и то
                -- асинхронно. Autosave продолжает кормить LSP-диагностики и
                -- rust-analyzer checkOnSave/clippy (autocmd'ы записи включены).
                if vim.g.user_auto_save_active then
                    return
                end

                return { lsp_format = "fallback" }
            end,
            formatters = {
                stylua = {
                    prepend_args = { "--indent-type", "Spaces", "--indent-width", "4", "--column-width", "120" },
                },
                golines = {
                    -- -m 100 — макс. длина строки (совпадает с colorcolumn).
                    -- golines читает stdin, ломает длинные строки и внутри
                    -- прогоняет gofmt (по умолчанию). Финальный строгий
                    -- стиль накладывает gofumpt следующим в цепочке (он —
                    -- надмножество gofmt, так что двойной проход безопасен).
                    -- --no-reformat-tags — не трогать struct-теги.
                    prepend_args = { "-m", "100", "--no-reformat-tags" },
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
