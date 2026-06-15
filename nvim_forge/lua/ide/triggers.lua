-- ide/triggers.lua — декларативный слой «событие → авто-открытие панели».
--
-- Раньше авто-открытие было размазано императивно по плагинам (dap.lua дёргал
-- panels.show_debug_section в слушателях). Здесь — ОДНА таблица «что на что
-- открывается». Точки интеграции просто зовут ide.triggers.fire(name, ctx);
-- что именно открыть — решает SPECS, в одном месте.
--
-- Подключённые триггеры (по требованию пользователя):
--   debug:start  — старт DAP-сессии  → debug-раскладка (sidebar + секция)
--   test:run     — запуск тестов      → Test Output (bottom)
--   task:run     — запуск задачи/сборки→ Tasks (bottom)
--   project:open — вход в проект       → дерево файлов (explorer, left)
--
-- НАМЕРЕННО НЕ подключено: диагностика/ошибки → Trouble (по требованию — не
-- открывать автоматически, раздражает). Добавить — просто строкой в SPECS.

local M = {}

local SPECS = {
    ["debug:start"] = function(ctx)
        require("ide.dap").show_section(ctx.section, false)
    end,
    ["test:run"] = function()
        require("ide").show("tests_output")
    end,
    ["task:run"] = function()
        require("ide").show("tasks_output")
    end,
    ["project:open"] = function()
        require("ide").show("explorer")
    end,
}

---Выстрелить триггером.
---@param name string  ключ из SPECS
---@param ctx? table   контекст (например { section = "repl" } для debug:start)
function M.fire(name, ctx)
    local action = SPECS[name]
    if action then pcall(action, ctx or {}) end
end

---Зарегистрировать/переопределить триггер (для расширения из других модулей).
---@param name string
---@param action fun(ctx: table)
function M.register(name, action)
    SPECS[name] = action
end

M.specs = SPECS

return M
