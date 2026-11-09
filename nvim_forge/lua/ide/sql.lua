-- spec: IDE-SQL-3. SQL Results — обычный bottom component, без запуска SQL.
local M={}
local views={}
local function view()
    local tab=vim.api.nvim_get_current_tabpage()
    views[tab]=views[tab] or {records={}}
    return views[tab],tab
end
function M.root() return view().root end
local function window()
    for _,win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(win)].filetype=='forge-sql' then return win end
    end
end
function M.is_open() return window()~=nil end
local function buffer(v)
    if not v.buf or not vim.api.nvim_buf_is_valid(v.buf) then
        v.buf=vim.api.nvim_create_buf(false,true)
        vim.bo[v.buf].bufhidden='hide';vim.bo[v.buf].swapfile=false
        vim.bo[v.buf].filetype='forge-sql';vim.bo[v.buf].modifiable=false
    end
    return v.buf
end
local function render(v)
    local record=v.record or {label='SQL',source=v.root or '',status='Нет результатов'}
    local buf=buffer(v)
    local lines={'SQL Results | '..record.label,'Source: '..record.source,'Status: '..record.status,''}
    vim.list_extend(lines,vim.split(record.output or '', '\n',{plain=true}))
    vim.bo[buf].modifiable=true
    vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
    vim.bo[buf].modifiable=false
end
-- spec: IDE-SQL-6. Выбор обновляет buffer даже у уже видимого component:
-- общий ide.show в этом случае намеренно не вызывает open повторно.
function M.select(root)
    local v=view();v.root=root;v.record=v.records[root]
    render(v)
end
function M.open()
    local v=view();render(v)
    if window() then return end
    vim.api.nvim_open_win(v.buf,false,{split='below',win=require('ide').find_main_window(),height=12})
end
function M.close()
    local win=window();if win then vim.api.nvim_win_close(win,true) end
end
function M.focus()
    local win=window();if win then vim.api.nvim_set_current_win(win) end
end
function M.update(tab,root,record,activate)
    if not vim.api.nvim_tabpage_is_valid(tab) then return end
    views[tab]=views[tab] or {records={}};local v=views[tab]
    v.records[root]=record
    if activate then v.root=root end
    if v.root==root then v.record=record;render(v) end
    -- Callback обновляет скрытый buffer, не открывает его снова и не
    -- перехватывает фокус/выбранный workspace в другом tab.
    if activate and tab==vim.api.nvim_get_current_tabpage() then require('ide').show('sql.results') end
end
return M
