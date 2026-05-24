-- Реестр компонентов IDE-фреймворка.
--
-- Компонент = именованная обёртка над командой плагина с явным
-- контрактом (open / close / is_open / filetypes). Хранится здесь;
-- состояние слотов и transitions — в ide/state.lua.
--
-- Регистрация делается из ide/init.lua.setup() при старте Neovim.
-- Плагины (neo-tree, aerial, ...) сами по себе ничего не знают об
-- ide.registry — это thin facade.

local M = {}

---@class ide.Component
---@field id        string             -- уникальный, e.g. "explorer", "dap.console"
---@field slot      "left"|"right"|"bottom"
---@field title     string             -- человекочитаемое имя
---@field open      fun()              -- открыть и сделать видимым
---@field close     fun()              -- закрыть (если открыт)
---@field is_open   fun(): boolean
---@field focus?    fun()              -- сфокусироваться (default: find by filetypes)
---@field filetypes? string[]          -- для default is_open / focus / edgy filter
---@field icon?     string             -- для Activity Bar UI (пока не используется)

local components = {} ---@type table<string, ide.Component>

---@param spec ide.Component
function M.register(spec)
    assert(type(spec) == "table", "ide.registry.register: spec must be a table")
    assert(type(spec.id) == "string" and #spec.id > 0,
        "ide.registry.register: spec.id must be a non-empty string")
    assert(spec.slot == "left" or spec.slot == "right" or spec.slot == "bottom",
        "ide.registry.register: spec.slot must be 'left' | 'right' | 'bottom', got " ..
        tostring(spec.slot))
    assert(type(spec.open) == "function",
        "ide.registry.register: spec.open must be a function for id=" .. spec.id)
    assert(type(spec.close) == "function",
        "ide.registry.register: spec.close must be a function for id=" .. spec.id)
    assert(type(spec.is_open) == "function",
        "ide.registry.register: spec.is_open must be a function for id=" .. spec.id)

    spec.title = spec.title or spec.id
    spec.filetypes = spec.filetypes or {}

    -- Default focus: первая попавшаяся window с матчящимся filetype'ом.
    if not spec.focus then
        spec.focus = function()
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if vim.api.nvim_win_is_valid(win) then
                    local buf = vim.api.nvim_win_get_buf(win)
                    local ft = vim.bo[buf].filetype
                    for _, target in ipairs(spec.filetypes) do
                        if ft == target then
                            vim.api.nvim_set_current_win(win)
                            return
                        end
                    end
                end
            end
        end
    end

    components[spec.id] = spec
end

---@param id string
---@return ide.Component|nil
function M.get(id)
    return components[id]
end

---@param slot? "left"|"right"|"bottom"
---@return ide.Component[]
function M.list(slot)
    local result = {}
    for _, c in pairs(components) do
        if not slot or c.slot == slot then
            table.insert(result, c)
        end
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end

---@return table<string, ide.Component>
function M.all()
    return components
end

-- Сброс реестра — нужен для тестов и :Lazy reload.
function M.reset()
    components = {}
end

return M
