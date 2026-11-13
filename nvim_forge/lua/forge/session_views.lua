-- spec: IDE-PANEL-25/26/27/28/IDE-LOG-5. Только данные native представления.
local M = {}
local captured
local sizes, applied, queued = {}, {}, {}
local epoch = 0
local deferred = {
    toggleterm = { id = 'terminal', dimension = 'height' },
    dapui_scopes = { id = 'debug_sidebar', dimension = 'width' },
    dapui_watches = { id = 'debug_sidebar', dimension = 'width' },
    dapui_stacks = { id = 'debug_sidebar', dimension = 'width' },
    dapui_breakpoints = { id = 'debug_sidebar', dimension = 'width' },
    ['dap-repl'] = { id = 'debug_output', dimension = 'height' },
    dapui_console = { id = 'debug_output', dimension = 'height' },
    ['dap-terminal'] = { id = 'debug_output', dimension = 'height' },
}

local function fingerprint(file)
    return vim.fn.sha256(table.concat(vim.fn.readfile(file, 'b'), '\n'))
end

local function data_file(session)
    local path = vim.fs.normalize(session):gsub('\\', '/')
    if vim.fn.has('win32') == 1 then path = path:lower() end
    return vim.fn.stdpath('state') .. '/forge-session-views/' .. vim.fn.sha256(path) .. '.json'
end

local function restore_window(ft, view, dimension, done, target)
    local win = target or require('ide.activities').find_window(ft, function(_, w)
        return vim.api.nvim_win_get_config(w).relative == ''
    end)
    local buf = win and vim.api.nvim_win_get_buf(win)
    local current_epoch = epoch
    vim.schedule(function()
        if current_epoch ~= epoch then return end
        local ok, err = pcall(function()
            assert(win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf, 'Session view window changed')
            local edge = assert(require('edgy').get_win(win), 'Session view is not registered in Edgy')
            local extent = dimension == 'width' and 'columns' or 'lines'
            local size = math.max(1, math.floor(view[dimension] * math.min(1, vim.o[extent] / view[extent]) + 0.5))
            edge:resize(dimension, size - vim.api['nvim_win_get_' .. dimension](win))
            if view.view then vim.api.nvim_win_call(win, function() vim.fn.winrestview(view.view) end) end
        end)
        done(not ok and err or nil)
    end)
end

local function tool_window(win)
    if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_config(win).relative ~= '' then return end
    local buf = vim.api.nvim_win_get_buf(win)
    local spec = deferred[vim.bo[buf].filetype]
    if spec then return spec, buf, vim.api.nvim_win_get_tabpage(win) end
end

local function remember(win)
    local spec, buf, tab = tool_window(win)
    if not spec then return end
    local view = sizes[tab] and sizes[tab][spec.id]
    if view and applied[win] ~= buf then return end -- не заменять saved размер открывающими defaults
    local edge = package.loaded.edgy and require('edgy').get_win(win)
    local value = vim.api['nvim_win_get_' .. spec.dimension](win)
    if not edge or edge[spec.dimension] ~= value then return end
    local extent = spec.dimension == 'width' and 'columns' or 'lines'
    sizes[tab] = sizes[tab] or {}
    sizes[tab][spec.id] = { [spec.dimension] = value, [extent] = vim.o[extent] }
    applied[win] = buf
end

function M.setup()
    local group = vim.api.nvim_create_augroup('ForgeSessionToolSizes', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter', 'FileType' }, {
        group = group,
        callback = function(ev)
            for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
                local spec, buf, tab = tool_window(win)
                if spec and tab == vim.api.nvim_get_current_tabpage() and applied[win] ~= buf and queued[win] ~= buf then
                    local view = sizes[tab] and sizes[tab][spec.id]
                    if view then
                        queued[win] = buf
                        restore_window(vim.bo[buf].filetype, vim.deepcopy(view), spec.dimension, function(err)
                            queued[win] = nil
                            if not err then applied[win] = buf;remember(win)
                            elseif vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
                                vim.notify('Session size: ' .. tostring(err), vim.log.levels.WARN)
                            end
                        end, win)
                    else
                        applied[win] = buf
                        remember(win)
                    end
                end
            end
        end,
    })
    vim.api.nvim_create_autocmd('WinLeave', { group = group, callback = function() remember(vim.api.nvim_get_current_win()) end })
    vim.api.nvim_create_autocmd('WinResized', { group = group, callback = function()
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do remember(win) end
    end })
    vim.api.nvim_create_autocmd('WinClosed', { group = group, callback = function(ev)
        local win = tonumber(ev.match);applied[win] = nil;queued[win] = nil
    end })
    vim.api.nvim_create_autocmd('TabClosed', { group = group, callback = function()
        for tab in pairs(sizes) do if not vim.api.nvim_tabpage_is_valid(tab) then sizes[tab] = nil end end
    end })
    vim.api.nvim_create_autocmd('User', { group = group, pattern = 'PersistenceLoadPre', callback = function()
        epoch = epoch + 1;sizes, applied, queued = {}, {}, {}
    end })
end

function M.capture()
    captured = nil
    local snapshot = {}
    local logs = package.loaded['forge.logs']
    if logs then snapshot.logs = { source = logs.source, minimum = logs.minimum, query = logs.query } end
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        local item = { files = false, logs = false, outline = false, tests = false }
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
            remember(win)
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == 'neo-tree' and vim.b[buf].neo_tree_source == 'filesystem'
                and vim.api.nvim_win_get_config(win).relative == '' then
                -- get_state_for_window(win) берёт current tab, даже для чужого win.
                local state = require('neo-tree.sources.manager').get_state('filesystem', tab)
                if state and state.tree then
                    local node = state.tree:get_node(vim.api.nvim_win_get_cursor(win)[1])
                    item.files = {
                        path = state.path, selected = node and node:get_id(),
                        expanded = require('neo-tree.ui.renderer').get_expanded_nodes(state.tree),
                        explicit = vim.deepcopy(state.explicitly_opened_nodes or {}),
                        view = vim.api.nvim_win_call(win, vim.fn.winsaveview),
                        width = vim.api.nvim_win_get_width(win), columns = vim.o.columns,
                    }
                end
            elseif vim.bo[buf].filetype == 'forge-logs' and vim.api.nvim_win_get_config(win).relative == '' then
                item.logs = {
                    view = vim.api.nvim_win_call(win, vim.fn.winsaveview),
                    height = vim.api.nvim_win_get_height(win), lines = vim.o.lines,
                }
            elseif vim.bo[buf].filetype == 'aerial' and vim.api.nvim_win_get_config(win).relative == '' then
                item.outline = { width = vim.api.nvim_win_get_width(win), columns = vim.o.columns }
            elseif vim.bo[buf].filetype == 'neotest-summary' and vim.api.nvim_win_get_config(win).relative == '' then
                item.tests = { width = vim.api.nvim_win_get_width(win), columns = vim.o.columns }
            end
        end
        item.deferred = sizes[tab] and vim.deepcopy(sizes[tab]) or nil
        snapshot[tab] = item
    end
    captured = snapshot
end

function M.save()
    local snapshot = captured
    captured = nil
    if not snapshot then return end
    local ok, err = pcall(function()
        local session = require('persistence').current()
        local data = { version = 1, session_hash = fingerprint(session), tabs = {}, logs = snapshot.logs }
        -- Cleanup может закрыть tabpage, где не было файлов кода.
        for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
            data.tabs[#data.tabs + 1] = snapshot[tab] or { files = false, logs = false, outline = false, tests = false }
        end
        local file = data_file(session)
        vim.fn.mkdir(vim.fs.dirname(file), 'p')
        assert(vim.fn.writefile({ vim.json.encode(data) }, file) == 0, 'write failed')
    end)
    if not ok then vim.notify('Session views: ' .. tostring(err), vim.log.levels.WARN) end
end

function M.restore(done)
    local restore_epoch = epoch
    local session = vim.v.this_session
    if session == '' then return false end
    local file = data_file(session)
    if vim.fn.filereadable(file) ~= 1 then return false end
    local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(file), '\n')) end)
    if not ok or type(data) ~= 'table' or data.version ~= 1 or type(data.tabs) ~= 'table' then
        vim.notify('Session views: invalid view data', vim.log.levels.WARN)
        return false
    end
    local tabs = vim.api.nvim_list_tabpages()
    if data.session_hash ~= fingerprint(session) or #data.tabs ~= #tabs then return false end
    if data.logs ~= nil and (type(data.logs) ~= 'table' or type(data.logs.source) ~= 'string'
        or type(data.logs.query) ~= 'string' or type(data.logs.minimum) ~= 'number'
        or data.logs.minimum < 0 or data.logs.minimum > 5) then return false end
    for _, item in ipairs(data.tabs) do
        if type(item) ~= 'table' then return false end
        local view = item.files
        if view ~= false then
            if type(view) ~= 'table' or type(view.path) ~= 'string'
                or type(view.expanded) ~= 'table' or type(view.view) ~= 'table'
                or type(view.width) ~= 'number' or view.width < 1
                or type(view.columns) ~= 'number' or view.columns < 1 then return false end
            for _, field in ipairs({ 'lnum', 'topline', 'leftcol', 'col' }) do
                if type(view.view[field]) ~= 'number' then return false end
            end
        end
        local logs = item.logs
        if logs ~= nil and logs ~= false then
            if type(logs) ~= 'table' or type(logs.view) ~= 'table'
                or type(logs.height) ~= 'number' or logs.height < 1
                or type(logs.lines) ~= 'number' or logs.lines < 1 then return false end
            for _, field in ipairs({ 'lnum', 'topline', 'leftcol', 'col' }) do
                if type(logs.view[field]) ~= 'number' then return false end
            end
        end
        local outline = item.outline
        if outline ~= nil and outline ~= false and (type(outline) ~= 'table'
            or type(outline.width) ~= 'number' or outline.width < 1
            or type(outline.columns) ~= 'number' or outline.columns < 1) then return false end
        local tests = item.tests
        if tests ~= nil and tests ~= false and (type(tests) ~= 'table'
            or type(tests.width) ~= 'number' or tests.width < 1
            or type(tests.columns) ~= 'number' or tests.columns < 1) then return false end
        if item.deferred ~= nil and type(item.deferred) ~= 'table' then return false end
        for id, view in pairs(item.deferred or {}) do
            local dimension = id == 'debug_sidebar' and 'width' or (id == 'terminal' or id == 'debug_output') and 'height'
            local extent = dimension == 'width' and 'columns' or 'lines'
            if not dimension or type(view) ~= 'table' or type(view[dimension]) ~= 'number' or view[dimension] < 1
                or type(view[extent]) ~= 'number' or view[extent] < 1 then return false end
        end
    end
    for i, tab in ipairs(tabs) do sizes[tab] = vim.deepcopy(data.tabs[i].deferred or {}) end
    if data.logs then
        local logs = require('forge.logs')
        logs.source, logs.minimum, logs.query = data.logs.source, data.logs.minimum, data.logs.query
        logs.refresh()
    end
    local original = vim.api.nvim_get_current_win()
    local index, finished = 0, false
    local function complete(err)
        if finished then return end
        finished = true
        if vim.api.nvim_win_is_valid(original) then vim.api.nvim_set_current_win(original) end
        if done then done(err)
        elseif err then vim.notify('Session views: ' .. tostring(err), vim.log.levels.WARN) end
    end
    local function advance(err)
        if finished or restore_epoch ~= epoch then return end
        if err then complete(err); return end
        index = index + 1
        local tab, item = tabs[index], data.tabs[index]
        if not tab then complete(); return end
        -- Edgy управляет текущей вкладкой. Следующая — после её native render.
        vim.schedule(function()
            if finished or restore_epoch ~= epoch then return end
            local ok, why = pcall(function()
                vim.api.nvim_set_current_tabpage(tab)
                local code = vim.api.nvim_get_current_win()
                local ide = require('ide')
                ide.hide('explorer')
                local tools = {
                    { id = 'outline', ft = 'aerial', view = item.outline, dimension = 'width' },
                    { id = 'tests', ft = 'neotest-summary', view = item.tests, dimension = 'width', event = 'NeotestSummaryOpen' },
                    { id = 'logs', ft = 'forge-logs', view = item.logs, dimension = 'height' },
                }
                local tool_index = 0
                local function after_files(err)
                    if err then advance(err); return end
                    tool_index = tool_index + 1
                    local tool = tools[tool_index]
                    if not tool then advance(); return end
                    local opened, why = pcall(function()
                        -- nil — прежний snapshot; false — явно скрытая панель.
                        if tool.view ~= nil then ide.hide(tool.id) end
                        if type(tool.view) == 'table' then
                            if tool.event then
                                require('neotest') -- отсутствующий backend не оставляет ожидающий handler
                                local event, started
                                local function ready()
                                    if started then return end
                                    started = true
                                    if event then pcall(vim.api.nvim_del_autocmd, event) end
                                    if restore_epoch == epoch then restore_window(tool.ft, tool.view, tool.dimension, after_files) end
                                end
                                event = vim.api.nvim_create_autocmd('User', { pattern = tool.event, once = true, callback = ready })
                                ide.show(tool.id, { focus = false })
                                if require('ide.activities').find_window(tool.ft) then ready() end
                            else
                                ide.show(tool.id, { focus = false })
                                restore_window(tool.ft, tool.view, tool.dimension, after_files)
                            end
                        else
                            after_files()
                        end
                        if not finished and vim.api.nvim_win_is_valid(code) then vim.api.nvim_set_current_win(code) end
                    end)
                    if not opened then advance(why) end
                end
                local view = item.files
                if type(view) == 'table' then
                    view = vim.deepcopy(view)
                    local stat = vim.uv.fs_stat(view.path)
                    if not stat or stat.type ~= 'directory' then view.path = vim.fn.getcwd() end
                    if type(view.selected) ~= 'string' or not vim.uv.fs_stat(view.selected) then
                        view.selected = view.path
                    end
                    ide.show('explorer', { focus = false, tree_view = view, on_tree_restored = after_files })
                else
                    after_files()
                end
                if not finished and vim.api.nvim_win_is_valid(code) then vim.api.nvim_set_current_win(code) end
            end)
            if not ok then complete(why) end
        end)
    end
    advance()
    return true
end

return M
