-- spec: IDE-PANEL-3. Neo-tree v3 создаёт новое окно до нового NuiTree.
-- После close старый tree остаётся в state, но его буфер уже удалён.
-- Штатный follow может попасть в этот промежуток и прочитать cursor(nil).
-- Используем события backend; его функции/таймеры не подменяются.
local M = {}
local pending = setmetatable({}, { __mode = 'k' })
local passive = setmetatable({}, { __mode = 'k' })
local restoring = false
local last_files = {}

function M.session_loading(value)
    restoring = value
    if value then last_files = {} end
end

-- Возврат фокуса в тот же файл не сбрасывает просмотр/восстановленный view.
function M.follow_file(args)
    local utils = require('neo-tree.utils')
    if not utils.is_real_file(args.afile) then return end
    local tab = vim.api.nvim_get_current_tabpage()
    local file = utils.normalize_path(args.afile)
    local previous = last_files[tab]
    last_files[tab] = file
    if not restoring and previous ~= file then require('neo-tree.sources.filesystem').follow() end
end

local function source_state(source)
    require('neo-tree').ensure_config()
    return require('neo-tree.sources.manager').get_state(source)
end

-- spec: IDE-PANEL-23. Только общий restore просит возврат после native render.
function M.open(source, opts)
    local state = source_state(source)
    passive[state] = opts and opts.focus == false and { origin = vim.api.nvim_get_current_win() } or nil
    local args = { source = source, position = 'left', reveal = true }
    local view = opts and opts.tree_view
    if view then
        pending[state] = { defaults = state.default_expanded_nodes, view = view, done = opts.on_tree_restored }
        state.default_expanded_nodes = view.expanded or {}
        state.explicitly_opened_nodes = view.explicit or {}
        args.dir, args.reveal_file, args.reveal = view.path, view.selected, false
    end
    if view then
        local ok, err = pcall(require('neo-tree.command').execute, args)
        if not ok then
            local saved = pending[state]
            if saved then state.default_expanded_nodes = saved.defaults end
            pending[state], passive[state] = nil, nil
            if opts.on_tree_restored then opts.on_tree_restored(err) end
            error(err)
        end
    else
        require('neo-tree.command').execute(args)
    end
end

function M.focus(source)
    passive[source_state(source)] = nil
    -- Прежний default focus реестра: первая подходящая window текущей вкладки.
    require('ide.activities').focus_window(nil, function(buf) return vim.bo[buf].filetype == 'neo-tree' end)
end

function M.opened(args)
    local state = require('neo-tree.sources.manager').get_state(args.source, args.tabid)
    if not state.tree or state.tree.bufnr == state.bufnr then return end

    local renderer = require('neo-tree.ui.renderer')
    local saved = pending[state]
    local defaults = state.default_expanded_nodes
    if saved then defaults = saved.defaults end
    local expanded = saved and saved.view and saved.view.expanded or renderer.get_expanded_nodes(state.tree)
    pending[state] = saved or { defaults = defaults }
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
        if saved.view then
            local win, tree = state.winid, state.tree
            local view = saved.view
            vim.schedule(function()
                local ok, err = pcall(function()
                    assert(vim.api.nvim_win_is_valid(win) and state.tree == tree
                        and vim.api.nvim_win_get_buf(win) == tree.bufnr
                        and vim.b[tree.bufnr].neo_tree_source == 'filesystem', 'Files view window changed')
                    local edge = assert(require('edgy').get_win(win), 'Files view is not registered in Edgy')
                    local scale = math.min(1, vim.o.columns / view.columns)
                    local width = math.max(1, math.floor(view.width * scale + 0.5))
                    edge:resize('width', width - vim.api.nvim_win_get_width(win))
                    local renderer = require('neo-tree.ui.renderer')
                    assert(renderer.focus_node(state, view.selected, true), 'Files view node is not ready')
                    vim.api.nvim_win_call(win, function()
                        local current = vim.fn.winsaveview()
                        current.topline = math.max(1, current.lnum - (view.view.lnum - view.view.topline))
                        current.leftcol, current.col = view.view.leftcol, view.view.col
                        vim.fn.winrestview(current)
                    end)
                    renderer.position.save(state, true)
                end)
                if saved.done then saved.done(not ok and err or nil)
                elseif not ok then vim.notify('Files session: ' .. tostring(err), vim.log.levels.WARN) end
            end)
        end
    end
    if state.current_position ~= 'left' then return end
    local restore_request = passive[state]
    local restore_focus = restore_request and require('neo-tree').get_prior_window()
    if restore_focus and restore_focus < 0 then restore_focus = restore_request.origin end
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
        if restore_request and passive[state] == restore_request then
            passive[state] = nil
            if vim.api.nvim_get_current_win() == state.winid and restore_focus
                and vim.api.nvim_win_is_valid(restore_focus)
                and vim.api.nvim_win_get_tabpage(restore_focus) == vim.api.nvim_get_current_tabpage() then
                vim.api.nvim_set_current_win(restore_focus)
            end
        end
        controls.refresh() -- selector backend уже отрисован; добавить общий фокус
    end)
end

return M
