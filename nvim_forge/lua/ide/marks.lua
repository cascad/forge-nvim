-- ide/marks.lua — явная маркировка tool-окон.
--
-- Зачем: «какое окно — какая панель» раньше вычислялось эвристикой (filetype,
-- winfix в panel_guard). Здесь мы СТАВИМ на каждое tool-окно явные window-local
-- метки из registry:
--   w:forge_panel     = true
--   w:forge_slot      = "left" | "right" | "bottom"
--   w:forge_component = "<id компонента>"
--
-- Метки ПЕРЕЖИВАЮТ смену буфера в окне (window-local) — поэтому если в панель
-- просочился файл (ft уже не tool), окно всё равно помечено forge_panel, и
-- forge/panel_guard.lua точно знает: это бывшая панель, файл надо унести.
--
-- ВАЖНО: window-local переменные НЕ сохраняются в сессию. После restore метки
-- теряются — поэтому panel_guard держит winfix-fallback для восстановленных
-- сломанных сессий (см. там). На живой сессии метки выставляются заново через
-- FileType/BufWinEnter, как только tool-буфер попадает в окно.

local registry = require("ide.registry")

local M = {}

-- ft -> { slot, id }. Первый зарегистрированный компонент для ft — «дефолт».
local ft_map = nil

-- neo-tree: один ft на три источника — уточняем компонент по b:neo_tree_source.
local NEOTREE_SOURCE_TO_ID = {
    filesystem = "explorer",
    buffers    = "buffers",
    git_status = "git_status",
}

local function build_map()
    ft_map = {}
    for id, comp in pairs(registry.all()) do
        for _, ft in ipairs(comp.filetypes or {}) do
            if not ft_map[ft] then
                ft_map[ft] = { slot = comp.slot, id = id }
            end
        end
    end
end

local function mark_window(win)
    if not (win and vim.api.nvim_win_is_valid(win)) then return end
    if vim.api.nvim_win_get_config(win).relative ~= "" then return end -- float
    if not ft_map then build_map() end

    local buf = vim.api.nvim_win_get_buf(win)
    local entry = ft_map[vim.bo[buf].filetype]
    if not entry then return end -- не tool-буфер: НЕ трогаем (и не чистим метку)

    vim.w[win].forge_panel = true
    vim.w[win].forge_slot = entry.slot

    local id = entry.id
    if vim.bo[buf].filetype == "neo-tree" then
        id = NEOTREE_SOURCE_TO_ID[vim.b[buf].neo_tree_source] or id
    end
    vim.w[win].forge_component = id
end

M.mark_window = mark_window

function M.setup()
    if M._setup then return end
    M._setup = true
    build_map()

    -- Метим в момент, когда tool-буфер оказывается в окне.
    vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
        group = vim.api.nvim_create_augroup("ForgeIdeMarks", { clear = true }),
        callback = function()
            mark_window(vim.api.nvim_get_current_win())
        end,
    })

    -- Пометить уже открытые tool-окна (например, после :Lazy reload).
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        mark_window(win)
    end
end

return M
