-- spec: IDE-PANEL-3. Neo-tree v3 создаёт новое окно до нового NuiTree.
-- После close старый tree остаётся в state, но его буфер уже удалён.
-- Штатный follow может попасть в этот промежуток и прочитать cursor(nil).
-- Используем события backend; его функции/таймеры не подменяются.
local M = {}
local pending = setmetatable({}, { __mode = 'k' })

function M.opened(args)
    local state = require('neo-tree.sources.manager').get_state(args.source, args.tabid)
    if not state.tree or state.tree.bufnr == state.bufnr then return end

    local renderer = require('neo-tree.ui.renderer')
    local defaults = pending[state] and pending[state].defaults or state.default_expanded_nodes
    local expanded = renderer.get_expanded_nodes(state.tree)
    pending[state] = { defaults = defaults }
    state.default_expanded_nodes = vim.list_extend(vim.deepcopy(defaults or {}), expanded)
    state.tree = nil -- следующая штатная отрисовка создаст объект для нового буфера
end

function M.rendered(state)
    local saved = pending[state]
    if saved and state.tree and state.tree.bufnr == state.bufnr then
        -- Раскрытия переданы только первой отрисовке. Не превращаем их в
        -- постоянные defaults: пользователь сможет снова свернуть каталог.
        state.default_expanded_nodes = saved.defaults
        pending[state] = nil
    end
    if state.current_position ~= 'left' then return end
    -- Отложенный navigate тоже может закончиться после смены left-слота.
    -- Завершаем render, затем сверяем намерение менеджера и убираем позднее
    -- окно. Не закрываем его внутри acquire_window / отрисовки backend.
    vim.schedule(function()
        local ide = require('ide')
        local controls = require('ide.controls')
        local source_id = controls.tree_component(state.name)
        if source_id then ide.sync_visible_source(source_id, 'neo-tree') end
        local id = ide.current().slots.left
        local comp = id and ide.registry.get(id)
        if comp and not vim.tbl_contains(comp.filetypes, 'neo-tree') then
            -- spec: IDE-PANEL-10. Edgy on_hide может выбрать код уже после
            -- возврата Neo-tree в прежнее окно. Cleanup сохраняет этот выбор.
            local focus = vim.api.nvim_get_current_win()
            if focus == state.winid then focus = require('neo-tree').get_prior_window() end
            require('neo-tree.command').execute({ action = 'close', source = state.name, position = state.current_position })
            if focus > 0 and vim.api.nvim_win_is_valid(focus)
                and vim.api.nvim_win_get_tabpage(focus) == vim.api.nvim_get_current_tabpage() then
                vim.api.nvim_set_current_win(focus)
            end
        end
        controls.refresh() -- selector backend уже отрисован; добавить общий фокус
    end)
end

return M
