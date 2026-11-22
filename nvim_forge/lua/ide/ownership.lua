-- IDE-PANEL-32: declared owners + native winfixbuf; no API monkeypatch.
local M = {}
local registry = require('ide.registry')
local owned, depth = {}, {}
local known, mapped = {}, {}
local busy, loading = false, false
local function valid(w) return w and vim.api.nvim_win_is_valid(w) end
local function pack(...) return { n = select('#', ...), ... } end
local function clear(w)
    owned[w] = nil
    if not valid(w) then return end
    vim.w[w].forge_panel, vim.w[w].forge_slot, vim.w[w].forge_component = nil, nil, nil
    vim.wo[w].winfixbuf = false
end
function M.is_editor_window(w)
    local pilot = package.loaded['forge.frame_pilot']
    if pilot and pilot.is_code(w) then return true end
    return valid(w) and vim.api.nvim_win_get_config(w).relative == '' and not owned[w]
        and registry.policy(vim.api.nvim_win_get_buf(w)).role == 'editor'
end
function M.release(family)
    for w, o in pairs(owned) do if valid(w) and o.family == family then vim.wo[w].winfixbuf = false end end
end
function M.transition(family, fn, ...)
    depth[family] = (depth[family] or 0) + 1
    M.release(family)
    local result = pack(pcall(fn, ...))
    depth[family] = depth[family] - 1
    M.reconcile()
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2, result.n)
end
function M.backend_open(family)
    M.release(family)
    vim.schedule(M.reconcile)
end
local function repair(w, old, incoming)
    local focus = vim.api.nvim_get_current_win()
    local target
    if registry.is_document(incoming) then
        for _, other in ipairs(vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(w))) do
            if other ~= w and M.is_editor_window(other) then target = other; break end
        end
    end
    if target then vim.api.nvim_win_set_buf(target, incoming)
    else target = vim.api.nvim_open_win(incoming, false, { split = 'right', win = w }); clear(target) end
    if vim.api.nvim_buf_is_valid(old.buf) then
        vim.wo[w].winfixbuf = false
        vim.api.nvim_win_set_buf(w, old.buf)
    else
        clear(w)
        if #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(w)) > 1 then vim.api.nvim_win_close(w, false) end
    end
    if focus == w and registry.is_document(incoming) then vim.api.nvim_set_current_win(target) end
end
function M.mark(w)
    if not valid(w) or loading then return end
    if vim.api.nvim_win_get_config(w).relative ~= '' then clear(w); return end
    local b = vim.api.nvim_win_get_buf(w)
    local p, old = registry.policy(b), owned[w]
    if old and old.buf ~= b and old.family ~= p.family and not (depth[old.family] and depth[old.family] > 0) then
        repair(w, old, b); return
    end
    if p.role == 'tool' then
        owned[w] = { family = p.family, buf = b, slot = p.slot, id = p.id }
        vim.w[w].forge_panel, vim.w[w].forge_slot, vim.w[w].forge_component = true, p.slot, p.id
        vim.wo[w].winfixbuf = not (depth[p.family] and depth[p.family] > 0)
        if not mapped[b] then
            mapped[b] = true
            local has_gf = false
            for _, key in ipairs(vim.api.nvim_buf_get_keymap(b, 'n')) do if key.lhs == 'gf' then has_gf = true end end
            if not has_gf then
                vim.keymap.set('n', 'gf', function()
                    M.transition(p.family, function() vim.cmd('normal! gf') end)
                end, { buffer = b, desc = 'Open file in editor' })
            end
        end
    else
        clear(w)
        if p.role == 'editor' then vim.wo[w].winfixwidth, vim.wo[w].winfixheight = false, false end
    end
end
function M.reconcile()
    if busy or loading then return end
    busy = true
    local ok, err = pcall(function()
        for _, w in ipairs(vim.api.nvim_list_wins()) do M.mark(w) end
        for w in pairs(owned) do if not valid(w) then owned[w] = nil end end
    end)
    busy = false
    if not ok then vim.notify('Window ownership: '..tostring(err), vim.log.levels.ERROR) end
end
function M.session_loading(value)
    loading = value
    if value then for w in pairs(owned) do clear(w) end end
end
function M.clean_session()
    for _, w in ipairs(vim.api.nvim_list_wins()) do
        local b = vim.api.nvim_win_get_buf(w)
        if registry.policy(b).lifetime == 'transient' and not vim.bo[b].modified
            and #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(w)) > 1 then vim.api.nvim_win_close(w, false) end
    end
    M.reconcile()
end
function M.setup()
    if M._setup then return end
    M._setup = true
    local group = vim.api.nvim_create_augroup('ForgeWindowOwnership', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufWinEnter', 'FileType', 'WinEnter' }, { group = group, callback = function() vim.schedule(M.reconcile) end })
    -- The core has already authorized a buffer leave (or an explicit bang).
    -- Do not obstruct native backend cleanup inside its BufEnter handlers.
    vim.api.nvim_create_autocmd('BufLeave', { group = group, callback = function()
        local w = vim.api.nvim_get_current_win()
        if owned[w] then vim.wo[w].winfixbuf = false; vim.schedule(M.reconcile) end
    end })
    for _, w in ipairs(vim.api.nvim_list_wins()) do known[w] = true end
    vim.api.nvim_create_autocmd('WinNew', { group = group, callback = function()
        for _, w in ipairs(vim.api.nvim_list_wins()) do if not known[w] then known[w] = true; clear(w) end end
    end })
    vim.api.nvim_create_autocmd('WinClosed', { group = group, callback = function(ev)
        local w = tonumber(ev.match); owned[w], known[w] = nil, nil
    end })
    vim.api.nvim_create_autocmd('BufWipeout', { group = group, callback = function(ev) mapped[ev.buf] = nil end })
    vim.api.nvim_create_autocmd('SessionLoadPre', { group = group, callback = function()
        if vim.g.SessionLoad == 1 then M.session_loading(true) end
    end })
    vim.api.nvim_create_autocmd('SessionLoadPost', { group = group, callback = function()
        -- :loadview fires this event too. Only a native :mksession script sets
        -- SessionLoad; loading a cursor/fold view must not close any windows.
        if vim.g.SessionLoad == 1 then M.session_loading(false); vim.schedule(M.clean_session) end
    end })
    vim.api.nvim_create_autocmd('CmdlineLeave', { group = group, callback = function()
        if vim.fn.getcmdtype() ~= ':' or vim.v.event.abort then return end
        local ok, cmd = pcall(vim.api.nvim_parse_cmd, vim.fn.getcmdline(), {})
        if not ok or not ({ edit=true, enew=true, buffer=true, bnext=true, bprevious=true, find=true,
            split=true, vsplit=true, sfind=true, sbuffer=true })[cmd.cmd] then return end
        local current = vim.api.nvim_get_current_win()
        if owned[current] then require('ide.buffers').focus_editor() end
    end })
    vim.api.nvim_create_autocmd('User', { group = group, pattern = 'PersistenceLoadPost', callback = function()
        M.session_loading(false); vim.schedule(M.clean_session)
    end })
    M.reconcile()
end
return M
