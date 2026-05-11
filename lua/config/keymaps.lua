-- Keymaps. Some bindings were ported from an earlier VS Code/Helix setup:
-- Ctrl keys, Alt navigation, smart selection, and Space-leader groups.
--
-- LSP-маппинги (gd/gr/F2/code action и т.п.) живут в plugins\lsp.lua
-- внутри LspAttach autocmd — там, где они привязаны к буферу с LSP.
-- DAP-маппинги — в plugins\dap.lua. Telescope/neo-tree/trouble — в их
-- собственных файлах. Здесь — только редакторская «база».

local map = vim.keymap.set
local function nm(lhs, rhs, desc) map({ "n" }, lhs, rhs, { desc = desc, silent = true }) end
local function im(lhs, rhs, desc) map({ "i" }, lhs, rhs, { desc = desc, silent = true }) end
local function vm(lhs, rhs, desc) map({ "v" }, lhs, rhs, { desc = desc, silent = true }) end
local function xm(lhs, rhs, desc) map({ "x" }, lhs, rhs, { desc = desc, silent = true }) end
local function nv(lhs, rhs, desc) map({ "n", "v" }, lhs, rhs, { desc = desc, silent = true }) end
local function niv(lhs, rhs, desc) map({ "n", "i", "v" }, lhs, rhs, { desc = desc, silent = true }) end
local function tc(keys) return vim.api.nvim_replace_termcodes(keys, true, false, true) end

local function comment_api()
    local ok, api = pcall(require, "Comment.api")
    if not ok then
        vim.notify("Comment.nvim API is not available", vim.log.levels.ERROR, { title = "Keymap" })
        return nil
    end
    return api
end

local function toggle_comment_line()
    local api = comment_api()
    if not api then return end
    api.toggle.linewise.current()
end

local function toggle_comment_selection()
    local api = comment_api()
    if not api then return end

    local mode = vim.fn.visualmode()
    local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
    vim.api.nvim_feedkeys(esc, "nx", false)
    api.toggle.linewise(mode)
end

local function close_current_buffer()
    local current = vim.api.nvim_get_current_buf()
    local listed = vim.tbl_filter(function(buf)
        return vim.bo[buf].buflisted
    end, vim.api.nvim_list_bufs())

    if #listed <= 1 then
        vim.cmd("enew")
    else
        vim.cmd("bprevious")
    end

    if vim.api.nvim_buf_is_valid(current) then
        vim.cmd("bdelete " .. current)
    end
end

-- ===========================================================================
-- VS Code-style Ctrl-биндинги (vim.handleKeys: <C-*> = false из settings.json)
-- ===========================================================================

-- Ctrl+S — save во всех режимах
niv("<C-s>", "<Esc><cmd>silent! write<CR>", "Save")

-- Ctrl+A — select all
nm("<C-a>", "ggVG", "Select all")
im("<C-a>", "<Esc>ggVG", "Select all")

-- Ctrl+C / Ctrl+X / Ctrl+V — clipboard как в IDE
-- В normal/visual мы уже clipboard=unnamedplus, поэтому y/d/p == системный.
-- Но Ctrl+C должен копировать выделение _и оставаться в normal_, как в VS Code.
vm("<C-c>", '"+y', "Copy")
vm("<C-x>", '"+d', "Cut")
-- Ctrl+V в normal/visual — paste из системного. В insert — тоже paste.
nm("<C-v>", '"+p', "Paste")
vm("<C-v>", '"+P', "Paste over selection")
im("<C-v>", "<C-r>+", "Paste")
-- Командной строки тоже касается (искать/менять с системного буфера)
map("c", "<C-v>", "<C-r>+", { desc = "Paste" })
map("c", "<Tab>", function()
    local ok_cmp, cmp = pcall(require, "cmp")
    if ok_cmp and cmp.visible() then
        cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true })
        return ""
    end

    if vim.fn.pumvisible() == 1 or vim.fn.wildmenumode() == 1 then
        return tc("<C-y>")
    end

    return tc("<C-z>")
end, { expr = true, desc = "Cmdline: accept or trigger completion" })
map("c", "<CR>", function()
    if vim.fn.wildmenumode() == 1 then
        return vim.api.nvim_replace_termcodes("<C-y>", true, false, true)
    end
    return vim.api.nvim_replace_termcodes("<CR>", true, false, true)
end, { expr = true, desc = "Cmdline: accept completion or submit" })

-- Neovim's built-in command is :checkhealth, but :healthcheck is a common
-- muscle-memory typo. Keep the native command and add forgiving aliases.
local function run_checkhealth(args)
    vim.cmd("checkhealth " .. (args.args or ""))
end
vim.api.nvim_create_user_command("Healthcheck", run_checkhealth, {
    nargs = "*",
    desc = "Alias for :checkhealth",
})
vim.api.nvim_create_user_command("HealthCheck", run_checkhealth, {
    nargs = "*",
    desc = "Alias for :checkhealth",
})
vim.cmd([[
cnoreabbrev <expr> healthcheck
      \ getcmdtype() ==# ':' && getcmdline() ==# 'healthcheck' ? 'checkhealth' : 'healthcheck'
]])

-- Ctrl+Z / Ctrl+Y — undo/redo
nm("<C-z>", "u", "Undo")
im("<C-z>", "<C-o>u", "Undo")
nm("<C-y>", "<C-r>", "Redo")
im("<C-y>", "<C-o><C-r>", "Redo")

-- Ctrl+W — закрыть текущий буфер как вкладку в IDE.
-- Стандартные Vim window-команды остаются на <leader>w...
nm("<C-w>", close_current_buffer, "Buffer: close")
im("<C-w>", function()
    vim.cmd("stopinsert")
    close_current_buffer()
end, "Buffer: close")
vm("<C-w>", function()
    vim.cmd("normal! \27")
    close_current_buffer()
end, "Buffer: close")

-- Ctrl+F — поиск (как `/`)
nm("<C-f>", "/", "Find in buffer")
im("<C-f>", "<Esc>/", "Find in buffer")

-- Ctrl+H — заменить (как `:%s//`)
nm("<C-h>", ":%s/", "Replace in buffer")

-- Ctrl+/ — toggle comment. VS Code держит это как дефолтный
-- editor.action.commentLine, поэтому в keybindings.json отдельной записи нет.
-- Терминалы обычно присылают Ctrl+/ как Ctrl+_ (ASCII 31), новые TUI могут
-- прислать буквальный <C-/>. Держим оба варианта и вызываем Comment.nvim API,
-- а не строку `gc`, чтобы не зависеть от remap-поведения.
nm("<C-_>", toggle_comment_line, "Toggle comment line")
nm("<C-/>", toggle_comment_line, "Toggle comment line")
xm("<C-_>", toggle_comment_selection, "Toggle comment selection")
xm("<C-/>", toggle_comment_selection, "Toggle comment selection")
im("<C-_>", function()
    vim.cmd("stopinsert")
    vim.schedule(function()
        toggle_comment_line()
        vim.cmd("startinsert")
    end)
end, "Toggle comment line")
im("<C-/>", function()
    vim.cmd("stopinsert")
    vim.schedule(function()
        toggle_comment_line()
        vim.cmd("startinsert")
    end)
end, "Toggle comment line")

-- Ctrl+L — выделить строку без \n (helix: extend_to_line_bounds + trim).
-- В Neovim `V` берёт строку с переводом, `0vg_` — без него.
nm("<C-l>", "0vg_", "Select line without newline")

-- ===========================================================================
-- Из keybindings.json: Alt-навигация и smart-select
-- ===========================================================================

-- Alt+[ / Alt+] — jumplist back/forward (VS Code navigateBack/Forward)
nm("<A-[>", "<C-o>", "Jumplist back")
nm("<A-]>", "<C-i>", "Jumplist forward")

-- Ctrl+] — indent как в IDE.
-- Ctrl+[ НЕ маппим: в терминалах это часто тот же код, что Esc, и такой
-- mapping ломает выход из insert/visual mode.
nm("<C-]>", ">>", "Indent line")
-- Raw Ctrl+] fallback: если терминал присылает ASCII 29, перебиваем
-- дефолтный Vim tag-jump, который иначе даёт E439 "Not identifier under cursor".
map("n", "\29", ">>", { desc = "Indent line", silent = true })
im("<C-]>", "<Esc>>>gi", "Indent line")
map("i", "\29", "<Esc>>>gi", { desc = "Indent line", silent = true })
vm("<C-]>", ">gv", "Indent selection")
map("v", "\29", ">gv", { desc = "Indent selection", silent = true })

-- Alt+J — go-to definition (VS Code revealDefinition).
-- Здесь для случая, когда LSP ещё не подцепился; LspAttach перевесит на
-- LSP-вариант с nicer fallback.
nm("<A-j>", function() vim.lsp.buf.definition() end, "Go to definition")

-- Shift+Alt+K / Shift+Alt+J — smartSelect.expand / shrink.
-- Реализуется через nvim-treesitter incremental_selection, который
-- настраивается в plugins\treesitter.lua. Маппим тут только глобальные
-- алиасы для visual-mode вызова, чтобы привычка работала вне TS-инициации.
-- (Сама привязка `init_selection` идёт через TS-config.)

-- Shift+Alt+F — format document (VS Code Alt+Win+L → перевешено: Win-key
-- в TUI ловится плохо, поэтому Shift+Alt+F как было раньше в VS Code).
nm("<S-A-f>", function()
    -- conform.nvim grabs this; до его загрузки fallback на LSP.
    local ok, conform = pcall(require, "conform")
    if ok then conform.format({ async = true, lsp_format = "fallback" })
    else vim.lsp.buf.format({ async = true }) end
end, "Format document")

-- Ctrl+Enter — выполнить выделение (helix: pipe-to bash, VS Code: terminal.runSelectedText).
-- Под Windows прогоняем через pwsh, чтобы вёл себя как в helix `:sh`.
vm("<C-CR>", function()
    vim.cmd("'<,'>w !pwsh -NoLogo -NoProfile -Command -")
end, "Run selection in pwsh")

-- ===========================================================================
-- Перенос фикса из vim.visualModeKeyBindings: $ ⇒ g_ (без \n на конце)
-- ===========================================================================
xm("$", "g_", "End of line (without newline)")
xm("<End>", "g_", "End of line (without newline)")

-- Дублируем в normal-mode (vim.normalModeKeyBindingsNonRecursive)
nm("$", "g_", "End of line (without newline)")
nm("<End>", "g_", "End of line (without newline)")

-- ===========================================================================
-- Quality of life: окна, буферы, перемещение строк
-- ===========================================================================

-- Перемещение строк (helix: move_line_up/down есть из коробки в Vim, но
-- в VS Code это Alt+Up/Down — добавляем).
nm("<A-Up>",   ":m .-2<CR>==",       "Move line up")
nm("<A-Down>", ":m .+1<CR>==",       "Move line down")
im("<A-Up>",   "<Esc>:m .-2<CR>==gi", "Move line up")
im("<A-Down>", "<Esc>:m .+1<CR>==gi", "Move line down")
vm("<A-Up>",   ":m '<-2<CR>gv=gv",   "Move selection up")
vm("<A-Down>", ":m '>+1<CR>gv=gv",   "Move selection down")

-- Дублирование строки (VS Code Shift+Alt+Down/Up).
nm("<S-A-Down>", "yyp",       "Duplicate line down")
nm("<S-A-Up>",   "yyP",       "Duplicate line up")
vm("<S-A-Down>", "y'>p",      "Duplicate selection down")
vm("<S-A-Up>",   "y'<P",      "Duplicate selection up")

-- Эскейп выделения подсветки и поискового highlight'а.
nm("<Esc>", function()
    vim.cmd("nohlsearch")
end, "Clear search highlight")

-- Better up/down при wrap
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- В visual mode сохранять выделение после indent
xm("<", "<gv", "Indent left")
xm(">", ">gv", "Indent right")

-- ===========================================================================
-- Leader-маппинги верхнего уровня (которые не относятся к плагинам).
-- Группы (f/l/d/g/w/s/b/x) регистрируются в which-key из plugins\ui.lua
-- и доопределяются плагинами (telescope, lsp, dap, gitsigns, trouble).
-- ===========================================================================

-- IDE modes/layouts: each command switches the whole tool-window layout.
local panels = require("config.panels")
nm("<leader>mm", panels.select_mode,  "Mode: select")
nm("<leader>mf", panels.mode_files,   "Mode: files")
nm("<leader>mb", panels.mode_buffers, "Mode: buffers")
nm("<leader>mg", panels.mode_git,     "Mode: git")
nm("<leader>md", panels.mode_debug,   "Mode: debug")
nm("<leader>mt", panels.mode_tests,   "Mode: tests")
nm("<leader>mj", panels.mode_jobs,    "Mode: jobs")
nm("<leader>ms", panels.mode_search,  "Mode: search")
nm("<leader>mo", panels.mode_output,  "Mode: output")
nm("<leader>mc", panels.mode_code,    "Mode: code only")
nm("<leader>mq", panels.close_ide,    "Mode: close IDE")
nm("<leader>mQ", panels.close_ide,    "Mode: close IDE")
nm("<leader>m0", panels.focus_code,   "Mode: focus code")
nm("<leader>m]", panels.next_mode_window, "Mode: next window")
nm("<leader>m[", panels.prev_mode_window, "Mode: previous window")
for i = 1, 6 do
    local slot = i
    nm("<leader>m" .. slot, function()
        panels.focus_mode_slot(slot)
    end, "Mode: focus slot " .. slot)
end

-- Toggles (helix space.T)
nm("<leader>tw", "<cmd>set wrap!<CR>",         "Toggle: wrap")
nm("<leader>tn", "<cmd>set relativenumber!<CR>", "Toggle: relativenumber")
-- Toggle inlay hints в ТЕКУЩЕМ буфере. Per-buffer (а не global) —
-- чтобы включить hint'ы во внешнем файле (std::fs::File и т.п.) можно
-- было точечно, не затрагивая свои буферы. По умолчанию во внешних
-- файлах hint'ы выключены ради скорости (см. lsp.lua: in_project).
nm("<leader>th", function()
    local buf = vim.api.nvim_get_current_buf()
    local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
    vim.lsp.inlay_hint.enable(not enabled, { bufnr = buf })
    vim.notify("Inlay hints: " .. (not enabled and "ON" or "OFF") .. " (buffer)",
        vim.log.levels.INFO)
end, "Toggle: inlay hints (buffer)")
nm("<leader>ts", "<cmd>set spell!<CR>",        "Toggle: spell")

-- Окна (helix space.w)
nm("<leader>wv", "<C-w>v", "Window: vsplit")
nm("<leader>ws", "<C-w>s", "Window: hsplit")
nm("<leader>wh", "<C-w>h", "Window: left")
nm("<leader>wj", "<C-w>j", "Window: down")
nm("<leader>wk", "<C-w>k", "Window: up")
nm("<leader>wl", "<C-w>l", "Window: right")
nm("<leader>wq", "<C-w>q", "Window: close")
nm("<leader>wo", "<C-w>o", "Window: only")

-- Буферы (helix space.B)
nm("<leader>bd", close_current_buffer,     "Buffer: close")
nm("<leader>bn", "<cmd>bnext<CR>",         "Buffer: next")
nm("<leader>bp", "<cmd>bprevious<CR>",     "Buffer: prev")
nm("<S-h>",      "<cmd>bprevious<CR>",     "Buffer: prev")
nm("<S-l>",      "<cmd>bnext<CR>",         "Buffer: next")
nm("<Tab>",      "<cmd>bnext<CR>",         "Buffer: next")
nm("<S-Tab>",    "<cmd>bprevious<CR>",     "Buffer: prev")
nm("]b",         "<cmd>bnext<CR>",         "Buffer: next")
nm("[b",         "<cmd>bprevious<CR>",     "Buffer: prev")
nm("<C-PageDown>", "<cmd>bnext<CR>",       "Buffer: next")
nm("<C-PageUp>",   "<cmd>bprevious<CR>",   "Buffer: prev")

-- Quit / save
nm("<leader>qq", "<cmd>qa<CR>",   "Quit all")
nm("<leader>qw", "<cmd>wqa<CR>",  "Save & quit all")

-- Открыть конфиг быстро (одиночный маппинг, не группа)
nm("<leader>oC", function()
    vim.cmd("edit " .. vim.fn.stdpath("config") .. "/init.lua")
end, "Open config")

-- Toggle terminal (split снизу). Нормальный TUI — в плагин toggleterm
-- не лезем, обходимся встроенным :terminal, чтобы не плодить плагины.
nm("<leader>tt", function()
    vim.cmd("botright split | resize 15 | terminal pwsh")
    vim.cmd("startinsert")
end, "Toggle terminal (pwsh)")
-- Esc в терминале — выход в normal
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Terminal: normal mode" })
