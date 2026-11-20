-- spec: IDE-BOOT-48. Actual Node/LSP/native exports; no LSP command substitution.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local win=vim.fn.has('win32')==1
local suffix,sep=win and '.exe' or '',win and ';' or ':'
local py=vim.env.FORGE_E2E_PYTHON_DEPS or root..'/.tests/python-deps'
local bash=vim.env.FORGE_E2E_BASH_DEPS or root..'/.tests/bash-deps'
local sql=vim.env.FORGE_E2E_SQL_DEPS or root..'/.tests/sql-deps'
local function read(path) return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end
local pm,bm=read(py..'/manifest.json'),read(bash..'/manifest.json')
local binaries={shellcheck=bash..'/bin/shellcheck'..suffix,shfmt=bash..'/bin/shfmt'..suffix,sqruff=sql..'/bin/sqruff'..suffix}
local function json(path,data)
    vim.fn.mkdir(vim.fs.dirname(path),'p');assert(vim.fn.writefile({vim.json.encode(data)},path)==0)
end
local function copy(source,target)
    vim.fn.mkdir(vim.fs.dirname(target),'p');assert(vim.uv.fs_copyfile(source,target))
    if not win then assert(vim.uv.fs_chmod(target,493)) end
end
local function check(name,fn)
    if vim.env.FORGE_EXPORT_CASE and not name:find(vim.env.FORGE_EXPORT_CASE,1,true) then return end
    T.check('IDE-BOOT-48 '..name,function()
        local e
        local ok,err=xpcall(function()
            e=require('editor').start(root,{timeout=180000,site=py..'/site',prepare=function(project,env,runtime)
                local path={}
                for _,dir in ipairs(vim.split(env.PATH or '',sep,{plain=true})) do
                    if vim.fn.filereadable(dir..'/node'..suffix)~=1 then path[#path+1]=dir end
                end
                env.PATH=table.concat(path,sep)
                env.FORGE_NODE_EXECUTABLE,env.FORGE_NODE_TOOLS,env.FORGE_PYTHON_PATH='','',''
                env.SHELLCHECK_PATH,env.SHFMT_PATH=nil,nil
                local data=env.XDG_DATA_HOME..'/nvim_forge'..(win and '-data' or '')
                local mason=data..'/mason'
                for id,source in pairs(binaries) do
                    copy(source,mason..'/packages/'..id..'/'..id..suffix)
                    local alias=id..(win and '.cmd' or '')
                    if win then vim.fn.mkdir(mason..'/bin','p');vim.fn.writefile({'@echo off','exit /b 97'},mason..'/bin/'..alias)
                    else copy(source,mason..'/bin/'..alias) end
                    json(mason..'/packages/'..id..'/mason-receipt.json',{schema_version='2.0',name=id,
                        source={type='registry+v1',id='pkg:github/fixture/'..id..'@v1'},links={bin={[alias]=id..suffix}}})
                end
                for _,id in ipairs({'bash','sql'}) do
                    local source=(id=='bash' and bash or sql)..'/site/parser/'..id..'.so'
                    vim.fn.mkdir(data..'/site/parser','p');assert(vim.uv.fs_copyfile(source,data..'/site/parser/'..id..'.so'))
                end
                json(project..'/.fride/tools.json',{tools={node=bm.node,python=pm.host_python,
                    pyright=py..'/tools/node_modules/pyright/langserver.index.js',
                    ['bash-language-server']=bash..'/tools/node_modules/bash-language-server/out/cli.js'}})
                vim.fn.writefile({'value: int = "bad"','print(value)'},project..'/main.py')
                vim.fn.writefile({'#!/usr/bin/env bash','echo "$not_defined"'},project..'/main.sh')
                vim.fn.writefile({'select from;'},project..'/main.sql')
                vim.fn.writefile({'[sqruff]','dialect = ansi','[sqruff:rules:capitalisation.keywords]',
                    'capitalisation_policy = upper'},project..'/.sqruff')
                json(runtime..'/native-entrypoints.json',{mason=mason,binaries=binaries})
            end})
            e:wait('editor ready',function() return e:lua('return _G.forge_e2e_observed') end,12000)
            e:lua([[vim.lsp.log.set_level('debug')]])
            fn(e)
            T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
        end,debug.traceback)
        if e then
            local observed,state=pcall(e.lua,e,[[return {diagnostics=vim.diagnostic.get(0),clients=vim.tbl_map(function(c)
                return {name=c.name,initialized=c.initialized,root=c.root_dir,settings=c.settings}
                end,vim.lsp.get_clients()),lsp_log=vim.lsp.log.get_filename()}]])
            if observed then
                json(e.dir..'/language-state.json',state)
                if vim.fn.filereadable(state.lsp_log)==1 then vim.uv.fs_copyfile(state.lsp_log,e.dir..'/lsp.log') end
            end
            e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n')
            local stopped,why=pcall(e.stop,e,not ok and err or nil)
            if not stopped then ok=false;err=tostring(err or '')..'\n'..tostring(why) end
        end
        assert(ok,err)
    end)
end
local function open(e,file,server)
    e:lua([[vim.cmd.edit(vim.fn.fnameescape(...))]],{e.project..'/'..file})
    e:wait(server..' initialized',function() return e:lua([[local name=...;for _,c in ipairs(vim.lsp.get_clients({bufnr=0})) do
        if c.name==name and c.initialized then return true end end;return false]],{server}) end,30000)
end
check('Pyright uses selected Node outside PATH and keeps Python selection',function(e)
    open(e,'main.py','pyright')
    e:wait('actual Pyright type diagnostics',function() return e:lua('return #vim.diagnostic.get(0)>0') end,30000)
    local data=e:lua([[local c=vim.lsp.get_clients({name='pyright',bufnr=0})[1]
        return {node=vim.fn.exepath('node'),cmd=type(c.config.cmd),python=c.config.settings.python.pythonPath,
            selected=require('forge.node').executable(),entry=require('forge.node').script('pyright','langserver.index.js')} ]])
    T.eq(data.node,'');T.eq(data.cmd,'function');T.eq(vim.fs.normalize(data.python),vim.fs.normalize(pm.host_python))
    T.eq(vim.fs.normalize(data.selected),vim.fs.normalize(bm.node));assert(data.entry:find('langserver.index.js',1,true))
end)
check('Bash native exports publish ShellCheck diagnostics and format',function(e)
    open(e,'main.sh','bashls')
    e:wait('ShellCheck SC2154',function() return e:lua([[for _,d in ipairs(vim.diagnostic.get(0)) do
        if tostring(d.code):find('2154',1,true) then return true end end;return false]]) end,30000)
    local info=e:lua([[local c=vim.lsp.get_clients({name='bashls',bufnr=0})[1]
        return {shellcheck=c.config.settings.bashIde.shellcheckPath,shfmt=c.config.settings.bashIde.shfmt.path} ]])
    if win then assert(info.shellcheck:lower():match('shellcheck%.exe$') and info.shfmt:lower():match('shfmt%.exe$')) end
    e:lua([[vim.api.nvim_buf_set_lines(0,0,-1,false,{'#!/usr/bin/env bash','echo    hello'});vim.cmd('Format')]])
    assert(e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('echo hello',1,true)~=nil]]))
end)
check('Sqruff native export works and external choice stays unchanged',function(e)
    open(e,'main.sql','sqruff')
    e:wait('actual Sqruff parser diagnostics',function() return e:lua('return #vim.diagnostic.get(0)>0') end,30000)
    local result=e:lua([[local p=require('forge.tool_paths');local sql=require('forge.sql_language').tool('sqruff')
        local external=...;return {sql=sql,external=p.mason_native('sqruff',external)}]],{binaries.sqruff})
    T.eq(result.external,binaries.sqruff)
    if win then assert(result.sql:lower():match('sqruff%.exe$')) end
    e:lua([[vim.api.nvim_buf_set_lines(0,0,-1,false,{'select  1 as value;'});vim.cmd('Format')]])
    assert(e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('SELECT',1,true)~=nil]]))
end)
T.finish()
