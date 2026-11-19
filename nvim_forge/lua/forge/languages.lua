-- IDE-BOOT-50/51. Passive first-file notice and persistent native environment UI.
local M={seen={},versions={},results={},components={},active=nil}
local join=vim.fs.joinpath
local titles={go='Go',rust='Rust',python='Python',node='JS / Node',bash='Bash',sql='SQL'}
local ordered={'go','rust','python','node','bash','sql'}
local filetypes={go='go',rust='rust',python='python',javascript='node',typescript='node',
    javascriptreact='node',typescriptreact='node',sh='bash',bash='bash',sql='sql'}
local function root(path) return require('forge.tool_paths').root(path) end
local function key(kind,directory) return directory..'\n'..kind end
local function notice(text,level)
    vim.notify(text,level or vim.log.levels.INFO,{title='Языки и инструменты'})
end
local function log(text,level) require('forge.log_store').record(text,level or vim.log.levels.INFO,'Languages') end
local function read(file)
    local stat=vim.uv.fs_stat(file);assert(stat and stat.type=='file' and stat.size<=1048576,'Invalid report: '..file)
    local f=assert(io.open(file,'rb'));local data=f:read('*a');f:close();return vim.json.decode(data)
end
local function sdk(kind,directory)
    local backend=(kind=='go' or kind=='rust') and require('forge.sdk') or require('forge.runtime_sdk')
    local ok,value=pcall(function()
        local choice=backend.choice(kind,directory)
        if choice.error then error(choice.error,0) end
        local path,source
        if kind=='go' or kind=='rust' then
            local selected=backend.selection(kind,directory)
            path=selected and selected.tools[kind=='rust' and 'rustc' or 'go'] or vim.fn.exepath(kind=='rust' and 'rustc' or 'go')
            source=choice.source
        else
            path=choice.value~='auto' and choice.value or nil;source=choice.source
        end
        if not path or path=='' then return {kind=kind,ready=false,source=source} end
        local location=backend.location(kind,(kind=='go' or kind=='rust') and vim.fs.dirname(path) or path)
        local cached=M.versions[location.executable]
        return {kind=kind,path=location.executable,source=source,ready=not (cached and cached.error),
            version=cached and cached.version,error=cached and cached.error}
    end)
    if not ok then return {kind=kind,ready=false,error=tostring(value),configuration_error=true} end
    return value
end
local function tools(kind,directory)
    local profile=require('forge.install_profile')
    local core={};for _,name in ipairs(profile.filter({},4,'core')) do core[name]=true end
    local result={}
    for _,name in ipairs(profile.filter({},4,'core,'..kind)) do
        if not core[name] then
            local external,entry=pcall(require('forge.setup_tools').external,name,{scope='project'})
            local ok,value
            if not external then ok=false;value=entry
            elseif entry then ok=true;value={source=entry.source,path=entry.path}
            else ok,value=pcall(require('forge.setup_readiness').local_tool,name,nil,{preserve_versions=true}) end
            result[#result+1]={name=name,ready=ok,source=ok and value.source or nil,path=ok and value.path or nil,
                version=ok and value.version or nil,error=not ok and tostring(value) or nil}
        end
    end
    if kind=='rust' then
        local ok,path=pcall(require('forge.nextest').executable,directory)
        result[#result+1]={name='cargo-nextest',ready=ok and path~=nil,path=ok and path or nil,error=not ok and tostring(path) or nil,source='Rust tool'}
        local valid,pathfmt=pcall(require('forge.tool_paths').executable,'rustfmt',{root=directory})
        result[#result+1]={name='rustfmt',ready=valid and pathfmt~=nil,path=valid and pathfmt or nil,error=not valid and tostring(pathfmt) or nil,source='Rust SDK'}
    end
    return result
end
function M.status(kind,directory)
    assert(titles[kind],'Unknown language');directory=root(directory)
    local state={kind=kind,title=titles[kind],root=directory,sdks={},tools={},ready=true,available=0}
    for _,required in ipairs(require('forge.install_profile').sdk_kinds(kind)) do
        local entry=sdk(required,directory);state.sdks[#state.sdks+1]=entry
        if not entry.ready then state.ready=false end
        if entry.error then state.error=entry.error end
        if entry.configuration_error then state.settings_error=entry.error end
    end
    state.tools=tools(kind,directory)
    for _,tool in ipairs(state.tools) do if tool.ready then state.available=state.available+1 else state.ready=false end end
    local ok,policy=pcall(require('forge.language_settings').get,kind,directory)
    state.policy=ok and policy or {value='manual',source='ERROR',error=tostring(policy)}
    if not ok then state.error=tostring(policy) end
    state.prepared=M.results[key(kind,directory)]
    state.components=M.components[key(kind,directory)]
    if state.components and not state.components.ready then state.ready=false end
    return state
end
function M.recheck(kind,directory,callback)
    directory=root(directory);local state=M.status(kind,directory)
    local pending=0
    for _,entry in ipairs(state.sdks) do if entry.path then pending=pending+1 end end
    local function complete()
        if kind~='rust' then if callback then callback(M.status(kind,directory)) end;return end
        -- Explicit recheck only: the first-file hook never starts a CLI probe.
        local folder=join(vim.fn.stdpath('state'),'language-checks');vim.fn.mkdir(folder,'p')
        local report=join(folder,tostring(vim.uv.hrtime())..'.json')
        local script=join(vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':h:h:h'),'scripts/check-rust-components.lua')
        local entry=M.status(kind,directory).sdks[1]
        if not entry or not entry.path then if callback then callback(M.status(kind,directory)) end;return end
        vim.system({vim.v.progpath,'--headless','-u','NONE','-i','NONE','-l',script,entry.path,report,'project'},
            {cwd=directory,text=true,timeout=30000},function(result)
                vim.schedule(function()
                    local valid,value=pcall(read,report)
                    if result.code==0 and (result.signal or 0)==0 and valid and value.schema==1 then
                        M.components[key(kind,directory)]=value
                    else M.components[key(kind,directory)]={ready=false,error='Проверка компонентов Rust не завершилась: '..(result.stderr or '')} end
                    vim.uv.fs_unlink(report)
                    if callback then callback(M.status(kind,directory)) end
                end)
            end)
    end
    if pending==0 then complete();return end
    for _,entry in ipairs(state.sdks) do
        if entry.path then
            local backend=(entry.kind=='go' or entry.kind=='rust') and require('forge.sdk') or require('forge.runtime_sdk')
            backend.probe(entry.kind,entry.path,function(found,why)
                M.versions[entry.path]=found and {version=found.version} or {error=tostring(why)}
                pending=pending-1
                if pending==0 then complete() end
            end)
        end
    end
end
local function maintenance()
    local runtime=vim.env.FRIDE_RUNTIME
    if not runtime or runtime=='' then return nil,'Source checkout: установи готовый fride для встроенной подготовки; ручной выбор SDK/Mason доступен.' end
    local kit=vim.fs.dirname(runtime)
    local ok,owner=pcall(read,join(kit,'.forge-install.json'))
    local binary=join(kit,'bin',vim.fn.has('win32')==1 and 'fride-setup.exe' or 'fride-setup')
    if not ok or owner.product~='forge-nvim' or owner.ready~=true or vim.fn.executable(binary)~=1 then
        return nil,'Установщик среды в kit не найден. Обнови fride; выбор существующего SDK и Mason доступны.'
    end
    return {kit=kit,binary=binary}
end
function M.prepare(kind,directory)
    directory=root(directory)
    if M.active then M.active.task:open_output('horizontal');notice('Уже подготавливается '..M.active.kind);return end
    local state=M.status(kind,directory)
    if state.settings_error then notice('Сначала исправь выбранный SDK/настройку: '..state.settings_error,vim.log.levels.WARN);return end
    local installer,why=maintenance()
    if not installer then notice(why,vim.log.levels.WARN);log(why);return end
    local folder=join(vim.fn.stdpath('state'),'language-setup',tostring(vim.uv.hrtime()))
    vim.fn.mkdir(folder,'p');local result=join(folder,'result.json')
    local command={installer.binary,'--prepare-language',kind,'--installed-kit',installer.kit,'--result',result,'--log-dir',folder}
    local task=require('overseer').new_task({name='Подготовка '..titles[kind],cmd=command,cwd=directory,
        components={'on_exit_set_status'},strategy={'jobstart',use_terminal=true}})
    M.active={kind=kind,root=directory,task=task};M.seen[key(kind,directory)]=true
    log('Подготовка '..kind..' | '..directory..' | '..folder)
    task:subscribe('on_complete',function(_,status)
        vim.schedule(function()
            if M.active and M.active.task==task then M.active=nil end
            local ok,data=pcall(read,result)
            if status=='SUCCESS' and ok and data.schema==1 and data.language==kind and data.ready==true then
                M.results[key(kind,directory)]=data
                notice(titles[kind]..' подготовлен. Space l S → выбрать SDK и применить среду.')
                log('Готово '..kind..' | '..directory..' | '..result)
            else
                local message='Подготовка '..titles[kind]..' не завершилась; вывод сохранён в Tasks и '..folder
                M.results[key(kind,directory)]={error=message}
                notice('Подготовка '..titles[kind]..' не завершилась — Space l S, логи.',vim.log.levels.WARN)
                log(message,vim.log.levels.WARN)
            end
        end)
        return true
    end)
    local ok,err=pcall(function()
        task:start();require('ide').triggers.fire('task:run');task:open_output('horizontal');vim.cmd.startinsert()
    end)
    if not ok then M.active=nil;notice(tostring(err),vim.log.levels.ERROR);log(err,vim.log.levels.ERROR) end
    return task
end
function M.policy(kind,directory)
    directory=root(directory)
    local items={{'Позже (только этот сеанс)'},{'Спрашивать для проекта','ask','project'},
        {'Не предлагать для проекта','manual','project'},{'Наследовать пользовательскую настройку',nil,'project'},
        {'Спрашивать для пользователя','ask','user'},{'Не предлагать вообще','manual','user'},
        {'Сбросить пользовательскую настройку',nil,'user'},
        {'Открыть настройки предложений проекта',nil,'project','edit'},
        {'Открыть настройки предложений пользователя',nil,'user','edit'}}
    vim.ui.select(items,{prompt=titles[kind]..': предложения',format_item=function(item)return item[1] end},function(item)
        if not item or root()~=directory then return end
        if item[4]=='edit' then
            local file=require('forge.language_settings').files(directory)[item[3]]
            vim.fn.mkdir(vim.fs.dirname(file),'p')
            if vim.fn.filereadable(file)~=1 then vim.fn.writefile({'{','  "version": 1,','  "prompts": {}','}'},file) end
            require('ide').focus_main();vim.cmd.edit(vim.fn.fnameescape(file));return
        end
        M.seen[key(kind,directory)]=item[1]:find('Позже',1,true)~=nil
        if item[3] then
            local ok,why=pcall(require('forge.language_settings').set,kind,item[2],item[3],directory)
            if not ok then notice(tostring(why),vim.log.levels.ERROR);return end
            log(kind..' prompts '..tostring(item[2])..' | '..item[3]..' | '..directory)
        end
        M.open(kind)
    end)
end
function M.open(kind)
    local directory=root()
    require('lazy').load({plugins={'telescope.nvim'}})
    if not kind or kind=='' then
        local items={}
        for _,id in ipairs(ordered) do
            local state=M.status(id,directory)
            items[#items+1]={kind=id,label=state.title..' · '..(state.ready and 'готово' or state.error and 'ошибка настройки' or 'нужна подготовка')..' · tools '..state.available..'/'..#state.tools}
        end
        vim.ui.select(items,{prompt='Языки и инструменты',format_item=function(item)return item.label end},function(item)
            if item and root()==directory then M.recheck(item.kind,directory,function()if root()==directory then M.open(item.kind) end end) end
        end)
        return
    end
    if not titles[kind] then notice('Язык: go, rust, python, node, bash или sql',vim.log.levels.ERROR);return end
    local state=M.status(kind,directory)
    local details={}
    for _,entry in ipairs(state.sdks) do details[#details+1]=entry.kind..': '..(entry.version or entry.error or entry.path or 'не найден')..' ['..tostring(entry.source or 'PATH')..']' end
    if state.components then details[#details+1]=state.components.ready and 'rustfmt / rust-src: готовы' or state.components.error or ('Нужны компоненты: '..table.concat(state.components.missing or {},', ')) end
    local items={{label='Подготовить недостающее',action='prepare'},
        {label='Выбрать SDK / версию / путь…',action='sdk'},
        {label='Применить текущий выбор SDK…',action='apply'},
        {label='Проверить версии и готовность',action='check'},
        {label='Инструменты языка ('..state.available..'/'..#state.tools..')',action='tools'},
        {label='Предложения: '..state.policy.value..' ['..state.policy.source..']',action='policy'},
        {label='Логи подготовки',action='logs'},{label='Все языки',action='back'}}
    for index=#details,1,-1 do table.insert(items,1,{label=details[index],action='info'}) end
    if state.prepared and state.prepared.ready then table.insert(items,1,{label='Установлено; при необходимости выбери SDK и примени его',action='info'}) end
    if state.error then table.insert(items,1,{label=state.error,action='info'}) end
    vim.ui.select(items,{prompt=titles[kind]..' · Языки и инструменты',format_item=function(item)return item.label end},function(item)
        if not item or root()~=directory then return end
        if item.action=='prepare' then M.prepare(kind,directory)
        elseif item.action=='sdk' then
            local kinds=require('forge.install_profile').sdk_kinds(kind)
            if #kinds==0 then notice('У SQL нет общего SDK; инструменты — через Mason.')
            elseif #kinds==1 then require('forge.sdk').open(kinds[1])
            else vim.ui.select(kinds,{prompt='SDK для '..titles[kind]},function(value)if value and root()==directory then require('forge.sdk').open(value) end end) end
        elseif item.action=='apply' then require('forge.sdk').apply()
        elseif item.action=='check' then M.recheck(kind,directory,function()if root()==directory then M.open(kind) end end)
        elseif item.action=='tools' then M.tools(kind,directory)
        elseif item.action=='policy' then M.policy(kind,directory)
        elseif item.action=='logs' then vim.cmd('ForgeLogs events:Languages')
        elseif item.action=='back' then M.open()
        else M.open(kind) end
    end)
end
function M.tools(kind,directory)
    directory=root(directory);local state=M.status(kind,directory)
    local items={{label='Открыть штатный Mason',action='mason'},{label='Настроить пути tools.json…',action='paths'}}
    for _,tool in ipairs(state.tools) do
        items[#items+1]={label=tool.name..' · '..(tool.ready and (tool.version or 'готово') or 'не подготовлен')..' · '..(tool.source or tool.error or '')}
    end
    vim.ui.select(items,{prompt=titles[kind]..': LSP / format / debug / tests',format_item=function(item)return item.label end},function(item)
        if not item or root()~=directory then return end
        if item.action=='mason' then vim.cmd.Mason()
        elseif item.action=='paths' then
            vim.ui.select({'project','user'},{prompt='Tool paths: область'},function(scope)
                if not scope or root()~=directory then return end
                local file=require('forge.tool_paths').files(directory)[scope]
                vim.fn.mkdir(vim.fs.dirname(file),'p')
                if vim.fn.filereadable(file)~=1 then vim.fn.writefile({'{','  "tools": {}','}'},file) end
                require('ide').focus_main();vim.cmd.edit(vim.fn.fnameescape(file))
            end)
        else M.open(kind) end
    end)
end
function M.file(buf)
    if vim.g.forge_setup_sdk_report or not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype~='' then return end
    local ft=vim.bo[buf].filetype
    if ft=='' then ft=vim.filetype.match({buf=buf}) end
    local kind=filetypes[ft];local name=vim.api.nvim_buf_get_name(buf)
    if not kind or name=='' then return end
    local directory=root(name);local id=key(kind,directory)
    if M.seen[id] then return end
    M.seen[id]=true
    local ok,state=pcall(M.status,kind,directory)
    if not ok then log(tostring(state),vim.log.levels.WARN);return end
    if state.policy.value~='ask' or state.ready then return end
    notice(titles[kind]..': '..(state.error and 'проверь среду' or 'подготовить среду')..' — Space l S')
end
function M.setup()
    vim.api.nvim_create_user_command('ForgeLanguages',function(args)M.open(args.args)end,{nargs='?',
        complete=function()return ordered end,desc='Языки и инструменты: SDK, подготовка, paths, prompts и логи'})
    vim.keymap.set('n','<leader>lS',function()M.open()end,{desc='Языки и инструменты'})
    local group=vim.api.nvim_create_augroup('ForgeLanguageEnvironments',{clear=true})
    vim.api.nvim_create_autocmd({'FileType','BufEnter'},{group=group,callback=function(args)
        vim.schedule(function()M.file(args.buf)end)
    end})
end
return M
