-- spec: IDE-BOOT-37 IDE-BOOT-38. Explicit SDK selection; startup never probes CLI.
local M = {}
local uv = vim.uv
local win = vim.fn.has('win32') == 1
local sep, suffix = win and ';' or ':', win and '.exe' or ''
local keys = {'PATH','GOROOT','GOTOOLCHAIN','RUSTUP_TOOLCHAIN','RUSTUP_AUTO_INSTALL','RUSTC','RUSTDOC','CARGO'}
local startup_env={}
for _,key in ipairs(keys) do startup_env[key]=vim.env[key] or vim.NIL end
local generation = 0

local function log(message, level)
    local store=require('forge.log_store')
    if store.session then store.record(message, level or vim.log.levels.INFO, 'SDK') end
end
local function failure(message)
    log(message, vim.log.levels.ERROR)
    error(message, 0)
end
local function notify(message, level)
    log(message, level)
    vim.notify(message, level or vim.log.levels.INFO, {title='SDK'})
end
function M.root(path)
    return require('forge.tool_paths').root(path or vim.fn.getcwd())
end
local function read(path)
    local stat, err, code = uv.fs_stat(path)
    if not stat then
        if code == 'ENOENT' then return {version=1,sdks={}} end
        failure('SDK ['..path..']: '..tostring(err))
    end
    if stat.type~='file' or stat.size>65536 then failure('SDK ['..path..']: expected JSON file <=64KiB') end
    local ok, data = pcall(function()
        local file=assert(io.open(path,'rb'));local raw=file:read(65537);file:close()
        local value=vim.json.decode(raw)
        assert(type(value)=='table' and value.version==1 and type(value.sdks)=='table','expected version=1, sdks object')
        for kind,entry in pairs(value.sdks) do
            assert((kind=='go' or kind=='rust') and type(entry)=='string' and entry~='' and not entry:find('%c'),
                'sdks supports nonempty go/rust path strings or auto')
        end
        return value
    end)
    if not ok then failure('SDK ['..path..']: '..tostring(data)) end
    return data
end
function M.files(root)
    return {project=vim.fs.joinpath(M.root(root),'.fride/sdk.json'),user=vim.fs.joinpath(vim.fn.stdpath('config'),'sdk.json')}
end
function M.choice(kind, root, options)
    assert(kind=='go' or kind=='rust','Expected go or rust')
    local files=M.files(root)
    for _,scope in ipairs(options and options.scope=='user' and {'user'} or {'project','user'}) do
        local data=read(files[scope]);local value=data.sdks[kind]
        if value then return {kind=kind,value=value,source=scope..': '..files[scope],
            base=scope=='project' and M.root(root) or vim.fn.stdpath('config')} end
    end
    return {kind=kind,value='auto',source='inherited environment'}
end
local function normalize(value, base)
    local path=vim.fs.normalize(value)
    if not path:match('^[/\\]') and not path:match('^%a:[/\\]') then path=vim.fs.joinpath(base or vim.fn.getcwd(),path) end
    path=vim.fs.normalize(path)
    if (uv.fs_stat(path) or {}).type=='file' then
        -- Proxies use their invocation name (rustc/cargo, for example). Resolve
        -- the parent directory while retaining the executable symlink itself.
        local parent=vim.fs.dirname(path)
        return vim.fs.joinpath(uv.fs_realpath(parent) or parent,vim.fs.basename(path))
    end
    return vim.fs.normalize(uv.fs_realpath(path) or path)
end
function M.location(kind, value, base)
    assert(kind=='go' or kind=='rust','Expected go/rust')
    local path=normalize(value,base)
    local stat=uv.fs_stat(path)
    if not stat then error('SDK path does not exist: '..path,0) end
    if stat.type=='file' then
        local name=vim.fs.basename(path):lower()
        local expected=kind=='go' and 'go'..suffix or 'rustc'..suffix
        if name~=expected and not (kind=='rust' and name=='cargo'..suffix) then error('Expected native '..expected..' executable: '..path,0) end
        path=vim.fs.dirname(path)
    end
    local command=kind=='go' and 'go' or 'rustc'
    if vim.fn.executable(path..'/bin/'..command..suffix)==1 then path=path..'/bin' end
    local executable=path..'/'..command..suffix
    if vim.fn.executable(executable)~=1 then error('SDK executable not found: '..executable,0) end
    if kind=='rust' and vim.fn.executable(path..'/cargo'..suffix)~=1 then error('Cargo not found beside rustc: '..path,0) end
    return {kind=kind,bin=vim.fs.normalize(path),path=vim.fs.normalize(vim.fs.dirname(path)),executable=executable}
end
local function baseline()
    if vim.env.FRIDE_SDK_BASE then
        local data=vim.json.decode(vim.env.FRIDE_SDK_BASE)
        assert(type(data)=='table' and data.version==1 and type(data.env)=='table','Invalid FRIDE_SDK_BASE')
        for _,key in ipairs(keys) do
            local value=data.env[key]
            assert(value==vim.NIL or value==nil or type(value)=='string','Invalid SDK baseline: '..key)
        end
        return data.env
    end
    return vim.deepcopy(startup_env)
end
local function inherited_env()
    local env=vim.fn.environ()
    for key,value in pairs(baseline()) do env[key]=value~=vim.NIL and value or nil end
    return env
end
-- Pure selection shared by runtime startup and installer preflight; no CLI probes.
function M.selection(kind, root, options)
    local choice=M.choice(kind,root,options)
    if choice.value=='auto' then return nil end
    local ok,sdk=pcall(M.location,kind,choice.value,choice.base)
    if not ok then failure('SDK ['..choice.source..']: '..tostring(sdk)) end
    sdk.source=choice.source
    sdk.tools=kind=='go' and {go=sdk.executable} or {rustc=sdk.executable,cargo=sdk.bin..'/cargo'..suffix}
    sdk.env=kind=='go' and {GOROOT=sdk.path,GOTOOLCHAIN='local'} or {
        RUSTUP_TOOLCHAIN=sdk.path,RUSTUP_AUTO_INSTALL='0',RUSTC=sdk.executable,
        RUSTDOC=sdk.bin..'/rustdoc'..suffix,CARGO=sdk.tools.cargo}
    return sdk
end
function M.initialize(root, options)
    options=options or {}
    root=M.root(root or vim.env.FRIDE_SDK_PROJECT or vim.fn.getcwd())
    local selected, any = {}, false
    for _,kind in ipairs(options.kinds or {'go','rust'}) do
        selected[kind]=M.selection(kind,root,options)
        any=any or selected[kind]~=nil
    end
    local base=baseline()
    if any or vim.env.FRIDE_SDK_BASE then
        vim.env.FRIDE_SDK_BASE=vim.json.encode({version=1,env=base})
        for _,key in ipairs(keys) do vim.env[key]=base[key]~=vim.NIL and base[key] or nil end
    end
    local bins={}
    for _,kind in ipairs({'go','rust'}) do
        local sdk=selected[kind]
        if sdk then
            bins[#bins+1]=sdk.bin
            for key,value in pairs(sdk.env) do vim.env[key]=value end
        end
    end
    if #bins>0 then bins[#bins+1]=vim.env.PATH or '';vim.env.PATH=table.concat(bins,sep) end
    vim.env.FRIDE_SDK_PROJECT=nil
    M.active={root=root,selected=selected}
    for kind,sdk in pairs(selected) do log(kind..' | '..sdk.executable..' | '..sdk.source) end
end
function M.validate(root)
    for _,kind in ipairs({'go','rust'}) do
        local choice=M.choice(kind,root)
        if choice.value~='auto' then
            local ok,why=pcall(M.location,kind,choice.value,choice.base)
            if not ok then failure('SDK ['..choice.source..']: '..tostring(why)) end
        end
    end
end
function M.prepare_restart(root)
    M.validate(root)
    local saved={project=vim.env.FRIDE_SDK_PROJECT,base=vim.env.FRIDE_SDK_BASE}
    -- Snapshot only touched keys; SDK homes/cache/auth remain native.
    vim.env.FRIDE_SDK_BASE=vim.json.encode({version=1,env=baseline()})
    vim.env.FRIDE_SDK_PROJECT=M.root(root)
    return function() vim.env.FRIDE_SDK_PROJECT=saved.project;vim.env.FRIDE_SDK_BASE=saved.base end
end
function M.save(kind, value, scope, root)
    assert(scope=='user' or scope=='project','Expected user/project scope')
    assert(kind=='go' or kind=='rust','Expected go/rust')
    assert(type(value)=='string' and value~='' and not value:find('%c'),'Expected SDK path or auto')
    if value~='auto' then M.location(kind,value,scope=='project' and M.root(root) or vim.fn.stdpath('config')) end
    local file=M.files(root)[scope];local data=read(file)
    data.sdks[kind]=value
    vim.fn.mkdir(vim.fs.dirname(file),'p')
    local temp=file..'.'..uv.os_getpid()..'.tmp'
    local ok,err=pcall(function()
        local handle=assert(io.open(temp,'wb'));assert(handle:write(vim.json.encode(data)..'\n'));assert(handle:close())
        assert(uv.fs_rename(temp,file))
    end)
    if not ok then uv.fs_unlink(temp);failure('SDK save ['..file..']: '..tostring(err)) end
    log(kind..' | saved '..value..' | '..scope..': '..file)
end
-- No CLI until explicit menu/refresh. Probe environment cannot install a toolchain.
function M.probe(kind, value, callback, directory)
    local ok, location=pcall(M.location,kind,value)
    if not ok then callback(nil,tostring(location));return end
    local env=inherited_env()
    env.GOTOOLCHAIN='local';env.GOROOT=nil;env.GOENV='off';env.GOWORK='off';env.GOFLAGS=''
    env.GOTELEMETRY='off';env.RUSTUP_AUTO_INSTALL='0';env.GO111MODULE='off'
    env.MISE_AUTO_INSTALL='false';env.MISE_EXEC_AUTO_INSTALL='false';env.MISE_NOT_FOUND_AUTO_INSTALL='false'
    local cwd=M.root(directory)
    local function run(argv, done)
        local started,why=pcall(vim.system,argv,{env=env,clear_env=true,cwd=cwd,text=true,timeout=3000},function(result)
            vim.schedule(function()
                if result.code~=0 or (result.signal or 0)~=0 then done(nil,(result.stderr or '')..' (exit '..result.code..', signal '..tostring(result.signal or 0)..')')
                else done(result.stdout or '') end
            end)
        end)
        if not started then done(nil,tostring(why)) end
    end
    if kind=='go' then
        run({location.executable,'env','-json','GOROOT','GOVERSION'},function(out,err)
            if not out then callback(nil,err);return end
            local decoded,data=pcall(vim.json.decode,out)
            if not decoded or type(data.GOROOT)~='string' or type(data.GOVERSION)~='string' then callback(nil,'Invalid Go SDK response');return end
            local valid,sdk=pcall(M.location,'go',data.GOROOT)
            if not valid then callback(nil,tostring(sdk));return end
            sdk.version=data.GOVERSION;callback(sdk)
        end)
    else
        local root=location.path
        if vim.fn.isdirectory(root..'/lib/rustlib')==1 then env.RUSTUP_TOOLCHAIN=root end
        run({location.executable,'--print','sysroot'},function(out,err)
            if not out then callback(nil,err);return end
            local valid,sdk=pcall(M.location,'rust',vim.trim(out))
            if not valid then callback(nil,tostring(sdk));return end
            env.RUSTUP_TOOLCHAIN=sdk.path
            run({sdk.executable,'--version'},function(version,why)
                if not version then callback(nil,why);return end
                run({sdk.bin..'/cargo'..suffix,'--version'},function(cargo,cargo_err)
                    if not cargo then callback(nil,cargo_err);return end
                    sdk.version=vim.trim(version);sdk.cargo=vim.trim(cargo);callback(sdk)
                end)
            end)
        end)
    end
end
function M.discover(kind, callback)
    local candidates,seen={},{}
    local function add(path,source)
        local ok,sdk=pcall(M.location,kind,path)
        if ok then
            local key=win and sdk.path:lower() or sdk.path
            if not seen[key] and #candidates<64 then seen[key]=true;sdk.source=source;candidates[#candidates+1]=sdk end
        end
    end
    for _,dir in ipairs(vim.split(inherited_env().PATH or '',sep,{plain=true,trimempty=true})) do add(dir:gsub('^"',''):gsub('"$',''),'PATH') end
    for scope,file in pairs(M.files()) do
        local ok,data=pcall(read,file)
        if ok and data.sdks[kind] and data.sdks[kind]~='auto' then
            add(normalize(data.sdks[kind],scope=='project' and M.root() or vim.fn.stdpath('config')),scope..': '..file)
        end
    end
    local home=uv.os_homedir()
    local function children(directory,source,pattern)
        local count=0
        if vim.fn.isdirectory(directory)~=1 then return end
        for name in vim.fs.dir(directory) do
            count=count+1;if count>256 then break end
            if not pattern or name:match(pattern) then add(directory..'/'..name,source) end
        end
    end
    if kind=='go' then
        children(home..'/sdk','~/sdk','^go%d')
        for _,path in ipairs({'/usr/local/go','/usr/lib/go','/opt/homebrew/opt/go/libexec','/usr/local/opt/go/libexec',
            (vim.env.ProgramFiles or 'C:/Program Files')..'/Go',home..'/go'}) do add(path,'native location') end
        local gopath=vim.env.GOPATH or home..'/go'
        for _,path in ipairs(vim.split(gopath,sep,{plain=true,trimempty=true})) do
            children((vim.env.GOMODCACHE or path..'/pkg/mod')..'/golang.org','Go toolchain cache','^toolchain@')
        end
    else
        children((vim.env.RUSTUP_HOME or home..'/.rustup')..'/toolchains','rustup')
    end
    local results,errors,index,active,finished={}, {}, 1, 0, false
    local function next_probe()
        while active<2 and index<=#candidates do
            local candidate=candidates[index];index=index+1;active=active+1
            M.probe(kind,candidate.path,function(sdk,err)
                active=active-1
                if sdk then
                    local duplicate=false;for _,other in ipairs(results) do if other.path==sdk.path then duplicate=true end end
                    if not duplicate then sdk.source=candidate.source;results[#results+1]=sdk end
                else errors[#errors+1]=candidate.path..': '..tostring(err) end
                next_probe()
            end)
        end
        if index>#candidates and active==0 and not finished then
            finished=true
            table.sort(results,function(a,b) return a.version==b.version and a.path<b.path or a.version>b.version end)
            for _,err in ipairs(errors) do log('Discovery: '..err,vim.log.levels.WARN) end
            callback(results,errors)
        end
    end
    next_probe()
end
function M.busy()
    local dap=package.loaded.dap
    if dap and dap.session() then return 'запущена отладка' end
    local tests=package.loaded.neotest
    if tests and tests.forge_runner and tests.forge_runner.running() then return 'выполняются тесты' end
    if tests and tests.state then for _,id in ipairs(tests.state.adapter_ids()) do
        local counts=tests.state.status_counts(id);if counts and counts.running>0 then return 'выполняются тесты' end
    end end
    local tasks=package.loaded.overseer
    if tasks then for _,task in ipairs(tasks.list_tasks()) do if task:is_running() then return 'выполняется задача' end end end
    for _,buf in ipairs(vim.api.nvim_list_bufs()) do
        local job=vim.b[buf].terminal_job_id
        if vim.bo[buf].buftype=='terminal' and type(job)=='number' and vim.fn.jobwait({job},0)[1]==-1 then
            return 'работает терминал; закрой его перед переоткрытием'
        end
    end
end
function M.apply()
    local valid,err=pcall(M.validate,M.root())
    if not valid then notify(tostring(err),vim.log.levels.ERROR);return false end
    valid,err=pcall(require('forge.runtime_sdk').validate,M.root())
    if not valid then notify(tostring(err),vim.log.levels.ERROR);return false end
    local reason=M.busy()
    if reason then notify('SDK не применён: '..reason..'. Выбор сохранён для следующего запуска.',vim.log.levels.WARN);return false end
    require('config.start').open_project(vim.fn.getcwd(),{reopen=true,sdk=true})
    return true
end
function M.open(kind, scope)
    require('lazy').load({plugins={'telescope.nvim'}})
    if not kind or kind=='' then
        vim.ui.select({'go','rust','python','node'},{prompt='SDK: язык'},function(value) if value then M.open(value,scope) end end);return
    end
    if not vim.tbl_contains({'go','rust','python','node'},kind) then notify('SDK: выбери go, rust, python или node',vim.log.levels.ERROR);return end
    local runtime=kind=='python' or kind=='node'
    local backend=runtime and require('forge.runtime_sdk') or M
    if not scope or scope=='' then
        vim.ui.select({'project','user'},{prompt='SDK: сохранить для'},function(value) if value then M.open(kind,value) end end);return
    end
    if scope~='project' and scope~='user' then notify('SDK scope: project или user',vim.log.levels.ERROR);return end
    generation=generation+1;local id=generation;local root=M.root()
    local function current() return id==generation and M.root()==root end
    local selected_ok,selected=pcall(backend.choice,kind,root)
    if not selected_ok then notify(tostring(selected),vim.log.levels.ERROR);return end
    notify('Проверяю установленные '..kind..' SDK…')
    local function save(value)
        if not current() then return end
        vim.ui.select({'Сохранить и переоткрыть проект',runtime and 'Сохранить для следующих запусков задач' or 'Сохранить для следующего запуска'},
            {prompt='SDK '..kind..': '..value},function(action)
                if not action or not current() then return end
                log(kind..' | '..action..' | '..value..' | '..scope..': '..root)
                local ok,err=pcall(backend.save,kind,value,scope,root)
                if not ok then notify(tostring(err),vim.log.levels.ERROR);return end
                if action=='Сохранить и переоткрыть проект' then M.apply()
                else notify(runtime and 'Путь сохранён для следующих workflow. Работающий LSP обновится после переоткрытия проекта.'
                    or 'SDK сохранён. Применится при следующем запуске/переоткрытии проекта.') end
            end)
    end
    backend.discover(kind,function(found)
        if not current() then return end
        local items={{label=runtime and 'Сбросить выбор — наследовать настройки и среду' or 'Авто — исходное окружение языка',value='auto'}}
        for _,sdk in ipairs(found) do items[#items+1]={label=sdk.version..' | '..sdk.executable..' | '..sdk.source,value=sdk.path} end
        items[#items+1]={label='Указать путь…',manual=true};items[#items+1]={label='Обновить список',refresh=true}
        vim.ui.select(items,{prompt=kind..' SDK ['..scope..'] | '..selected.value..' | '..selected.source,
            format_item=function(item) return item.label end},function(item)
                if not item or not current() then return end
                if item.refresh then M.open(kind,scope)
                elseif item.manual then
                    vim.ui.input({prompt='SDK executable или каталог: ',completion='file'},function(value)
                        if not value or value=='' or not current() then return end
                        backend.probe(kind,value,function(sdk,err)
                            if not current() then return end
                            if not sdk then notify('SDK: '..tostring(err),vim.log.levels.ERROR);return end
                            save(sdk.path)
                        end)
                    end)
                else save(item.value) end
            end)
    end)
end
function M.setup()
    local report=vim.g.forge_setup_sdk_report
    local options=report and report.scope and {scope=report.scope,kinds=report.sdk_kinds} or nil
    local ok,err=pcall(M.initialize,nil,options)
    if not ok then
        M.error=tostring(err)
        vim.schedule(function() notify(M.error..'\nИсправь sdk.json или выбери Авто.',vim.log.levels.ERROR) end)
    end
    vim.api.nvim_create_user_command('ForgeSdk',function(args) M.open(args.fargs[1],args.fargs[2]) end,
        {nargs='*',complete=function() return {'go','rust','python','node','project','user'} end,desc='Select an installed SDK or enter its path'})
    vim.api.nvim_create_user_command('ForgeSdkApply',M.apply,{desc='Reopen project with its selected native SDK'})
    vim.keymap.set('n','<leader>lS',function() M.open() end,{desc='SDK: select installed version or path'})
end
return M
