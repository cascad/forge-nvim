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
local function anym(lhs, rhs, desc) map({ "n", "i", "v", "x", "t" }, lhs, rhs, { desc = desc, silent = true }) end
local function tc(keys) return vim.api.nvim_replace_termcodes(keys, true, false, true) end
local ru_keys = require("config.ru_keys")

local function delmap(modes, lhs)
    local aliases = { lhs }
    local ru_lhs = ru_keys.translate_lhs(lhs)
    if ru_lhs and ru_lhs ~= lhs then
        aliases[#aliases + 1] = ru_lhs
    end

    for _, mode in ipairs(modes) do
        for _, key in ipairs(aliases) do
            pcall(vim.keymap.del, mode, key)
        end
    end
end

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

-- Закрытие текущего буфера. Делегируется ide.empty.close_buffer_safe,
-- который умеет показывать alpha welcome screen, если это был
-- последний открытый файл (вместо пустого "Noname"). См. ide/empty.lua.
local function close_current_buffer()
    local ok, empty = pcall(require, "ide.empty")
    if ok and empty and empty.close_buffer_safe then
        empty.close_buffer_safe()
        return
    end

    -- Fallback на старое поведение (если ide не загрузился).
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

local function after_normal_mode(fn)
    local mode = vim.api.nvim_get_mode().mode

    if mode:sub(1, 1) == "t" then
        vim.api.nvim_feedkeys(tc("<C-\\><C-n>"), "n", false)
    elseif mode:sub(1, 1) == "i" or mode:sub(1, 1) == "R" then
        vim.cmd("stopinsert")
    elseif mode ~= "n" then
        vim.api.nvim_feedkeys(tc("<Esc>"), "n", false)
    end

    vim.schedule(fn)
end

local function focus_window(command)
    after_normal_mode(function()
        pcall(vim.cmd, "wincmd " .. command)
    end)
end

local in_diffview_tab

local function is_editable_file_window(win)
    if not vim.api.nvim_win_is_valid(win) then return false end

    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype ~= "" then return false end
    if vim.bo[buf].readonly or not vim.bo[buf].modifiable then return false end
    if vim.api.nvim_buf_get_name(buf) == "" then return false end

    local ft = vim.bo[buf].filetype
    return ft ~= "DiffviewFiles" and ft ~= "DiffviewFileHistory" and ft ~= "neo-tree"
end

-- Является ли buf "tab"-буфером — тем, который должен попадать в цикл
-- <Tab>/<S-Tab> и в `<leader>bb` / bufferline. Критерий ОДИН: buflisted.
--
-- Раньше мы дополнительно требовали nvim_buf_is_loaded(buf), но это было
-- неверно: после восстановления сессии (persistence.nvim) фоновые буферы
-- остаются listed, но не loaded до первого BufEnter. В результате они
-- видны в bufferline и в picker'е, но <Tab> их пропускал. Lazy-load
-- произойдёт автоматически при nvim_set_current_buf — это штатное
-- поведение vim.
local function is_tab_buffer(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return false end
    return vim.bo[buf].buflisted
end

local file_buffer_history = {}

local function touch_file_buffer(buf)
    if not is_tab_buffer(buf) then return end

    for i = #file_buffer_history, 1, -1 do
        if file_buffer_history[i] == buf then
            table.remove(file_buffer_history, i)
        end
    end
    table.insert(file_buffer_history, 1, buf)
end

vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("ForgeFileBufferHistory", { clear = true }),
    callback = function(args)
        touch_file_buffer(args.buf)
    end,
})

local function ordered_file_buffers()
    local seen = {}
    local buffers = {}

    local ok_bufferline, bufferline = pcall(require, "bufferline")
    if ok_bufferline and type(bufferline.get_elements) == "function" then
        local ok_elements, result = pcall(bufferline.get_elements)
        local elements = ok_elements and result and result.elements or {}
        for _, element in ipairs(elements) do
            local buf = tonumber(element.id)
            if buf and is_tab_buffer(buf) and not seen[buf] then
                buffers[#buffers + 1] = buf
                seen[buf] = true
            end
        end
    end

    if #buffers > 0 then return buffers end

    for _, buf in ipairs(file_buffer_history) do
        if is_tab_buffer(buf) and not seen[buf] then
            buffers[#buffers + 1] = buf
            seen[buf] = true
        end
    end

    for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
        local buf = info.bufnr
        if is_tab_buffer(buf) and not seen[buf] then
            buffers[#buffers + 1] = buf
            seen[buf] = true
        end
    end

    return buffers
end

-- Notify-throttle per buffer: один alert за переключение, не спамим.
local _missing_file_notified = {}

local function notify_if_file_missing(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" then return end
    -- Только для обычных file-buffers; временные (term://, etc.) пропускаем.
    if vim.bo[buf].buftype ~= "" then return end

    if vim.fn.filereadable(name) == 1 then
        _missing_file_notified[buf] = nil
        return
    end
    -- Не нотифицируем по 100 раз подряд за одну "пропажу".
    if _missing_file_notified[buf] then return end
    _missing_file_notified[buf] = true
    vim.schedule(function()
        vim.notify("File no longer available on disk: " .. vim.fn.fnamemodify(name, ":t")
            .. "\n(use <leader>bd to drop this buffer)",
            vim.log.levels.WARN, { title = "buffer" })
    end)
end

local function show_file_buffer(buf)
    if not is_tab_buffer(buf) then return end

    local target_win
    local current_win = vim.api.nvim_get_current_win()
    if is_editable_file_window(current_win) then
        target_win = current_win
    else
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if is_editable_file_window(win) then
                target_win = win
                break
            end
        end
    end

    if target_win and vim.api.nvim_win_is_valid(target_win) then
        vim.api.nvim_set_current_win(target_win)
    end

    -- nvim_set_current_buf лениво подгрузит unloaded buffer (BufRead).
    -- Если файл на диске уже не существует — vim покажет пустой буфер с
    -- тем же именем и пометит его как новый; мы дополнительно нотифицируем.
    vim.api.nvim_set_current_buf(buf)
    notify_if_file_missing(buf)
end

local function active_tab_buffer()
    local current = vim.api.nvim_get_current_buf()
    if is_tab_buffer(current) then return current end

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if is_editable_file_window(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if is_tab_buffer(buf) then return buf end
        end
    end
end

local function switch_file_buffer(direction)
    after_normal_mode(function()
        local buffers = ordered_file_buffers()
        if #buffers == 0 then return end

        local current = active_tab_buffer()
        local index
        for i, buf in ipairs(buffers) do
            if buf == current then
                index = i
                break
            end
        end

        local target
        if index then
            local next_index = ((index - 1 + direction) % #buffers) + 1
            target = buffers[next_index]
        else
            target = buffers[1]
        end

        if target and vim.api.nvim_buf_is_valid(target) then
            show_file_buffer(target)
        end
    end)
end

local function focus_editor_window()
    after_normal_mode(function()
        local current = vim.api.nvim_get_current_win()
        local diffview_active = in_diffview_tab()
        if not diffview_active and is_editable_file_window(current) then return end

        local fallback
        local rightmost_diff
        local rightmost_col = -1
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if is_editable_file_window(win) then
                fallback = fallback or win
                if vim.wo[win].diff then
                    local pos = vim.api.nvim_win_get_position(win)
                    local col = pos[2] or 0
                    if col > rightmost_col then
                        rightmost_col = col
                        rightmost_diff = win
                    end
                end
            end
        end

        local target = rightmost_diff or fallback
        if target then
            vim.api.nvim_set_current_win(target)
        end
    end)
end

local function next_buffer()
    switch_file_buffer(1)
end

local function previous_buffer()
    switch_file_buffer(-1)
end

in_diffview_tab = function()
    local ok, lib = pcall(require, "diffview.lib")
    return ok and type(lib.get_current_view) == "function" and lib.get_current_view() ~= nil
end

local closable_tool_filetypes = {
    ["neo-tree"] = true,
    ["DiffviewFiles"] = true,
    ["DiffviewFileHistory"] = true,
    ["dap-repl"] = true,
    ["dap-view"] = true,
    ["dap-view-term"] = true,
    ["dap-view-help"] = true,
    ["neotest-summary"] = true,
    ["neotest-output-panel"] = true,
    ["OverseerList"] = true,
    ["overseer"] = true,
    ["overseer-list"] = true,
    ["grug-far"] = true,
    ["qf"] = true,
    ["help"] = true,
}

local function smart_close_current_context()
    after_normal_mode(function()
        -- Любое ПЛАВАЮЩЕЕ окно (ConformInfo, LspInfo, hover, signature help,
        -- notify-история и т.п.) — просто закрываем окно. Floats не влияют на
        -- layout панелей, так что это всегда безопасно.
        local cur = vim.api.nvim_get_current_win()
        if vim.api.nvim_win_get_config(cur).relative ~= "" then
            pcall(vim.api.nvim_win_close, cur, true)
            return
        end

        if in_diffview_tab() then
            pcall(vim.cmd, "DiffviewClose")
            return
        end

        local buf = vim.api.nvim_get_current_buf()
        local ft = vim.bo[buf].filetype
        local bt = vim.bo[buf].buftype

        if ft == "neo-tree" then
            pcall(vim.cmd, "Neotree close")
            return
        end

        if closable_tool_filetypes[ft] or bt ~= "" then
            if #vim.api.nvim_tabpage_list_wins(0) > 1 then
                pcall(vim.api.nvim_win_close, vim.api.nvim_get_current_win(), true)
            else
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
            return
        end

        close_current_buffer()
    end)
end

for _, command in ipairs({
    "ForgeFocusNext",
    "ForgeFocusPrev",
    "ForgeFocusEditor",
    "ForgeCloseContext",
    "ForgeBufferNext",
    "ForgeBufferPrev",
}) do
    pcall(vim.api.nvim_del_user_command, command)
end

vim.api.nvim_create_user_command("ForgeFocusNext", function()
    focus_window("w")
end, { desc = "Focus next window/panel" })

vim.api.nvim_create_user_command("ForgeFocusPrev", function()
    focus_window("W")
end, { desc = "Focus previous window/panel" })

vim.api.nvim_create_user_command("ForgeFocusEditor", function()
    focus_editor_window()
end, { desc = "Focus editable editor window" })

vim.api.nvim_create_user_command("ForgeCloseContext", smart_close_current_context, {
    desc = "Close current context: Diffview, tool window, or file",
})

vim.api.nvim_create_user_command("ForgeBufferNext", next_buffer, { desc = "Next listed file buffer" })
vim.api.nvim_create_user_command("ForgeBufferPrev", previous_buffer, { desc = "Previous listed file buffer" })

-- Единообразный `q` = закрыть окно для транзиентных info/popup-окон. Многие
-- плагины и так мапят `q` (help, ConformInfo, Lazy, Mason, Trouble), но не все
-- (checkhealth, lspinfo, qf, fugitive-blame и т.п.). Ставим buffer-local `q`,
-- чтобы такие окна ВСЕГДА закрывались по `q` — и закрывали именно ОКНО, не
-- трогая твои файловые буферы и layout панелей.
--
-- НЕ трогаем edgy-панели (neo-tree/dap*/grug-far/overseer/neotest) — у них свои
-- toggle'ы (<leader>e, <C-j>, <leader>P*), и `q` там может значить другое.
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("ForgeQuitInfoWindows", { clear = true }),
    pattern = {
        "help", "man", "qf", "checkhealth", "lspinfo", "conform-info",
        "null-ls-info", "notify", "noice", "startuptime", "query",
        "fugitive", "fugitiveblame", "git", "gitsigns-blame", "tsplayground",
    },
    callback = function(ev)
        vim.keymap.set("n", "q", "<cmd>close<CR>", {
            buffer = ev.buf, nowait = true, silent = true,
            desc = "Close info window",
        })
    end,
})

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

-- Keep native Vim <C-w> window commands intact:
--   <C-w>h/j/k/l - move between windows
--   <C-w>q       - close window
--   <C-w>o       - keep only current window
-- Closing an editor tab/buffer lives on <leader>bd and the global F4 helper.
delmap({ "n", "i", "v", "x" }, "<C-w>")

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
local function format_document()
    -- conform.nvim grabs this; до его загрузки fallback на LSP.
    local ok, conform = pcall(require, "conform")
    if ok then conform.format({ async = true, lsp_format = "fallback" })
    else vim.lsp.buf.format({ async = true }) end
end
nm("<S-A-f>", format_document, "Format document")
vm("<S-A-f>", format_document, "Format selection")

-- Cmd+Alt+L (как Reformat Code в IntelliJ/GoLand). На Windows/в TUI клавиша
-- Cmd (<D-...>) не приходит — работает только в Neovide и на macOS-GUI.
-- На обычном терминале используй <S-A-f> или <leader>lf. Дублируем, чтобы
-- mac-мускульная память срабатывала там, где Cmd доступен.
nm("<D-A-l>", format_document, "Format document (Cmd+Alt+L)")
im("<D-A-l>", function() vim.cmd("stopinsert"); format_document() end, "Format document")
vm("<D-A-l>", format_document, "Format selection")

-- =========================================================================
-- Code action / Quick Fix (VS Code Ctrl+. / IntelliJ Alt+Enter).
-- Через них принимаются предложения LSP/линтеров: gopls "Fill struct"
-- (заполнить структуру дефолтами по всем полям), clippy "could lift into
-- loop condition", "organize imports", "add missing import" (с ВЫБОРОМ
-- пакета при коллизии) и т.п. Глобальные (не buffer-local LspAttach),
-- чтобы работали даже до attach; без LSP — просто no-op.
-- =========================================================================
local function lsp_code_action()
    vim.lsp.buf.code_action()
end
nm("<C-.>", lsp_code_action, "LSP: code action / quick fix")
im("<C-.>", function() vim.cmd("stopinsert"); lsp_code_action() end, "LSP: code action")
vm("<C-.>", lsp_code_action, "LSP: code action (range)")
nm("<A-CR>", lsp_code_action, "LSP: code action / quick fix")
im("<A-CR>", function() vim.cmd("stopinsert"); lsp_code_action() end, "LSP: code action")
vm("<A-CR>", lsp_code_action, "LSP: code action (range)")
-- <leader>. — терминал-безопасная "точка"-мнемоника под Ctrl+. из VS Code.
-- Работает в ЛЮБОМ терминале (в отличие от <C-.>, который многие терминалы
-- не передают — шлют голую `.`, а это в normal mode = повтор изменения).
nm("<leader>.", lsp_code_action, "LSP: code action / quick fix")
vm("<leader>.", lsp_code_action, "LSP: code action (range)")

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

-- Global focus/close keys that work from code, tool windows, insert mode and
-- terminal mode. F6 mirrors the common "cycle focus between UI parts" behavior
-- from desktop IDEs and does not steal Vim's native <C-w> prefix.
anym("<F6>", function() focus_window("w") end, "Window: next focus")
anym("<S-F6>", function() focus_window("W") end, "Window: previous focus")
anym("<F7>", focus_editor_window, "Window: focus editor")
anym("<F4>", smart_close_current_context, "Close current context")
anym("<C-F4>", smart_close_current_context, "Close current context")
anym("<C-PageDown>", next_buffer, "Buffer: next")
anym("<C-PageUp>", previous_buffer, "Buffer: previous")
anym("<A-h>", previous_buffer, "Buffer tab: previous")
anym("<A-l>", next_buffer, "Buffer tab: next")
anym("<A-w>", smart_close_current_context, "Close current file")
delmap({ "n", "i", "v", "x", "t" }, "<A-W>")
delmap({ "n", "i", "v", "x", "t" }, "<A-S-w>")
anym("<A-e>", focus_editor_window, "Window: focus editor")
anym("<A-q>", smart_close_current_context, "Close current context")

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
-- Всё ведёт в единый контроллер ide.* (config/panels.lua больше нет).
local ide = require("ide")
nm("<leader>mm", function() ide.layouts.select()      end, "Mode: select")
nm("<leader>mf", function() ide.apply_layout("files")   end, "Mode: files")
nm("<leader>mb", function() ide.apply_layout("buffers") end, "Mode: buffers")
nm("<leader>mg", function() ide.apply_layout("git")     end, "Mode: git")
nm("<leader>md", function() ide.dap.open()              end, "Mode: debug")
nm("<leader>mt", function() ide.apply_layout("tests")   end, "Mode: tests")
nm("<leader>mj", function() ide.apply_layout("jobs")    end, "Mode: jobs")
nm("<leader>ms", function() ide.apply_layout("search")  end, "Mode: search")
nm("<leader>mo", function() ide.dap.show_console()      end, "Mode: output")
nm("<leader>mc", function() ide.apply_layout("code")    end, "Mode: code only")
nm("<leader>mq", function() ide.close_ide()             end, "Mode: close IDE")
nm("<leader>mQ", function() ide.close_ide()             end, "Mode: close IDE")
nm("<leader>m0", function() ide.focus_main()            end, "Mode: focus code")
nm("<leader>m]", function() ide.focus_next_panel(1)     end, "Mode: next panel")
nm("<leader>m[", function() ide.focus_next_panel(-1)    end, "Mode: previous panel")
for i = 1, 6 do
    local slot = i
    nm("<leader>m" .. slot, function()
        ide.focus_panel(slot)
    end, "Mode: focus panel " .. slot)
end

-- ===========================================================================
-- Layouts (единый контроллер ide, edgy под капотом).
-- <leader>m* — «режимы» (apply_layout / dap / focus), см. выше.
-- <leader>p* — именованные пресеты (ide.apply_layout).
-- <leader>P* — ручное управление слотами, cycle и единый toggle панелей.
-- ===========================================================================
nm("<leader>pp", function() ide.layouts.select() end,           "Layout: select")
nm("<leader>pc", function() ide.apply_layout("code")    end,    "Layout: code only")
nm("<leader>pf", function() ide.apply_layout("files")   end,    "Layout: files")
nm("<leader>po", function() ide.apply_layout("outline") end,    "Layout: outline")
nm("<leader>pg", function() ide.apply_layout("git")     end,    "Layout: git")
nm("<leader>pd", function() ide.apply_layout("debug")   end,    "Layout: debug")
nm("<leader>pt", function() ide.apply_layout("tests")   end,    "Layout: tests")
nm("<leader>ps", function() ide.apply_layout("search")  end,    "Layout: search")
nm("<leader>pj", function() ide.apply_layout("jobs")    end,    "Layout: jobs")
nm("<leader>px", function() ide.apply_layout("trouble") end,    "Layout: trouble")
nm("<leader>pT", function() ide.apply_layout("term")    end,    "Layout: terminal")
nm("<leader>pq", function() ide.apply_layout("code")    end,    "Layout: close all")

-- Slot cycle (next/prev в одном слоте по группе компонентов).
-- <leader>P (uppercase), чтобы не конфликтовать с одиночным
-- <leader>e (Neotree toggle), который ждёт timeoutlen для уточнения.
nm("<leader>Pl", function() ide.cycle("left",    1) end, "IDE: next left group")
nm("<leader>Ph", function() ide.cycle("left",   -1) end, "IDE: prev left group")
nm("<leader>Pr", function() ide.cycle("right",   1) end, "IDE: next right group")
nm("<leader>PR", function() ide.cycle("right",  -1) end, "IDE: prev right group")
nm("<leader>Pb", function() ide.cycle("bottom",  1) end, "IDE: next bottom group")
nm("<leader>PB", function() ide.cycle("bottom", -1) end, "IDE: prev bottom group")

-- Slot hide
nm("<leader>PL", function() ide.hide_slot("left")   end, "IDE: hide left slot")
nm("<leader>PK", function() ide.hide_slot("right")  end, "IDE: hide right slot")
nm("<leader>PJ", function() ide.hide_slot("bottom") end, "IDE: hide bottom slot")

-- Slot TOGGLE — открыть/закрыть весь слот одной клавишей. Если слот пуст,
-- открываем последний показанный (или явный fallback). Если открыт —
-- скрываем.
--
-- ВНИМАНИЕ про терминальные коды:
--   В Windows Terminal / cmd / PowerShell ConHost <C-S-b> и <C-S-j>
--   НЕ передаются отдельно — терминал шлёт те же байты что и <C-b>/<C-j>.
--   Поэтому мапим прямо на <C-b>/<C-j> (это override старого
--   telescope <C-b>; buffers picker остаётся на <leader>bb / <leader>fb).
--   На случай если терминал ест <C-j> (бывает в RDP-сессиях и старых
--   терминалах), есть F-key fallback <F8> для bottom.
local function tlmap(modes, lhs, fn, desc)
    vim.keymap.set(modes, lhs,
        function()
            if vim.fn.mode() == "t" then
                pcall(vim.cmd, "stopinsert")
            end
            fn()
        end,
        { silent = true, desc = desc })
end

local function toggle_left()   ide.toggle_slot("left",   "explorer") end
local function toggle_bottom() ide.toggle_slot("bottom", "terminal") end
local function toggle_right()  ide.toggle_slot("right",  "tests")    end

-- Primary VS Code-style bindings (Ctrl+B / Ctrl+J).
-- <C-b>: normal+insert+terminal. В cmp/telescope не пересекается.
-- <C-j>: НЕ insert — там cmp использует его для select_next_item().
tlmap({ "n", "i", "t" }, "<C-b>", toggle_left,
    "IDE: toggle left panel (VS Code Ctrl+B)")
tlmap({ "n", "t" },      "<C-j>", toggle_bottom,
    "IDE: toggle bottom panel (VS Code Ctrl+J)")

-- F-key fallback на случай, если терминал ест <C-j> (RDP / старые
-- терминалы / WSL2 в некоторых конфигах).
tlmap({ "n", "i", "t" }, "<F8>",  toggle_bottom,
    "IDE: toggle bottom panel")

-- Leader-aliases (надёжно работают в любом терминале).
nm("<leader>Pt", toggle_left,   "IDE: toggle left panel")
nm("<leader>Py", toggle_bottom, "IDE: toggle bottom panel")
nm("<leader>Pu", toggle_right,  "IDE: toggle right panel")

-- Единый toggle ВСЕХ панелей: спрятать весь набор / вернуть последний.
-- Только leader-аккорд: Ctrl+Shift+буква на части терминалов схлопывается в
-- Ctrl+буква и перехватил бы, например, <C-e> (скролл).
nm("<leader>Pp", function() ide.toggle_panels() end, "IDE: toggle all panels")

-- Focus
nm("<leader>P0", function() ide.focus_main() end,        "IDE: focus main editor")
nm("<leader>P/", function() ide.focus_slot("left")   end, "IDE: focus left slot")
nm("<leader>P.", function() ide.focus_slot("right")  end, "IDE: focus right slot")
nm("<leader>P,", function() ide.focus_slot("bottom") end, "IDE: focus bottom slot")

-- ===========================================================================
-- Debug focus jumps (<leader>D*) — прыжки между DAP-окнами без слома
-- останова на брейкпоинте.
--
-- Любая навигация фокусом (nvim_set_current_win, <C-w>*) — это чисто
-- UI-операция, она НЕ вызывает dap.continue/step/terminate. Так что
-- скакать между секциями во время паузы безопасно: variable inspection
-- через scopes/watches, навигация по стеку через stacks, ввод выражения
-- в REPL — всё без потери paused-состояния.
-- ===========================================================================
local function focus_window_by_ft(filetypes)
    -- filetypes: string | string[].
    local fts = {}
    if type(filetypes) == "string" then
        fts[filetypes] = true
    else
        for _, ft in ipairs(filetypes) do fts[ft] = true end
    end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win)
            and vim.api.nvim_win_get_config(win).relative == "" then
            local buf = vim.api.nvim_win_get_buf(win)
            if fts[vim.bo[buf].filetype] then
                pcall(vim.api.nvim_set_current_win, win)
                return true
            end
        end
    end
    return false
end

local function focus_dap_section(filetypes, fallback_open)
    if focus_window_by_ft(filetypes) then return end
    -- Не открыто — открываем sidebar/bottom и пробуем ещё раз.
    if fallback_open then pcall(fallback_open) end
    vim.schedule(function() focus_window_by_ft(filetypes) end)
end

nm("<leader>Dv", function()
    focus_dap_section("dapui_scopes", function() ide.show("dap.sidebar") end)
end, "Debug: focus Variables (scopes)")

nm("<leader>Dw", function()
    focus_dap_section("dapui_watches", function() ide.show("dap.sidebar") end)
end, "Debug: focus Watch")

nm("<leader>Ds", function()
    focus_dap_section("dapui_stacks", function() ide.show("dap.sidebar") end)
end, "Debug: focus call Stack")

nm("<leader>Db", function()
    focus_dap_section("dapui_breakpoints", function() ide.show("dap.sidebar") end)
end, "Debug: focus Breakpoints")

-- Bottom: REPL / Debug Console / DAP Terminal — что бы там сейчас ни было.
-- focus_slot("bottom") уже умеет находить активное окно слота.
nm("<leader>Dc", function()
    -- Сначала пытаемся прыгнуть в любой known DAP-bottom ft напрямую
    -- (REPL/console/terminal). Если ничего нет — focus_slot подберёт
    -- что есть (мог оказаться terminal / search / overseer).
    if focus_window_by_ft({ "dap-repl", "dapui_console", "dap-terminal" }) then return end
    ide.focus_slot("bottom")
end, "Debug: focus REPL/Console/Terminal (bottom)")

nm("<leader>D0", function() ide.focus_main() end, "Debug: focus main editor (code)")

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
nm("<leader>bn", next_buffer,         "Buffer: next")
nm("<leader>bp", previous_buffer,     "Buffer: prev")
nm("<S-h>",      previous_buffer,     "Buffer: prev")
nm("<S-l>",      next_buffer,         "Buffer: next")
nm("<Tab>",      next_buffer,         "Buffer: next")
nm("<S-Tab>",    previous_buffer,     "Buffer: prev")
nm("]b",         next_buffer,         "Buffer: next")
nm("[b",         previous_buffer,     "Buffer: prev")
nm("<C-PageDown>", next_buffer,       "Buffer: next")
nm("<C-PageUp>",   previous_buffer,   "Buffer: prev")

-- Quit / save
nm("<leader>qq", "<cmd>qa<CR>",   "Quit all")
nm("<leader>qw", "<cmd>wqa<CR>",  "Save & quit all")

-- Открыть конфиг быстро (одиночный маппинг, не группа)
nm("<leader>oC", function()
    vim.cmd("edit " .. vim.fn.stdpath("config") .. "/init.lua")
end, "Open config")

-- Toggle terminal — handled by toggleterm.nvim (plugins/terminal.lua):
--   <leader>tt — horizontal toggle (bottom edgebar via edgy)
--   <leader>tT — float
--   <leader>tV — vertical split
--   <C-\>      — quick toggle (VS Code-style)
-- Esc в терминале — выход в normal
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Terminal: normal mode" })
