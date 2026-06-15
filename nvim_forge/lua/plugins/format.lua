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
-- Тулзы ставятся СИСТЕМНО (этот сетап не использует mason-tool-installer
-- для не-Python-тулз):
--   gofumpt  : go install mvdan.cc/gofumpt@latest
--   stylua   : cargo install stylua   |   winget install JohnnyMorganz.StyLua
--   prettier : npm i -g prettier      (или prettierd)
-- Если что-то unavailable, conform тихо пропустит формат и
-- сделает lsp_format = "fallback" (если LSP сервер прицеплен).

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
            format_on_save = function(bufnr)
                -- Hard bypass — глобально / per-buffer.
                if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
                    return
                end

                -- НЕ форматируем фоновые autosave-записи.
                --
                -- Это и был источник «фриза при форматировании» (problem 2):
                -- format_on_save — СИНХРОННЫЙ хук на BufWritePre, а gofumpt/
                -- golines/rustfmt/prettier — внешние процессы. auto-save.nvim
                -- пишет каждые 500мс по ходу набора, и на КАЖДУЮ такую запись
                -- редактор синхронно ждал внешний форматтер → подвисал прямо
                -- во время печати.
                --
                -- Autosave нужен не ради формата, а ради LSP-диагностик и
                -- rust-analyzer checkOnSave/clippy — они продолжают работать
                -- (autocmd'ы записи не отключены). Форматируем ТОЛЬКО на ЯВНОМ
                -- сохранении (:w / Ctrl+S): тогда user_auto_save_active=false,
                -- блокировка одноразовая и ожидаемая, а не каждые полсекунды.
                if vim.g.user_auto_save_active then
                    return
                end

                return { timeout_ms = 1000, lsp_format = "fallback" }
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
