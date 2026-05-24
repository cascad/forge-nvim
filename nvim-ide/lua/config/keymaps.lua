-- Global keymaps. Plugin-specific maps live in each plugin's spec.

local map = vim.keymap.set

-- Save / quit
map("n", "<leader>w", "<cmd>write<CR>",    { desc = "Save buffer" })
map("n", "<leader>W", "<cmd>wall<CR>",     { desc = "Save all" })
map("n", "<leader>q", "<cmd>confirm q<CR>", { desc = "Quit window" })
map("n", "<leader>Q", "<cmd>qa<CR>",       { desc = "Quit all" })

-- "Close current file" (VS Code Ctrl+W semantics, mini.bufremove-style).
--
-- Закрывает текущий буфер так, чтобы:
--   * не падал из-за несохранённых изменений (confirm-диалог),
--   * не выходил из Neovim, если буфер последний listed,
--   * НЕ закрывал окно — а значит nvim-ide Explorer / tabline / другие
--     панели остаются на своих местах и не растягиваются на весь экран
--     из-за `equalalways`,
--   * не убивал служебные unlisted-буферы (Explorer, BufferList и т.п.),
--     если шорткат случайно нажали в их окне.
--
-- `force = true` — `bdelete!`, иначе `confirm bdelete` (диалог при unsaved).
local function close_buffer(force)
    local current = vim.api.nvim_get_current_buf()

    if not vim.bo[current].buflisted then
        vim.notify(
            "close_buffer: служебный (unlisted) буфер, не закрываю",
            vim.log.levels.WARN
        )
        return
    end

    -- Находим следующий listed-буфер для подмены в окнах.
    -- Если такого нет — создаём пустой listed-scratch ([No Name]).
    local alt
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if b ~= current
            and vim.api.nvim_buf_is_loaded(b)
            and vim.bo[b].buflisted
        then
            alt = b
            break
        end
    end
    if not alt then
        alt = vim.api.nvim_create_buf(true, false)
    end

    -- Подменяем current → alt во всех окнах, где он показан.
    -- После этого ни одно окно не «зависит» от current, и его удаление
    -- никогда не повлечёт `:close` окна.
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == current then
            vim.api.nvim_win_set_buf(win, alt)
        end
    end

    local cmd = force and "bdelete! " or "confirm bdelete "
    local ok, err = pcall(vim.cmd, cmd .. current)
    if not ok then
        vim.notify(tostring(err), vim.log.levels.WARN)
    end
end

map("n", "<C-q>",      function() close_buffer(false) end, { desc = "Close current file (smart)" })
map("n", "<leader>bd", function() close_buffer(false) end, { desc = "Buffer: close current (smart)" })
map("n", "<leader>bD", function() close_buffer(true)  end, { desc = "Buffer: close current (force)" })

-- Better defaults
map("n", "n",     "nzzzv", { desc = "Next search match (centered)" })
map("n", "N",     "Nzzzv", { desc = "Prev search match (centered)" })
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "<Esc>", "<cmd>noh<CR>", { desc = "Clear search highlight" })

-- Window navigation (also re-mapped by nvim-ide focus, but useful elsewhere)
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Window resize
map("n", "<C-Up>",    "<cmd>resize +2<CR>",          { desc = "Resize window up" })
map("n", "<C-Down>",  "<cmd>resize -2<CR>",          { desc = "Resize window down" })
map("n", "<C-Left>",  "<cmd>vertical resize -2<CR>", { desc = "Resize window left" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Resize window right" })

-- Buffers
map("n", "<S-h>",     "<cmd>bprevious<CR>", { desc = "Prev buffer" })
map("n", "<S-l>",     "<cmd>bnext<CR>",     { desc = "Next buffer" })
-- (<leader>bd / <leader>bD навешиваются выше в smart-варианте через close_buffer())

-- Move lines (visual + normal)
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
map("n", "<A-j>", "<cmd>m .+1<CR>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<CR>==", { desc = "Move line up" })

-- Keep cursor centered on join
map("n", "J", "mzJ`z", { desc = "Join lines (keep cursor)" })

-- Paste over selection without yanking the selection
map("v", "p", '"_dP', { desc = "Paste without yanking selection" })

-- Better indent in visual mode
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Diagnostic navigation (LSP overrides may extend this in plugins/lsp.lua)
map("n", "]d", function() vim.diagnostic.jump({ count = 1 })  end, { desc = "Next diagnostic" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Prev diagnostic" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Diagnostic float" })
map("n", "<leader>cD", "<cmd>lua vim.diagnostic.setloclist()<CR>", { desc = "Diagnostics → loclist" })

-- Toggle spell
map("n", "<leader>us", "<cmd>set spell!<CR>", { desc = "Toggle: spell" })
map("n", "<leader>uw", "<cmd>set wrap!<CR>",  { desc = "Toggle: wrap" })

-- Terminal escape
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- =========================================================
-- VS Code-style clipboard (Ctrl+C / Ctrl+V / Ctrl+X / Ctrl+A)
-- =========================================================
--
-- Принципы:
--   * Vim-native `<C-c>` (interrupt/Esc) и `<C-v>` (visual-block) в
--     normal/insert НЕ трогаем — без них Vim становится неудобным.
--   * `<C-c>` / `<C-x>` навешиваем только в visual mode (там Vim-native
--     `<C-c>` всё равно был лишь "псевдо-Esc").
--   * `<C-v>` навешиваем как paste только в insert/command-line — там
--     Vim-native поведение почти никем не используется (literal char
--     insert через `<C-v><char>` остался доступен через `<C-q>` —
--     Vim сам сохраняет такой fallback).
--   * `<C-a>` (select all) в Vim-native — increment number. Мы перевешиваем
--     его в normal/insert на select-all; для increment остаётся `<C-x>`
--     обратной операцией… но `<C-x>` мы уже занимаем в visual под cut.
--     Increment в normal остаётся доступным через `<C-a>`-же? Нет.
--     Используй `g<C-a>` если будут нужны последовательные increment'ы
--     в visual block. Для редких случаев — `:normal! <C-a>` тоже работает.
--   * `<C-s>` — save (соответствует VS Code Ctrl+S).

-- Copy в системный буфер
map({ "v", "x" }, "<C-c>", '"+y',  { desc = "Copy to system clipboard" })
map({ "v", "x" }, "<C-x>", '"+d',  { desc = "Cut to system clipboard" })

-- Paste из системного буфера
map("i", "<C-v>", "<C-r>+",                 { desc = "Paste from system clipboard" })
map("c", "<C-v>", "<C-r>+",                 { desc = "Paste from system clipboard" })

-- Select all
map("n", "<C-a>", "ggVG",                   { desc = "Select all" })
map("i", "<C-a>", "<Esc>ggVG",              { desc = "Select all" })

-- Save (как Ctrl+S в VS Code) — работает в normal и insert
map("n", "<C-s>", "<cmd>write<CR>",         { desc = "Save buffer" })
map("i", "<C-s>", "<Esc><cmd>write<CR>a",   { desc = "Save buffer" })
