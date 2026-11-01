-- spec: IDE-GIT-5. Владение запросом close, без подмены методов Diffview.
local M = {}
local states = setmetatable({}, { __mode = 'k' })
local api = vim.api

local function valid_tab(tab) return tab and api.nvim_tabpage_is_valid(tab) end
local function current_view() return require('diffview.lib').get_current_view() end

local function return_to_source(view, state)
    if api.nvim_get_current_tabpage() ~= view.tabpage then return end
    local source = state.source
    if not valid_tab(source) then
        for _, tab in ipairs(api.nvim_list_tabpages()) do
            if tab ~= view.tabpage then source = tab; break end
        end
    end
    if valid_tab(source) and source ~= view.tabpage then
        api.nvim_set_current_tabpage(source)
        if state.win and api.nvim_win_is_valid(state.win) and api.nvim_win_get_tabpage(state.win) == source then
            api.nvim_set_current_win(state.win)
        end
    else
        vim.cmd('tabnew')
    end
end

local function busy(view, state)
    return not view.ready or state.opening > 0 or (view.panel and view.panel.updating)
end

local function dispose(view, state)
    state.pending = false
    -- Не использовать get_current_view здесь: пользователь уже может открыть
    -- другой просмотр. Это те же операции, что выполняет native close.
    view:close()
    require('diffview.lib').dispose_view(view)
    states[view] = nil
end

local function finish(view, state)
    if states[view] ~= state or not state.pending then return end
    if view.closing:check() or not valid_tab(view.tabpage) then
        states[view] = nil
        return
    end
    if busy(view, state) then
        vim.defer_fn(function() finish(view, state) end, 20)
        return
    end
    dispose(view, state)
end

function M.opened(view)
    if states[view] then return end
    local source = api.nvim_list_tabpages()[vim.fn.tabpagenr('#')]
    local state = { source = source, win = valid_tab(source) and api.nvim_tabpage_get_win(source), opening = 0 }
    states[view] = state
    view.emitter:on('file_open_pre', function() state.opening = state.opening + 1 end)
    view.emitter:on('file_open_post', function() state.opening = math.max(0, state.opening - 1) end)
end

function M.closed(view) states[view] = nil end

function M.close()
    local view = current_view()
    if not view then return end
    if not states[view] then M.opened(view) end
    local state = states[view]
    if state.pending then return_to_source(view, state); return end
    if not busy(view, state) then dispose(view, state); return end
    state.pending = true
    return_to_source(view, state)
    -- file_open_post ещё выполняет код coroutine после эмиссии события.
    -- Очистка всегда начинается вне этого стека и ждёт также запрос панели.
    vim.schedule(function() finish(view, state) end)
end

function M.setup()
    api.nvim_create_user_command('DiffviewClose', M.close, {
        nargs = 0, bang = true, force = true, desc = 'Git: close view safely while loading',
    })
end

return M
