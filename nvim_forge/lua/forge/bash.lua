-- spec: IDE-SH-1 IDE-SH-3. Один workflow для Windows/macOS/Linux.
local M={}
local host=require('forge.bash_host')
local function warn(text) vim.notify(text,vim.log.levels.WARN,{title='Bash'}) end
function M.root(path)
    path=path and path~='' and path or vim.api.nvim_buf_get_name(0)
    return vim.fs.root(path,{'.git'}) or vim.fs.dirname(path) or vim.fn.getcwd()
end
function M.setup_lsp()
    vim.lsp.config('bashls',{
        handlers={['textDocument/rename']=function(err,result,ctx,config)
            -- IDE-058: indexed URI и didOpen URI отличаются %C3%BC/%c3%bc.
            -- Сервер возвращает один edit дважды; повтор стирает соседний текст.
            if result and result.changes then
                local merged={}
                for uri,edits in pairs(result.changes) do
                    local canonical=uri
                    if uri:match('^file:') then
                        local path=vim.uri_to_fname(uri)
                        canonical=vim.uri_from_fname(vim.uv.fs_realpath(path) or path)
                    end
                    merged[canonical]=merged[canonical] or {}
                    for _,edit in ipairs(edits) do
                        local duplicate=false
                        for _,old in ipairs(merged[canonical]) do if vim.deep_equal(old,edit) then duplicate=true;break end end
                        if not duplicate then table.insert(merged[canonical],edit) end
                    end
                end
                result=vim.tbl_extend('force',{},result,{changes=merged})
            end
            return vim.lsp.handlers['textDocument/rename'](err,result,ctx,config)
        end},
        root_dir=function(buf,on_dir)
            local path=vim.api.nvim_buf_get_name(buf)
            if require('forge.node').command('bash-language-server','out/cli.js',path) then on_dir(M.root(path)) end
        end,
        cmd=function(dispatchers,config)
            local cmd=assert(require('forge.node').command('bash-language-server','out/cli.js',config.root_dir),'Bash Language Server не найден')
            cmd[#cmd+1]='start'
            return vim.lsp.rpc.start(cmd,dispatchers)
        end,
    })
    vim.lsp.enable('bashls')
end
function M.run_file(args)
    require('ide').focus_main()
    local path=vim.api.nvim_buf_get_name(0)
    if path=='' or vim.fn.filereadable(path)~=1 then warn('BashRunFile: сначала сохрани script.');return end
    local bash=host.executable()
    if not bash then warn('Bash не найден. Установи native Bash (Windows: Git Bash) или задай FORGE_BASH_EXECUTABLE.');return end
    local script,err=host.path(path,bash)
    if not script then warn(err);return end
    local cmd={bash,'--noprofile','--norc',script}
    vim.list_extend(cmd,args or {})
    local task=require('overseer').new_task({name='Bash: '..vim.fs.basename(path),cmd=cmd,cwd=M.root(path),
        env=host.environment(bash),components={'default'}})
    task:start();require('ide').triggers.fire('task:run')
    return task
end
function M.tests() return require('forge.bats') end
return M
