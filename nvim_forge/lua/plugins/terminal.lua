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
        cmd = { "ToggleTerm", "ToggleTermToggleAll", "TermExec" },
        keys = {
            { "<leader>tt", "<cmd>ToggleTerm direction=horizontal<CR>", desc = "Terminal: toggle" },
            { "<leader>tT", "<cmd>ToggleTerm direction=float<CR>",      desc = "Terminal: float" },
            { "<leader>tV", "<cmd>ToggleTerm direction=vertical<CR>",   desc = "Terminal: vertical split" },
            -- VS Code-style Ctrl+\` (на терминалах часто <C-_> или <C-/>).
            -- Backtick неуниверсален, поэтому <C-\\> + <C-t> как алиасы.
            { "<C-\\>",     "<cmd>ToggleTerm<CR>",                        desc = "Terminal: toggle" },
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

            -- На Windows shell = pwsh (PowerShell 7+), если установлен.
            -- Иначе fallback на дефолтный shell (cmd.exe).
            shell = (vim.fn.executable("pwsh") == 1) and "pwsh -NoLogo" or vim.o.shell,

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
    },
}
