-- FSM для panel/sidebar layout'а.
--
-- Слоты: left / right / bottom. В каждом — максимум один visible
-- компонент. Editor group (main) НЕ слот, он живёт отдельно и
-- никогда не закрывается этим модулем.
--
-- Инварианты (см. docs/PANELS_PLAN.md §3.4):
--   1. Editor group существует всегда.
--   2. В слоте ≤ 1 компонент.
--   3. После любого transition: state.slots соответствует реальности.
--   4. apply_layout идемпотентен.
--   5. open_file_from_explorer → editor group.

local registry = require("ide.registry")

local M = {}

---@class ide.SlotState
---@field [string] string|nil  -- "left"|"right"|"bottom" → component id

---@class ide.RuntimeState
---@field slots  ide.SlotState
---@field layout string|nil
---@field layouts table<string, ide.Layout>

---@class ide.Layout
---@field left?    string|nil
---@field right?   string|nil
---@field bottom?  string|nil

local state = {
    slots = { left = nil, right = nil, bottom = nil },
    -- Последний показанный компонент в каждом слоте — нужен для
    -- M.toggle_slot, чтобы "открыть обратно то же, что закрывали".
    last_shown = { left = nil, right = nil, bottom = nil },
    layout = nil,
    layouts = {},  ---@type table<string, ide.Layout>
}

local SLOTS = { "left", "right", "bottom" }

-- =============================================================
-- Helpers
-- =============================================================

local function is_valid_slot(slot)
    return slot == "left" or slot == "right" or slot == "bottom"
end

-- Lazy refresh: подтянуть реальное состояние из registry перед
-- transition. Защищает от рассинхронизации, если кто-то закрыл
-- окно мимо нас (например, <C-w>q или :q на edgy view).
local function refresh_slot(slot)
    local id = state.slots[slot]
    if id then
        local comp = registry.get(id)
        if comp and not comp.is_open() then
            state.slots[slot] = nil
        end
    end
end

local function refresh_all_slots()
    for _, slot in ipairs(SLOTS) do refresh_slot(slot) end
end

-- =============================================================
-- Main window discovery
-- =============================================================

---Является ли это окно "main editor"-окном?
---Правило: обычный буфер (buftype == ""), не помечен edgy-disable,
---не tool-окно по filetype.
---@param win integer
---@return boolean
function M.is_main_window(win)
    if not vim.api.nvim_win_is_valid(win) then return false end
    if vim.api.nvim_win_get_config(win).relative ~= "" then return false end

    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype ~= "" then return false end

    -- Buffer-local override (edgy auto-set'ит этот флаг для своих
    -- views; мы можем устанавливать вручную для diffview, neogit
    -- log и т.п.).
    if vim.b[buf].edgy_disable == false then return true end

    -- Любой tool-ft исключаем явно, чтобы не считать edgebar окна
    -- "главными" в случае, если edgy_disable не выставлен.
    local tool_ft = {
        ["neo-tree"] = true, ["aerial"] = true, ["toggleterm"] = true,
        ["dap-repl"] = true,
        ["dapui_scopes"] = true, ["dapui_watches"] = true,
        ["dapui_stacks"] = true, ["dapui_breakpoints"] = true,
        ["dapui_console"] = true,
        ["neotest-summary"] = true, ["neotest-output-panel"] = true,
        ["OverseerList"] = true, ["grug-far"] = true,
        ["trouble"] = true, ["qf"] = true,
        ["NeogitStatus"] = true, ["NeogitPopup"] = true,
        ["help"] = true, ["man"] = true, ["alpha"] = true,
    }
    return not tool_ft[vim.bo[buf].filetype]
end

---Найти окно для редактора. Если ни одного — создать.
---@return integer  window id
function M.find_main_window()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if M.is_main_window(win) then return win end
    end

    -- Нет ни одного main-окна. Создаём split в основной области
    -- (избегая edgy edgebar'ов).
    local cur = vim.api.nvim_get_current_win()
    -- Перейти на main: пробуем edgy.goto_main, иначе wincmd t/l.
    local ok = pcall(function() require("edgy").goto_main() end)
    if not ok then
        pcall(vim.cmd, "wincmd t")  -- top-left как fallback
    end
    -- Если current сейчас всё ещё tool-окно, открыть :enew в новом
    -- split'е, который точно будет main.
    if not M.is_main_window(vim.api.nvim_get_current_win()) then
        pcall(vim.cmd, "vsplit | enew")
    end
    local found = vim.api.nvim_get_current_win()
    -- Восстановить cursor на изначальное место, если оно валидно.
    if vim.api.nvim_win_is_valid(cur) and cur ~= found then
        pcall(vim.api.nvim_set_current_win, cur)
    end
    return found
end

function M.focus_main()
    local win = M.find_main_window()
    if win then pcall(vim.api.nvim_set_current_win, win) end
end

-- =============================================================
-- Slot transitions
-- =============================================================

---Закрыть текущий компонент в слоте (если есть).
---@param slot string
local function close_active(slot)
    refresh_slot(slot)
    local id = state.slots[slot]
    if not id then return end
    local comp = registry.get(id)
    if comp then pcall(comp.close) end
    state.slots[slot] = nil
end

---Открыть компонент.
---@param id string
function M.show(id)
    local comp = registry.get(id)
    if not comp then
        vim.notify("ide.show: unknown component '" .. tostring(id) .. "'",
            vim.log.levels.WARN, { title = "ide" })
        return
    end

    local slot = comp.slot
    refresh_slot(slot)

    -- Идемпотентность: если уже активен — оставляем как есть.
    if state.slots[slot] == id and comp.is_open() then return end

    close_active(slot)
    pcall(comp.open)
    state.slots[slot] = id
    state.last_shown[slot] = id
end

---@param id string
function M.hide(id)
    local comp = registry.get(id)
    if not comp then return end
    if state.slots[comp.slot] == id then
        close_active(comp.slot)
    end
end

---@param slot string
function M.hide_slot(slot)
    if not is_valid_slot(slot) then return end
    close_active(slot)
end

---Toggle всего слота: если в нём что-то открыто — закрыть; если пусто —
---открыть последний показанный компонент (или первый зарегистрированный
---в слоте как fallback).
---@param slot string
---@param fallback_id? string  что открыть, если в слоте никогда ничего
---  не показывалось и в registry нет компонентов в этом слоте
function M.toggle_slot(slot, fallback_id)
    if not is_valid_slot(slot) then return end
    refresh_slot(slot)

    if state.slots[slot] ~= nil then
        close_active(slot)
        return
    end

    -- Слот пуст. Выбираем кого открыть:
    --   1) last_shown — если он ещё зарегистрирован в нужном слоте;
    --   2) явный fallback_id из аргумента;
    --   3) первый зарегистрированный компонент в слоте.
    local function valid_in_slot(id)
        if not id then return false end
        local comp = registry.get(id)
        return comp ~= nil and comp.slot == slot
    end

    local target = nil
    if valid_in_slot(state.last_shown[slot]) then
        target = state.last_shown[slot]
    elseif valid_in_slot(fallback_id) then
        target = fallback_id
    else
        local components = registry.list(slot)
        if #components > 0 then target = components[1].id end
    end

    if target then M.show(target) end
end

---@param id string
function M.toggle(id)
    local comp = registry.get(id)
    if not comp then return end
    refresh_slot(comp.slot)
    if state.slots[comp.slot] == id then
        M.hide(id)
    else
        M.show(id)
    end
end

---Перейти к next/prev компоненту в группе того же слота.
---Группа = все зарегистрированные компоненты слота, sorted by id.
---@param slot string
---@param dir? integer  +1 (next, default) или -1 (prev)
function M.cycle(slot, dir)
    if not is_valid_slot(slot) then return end
    dir = dir or 1

    local components_in_slot = registry.list(slot)
    if #components_in_slot == 0 then return end

    refresh_slot(slot)
    local current_id = state.slots[slot]

    -- Найти индекс текущего; если ничего не открыто — start at 1.
    local idx = 0
    if current_id then
        for i, c in ipairs(components_in_slot) do
            if c.id == current_id then idx = i; break end
        end
    end

    local next_idx = ((idx - 1 + dir) % #components_in_slot) + 1
    if idx == 0 then next_idx = (dir > 0) and 1 or #components_in_slot end

    M.show(components_in_slot[next_idx].id)
end

---@param slot string
function M.focus_slot(slot)
    if not is_valid_slot(slot) then return end
    refresh_slot(slot)
    local id = state.slots[slot]
    if not id then return end
    local comp = registry.get(id)
    if comp and comp.focus then pcall(comp.focus) end
end

-- =============================================================
-- Единый toggle всех панелей on/off
-- =============================================================

---Спрятать ВСЕ панели (запомнив набор) / вернуть последний набор.
---Если прятать нечего и снимка нет — открываем explorer как дефолт.
function M.toggle_panels()
    refresh_all_slots()
    local any = state.slots.left or state.slots.right or state.slots.bottom

    if any then
        -- Снимок текущего набора слотов, потом закрываем всё.
        state.last_panel_slots = vim.deepcopy(state.slots)
        for _, slot in ipairs(SLOTS) do
            if state.slots[slot] then close_active(slot) end
        end
        M.focus_main()
    else
        local snap = state.last_panel_slots
        if snap and (snap.left or snap.right or snap.bottom) then
            for _, slot in ipairs(SLOTS) do
                if snap[slot] then M.show(snap[slot]) end
            end
        else
            M.show("explorer")
        end
        M.focus_main()
    end
end

-- =============================================================
-- Фокус по панелям (через маркер w:forge_panel, см. ide/marks.lua)
-- =============================================================

local function list_panel_windows()
    local wins = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) and vim.w[win].forge_panel then
            wins[#wins + 1] = win
        end
    end
    return wins
end

---Циклически перейти к следующей/предыдущей видимой панели.
---@param dir? integer +1 (next, default) | -1 (prev)
function M.focus_next_panel(dir)
    dir = dir or 1
    local wins = list_panel_windows()
    if #wins == 0 then return end

    local cur = vim.api.nvim_get_current_win()
    local idx = 0
    for i, w in ipairs(wins) do if w == cur then idx = i; break end end
    local nxt = ((idx - 1 + dir) % #wins) + 1
    if idx == 0 then nxt = (dir > 0) and 1 or #wins end
    pcall(vim.api.nvim_set_current_win, wins[nxt])
end

---Сфокусировать N-ю видимую панель (1-based, по порядку окон).
---@param n integer
function M.focus_panel(n)
    local wins = list_panel_windows()
    if wins[n] then pcall(vim.api.nvim_set_current_win, wins[n]) end
end

-- =============================================================
-- Layouts
-- =============================================================

---@param name string
---@param def ide.Layout
function M.register_layout(name, def)
    assert(type(name) == "string", "ide.register_layout: name must be string")
    state.layouts[name] = def
end

---Атомарно применить layout.
---@param name string
function M.apply_layout(name)
    local layout = state.layouts[name]
    if not layout then
        vim.notify("ide.apply_layout: unknown layout '" .. tostring(name) .. "'",
            vim.log.levels.WARN, { title = "ide" })
        return
    end

    refresh_all_slots()

    for _, slot in ipairs(SLOTS) do
        local target_id = layout[slot]
        local current_id = state.slots[slot]

        if target_id == nil then
            if current_id ~= nil then close_active(slot) end
        elseif target_id ~= current_id then
            M.show(target_id)
        end
        -- target_id == current_id: ничего не делаем (идемпотентность).
    end

    state.layout = name

    -- После применения layout курсор оставляем в main editor — это
    -- ожидаемое поведение для большинства layouts (debug, tests,
    -- files открывают tool-окна но юзер хочет писать код).
    M.focus_main()
end

function M.list_layouts()
    local names = vim.tbl_keys(state.layouts)
    table.sort(names)
    return names
end

-- =============================================================
-- Introspection
-- =============================================================

---@return { slots: ide.SlotState, layout: string|nil }
function M.current()
    refresh_all_slots()
    return {
        slots = vim.deepcopy(state.slots),
        layout = state.layout,
    }
end

-- =============================================================
-- Reset (для тестов и :Lazy reload)
-- =============================================================

function M.reset()
    state = {
        slots = { left = nil, right = nil, bottom = nil },
        layout = nil,
        layouts = {},
    }
end

return M
