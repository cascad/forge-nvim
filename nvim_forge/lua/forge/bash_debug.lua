-- spec: IDE-SH-5. Официальный Node adapter сам использует WSL на Windows.
local M={}
local win=vim.fn.has('win32')==1
local function file(path) return path and path~='' and vim.fn.filereadable(path)==1 end
local function warn(text) vim.notify(text,vim.log.levels.WARN,{title='Bash debug'}) end
local function sdk_patch()
    local path=vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1,'S').source:sub(2)),'bash_debug_patch.json')
    return vim.json.decode(table.concat(vim.fn.readfile(path),'\n'))
end
local function sdk_source(script)
    local f=assert(io.open(script,'rb'));local raw=f:read('*a');f:close()
    local source=raw:gsub('\r\n','\n')
    return raw,source,vim.fn.sha256(source)
end
local function entrypoint()
    local explicit=vim.g.forge_bash_debug_adapter or vim.env.FORGE_BASH_DEBUG_ADAPTER
    if explicit and explicit~='' then return file(explicit) and explicit or nil end
    local path=vim.fs.joinpath(vim.fn.stdpath('data'),'mason/packages/bash-debug-adapter/extension/out/bashDebug.js')
    return file(path) and path or nil
end
function M.prepare()
    local script=entrypoint()
    if not script then warn('BashDebugPrepare: adapter не найден. Сначала :MasonInstall bash-debug-adapter.');return end
    local temporary
    local ok,why=pcall(function()
        local patch=sdk_patch();local raw,source,digest=sdk_source(script)
        for _,p in ipairs(patch.payloads) do if digest==p.after_sha256 then return 'уже готов' end end
        local payload
        for _,p in ipairs(patch.payloads) do if digest==p.before_sha256 then payload=p;break end end
        assert(payload,'Неизвестный SDK: исходник сохранён. Подготовь pinned SDK через prepare_bash_dap.py --download.')
        local result=source
        for _,replacement in ipairs(patch.replacements) do
            local first,last=result:find(replacement.before,1,true)
            assert(first and not result:find(replacement.before,last+1,true),'Неожиданный SDK fragment; исходник сохранён')
            result=result:sub(1,first-1)..replacement.after..result:sub(last+1)
        end
        assert(vim.fn.sha256(result)==payload.after_sha256,'SDK after SHA не совпал')
        if raw:find('\r\n',1,true) then result=result:gsub('\n','\r\n') end
        temporary=script..'.forge-'..vim.uv.hrtime()
        local target=assert(io.open(temporary,'wb'));local written,err=target:write(result);target:close();assert(written,err)
        assert(vim.uv.fs_chmod(temporary,assert(vim.uv.fs_stat(script)).mode%512))
        assert(vim.uv.fs_rename(temporary,script));temporary=nil
        return 'подготовлен'
    end)
    if temporary then vim.uv.fs_unlink(temporary) end
    if not ok then warn('BashDebugPrepare: '..tostring(why));return end
    vim.notify('Bash debug SDK '..why..' (IDE-128)',vim.log.levels.INFO,{title='Bash debug'})
end
local function sdk_ready(script)
    local _,_,digest=sdk_source(script)
    for _,p in ipairs(sdk_patch().payloads) do if digest==p.after_sha256 then return true end end
    return false
end
local function debugger_path(path)
    if not win then return path end
    -- Это только bundled bashdb paths. Program/cwd/source переводит native adapter.
    path=path:gsub('\\','/')
    return (path:gsub('^(%a):',function(drive) return '/mnt/'..drive:lower() end))
end
local function bash()
    local explicit=vim.g.forge_bash_debug_bash or vim.env.FORGE_BASH_DEBUG_BASH
    if explicit and explicit~='' then return explicit end
    if win then return '/bin/bash' end
    if vim.fn.has('macunix')==1 then
        for _,path in ipairs({'/opt/homebrew/bin/bash','/usr/local/bin/bash'}) do
            if vim.fn.executable(path)==1 then return path end
        end
    end
    return require('forge.bash_host').executable() or '/bin/bash'
end
function M.default_config(path)
    return {name='Current Bash file',type='bashdb',request='launch',program=path,
        cwd=require('forge.bash').root(path),terminalKind='integrated',console='integratedTerminal'}
end
function M.setup(dap)
    vim.api.nvim_create_user_command('BashDebugPrepare',M.prepare,{desc='Явно подготовить проверенный Bash debug SDK',force=true})
    dap.adapters.bashdb=function(callback)
        local node=require('forge.node').executable()
        if not node then warn('Node не найден. Подготовь Node для bash-debug или задай FORGE_NODE_EXECUTABLE.');return end
        local script=entrypoint()
        if not script then
            warn('bash-debug adapter не найден. :MasonInstall bash-debug-adapter или FORGE_BASH_DEBUG_ADAPTER=<extension/out/bashDebug.js>.')
            return
        end
        local checked,ready=pcall(sdk_ready,script)
        if not checked or not ready then
            warn('Bash debug SDK не подготовлен для безопасного Stop. Выполни :BashDebugPrepare или prepare_bash_dap.py --download.')
            return
        end
        local bundle=vim.fs.dirname(vim.fs.dirname(script))
        callback({type='executable',command=node,args={script},
            options={detached=false,initialize_timeout_sec=win and 30 or nil},
            enrich_config=function(config,on_config)
                local terminal=config.terminalKind or (config.console=='internalConsole' and 'debugConsole' or 'integrated')
                local defaults={pathBash=bash(),pathBashdb=debugger_path(bundle..'/bashdb_dir/bashdb'),
                    pathBashdbLib=debugger_path(bundle..'/bashdb_dir'),
                    pathCat=win and '/usr/bin/cat' or vim.fn.exepath('cat'),
                    pathMkfifo=win and '/usr/bin/mkfifo' or vim.fn.exepath('mkfifo'),
                    pathPkill='/usr/bin/pkill',terminalKind=terminal,
                    console=terminal=='debugConsole' and 'internalConsole' or 'integratedTerminal',showDebugOutput=false,
                    trace=false,args={},argsString='',env={BASH_ENV='',ENV=''},
                    cwd=require('forge.bash').root(vim.api.nvim_buf_get_name(0)),program='${file}'}
                on_config(vim.tbl_extend('keep',config,defaults))
            end})
    end
end
return M
