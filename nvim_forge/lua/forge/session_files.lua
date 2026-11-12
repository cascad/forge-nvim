-- spec: IDE-PANEL-25. Данные native Files, не копия окон/процессов.
local M = {}
local captured

local function fingerprint(file)
    return vim.fn.sha256(table.concat(vim.fn.readfile(file, 'b'), '\n'))
end

local function data_file(session)
    local path = vim.fs.normalize(session):gsub('\\', '/')
    if vim.fn.has('win32') == 1 then path = path:lower() end
    return vim.fn.stdpath('state') .. '/forge-session-views/' .. vim.fn.sha256(path) .. '.json'
end

function M.capture()
    captured = nil
    local snapshot = {}
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        local item = { files = false }
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
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
                break
            end
        end
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
        local data = { version = 1, session_hash = fingerprint(session), tabs = {} }
        -- Cleanup может закрыть tabpage, где не было файлов кода.
        for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
            data.tabs[#data.tabs + 1] = snapshot[tab] or { files = false }
        end
        local file = data_file(session)
        vim.fn.mkdir(vim.fs.dirname(file), 'p')
        assert(vim.fn.writefile({ vim.json.encode(data) }, file) == 0, 'write failed')
    end)
    if not ok then vim.notify('Files session: ' .. tostring(err), vim.log.levels.WARN) end
end

function M.restore(done)
    local session = vim.v.this_session
    if session == '' then return false end
    local file = data_file(session)
    if vim.fn.filereadable(file) ~= 1 then return false end
    local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(file), '\n')) end)
    if not ok or type(data) ~= 'table' or data.version ~= 1 or type(data.tabs) ~= 'table' then
        vim.notify('Files session: invalid view data', vim.log.levels.WARN)
        return false
    end
    local tabs = vim.api.nvim_list_tabpages()
    if data.session_hash ~= fingerprint(session) or #data.tabs ~= #tabs then return false end
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
    end
    local original = vim.api.nvim_get_current_win()
    local index, finished = 0, false
    local function complete(err)
        if finished then return end
        finished = true
        if vim.api.nvim_win_is_valid(original) then vim.api.nvim_set_current_win(original) end
        if done then done(err)
        elseif err then vim.notify('Files session: ' .. tostring(err), vim.log.levels.WARN) end
    end
    local function advance(err)
        if finished then return end
        if err then complete(err); return end
        index = index + 1
        local tab, item = tabs[index], data.tabs[index]
        if not tab then complete(); return end
        -- Edgy управляет текущей вкладкой. Следующая — после её native render.
        vim.schedule(function()
            if finished then return end
            local ok, why = pcall(function()
                vim.api.nvim_set_current_tabpage(tab)
                local code = vim.api.nvim_get_current_win()
                local ide = require('ide')
                ide.hide('explorer')
                local view = item.files
                if type(view) == 'table' then
                    view = vim.deepcopy(view)
                    local stat = vim.uv.fs_stat(view.path)
                    if not stat or stat.type ~= 'directory' then view.path = vim.fn.getcwd() end
                    if type(view.selected) ~= 'string' or not vim.uv.fs_stat(view.selected) then
                        view.selected = view.path
                    end
                    ide.show('explorer', { focus = false, tree_view = view, on_tree_restored = advance })
                else
                    advance()
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
