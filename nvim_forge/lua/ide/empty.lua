-- "No files" заглушка — заменяет старое поведение
-- close_current_buffer (config/keymaps.lua), которое при закрытии
-- последнего code-буфера делало `:enew` (т.е. оставлял пустой
-- "Noname" буфер).
--
-- В VS Code-стиле: вместо Noname показываем alpha-nvim welcome
-- screen, как при свежем старте Neovim без файлов.

local M = {}

-- Является ли буфер "code"-буфером, т.е. пользовательским
-- редактируемым файлом, а не tool-окном.
---@param buf integer
---@return boolean
local function is_code_buffer(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return false end
    if not vim.bo[buf].buflisted then return false end
    if vim.bo[buf].buftype ~= "" then return false end

    -- Безымянные scratch-буферы пропускаем (Noname).
    if vim.api.nvim_buf_get_name(buf) == "" then return false end

    -- Tool-фильтры (на случай если кто-то выставил buflisted=true
    -- на tool-окне).
    local tool_ft = {
        ["alpha"] = true, ["neo-tree"] = true, ["aerial"] = true,
        ["dap-repl"] = true,
        ["dapui_scopes"] = true, ["dapui_watches"] = true,
        ["dapui_stacks"] = true, ["dapui_breakpoints"] = true,
        ["dapui_console"] = true,
        ["neotest-summary"] = true, ["neotest-output-panel"] = true,
        ["OverseerList"] = true, ["grug-far"] = true, ["trouble"] = true,
        ["qf"] = true, ["help"] = true, ["man"] = true,
        ["NeogitStatus"] = true, ["toggleterm"] = true,
    }
    if tool_ft[vim.bo[buf].filetype] then return false end

    return true
end

---Все code-буферы кроме указанного.
---@param except integer
---@return integer[]
local function other_code_buffers(except)
    local result = {}
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if b ~= except and is_code_buffer(b) then
            table.insert(result, b)
        end
    end
    return result
end

---Показать alpha welcome screen в текущем (main) window.
local function open_alpha_screen()
    local ok, alpha = pcall(require, "alpha")
    if not ok then
        -- Alpha не установлен — fallback на пустой scratch.
        pcall(vim.cmd, "enew")
        return
    end
    -- alpha.start(false) рендерит welcome, не делая autocmd-trigger.
    pcall(alpha.start, false)
end

---Умный close для текущего буфера. Заменяет старую
---close_current_buffer из config/keymaps.lua.
---@param opts? { force?: boolean }
function M.close_buffer_safe(opts)
    opts = opts or {}
    local current = vim.api.nvim_get_current_buf()

    -- В tool-окне close_buffer не должен делать ничего разумного —
    -- предложим закрыть окно вместо.
    if not is_code_buffer(current) then
        if vim.bo[current].buftype == "nofile" or vim.bo[current].buftype == "terminal" then
            -- Это уже scratch/term — просто переключимся на
            -- другой code buffer если есть.
            local others = other_code_buffers(current)
            if #others > 0 then
                vim.api.nvim_set_current_buf(others[1])
            end
            return
        end
        -- В остальных tool-окнах (neo-tree, aerial, и т.п.) просто
        -- закроем окно.
        pcall(vim.cmd, "close")
        return
    end

    local others = other_code_buffers(current)

    if #others == 0 then
        -- Это последний обычный файл. Показываем alpha вместо
        -- Noname, потом удаляем буфер.
        open_alpha_screen()
        -- Теперь current buffer — alpha. Удалить старый можно
        -- безопасно: окно не закроется.
        if vim.api.nvim_buf_is_valid(current) then
            pcall(vim.cmd, opts.force and ("bdelete! " .. current) or ("bdelete " .. current))
        end
        return
    end

    -- Есть другие code-буферы. Переключимся на первый из них
    -- (или предыдущий, что более привычно).
    local target = others[1]
    -- Найти ВСЕ окна, показывающие current, и заменить на target,
    -- чтобы layout (edgy edgebars) не схлопывался.
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == current then
            pcall(vim.api.nvim_win_set_buf, win, target)
        end
    end

    if vim.api.nvim_buf_is_valid(current) then
        pcall(vim.cmd, opts.force and ("bdelete! " .. current) or ("confirm bdelete " .. current))
    end
end

---Экспорт helper'ов на случай если они нужны где-то ещё.
M.is_code_buffer = is_code_buffer
M.other_code_buffers = other_code_buffers
M.open_alpha_screen = open_alpha_screen

return M
