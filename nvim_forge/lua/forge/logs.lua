-- spec: IDE-LOG-1/2/3/4. Один readonly buffer, обычный IDE bottom slot.
local M={source='events',minimum=0,query=''}
local store=require('forge.log_store')
local names={[0]='TRACE',[1]='DEBUG',[2]='INFO',[3]='WARN',[4]='ERROR',[5]='OFF'}
local details={}
local function valid() return M.buf and vim.api.nvim_buf_is_valid(M.buf) end
local function source_list()
    local out=require('forge.log_sources').list()
    local seen={}
    for _,entry in ipairs(store.entries()) do
        if not seen[entry.source] then
            seen[entry.source]=true
            out[#out+1]={id='events:'..entry.source,title='Сообщения / '..entry.source,group=entry.source}
        end
    end
    return out
end
local function selected()
    for _,source in ipairs(source_list()) do if source.id==M.source then return source end end
    return {id=M.source,title=M.source,hint='Источник больше недоступен'}
end
local function match(text,level)
    return (M.minimum==0 or level and level>=M.minimum)
        and text:lower():find(M.query:lower(),1,true)~=nil
end
function M.refresh()
    if not valid() then return end
    local source=selected()
    local lines={'IDE Logs | '..source.title,
        'Уровень: '..(M.minimum==0 and 'ALL' or names[M.minimum])..' | Фильтр: '..M.query,
        's источник · f текст · v уровень · c сброс · r обновить · Enter детали · y отчёт · H health',
        'История: последние200 сообщений / 8 завершённых сессий + активные; по2×128KiB на сессию',
        'Сессия: '..store.session,'Хранение: '..store.path}
    if store.disk_error then lines[#lines+1]='Ошибка хранения: '..store.clean(store.disk_error) end
    lines[#lines+1]='Native :messages: снимок при открытии/r/старте/выходе; timestamp — время снимка.'
    if store.capture_error then lines[#lines+1]='Native history недоступна: '..store.clean(store.capture_error) end
    if store.damaged and store.damaged>0 then lines[#lines+1]='Повреждённые строки истории: '..store.damaged end
    if store.dropped or store.rotated or store.history_truncated then lines[#lines+1]='Старые сообщения ограничены лимитом хранения/просмотра.' end
    details={}
    local count=0
    if source.id=='events' or source.group then
        lines[#lines+1]=''
        local previous
        for _,entry in ipairs(store.entries()) do
            if (not source.group or source.group==entry.source) and match(entry.message,entry.level) then
                if previous~=entry.session then lines[#lines+1]='── Сессия '..entry.session..' ──';previous=entry.session end
                local body=vim.split(entry.message,'\n',{plain=true})
                lines[#lines+1]=os.date('%H:%M:%S',entry.time)..' '..(names[entry.level] or 'UNKNOWN')..' ['..entry.source..'] '..body[1]
                details[#lines]={os.date('%Y-%m-%d %H:%M:%S',entry.time)..' '..entry.source,'Сессия: '..entry.session,'',unpack(body)}
                for i=2,#body do lines[#lines+1]='  '..body[i] end
                count=count+1
            end
        end
    else
        local data=require('forge.log_sources').read(source)
        lines[#lines+1]='Источник: '..data.status
        if data.path then lines[#lines+1]='Путь: '..store.clean(data.path) end
        if data.mtime then lines[#lines+1]='Изменён: '..data.mtime end
        lines[#lines+1]='Хвост источника: до64KiB / output до500 строк'..(data.truncated and ' [truncated]' or '')
        lines[#lines+1]='Нераспознанный уровень: UNKNOWN; такие строки видны в ALL.'
        if data.hint then lines[#lines+1]=data.hint end
        lines[#lines+1]=''
        for _,raw in ipairs(data.lines) do
            local text=store.clean(raw)
            local tag=text:match('^%[?(%u+)%]?[%s:]')
            local level=tag and vim.log.levels[tag]
            if match(text,level) then lines[#lines+1]=text;count=count+1 end
        end
    end
    if count==0 then lines[#lines+1]=(M.query~='' or M.minimum>0) and 'Нет совпадений по фильтру.' or 'Сообщений пока нет.' end
    -- Native logs не копируются в recorder. Report содержит только выбранный view.
    local views={}
    for _,win in ipairs(vim.fn.win_findbuf(M.buf)) do views[win]=vim.api.nvim_win_call(win,vim.fn.winsaveview) end
    vim.bo[M.buf].modifiable=true
    vim.api.nvim_buf_set_lines(M.buf,0,-1,false,lines)
    vim.bo[M.buf].modifiable=false
    for win,view in pairs(views) do vim.api.nvim_win_call(win,function() vim.fn.winrestview(view) end) end
end

-- spec: IDE-LOG-5. Native open уже поставил Edgy update в очередь.
function M.restore_view(view,done)
    local win
    for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_buf(w)==M.buf then win=w;break end
    end
    vim.schedule(function()
        local ok,err=pcall(function()
            assert(win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win)==M.buf,'Logs view window changed')
            local edge=assert(require('edgy').get_win(win),'Logs view is not registered in Edgy')
            local height=math.max(1,math.floor(view.height*math.min(1,vim.o.lines/view.lines)+0.5))
            edge:resize('height',height-vim.api.nvim_win_get_height(win))
            vim.api.nvim_win_call(win,function() vim.fn.winrestview(view.view) end)
        end)
        done(not ok and err or nil)
    end)
end

function M.visible()
    if not valid() then return false end
    for _,win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do if vim.api.nvim_win_get_buf(win)==M.buf then return true end end
    return false
end
function M.close()
    for _,win in ipairs(valid() and vim.fn.win_findbuf(M.buf) or {}) do
        if vim.api.nvim_win_get_tabpage(win)==vim.api.nvim_get_current_tabpage() then vim.api.nvim_win_close(win,true) end
    end
end
local function choose_source()
    local sources=source_list()
    vim.ui.select(sources,{prompt='IDE Logs: источник',format_item=function(item)
        if item.path then
            local status=vim.uv.fs_stat(item.path) and 'файл есть' or item.disabled and 'отключён' or 'не найден'
            return item.title..' ['..status..']'
        end
        return item.title
    end},function(item) if item then M.source=item.id;M.refresh() end end)
end
function M.open()
    store.snapshot_messages()
    if not valid() then
        M.buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_name(M.buf,'forge://ide-logs')
        vim.bo[M.buf].bufhidden='hide';vim.bo[M.buf].swapfile=false;vim.bo[M.buf].filetype='forge-logs'
        local maps={s=choose_source,r=function() store.snapshot_messages();store.reload();M.refresh() end,
            v=function() M.minimum=({[0]=3,[3]=4,[4]=0})[M.minimum] or 0;M.refresh() end,
            c=function() M.query='';M.minimum=0;M.refresh() end,
            f=function() vim.ui.input({prompt='IDE Logs: текст > ',default=M.query},function(query)
                if query~=nil then M.query=query;M.refresh() end
            end) end,
            y=function()
                local report=store.clean(table.concat(vim.api.nvim_buf_get_lines(M.buf,0,-1,false),'\n'))
                vim.fn.setreg('"',report)
                if vim.fn.has('clipboard')==1 or vim.g.clipboard then pcall(vim.fn.setreg,'+',report) end
            end,
            H=function() require('ide.controls').focus_code();vim.cmd('checkhealth forge') end,
            ['<CR>']=function()
                require('ide.controls').restore(true)
                local body=details[vim.api.nvim_win_get_cursor(0)[1]]
                if not body then return end
                local b,w=vim.lsp.util.open_floating_preview(body,'text',{border='rounded',focus=true,focusable=true})
                vim.api.nvim_set_current_win(w)
                for _,key in ipairs({'q','<Esc>'}) do vim.keymap.set('n',key,function()
                    if vim.api.nvim_win_is_valid(w) then vim.api.nvim_win_close(w,true) end
                end,{buffer=b,nowait=true}) end
            end}
        for key,action in pairs(maps) do vim.keymap.set('n',key,action,{buffer=M.buf,silent=true,desc='IDE Logs: '..key}) end
    end
    M.refresh()
    if not M.visible() then vim.cmd('botright 12split');vim.api.nvim_win_set_buf(0,M.buf) end
    require('ide.controls').work_maps(M.buf)
end
function M.setup()
    store.setup()
    store.changed=function() if M.visible() then M.refresh() end end
    vim.api.nvim_create_user_command('ForgeLogs',function(args)
        store.snapshot_messages()
        if args.args~='' then M.source=args.args end
        require('ide.controls').logs()
        M.refresh() -- уже видимая панель не вызывает component.open повторно
    end,{nargs='?',desc='IDE Logs: общая консоль и native источники',complete=function()
        local out={};for _,source in ipairs(source_list()) do out[#out+1]=source.id end;return out
    end})
end
return M
