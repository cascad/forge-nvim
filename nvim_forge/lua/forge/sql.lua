-- spec: IDE-SQL-1/2/4. Общая SQL граница без установки tools на старте.
local M={}
local versions={}
M.selected={}
local sessions={}
local stopping={}
local lifetimes=setmetatable({},{__mode='k'})
local function stop(client)
    stopping[client.id]=true
    if lifetimes[client.rpc] then lifetimes[client.rpc].expected=true end
    client:stop(true)
end
local function warn(message) vim.notify(message,vim.log.levels.WARN,{title='SQL'}) end
function M.tool(name)
    local explicit=vim.g['forge_'..name..'_executable'] or vim.env['FORGE_'..name:upper()..'_EXECUTABLE']
    if explicit and explicit~='' then return vim.fn.executable(explicit)==1 and vim.fn.exepath(explicit) or nil end
    local path=vim.fn.exepath(name)
    return path~='' and path or nil
end
function M.root(path)
    path=path and path~='' and path or vim.api.nvim_buf_get_name(0)
    if path=='' then return vim.fn.getcwd() end
    return vim.fs.root(path,{'.sqls.json'}) or vim.fs.root(path,{'.git'}) or vim.fs.dirname(path)
end
function M.profiles(root)
    local path=vim.g.forge_sql_config or vim.env.FORGE_SQL_CONFIG or root..'/.sqls.json'
    local ok,data=pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end)
    if not ok then return nil,'SQL: подготовь .sqls.json с connections или задай FORGE_SQL_CONFIG.' end
    if type(data)~='table' or not vim.islist(data.connections) or #data.connections==0 then return nil,'SQL: в .sqls.json нужен непустой connections.' end
    return data.connections
end
function M.connection(root)
    local profiles,err=M.profiles(root);if not profiles then return nil,err end
    local conn=profiles[M.selected[root] or 1]
    if type(conn)~='table' or type(conn.driver)~='string' then return nil,'SQL: connection не содержит driver.' end
    if conn.driver=='sqlite3' then
        local dsn=conn.dataSourceName or ''
        if type(dsn)~='string' or dsn=='' then return nil,'SQL: SQLite connection требует dataSourceName.' end
        if dsn~=':memory:' and not dsn:find('mode=memory',1,true) and not dsn:find('file::memory:',1,true) then
            local uri=dsn:sub(1,5)=='file:'
            local path=(uri and dsn:sub(6) or dsn):match('^[^?]*')
            if uri and path:sub(1,2)=='//' then path=vim.uri_to_fname('file:'..path)
            elseif uri then path=path:gsub('%%(%x%x)',function(code) return string.char(tonumber(code,16)) end) end
            if not path:match('^[/\\]') and not path:match('^%a:[/\\]') then path=vim.fs.joinpath(root,path) end
            if vim.fn.filereadable(path)~=1 then return nil,'SQL: SQLite файл не найден: '..vim.fs.basename(path)..'. Проверь .sqls.json.' end
        end
    end
    return vim.deepcopy(conn)
end
function M.version(path,callback)
    local stat=vim.uv.fs_stat(path)
    if not stat then callback(nil);return end
    local stamp=table.concat({stat.size,stat.mtime.sec,stat.mtime.nsec},':')
    local entry=versions[path]
    if entry and entry.stamp==stamp then
        if entry.done then callback(entry.value) else entry.waiters[#entry.waiters+1]=callback end
        return
    end
    entry={stamp=stamp,waiters={callback}};versions[path]=entry
    vim.system({path,'-version'},{text=true,timeout=2000},function(result)
        entry.value=result.code==0 and (result.stdout or ''):match('Version:%s*([%d%.]+)') or nil
        entry.done=true
        vim.schedule(function() for _,fn in ipairs(entry.waiters) do fn(entry.value) end;entry.waiters={} end)
    end)
end
function M.known_version(path) return versions[path] and versions[path].value end
function M.dialect_args(path)
    local explicit=vim.g.forge_sql_dialect or vim.env.FORGE_SQL_DIALECT
    if explicit and explicit~='' then return {'--dialect',explicit} end
    local dir=vim.fn.isdirectory(path)==1 and path or vim.fs.dirname(path)
    if vim.fs.find({'.sqruff','.sqlfluff'},{path=dir,upward=true})[1] then return {} end
    return {'--dialect','ansi'}
end
function M.formatter()
    return {command=function() return M.tool('sqruff') or '__missing_sqruff__' end,
        args=function(_,ctx)
            return vim.list_extend({'fix','--quiet'},vim.list_extend(M.dialect_args(ctx.filename),{'$FILENAME'}))
        end}
end
function M.setup_lsp()
    local on_exit=vim.lsp.config.sqls.on_exit
    vim.lsp.config('sqls',{
        on_exit=function(code,signal,id)
            if stopping[id] then stopping[id]=nil;return end
            if on_exit then on_exit(code,signal,id) end
        end,
        root_dir=function(buf,on_dir)
            local root=M.root(vim.api.nvim_buf_get_name(buf));local path=M.tool('sqls')
            if path and M.connection(root) then M.version(path,function() on_dir(root) end) end
        end,
        before_init=function(params,config)
            params.initializationOptions={connectionConfig=assert(M.connection(config.root_dir))}
        end,
        cmd=function(dispatchers,config)
            local path=assert(M.tool('sqls'))
            local lifetime={}
            local handlers=vim.tbl_extend('force',dispatchers,{on_exit=function(code,signal)
                -- Windows forced terminate возвращает exit=1/signal=15.
                -- Отмечаем только наш SQLStop/Connect, до native LSP crash UI.
                if lifetime.expected then code,signal=0,0 end
                dispatchers.on_exit(code,signal)
            end})
            local rpc=require('forge.sql_protocol').rpc(vim.lsp.rpc.start({path},handlers,{cwd=config.root_dir}),M.known_version(path))
            lifetimes[rpc]=lifetime
            return rpc
        end,
        on_init=function(client) require('forge.sql_protocol').initialized(client,M.known_version(M.tool('sqls'))) end,
    })
    require('forge.sql_diagnostics').setup()
    vim.lsp.enable('sqls')
end
local function context()
    local buf=vim.api.nvim_get_current_buf()
    if vim.bo[buf].filetype=='forge-sql' then
        return vim.api.nvim_win_get_buf(require('ide').find_main_window()),require('ide.sql').root()
    end
    if vim.bo[buf].filetype~='sql' then return nil,nil,'SQL: открой SQL файл.' end
    return buf,M.root(vim.api.nvim_buf_get_name(buf))
end
local function clients(root)
    return vim.tbl_filter(function(c) return c.root_dir==root and not stopping[c.id] and not c:is_stopped() end,vim.lsp.get_clients({name='sqls'}))
end
local function session(root)
    sessions[root]=sessions[root] or {generation=0}
    return sessions[root]
end
local function label(root)
    local profiles=M.profiles(root);local conn=profiles and profiles[M.selected[root] or 1]
    return conn and (conn.alias or ('Connection '..(M.selected[root] or 1))) or 'SQL'
end
local function ensure(buf,root,active,callback)
    local path=M.tool('sqls')
    if not path then callback(nil,'SQL: установи sqls явно и проверь PATH / FORGE_SQLS_EXECUTABLE.');return end
    local conn,err=M.connection(root);if not conn then callback(nil,err);return end
    M.version(path,function()
        if not active() then return end
        local client=clients(root)[1]
        if not client then
            local config=vim.deepcopy(vim.lsp.config.sqls)
            config.root_dir=root;config.name='sqls'
            local id=vim.lsp.start(config,{bufnr=buf,reuse_client=function(c)
                return c.name=='sqls' and c.root_dir==root and not stopping[c.id] and not c:is_stopped()
            end})
            client=id and vim.lsp.get_client_by_id(id)
        else vim.lsp.buf_attach_client(buf,client.id) end
        local deadline=vim.uv.hrtime()+15000000000
        local function ready()
            if not active() then return end
            if not client or client:is_stopped() then callback(nil,'SQL: backend не запустился; проверь подключение и :LspLog.');return end
            if client.initialized then callback(client);return end
            if vim.uv.hrtime()>deadline then callback(nil,'SQL: подключение не готово; проверь БД или вызови SQLStop.');return end
            vim.defer_fn(ready,100)
        end
        ready()
    end)
end
function M.run(text)
    local buf,root,err=context();if not buf or not root then warn(err or 'SQL: нет workspace.');return end
    local s=session(root)
    if s.running then warn('SQL: запрос уже выполняется; SQLStop остановит session.');return end
    if not M.tool('sqls') then warn('SQL: установи sqls явно и проверь PATH / FORGE_SQLS_EXECUTABLE.');return end
    local conn,why=M.connection(root);if not conn then warn(why);return end
    local snapshot=text or table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n')
    if vim.trim(snapshot)=='' then warn('SQL: пустой запрос.');return end
    s.generation=s.generation+1;local generation=s.generation;s.running=true
    local tab=vim.api.nvim_get_current_tabpage()
    local record={label=label(root),source=vim.api.nvim_buf_get_name(buf)..(text and ' [selection]' or ' [buffer]'),status='Running'}
    s.record=record;s.tab=tab
    require('ide.sql').update(tab,root,record,true)
    local function active() return s.generation==generation end
    local function finish(error,result)
        if not active() then return end
        s.running=false;record.status=error and 'Error' or 'Done'
        record.output=error and (type(error)=='table' and error.message or tostring(error)) or tostring(result or '')
        require('ide.sql').update(tab,root,record)
    end
    ensure(buf,root,active,function(client,error)
        if not client then finish(error);return end
        -- Только didOpen/didClose: snapshot не создаёт файл и не меняется
        -- вместе с исходным buffer. Statement parsing выполняет backend.
        local uri=vim.uri_from_fname(vim.fn.tempname()..'.sql')
        client:notify('textDocument/didOpen',{textDocument={uri=uri,languageId='sql',version=1,text=snapshot}})
        local sent=client:request('workspace/executeCommand',{command='executeQuery',arguments={uri}},function(error,result)
            if not client:is_stopped() then client:notify('textDocument/didClose',{textDocument={uri=uri}}) end
            finish(error,result)
        end,buf)
        if not sent then finish('SQL: запрос не отправлен.');return end
    end)
end
function M.run_visual()
    local mode=vim.fn.mode()
    local text=table.concat(vim.fn.getregion(vim.fn.getpos('v'),vim.fn.getpos('.'),{type=mode}), '\n')
    vim.cmd('normal! \27')
    M.run(text)
end
function M.stop()
    local _,root,err=context();if not root then warn(err or 'SQL: нет workspace.');return end
    local s=session(root);s.generation=s.generation+1;s.running=false
    for _,client in ipairs(clients(root)) do stop(client) end
    if s.record then s.record.status='Stopped';s.record.output=(s.record.output or '')..'\nSQL session остановлена.';require('ide.sql').update(s.tab,root,s.record) end
end
function M.connect()
    local buf,root,err=context();if not root then warn(err);return end
    local profiles,why=M.profiles(root);if not profiles then warn(why);return end
    local choices={};for i,conn in ipairs(profiles) do choices[i]={index=i,label=(conn.alias or ('Connection '..i))..' ['..tostring(conn.driver)..']'} end
    require('lazy').load({plugins={'telescope.nvim'}})
    vim.ui.select(choices,{prompt='SQL connection',format_item=function(item) return item.label end},function(item)
        if not item then return end
        local previous=M.selected[root];M.selected[root]=item.index
        local conn,error=M.connection(root);if not conn then M.selected[root]=previous;warn(error);return end
        local s=session(root);s.generation=s.generation+1;s.running=false
        for _,client in ipairs(clients(root)) do stop(client) end
        local generation=s.generation
        ensure(buf,root,function() return s.generation==generation end,function(client,issue)
            if not client then warn(issue);return end
            for _,b in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype=='sql' and M.root(vim.api.nvim_buf_get_name(b))==root then vim.lsp.buf_attach_client(b,client.id) end
            end
            vim.notify('SQL: '..label(root),vim.log.levels.INFO)
        end)
    end)
end
function M.results()
    local _,root=context()
    if root then require('ide.sql').select(root) end
    require('ide.controls').sql_results()
end
function M.setup()
    vim.api.nvim_create_user_command('SQLRun',function(args)
        M.run(args.range>0 and table.concat(vim.api.nvim_buf_get_lines(0,args.line1-1,args.line2,false),'\n') or nil)
    end,{range=true,desc='SQL: run buffer or selected lines'})
    for name,fn in pairs({SQLConnect=M.connect,SQLResults=M.results,SQLStop=M.stop}) do vim.api.nvim_create_user_command(name,fn,{}) end
    vim.keymap.set('n','<leader>jq',function() M.run() end,{desc='SQL: run buffer'})
    vim.keymap.set('x','<leader>jq',M.run_visual,{desc='SQL: run exact selection'})
    vim.keymap.set('n','<leader>jc',M.connect,{desc='SQL: connection'})
    vim.keymap.set('n','<leader>jo',M.results,{desc='SQL: results'})
    vim.keymap.set('n','<leader>jx',M.stop,{desc='SQL: stop session'})
end
return M
