-- Именованные layout-пресеты. Тонкая обёртка над ide.state.
--
-- В v2 (в отличие от v1) layouts не знают про команды плагинов —
-- они оперируют только id'шниками компонентов из registry. Всю
-- работу делает state.apply_layout.

local state = require("ide.state")

local M = {}

---Регистрация одного пресета.
---@param name string
---@param def ide.Layout
function M.register(name, def)
    state.register_layout(name, def)
end

---Применить пресет.
---@param name string
function M.apply(name)
    state.apply_layout(name)
end

---vim.ui.select по доступным пресетам.
function M.select()
    local items = state.list_layouts()
    if #items == 0 then
        vim.notify("ide.layouts: no layouts registered", vim.log.levels.WARN,
            { title = "ide" })
        return
    end
    vim.ui.select(items, { prompt = "Layout: " }, function(choice)
        if choice then M.apply(choice) end
    end)
end

function M.list()
    return state.list_layouts()
end

return M
