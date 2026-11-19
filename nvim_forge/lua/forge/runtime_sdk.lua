-- spec: IDE-BOOT-38. Menu provider over existing Python/Node settings/resolvers.
local M={}
local win=vim.fn.has('win32')==1
local suffix,sep=win and '.exe' or '',win and ';' or ':'
local function resolve(kind,root)
    if kind=='python' then return require('forge.python').resolve({require('forge.tool_paths').root(root)}) end
    return require('forge.node').executable(root)
end
function M.choice(kind,root)
    local ok,path=pcall(resolve,kind,root)
    local entry=require('forge.tool_paths').current(kind)
    return {value=ok and (path or 'auto') or 'ERROR',source=entry and entry.source or tostring(path or 'PATH'),error=not ok and path or nil}
end
function M.location(kind,value)
    local path=vim.fs.normalize(value)
    if not path:match('^[/\\]') and not path:match('^%a:[/\\]') then path=vim.fs.joinpath(vim.fn.getcwd(),path) end
    path=vim.fs.normalize(path)
    if path:lower():gsub('\\','/'):find('/microsoft/windowsapps/',1,true) then error('Choose a native SDK, not WindowsApps: '..path,0) end
    if vim.fn.isdirectory(path)==1 then
        local names=kind=='python' and (win and {'Scripts/python.exe','python.exe','bin/python.exe'} or {'bin/python','bin/python3','python3','python'})
            or {'bin/node'..suffix,'node'..suffix}
        for _,name in ipairs(names) do if vim.fn.executable(path..'/'..name)==1 then path=path..'/'..name;break end end
    end
    if vim.fn.executable(path)~=1 or vim.fn.isdirectory(path)==1 then error('SDK executable not found: '..path,0) end
    -- Do not fs_realpath Python: a venv's symlink belongs to that environment.
    return {kind=kind,path=path,executable=path}
end
function M.probe(kind,value,callback,directory)
    local ok,sdk=pcall(M.location,kind,value)
    if not ok then callback(nil,tostring(sdk));return end
    local command=kind=='python' and {sdk.executable,'-I','-B','-c',
        'import sys,json; print(json.dumps({"version":sys.version.split()[0],"prefix":sys.prefix}))'} or {sdk.executable,'--version'}
    local started,why=pcall(vim.system,command,{cwd=require('forge.tool_paths').root(directory),text=true,timeout=3000,
        env={NODE_OPTIONS='',MISE_AUTO_INSTALL='false',MISE_EXEC_AUTO_INSTALL='false',MISE_NOT_FOUND_AUTO_INSTALL='false'}},function(result)
        vim.schedule(function()
            if result.code~=0 or (result.signal or 0)~=0 then callback(nil,(result.stderr or '')..' (exit '..result.code..', signal '..tostring(result.signal or 0)..')');return end
            if kind=='python' then
                local decoded,data=pcall(vim.json.decode,result.stdout or '')
                if not decoded or type(data)~='table' or type(data.version)~='string' or type(data.prefix)~='string' then callback(nil,'Invalid Python response');return end
                sdk.version='Python '..data.version;sdk.prefix=data.prefix
            else
                local version=vim.trim(result.stdout or '')
                if not version:match('^v%d+%.%d+%.%d+') then callback(nil,'Invalid Node response');return end
                sdk.version='Node '..version
            end
            callback(sdk)
        end)
    end)
    if not started then callback(nil,tostring(why)) end
end
function M.save(kind,value,scope,root)
    local path=value~='auto' and M.location(kind,value).executable or nil
    local file=require('forge.tool_paths').save(kind,path,scope,root)
    require('forge.log_store').record(kind..' | '..(path or 'inherit')..' | '..scope..': '..file,vim.log.levels.INFO,'SDK')
end
function M.validate(root)
    require('forge.tool_paths').override('python',{root=root,global='forge_python_path',env='FORGE_PYTHON_PATH'})
    require('forge.tool_paths').override('node',{root=root,global='forge_node_executable',env='FORGE_NODE_EXECUTABLE'})
end
function M.discover(kind,callback)
    local candidates,seen={},{}
    local function add(path,source)
        if not path or #candidates>=64 then return end
        local ok,sdk=pcall(M.location,kind,path)
        if not ok then return end
        local key=win and sdk.path:lower() or sdk.path
        if not seen[key] then seen[key]=true;sdk.source=source;candidates[#candidates+1]=sdk end
    end
    local selected=M.choice(kind);if selected.value~='ERROR' then add(selected.value,selected.source) end
    local function children(directory,source,tail)
        if not directory or vim.fn.isdirectory(directory)~=1 then return end
        local count=0
        for name in vim.fs.dir(directory) do
            count=count+1;if count>128 then break end
            add(directory..'/'..name..(tail or ''),source)
        end
    end
    local home=vim.uv.os_homedir()
    if kind=='python' then
        add(vim.env.VIRTUAL_ENV,'VIRTUAL_ENV');add(vim.env.CONDA_PREFIX,'CONDA_PREFIX')
        local root=require('forge.tool_paths').root()
        for _,name in ipairs({'.venv','venv','.env','env'}) do add(root..'/'..name,'project venv') end
        children((vim.env.PYENV_ROOT or home..'/.pyenv')..'/versions','pyenv')
        children(home..'/.conda/envs','conda')
        if win then children((vim.env.LOCALAPPDATA or home..'/AppData/Local')..'/Programs/Python','native Python') end
    else
        add(vim.env.NVM_SYMLINK,'NVM_SYMLINK')
        children(vim.env.NVM_HOME,'nvm-windows')
        children((vim.env.NVM_DIR or home..'/.nvm')..'/versions/node','nvm')
        children((vim.env.VOLTA_HOME or home..'/.volta')..'/tools/image/node','Volta')
        children((vim.env.FNM_DIR or home..'/.local/share/fnm')..'/node-versions','fnm','/installation')
    end
    for _,directory in ipairs(vim.split(vim.env.PATH or '',sep,{plain=true,trimempty=true})) do
        directory=directory:gsub('^"',''):gsub('"$','')
        if kind=='python' then add(directory..'/python3'..suffix,'PATH');add(directory..'/python'..suffix,'PATH')
        else add(directory..'/node'..suffix,'PATH') end
    end
    local results,errors,index,active,finished={}, {}, 1, 0, false
    local function advance()
        while active<2 and index<=#candidates do
            local candidate=candidates[index];index=index+1;active=active+1
            M.probe(kind,candidate.path,function(sdk,err)
                active=active-1
                if sdk then sdk.source=candidate.source;results[#results+1]=sdk
                else errors[#errors+1]=candidate.path..': '..tostring(err) end
                advance()
            end)
        end
        if index>#candidates and active==0 and not finished then
            finished=true
            table.sort(results,function(a,b) return a.path<b.path end)
            for _,err in ipairs(errors) do require('forge.log_store').record('Discovery: '..err,vim.log.levels.WARN,'SDK') end
            callback(results,errors)
        end
    end
    advance()
end
return M
