-- forge/panel_guard.lua
--
-- Инвариант: нижняя и боковые панели (edgy edgebar'ы) — СТРОГО для своих
-- tool-окон (neo-tree, dap-ui, terminal, overseer, trouble, quickfix,
-- grug-far, ...). Обычный файл НИКОГДА не должен оказаться в области панели,
-- и редактор должен оставаться единым main-окном (вертикальные сплиты кода
-- допустимы, а «залипший» горизонтальный strip снизу с файлом — нет).
--
-- Как ломается (подтверждено диагностикой :luafile _paneldiag.lua):
--   1. Фокус в нижней панели (DAP terminal/REPL, Overseer, Trouble, qf), ты
--      делаешь gd/gf/<C-]>/:e/клик по пути — Neovim меняет буфер ПРЯМО в этом
--      окне. edgy ловит окна по filetype; как только там оказался файл
--      (ft=go/lua/…), edgy «забывает» окно — оно осиротевает в позиции панели.
--   2. edgy всем своим окнам ставит `winfixwidth`/`winfixheight` (см.
--      plugins/edgy.lua → wo). Это ОКОННЫЕ опции: они переживают смену буфера
--      И сохраняются в сессию (`localoptions` в sessionoptions). В итоге
--      `winfix` «протекает» и на соседние editor-окна, а persistence
--      сохраняет сломанный layout — файл в области панели возвращается на
--      каждый старт.
--
-- Ключ к детекту: НОРМАЛЬНОЕ editor-окно никогда не имеет winfix (этот конфиг
-- его на редактор не ставит — только edgy на свои окна). Значит editor-окно
-- (не edgy, не float, обычный буфер) с winfix = след протёкшей панели.
--
-- Лечение:
--   * relocate — если в panel/осиротевшем окне оказался ИМЕНОВАННЫЙ файл,
--     переносим его в main-редактор и закрываем лишнее окно (на BufWinEnter,
--     для живого gd-из-панели);
--   * sweep — схлопывает winfix-«порченые» editor-окна к одному main и СНИМАЕТ
--     winfix со всех editor-окон, чтобы в сессию больше не попало. Зовётся на
--     restore (PersistenceLoadPost), на старте (VimEnter) и перед сохранением
--     сессии (ide.cleanup_for_session).

local M = {}

-- Tool-filetypes, легитимно живущие в панелях. По-хорошему buftype ~= "" уже
-- отсекает большинство (nofile/terminal/prompt/quickfix/help), но держим явный
-- список как страховку — у части tool-буферов buftype="".
local TOOL_FT = {
    ["neo-tree"] = true, ["aerial"] = true, ["toggleterm"] = true,
    ["dap-repl"] = true, ["dap-terminal"] = true,
    ["dapui_scopes"] = true, ["dapui_watches"] = true,
    ["dapui_stacks"] = true, ["dapui_breakpoints"] = true,
    ["dapui_console"] = true,
    ["neotest-summary"] = true, ["neotest-output-panel"] = true,
    ["OverseerList"] = true, ["overseer"] = true, ["overseer-list"] = true,
    ["grug-far"] = true, ["trouble"] = true, ["qf"] = true,
    ["NeogitStatus"] = true, ["NeogitPopup"] = true,
    ["help"] = true, ["man"] = true, ["alpha"] = true,
    ["lazy"] = true, ["mason"] = true,
}

local function is_floating(win)
    return vim.api.nvim_win_get_config(win).relative ~= ""
end

local function edgy_tracks(win)
    local ok, edgy = pcall(require, "edgy")
    return ok and type(edgy.get_win) == "function" and edgy.get_win(win) ~= nil
end

local function win_has_winfix(win)
    return vim.wo[win].winfixwidth == true or vim.wo[win].winfixheight == true
end

local function win_area(win)
    if not vim.api.nvim_win_is_valid(win) then return 0 end
    return vim.api.nvim_win_get_width(win) * vim.api.nvim_win_get_height(win)
end

-- editor-окно: кандидат в main. Не float, не edgy-панель, НЕ помеченное
-- ide-маркером panel, обычный буфер (не tool-ft, buftype="").
local function is_editor_window(win)
    if not vim.api.nvim_win_is_valid(win) then return false end
    if is_floating(win) then return false end
    if edgy_tracks(win) then return false end
    if vim.w[win].forge_panel then return false end -- (бывшая) панель, не main
    local buf = vim.api.nvim_win_get_buf(win)
    return vim.bo[buf].buftype == "" and not TOOL_FT[vim.bo[buf].filetype]
end

-- «Чистое» main-окно — editor-окно БЕЗ winfix (нормальное состояние редактора).
local function is_clean_main(win)
    return is_editor_window(win) and not win_has_winfix(win)
end

-- Окно, где файлу не место: помечено ide-маркером panel, либо edgy-панель,
-- либо осиротевшее окно панели (winfix на editor-окне = протёкшая панель).
-- Приоритет — явный маркер w:forge_panel (ide/marks.lua); winfix остаётся
-- fallback'ом для restored-сессий, где window-local метки потеряны.
local function is_panel_or_orphan(win)
    if not vim.api.nvim_win_is_valid(win) then return false end
    if is_floating(win) then return false end
    if vim.w[win].forge_panel then return true end       -- явный маркер
    if edgy_tracks(win) then return true end
    return is_editor_window(win) and win_has_winfix(win)  -- fallback (restore)
end

-- Обычный ИМЕНОВАННЫЙ файл (а не tool-буфер и не безымянный scratch).
local function is_named_file_buffer(buf)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then return false end
    if vim.bo[buf].buftype ~= "" then return false end
    if TOOL_FT[vim.bo[buf].filetype] then return false end
    return vim.api.nvim_buf_get_name(buf) ~= ""
end

-- Куда переносить файл из панели. Приоритет: чистое main → любое editor-окно
-- (даже с winfix — крупнейшее, winfix снимем в relocate). exclude — окно, из
-- которого уносим.
local function find_main_target(exclude)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if win ~= exclude and is_clean_main(win) then return win end
    end
    local best
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if win ~= exclude and is_editor_window(win) then
            if not best or win_area(win) > win_area(best) then best = win end
        end
    end
    return best
end

-- Перенести файл из panel/осиротевшего окна в main и закрыть лишнее окно.
-- Возвращает true, если что-то сделали.
local function relocate(panel_win, buf)
    local main = find_main_target(panel_win)
    if not main or main == panel_win then return false end

    pcall(vim.api.nvim_win_set_buf, main, buf)
    -- main теперь нормальный редактор — снимаем возможный протёкший winfix.
    pcall(function() vim.wo[main].winfixwidth = false end)
    pcall(function() vim.wo[main].winfixheight = false end)

    if vim.api.nvim_win_is_valid(panel_win)
        and panel_win ~= main
        and #vim.api.nvim_tabpage_list_wins(0) > 1 then
        pcall(vim.api.nvim_win_close, panel_win, false)
    end

    if vim.api.nvim_win_is_valid(main) then
        pcall(vim.api.nvim_set_current_win, main)
    end
    return true
end

-- Снять winfix со ВСЕХ editor-окон — чтобы порча больше не попала в сессию.
-- edgy-окна не трогаем (им winfix нужен).
local function clear_editor_winfix()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if is_editor_window(win) and win_has_winfix(win) then
            pcall(function() vim.wo[win].winfixwidth = false end)
            pcall(function() vim.wo[win].winfixheight = false end)
        end
    end
end

-- Реентрантность: relocate триггерит BufWinEnter (для main) — не даём guard'у
-- зайти повторно посреди переноса.
local _busy = false

-- Один файл-в-панели → перенести. Используется живым BufWinEnter-стражем.
local function process_one(win)
    if not (win and vim.api.nvim_win_is_valid(win)) then return false end
    if is_floating(win) then return false end
    local buf = vim.api.nvim_win_get_buf(win)
    if not is_named_file_buffer(buf) then return false end
    if not is_panel_or_orphan(win) then return false end
    return relocate(win, buf)
end

local function guard_window(win)
    if _busy then return end
    _busy = true
    local ok, did = pcall(process_one, win)
    _busy = false
    if ok and did then
        vim.notify(
            "Файл открылся в области панели — перенёс в редактор. Панели только для своих инструментов.",
            vim.log.levels.INFO, { title = "panels" }
        )
    end
end

-- Полное лечение: схлопнуть winfix-порченые editor-окна к одному main и снять
-- winfix со всех editor-окон. Идемпотентно; на здоровом layout — no-op.
function M.sweep()
    if _busy then return end
    _busy = true

    local closed = 0
    -- Несколько проходов: relocate закрывает по окну за раз (список окон
    -- меняется), повторяем пока есть файлы в панелях. Bound — анти-залип.
    for _ = 1, 8 do
        local acted = false
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local buf = vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win)
            if buf and is_named_file_buffer(buf) and is_panel_or_orphan(win) then
                if relocate(win, buf) then
                    acted = true
                    closed = closed + 1
                    break
                end
            end
        end
        if not acted then break end
    end

    -- Финальный проход: гарантируем, что ни одно editor-окно не уносит winfix
    -- в сессию.
    clear_editor_winfix()

    _busy = false

    if closed > 0 then
        vim.notify(
            ("Прибрал область панели: убрал %d залипшее окно с файлом, редактор сведён к main.")
                :format(closed),
            vim.log.levels.INFO, { title = "panels" }
        )
    end
end

function M.setup()
    if M._setup then return end
    M._setup = true

    local group = vim.api.nvim_create_augroup("ForgePanelGuard", { clear = true })

    -- Живой перехват: именованный файл попал в panel/осиротевшее окно —
    -- переносим в main. Через schedule, чтобы не оперировать окнами посреди
    -- чужого события (в т.ч. :source при restore) и дать edgy/neo-tree
    -- доиграть layout.
    vim.api.nvim_create_autocmd("BufWinEnter", {
        group = group,
        callback = function(args)
            local win = vim.api.nvim_get_current_win()
            local buf = args.buf
            vim.schedule(function()
                if vim.api.nvim_win_is_valid(win)
                    and vim.api.nvim_win_get_buf(win) == buf then
                    guard_window(win)
                end
            end)
        end,
    })

    -- Вылечить уже сохранённый сломанный layout сразу после restore.
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "PersistenceLoadPost",
        callback = function() vim.schedule(M.sweep) end,
    })

    -- На старте (после lazy + возможного autoload сессии) тоже проходим.
    vim.api.nvim_create_autocmd("VimEnter", {
        group = group,
        once = true,
        callback = function() vim.defer_fn(M.sweep, 150) end,
    })

    -- Ручной хук для отладки/моментального лечения текущей сессии.
    vim.api.nvim_create_user_command("ForgePanelHeal", function()
        M.sweep()
    end, { desc = "Forge: вытащить файлы из панелей и свести редактор к main" })
end

return M
