-- WezTerm на Windows: подменные клавиши для сочетаний nvim_forge
-- (WT-KEYS-10, WT-KBD-9; add-nvim-chords-on-windows).
--
-- Между WezTerm и nvim на Windows стоит ConPTY, и часть сочетаний до nvim
-- не доходит отдельной клавишей: Ctrl+Shift+F приходит как <C-f>, Ctrl+Space
-- не приходит вовсе (WT-KBD-6). WezTerm перехватывает эти сочетания и, если
-- панель объявлена nvim_forge, шлёт вместо них подменную клавишу, которая
-- через ConPTY проходит (итог пробы: tests/wezterm/conpty/chords.fixture.json).
-- Здесь подменная клавиша переназначается на исходное сочетание во всех
-- режимах (remap): срабатывают те же привязки, что на macOS, включая `keys`
-- lazy.nvim и буферные привязки.
--
-- Объявление: user var FORGE_NVIM=<версия таблицы> через OSC 1337 SetUserVar,
-- ставится на VimEnter/VimResume, снимается на VimLeavePre/VimSuspend, только
-- при интерфейсе-терминале (не в headless и не в Neovide). WezTerm подменяет,
-- только если версия совпала с его таблицей; иначе — как без подмены.
--
-- Таблица — в двух местах (здесь и в wezterm.lua, ветка Windows) с общей
-- версией: wezterm.lua — один самодостаточный файл. Связь держит тест
-- tests/wezterm/key-ownership.test.lua (WT-KEYS-10). Сменил клавишу или
-- состав — подними версию в обоих местах.
--
-- Выключатель: vim.g.forge_wezterm_chords = false — объявления нет, WezTerm
-- ничего не подменяет (привязки подменных клавиш при этом безвредны).
-- Ручной сброс зависшего объявления из pwsh — docs/WEZTERM.md.
local M = {}

M.version = "1"

M.chords = {
    { chord = "Ctrl+Shift+F",  lhs = "<C-S-f>",   key = "<C-F13>" },
    { chord = "Ctrl+Shift+P",  lhs = "<C-S-p>",   key = "<C-F14>" },
    { chord = "Ctrl+Shift+E",  lhs = "<C-S-e>",   key = "<C-F15>" },
    { chord = "Ctrl+Shift+D",  lhs = "<C-S-d>",   key = "<C-F16>" },
    { chord = "Ctrl+Shift+F5", lhs = "<C-S-F5>",  key = "<C-F17>" },
    { chord = "Ctrl+.",        lhs = "<C-.>",     key = "<C-F18>" },
    { chord = "Ctrl+Enter",    lhs = "<C-CR>",    key = "<C-F19>" },
    { chord = "Ctrl+/",        lhs = "<C-/>",     key = "<C-F20>" },
    { chord = "Ctrl+Space",    lhs = "<C-Space>", key = "<C-S-F13>" },
}

M.modes = { "n", "x", "s", "o", "i", "c", "t" }

local function enabled()
    return vim.g.forge_wezterm_chords ~= false
end

-- Интерфейс-терминал (TUI): у него stdout_tty. В headless интерфейсов нет,
-- у Neovide и прочих GUI stdout_tty нет — объявлять некуда.
local function tty_ui()
    for _, ui in ipairs(vim.api.nvim_list_uis()) do
        if ui.stdout_tty then return true end
    end
    return false
end

local function announce(value)
    vim.api.nvim_ui_send("\027]1337;SetUserVar=FORGE_NVIM=" .. vim.base64.encode(value) .. "\007")
end

function M.setup()
    for _, row in ipairs(M.chords) do
        vim.keymap.set(M.modes, row.key, row.lhs, { remap = true, desc = "WezTerm: " .. row.chord })
    end
    local group = vim.api.nvim_create_augroup("forge_wezterm_chords", { clear = true })
    vim.api.nvim_create_autocmd({ "VimEnter", "VimResume" }, {
        group = group,
        callback = function()
            if enabled() and tty_ui() then announce(M.version) end
        end,
    })
    vim.api.nvim_create_autocmd({ "VimLeavePre", "VimSuspend" }, {
        group = group,
        callback = function()
            if enabled() and tty_ui() then announce("") end
        end,
    })
end

return M
