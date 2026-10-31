-- spec: IDE-SNIP-1 отмена только нетронутых параметров принятого вызова.
local M = {}
local states, attached = {}, {}
local pending
local ns = vim.api.nvim_create_namespace('ForgeSnippetInput')

local function le(a, b)
    return a[1] < b[1] or (a[1] == b[1] and a[2] <= b[2])
end

local function contains(range, pos)
    return range and le(range[1], pos) and le(pos, range[2])
end

-- Граница pinned LuaSnip: User events документированы, mark.id/session.ns_id
-- внутренние. Держим доступ здесь и проверяем настоящим editor E2E.
local function range(node, buf)
    if not node or not node.mark then return end
    -- LuaSnip Mark читает buf=0. on_bytes может прийти из другого буфера.
    local ok, mark = pcall(vim.api.nvim_buf_get_extmark_by_id,
        buf or 0, require('luasnip').session.ns_id, node.mark.id, { details = true })
    if ok and #mark > 0 then return { { mark[1], mark[2] }, { mark[3].end_row, mark[3].end_col } } end
end

local function text(node)
    local ok, value = pcall(node.get_text, node)
    if ok and value then return table.concat(value, '\n') end
end

local function root(node)
    while node and node.parent do node = node.parent end
    return node
end

-- Не разбираем язык или LSP syntax повторно: только уже развёрнутые простые
-- insert-узлы вызова. Блоки, choices, mirrors/dynamic/nested nodes не удаляем.
local function signature(snip)
    local types = require('luasnip.util.types')
    local params, prefix, suffix = {}, nil, nil
    local want_param = false
    for _, node in ipairs(snip.nodes) do
        if node.type == types.exitNode or node.pos == 0 then
            -- Финальный $0 не содержит предложения.
        elseif suffix then
            return
        elseif node.type == types.insertNode then
            if not want_param then return end
            params[#params + 1] = node
            want_param = false
        elseif node.type == types.textNode then
            local value = text(node)
            if not value then return end
            if not prefix then
                if not value:match('^[^%s%(%){};,]+%(%s*$') then return end
                prefix = node
                want_param = true
            elseif value:match('^%s*,%s*$') and not want_param then
                want_param = true
            elseif value:match('^%s*%)$') and not want_param then
                suffix = node
            else
                return
            end
        else
            return
        end
    end
    if prefix and suffix and #params > 0 then return params, prefix, suffix end
end

local function refresh(state)
    for _, item in ipairs(state.params) do item.range = range(item.node, state.buf) end
end

local function watch(buf)
    if attached[buf] then return end
    attached[buf] = vim.api.nvim_buf_attach(buf, false, {
        on_bytes = function(_, _, _, row, col, _, old_rows, old_cols)
            local state = states[buf]
            if not state then return end
            local first = { row, col }
            local last = { row + old_rows, old_rows == 0 and col + old_cols or old_cols }
            if not require('luasnip').session.jump_active then
                for _, item in ipairs(state.params) do
                    local r = item.range
                    if r and le(first, r[2]) and le(r[1], last) then item.changed = true end
                end
            end
            refresh(state)
        end,
        on_detach = function() states[buf], attached[buf] = nil, nil end,
    })
end

-- Вызывается командой в typeahead ПЕРЕД исходным ручным символом.
function M.cancel()
    local state = pending
    pending = nil
    local buf = vim.api.nvim_get_current_buf()
    if not state or states[buf] ~= state then return end
    states[buf] = nil
    local ls = require('luasnip')
    if ls.get_active_snip() ~= state.snip then return end
    local params, prefix, suffix = signature(state.snip)
    local edits, kept = {}, {}
    local cursor = vim.api.nvim_win_get_cursor(0)
    local pos = { cursor[1] - 1, cursor[2] }
    if params then
        for i, item in ipairs(state.params) do
            local r, value = range(item.node), text(item.node)
            -- Повреждённые marks: можно unlink, нельзя угадывать область удаления.
            if not r or not value then params = nil; break end
            item.range = r
            local untouched = not item.changed and value == item.default
            kept[i] = not untouched or contains(r, pos)
            if untouched and kept[i] then edits[#edits + 1] = r end
        end
    end
    if params then
        local i = 1
        while i <= #state.params do
            if kept[i] then
                i = i + 1
            else
                local first = i
                while i <= #state.params and not kept[i] do i = i + 1 end
                local from, to = state.params[first].range[1], state.params[i - 1].range[2]
                if first > 1 then from = state.params[first - 1].range[2]
                elseif i <= #state.params then to = state.params[i].range[1]
                else
                    -- Все параметры отменены: удаляем и whitespace внутри (...).
                    local p, s = range(prefix), range(suffix)
                    if not p or not s then edits = {}; break end
                    local head = text(prefix):match('^(.-)%(')
                    from = { p[1][1], p[1][2] + #head + 1 }
                    to = { s[2][1], s[2][2] - 1 }
                end
                edits[#edits + 1] = { from, to }
            end
        end
    else
        edits = {}
    end
    local cursor_mark = vim.api.nvim_buf_set_extmark(buf, ns, pos[1], pos[2], { right_gravity = false })
    ls.unlink_current()
    table.sort(edits, function(a, b) return not le(a[1], b[1]) end)
    for i, edit in ipairs(edits) do
        if i > 1 then vim.cmd('undojoin') end
        vim.api.nvim_buf_set_text(buf, edit[1][1], edit[1][2], edit[2][1], edit[2][2], {})
    end
    local restored = vim.api.nvim_buf_get_extmark_by_id(buf, ns, cursor_mark, {})
    vim.api.nvim_buf_del_extmark(buf, ns, cursor_mark)
    vim.api.nvim_win_set_cursor(0, { restored[1] + 1, restored[2] })
end

function M.setup()
    local group = vim.api.nvim_create_augroup('ForgeSnippetInput', { clear = true })
    vim.api.nvim_create_autocmd('User', {
        group = group,
        pattern = { 'LuasnipInsertNodeEnter', 'LuasnipExitNodeEnter' },
        callback = function()
            local node = require('luasnip').session.event_node
            local buf, snip = vim.api.nvim_get_current_buf(), root(node)
            if node.pos == 0 then states[buf] = nil; return end
            local state = states[buf]
            if not state or state.snip ~= snip then
                local params = signature(snip)
                if not params then states[buf] = nil; return end
                state = { snip = snip, params = {}, buf = buf }
                for _, param in ipairs(params) do
                    state.params[#state.params + 1] = { node = param, default = text(param) }
                end
                states[buf] = state
                watch(buf)
            end
            state.active = node
            refresh(state)
        end,
    })
    vim.api.nvim_create_autocmd('InsertCharPre', {
        group = group,
        callback = function()
            local state = states[vim.api.nvim_get_current_buf()]
            if not state or pending then return end
            local ls = require('luasnip')
            if ls.get_active_snip() ~= state.snip then states[vim.api.nvim_get_current_buf()] = nil; return end
            local cursor = vim.api.nvim_win_get_cursor(0)
            if contains(range(state.active), { cursor[1] - 1, cursor[2] }) then return end
            pending = state
            local char = vim.v.char
            vim.v.char = ''
            local keys = vim.api.nvim_replace_termcodes(
                "<C-g>u<Cmd>lua require('forge.snippet_input').cancel()<CR>" .. char, true, false, true)
            vim.api.nvim_feedkeys(keys, 'in', false)
        end,
    })
end

return M
