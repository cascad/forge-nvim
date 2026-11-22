-- toggleterm.nvim — persistent terminals с state, integrated с edgy.
-- Заменяет старый `<leader>tt` который дёргал `botright split | terminal pwsh`
-- (см. config/keymaps.lua), потому что:
--   1. toggleterm запоминает терминал между toggle (state, history, scroll).
--   2. Создаёт окно с filetype = "toggleterm" — edgy его подхватит как
--      bottom-edgebar view (см. plugins/edgy.lua).
--   3. Несколько именованных терминалов (term 1/2/3) — для разных задач.

return {
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        cmd = { "ToggleTerm", "ToggleTermToggleAll", "TermExec", "ForgeTerminalShell", "ForgeTerminalNew" },
        keys = {
            { "<leader>tt", "<cmd>ToggleTerm direction=horizontal<CR>", desc = "Terminal: toggle" },
            { "<leader>tT", "<cmd>ToggleTerm direction=float<CR>",      desc = "Terminal: float" },
            { "<leader>tV", "<cmd>ToggleTerm direction=vertical<CR>",   desc = "Terminal: vertical split" },
            { "<leader>tS", "<cmd>ForgeTerminalShell<CR>", desc = "Terminal: choose shell" },
            { "<leader>tN", "<cmd>ForgeTerminalNew<CR>", desc = "Terminal: new console" },
            -- VS Code-style Ctrl+\` (на терминалах часто <C-_> или <C-/>).
            -- Backtick неуниверсален, поэтому <C-\\> + <C-t> как алиасы.
            -- В terminal-normal сохраняем native prefix, включая repeat escape
            -- и завершившийся job. Из кода остаётся прежний быстрый toggle.
            { "<C-\\>", function()
                return vim.bo.buftype == "terminal" and string.char(28) or "<cmd>ToggleTerm<CR>"
            end, expr = true, desc = "Terminal: toggle / native prefix" },
            { "<C-t>",      "<cmd>ToggleTerm<CR>",                        desc = "Terminal: toggle" },
        },
        opts = {
            -- Дефолтное направление — горизонтальный split снизу,
            -- ровно туда, куда edgy ставит bottom edgebar.
            direction = "horizontal",

            -- Высота bottom-терминала. edgy в plugins/edgy.lua тоже
            -- задаёт size = { height = 0.30 } — оба значения близки.
            size = function(term)
                if term.direction == "horizontal" then
                    return 15
                elseif term.direction == "vertical" then
                    return math.floor(vim.o.columns * 0.35)
                end
            end,

            shell = function() return require('forge.terminal_shell').command() end,

            -- Открыть терминал и сразу войти в insert mode (как
            -- юзер ожидает).
            start_in_insert = true,

            -- Закрыть терминал клавишей q в normal mode неудобно
            -- (q используем для всего). Используем стандартный
            -- <C-\\><C-n> для escape в normal.
            insert_mappings = true,
            terminal_mappings = true,

            persist_size = true,
            persist_mode = true,

            -- Не закрывать терминал на выход процесса — пусть
            -- остаётся видимым с "[Process exited 0]", чтобы юзер
            -- успел прочитать вывод.
            close_on_exit = false,

            -- Floating windows для <leader>tT.
            float_opts = {
                border = "rounded",
                width = function() return math.floor(vim.o.columns * 0.85) end,
                height = function() return math.floor(vim.o.lines * 0.80) end,
            },

            -- Подсветка границы highlight'ом FloatBorder — берётся
            -- из catppuccin (см. plugins/ui.lua).
            highlights = {
                FloatBorder = { link = "FloatBorder" },
                NormalFloat = { link = "NormalFloat" },
            },
        },
        config = function(_, opts)
            require('toggleterm').setup(opts)
            vim.api.nvim_create_user_command('ForgeTerminalShell', function()
                require('forge.terminal_shell').choose()
            end, { desc = 'Terminal: choose shell' })
            vim.api.nvim_create_user_command('ForgeTerminalNew', function()
                local ide = require('ide')
                require('ide.controls').focus_code()
                ide.hide_slot('bottom')
                local term = require('toggleterm.terminal').Terminal:new()
                require('ide.ownership').transition('toggleterm', function()
                    term:open()
                end)
                if term:is_open() then ide.show('terminal') end
            end, { desc = 'Terminal: new console' })
        end,
    },
}
