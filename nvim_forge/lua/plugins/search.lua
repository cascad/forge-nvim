-- Project search/replace panel.

return {
    {
        "MagicDuck/grug-far.nvim",
        cmd = { "GrugFar", "GrugFarWithin" },
        keys = {
            { "<C-S-f>",    function() require("ide").show("search") end, desc = "Search: panel" },
            { "<leader>sF", function() require("ide").show("search") end, desc = "Search: panel" },
            { "<leader>sR", function() require("ide").show("search") end, desc = "Search: replace panel" },
            { "<leader>sV", function() vim.cmd("'<,'>GrugFarWithin") end, desc = "Search: within visual selection", mode = "v" },
        },
    },

    -- =====================================================================
    -- nvim-hlslens — «лупа» поиска: счётчик совпадений [n/total] виртуальным
    -- текстом у каждого вхождения и отдельно у текущего под курсором.
    --
    -- Работает ПОВЕРХ нативного incsearch+hlsearch (см. options.lua), не
    -- ломая живую подсветку всех совпадений (FIXLOG §20) — а дополняя её
    -- цифрами. enable_incsearch=true рисует счётчик прямо во время набора
    -- паттерна `/foo`, ещё до Enter.
    --
    -- Загружаем на BufReadPost (а не лениво по `/`), чтобы CmdlineChanged-
    -- хук incsearch был зарегистрирован ДО первого поиска.
    -- =====================================================================
    {
        "kevinhwang91/nvim-hlslens",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            require("hlslens").setup({
                -- Держим подсветку и счётчик до явного :noh (не гасим при
                -- движении курсора).
                calm_down = false,
                -- Показывать lens у ВСЕХ совпадений, не только у ближайшего.
                nearest_only = false,
                -- Только инлайновый virt-text, без плавающего окна у курсора
                -- (оно перекрывало бы текст во время набора).
                nearest_float_when = "never",
                -- Счётчик прямо во время набора паттерна.
                enable_incsearch = true,
            })

            -- n/N обновляют lens и держат направление; `*`/`#`/g*/g# —
            -- поиск слова под курсором с тем же счётчиком. langmap
            -- (config/ru_keys.lua) даёт это и под русской раскладкой, как у
            -- остальных normal-команд (ср. j/k в keymaps.lua).
            local kopts = { noremap = true, silent = true }
            local function jump(cmd)
                return ("<Cmd>execute('normal! ' . v:count1 . '%s')<CR>"
                    .. "<Cmd>lua require('hlslens').start()<CR>"):format(cmd)
            end
            vim.keymap.set("n", "n", jump("n"), kopts)
            vim.keymap.set("n", "N", jump("N"), kopts)
            vim.keymap.set("n", "*",  [[*<Cmd>lua require('hlslens').start()<CR>]],  kopts)
            vim.keymap.set("n", "#",  [[#<Cmd>lua require('hlslens').start()<CR>]],  kopts)
            vim.keymap.set("n", "g*", [[g*<Cmd>lua require('hlslens').start()<CR>]], kopts)
            vim.keymap.set("n", "g#", [[g#<Cmd>lua require('hlslens').start()<CR>]], kopts)
        end,
    },
}
