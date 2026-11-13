-- spec: IDE-SH-5. Официальный Node adapter сам использует WSL на Windows.
local M={}
local win=vim.fn.has('win32')==1
local function file(path) return path and path~='' and vim.fn.filereadable(path)==1 end
local function warn(text) vim.notify(text,vim.log.levels.WARN,{title='Bash debug'}) end
local function entrypoint()
    local explicit=vim.g.forge_bash_debug_adapter or vim.env.FORGE_BASH_DEBUG_ADAPTER
    if explicit and explicit~='' then return file(explicit) and explicit or nil end
    local path=vim.fs.joinpath(vim.fn.stdpath('data'),'mason/packages/bash-debug-adapter/extension/out/bashDebug.js')
    return file(path) and path or nil
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
    dap.adapters.bashdb=function(callback)
        local node=require('forge.node').executable()
        if not node then warn('Node не найден. Подготовь Node для bash-debug или задай FORGE_NODE_EXECUTABLE.');return end
        local script=entrypoint()
        if not script then
            warn('bash-debug adapter не найден. :MasonInstall bash-debug-adapter или FORGE_BASH_DEBUG_ADAPTER=<extension/out/bashDebug.js>.')
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
