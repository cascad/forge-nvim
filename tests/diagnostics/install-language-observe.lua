-- Installed Default acceptance; existing editor_rpc/editor_process, no tool substitutes.
local base=assert(arg[1],'Expected owned observation directory')
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local project=base..'/project'
vim.fn.mkdir(project,'p')
local function write(path,lines)
    vim.fn.mkdir(vim.fs.dirname(path),'p');assert(vim.fn.writefile(lines,path)==0)
end
write(project..'/go/go.mod',{'module fride.local/installed','go 1.26.0'})
write(project..'/rust/Cargo.toml',{'[package]','name="fride_installed"','version="0.1.0"','edition="2021"'})
write(project..'/node/package.json',{'{"private":true}'})
local cases={
    {id='go',path='go/main.go',server='gopls',invalid={'package main','func main() { var value int = "bad"; _ = value }'},valid={'package main','func main(){println( 1 )}'},formatter='gofumpt'},
    {id='rust',path='rust/src/main.rs',server='rust_analyzer',invalid={'fn main() { let value: i32 = "bad"; println!("{}",value); }'},valid={'fn main( ){ let value=1; println!( "{}",value ); }'},formatter='rustfmt'},
    {id='python',path='python/main.py',server='pyright',invalid={'value: int = "bad"','print(value)'},valid={'value=1','print(  value )'},formatter='ruff_format'},
    {id='node',path='node/main.js',server='ts_ls',invalid={'// @ts-check','/** @type {number} */','let value = "bad";','console.log(value);'},valid={'const   value={foo:1};console.log(value.foo);'},formatter='prettier'},
    {id='bash',path='bash/main.sh',server='bashls',invalid={'#!/usr/bin/env bash','echo "$missing_value"'},valid={'#!/usr/bin/env bash','echo    hello'},formatter='shfmt'},
    {id='sql',path='sql/main.sql',server='sqruff',invalid={'select from;'},valid={'select  1 as value;'},formatter='sqruff'},
}
for _,case in ipairs(cases) do write(project..'/'..case.path,case.invalid) end
local initialized=vim.system({'git','init','-q',project},{text=true}):wait(5000)
assert(initialized.code==0,initialized.stderr)
local artifacts=base..'/observed';vim.fn.mkdir(artifacts,'p')
local rpc=require('editor_rpc').start({vim.v.progpath,'--headless','--embed','-i','NONE',
    '--cmd','lua vim.opt.rtp:prepend(vim.env.FRIDE_CONFIG)','-u',vim.env.FRIDE_CONFIG..'/init.lua'},
    {cwd=project,env=vim.fn.environ(),clear_env=true,artifacts=artifacts,timeout=780000})
local function lua(code,args) return rpc:request('nvim_exec_lua',{code,args or {}}) end
local function wait_for(name,predicate,timeout)
    local deadline,last=vim.uv.hrtime()+timeout*1000000
    repeat
        local ok,value=pcall(predicate)
        if ok and value and value~=vim.NIL then return value end
        if not ok then last=tostring(value) end
        vim.wait(30)
    until vim.uv.hrtime()>=deadline
    error(name..(last and (': '..last) or ''))
end
local info={cases={}}
local ok,err=xpcall(function()
    rpc:request('nvim_ui_attach',{120,40,{rgb=true,ext_linegrid=true}})
    wait_for('startup',function() return lua('return vim.v.vim_did_enter==1') end,5000)
    info.startup=lua([[return {app=vim.env.NVIM_APPNAME,config=vim.env.FRIDE_CONFIG,runtime=vim.env.FRIDE_RUNTIME,errmsg=vim.v.errmsg}]])
    assert(info.startup.app=='fride' and info.startup.errmsg=='',vim.inspect(info.startup))
    for _,case in ipairs(cases) do
        if not vim.env.FORGE_INSTALLED_LANGUAGE_CASE or case.id==vim.env.FORGE_INSTALLED_LANGUAGE_CASE then
            local result={id=case.id};local started=vim.uv.hrtime()
            result.ok,result.error=xpcall(function()
                lua([[vim.cmd.edit(vim.fn.fnameescape(...))]],{project..'/'..case.path})
                result.client=wait_for(case.id..' initialized LSP',function()
                    return lua([[local name=...;for _,c in ipairs(vim.lsp.get_clients({bufnr=0})) do
                        if c.name==name and c.initialized then return {id=c.id,name=c.name,root=c.root_dir,command=type(c.config.cmd)=='table' and c.config.cmd or 'native function'} end end]],{case.server})
                end,60000)
                result.diagnostics=wait_for(case.id..' real diagnostics',function()
                    return lua([[local entries=vim.diagnostic.get(0);return #entries>0 and entries or false]])
                end,60000)
                local available=lua([[return require('conform').get_formatter_info(...,0).available]],{case.formatter})
                assert(available,case.id..' actual formatter unavailable')
                lua([[local lines=...;vim.api.nvim_buf_set_lines(0,0,-1,false,lines);vim.cmd('Format');vim.cmd('write')]],{case.valid})
                result.formatted=lua('return vim.api.nvim_buf_get_lines(0,0,-1,false)')
                assert(table.concat(result.formatted,'\n')~=table.concat(case.valid,'\n'),case.id..' formatter did not change input')
                wait_for(case.id..' diagnostics cleared after correction',function()
                    return lua([[for _,d in ipairs(vim.diagnostic.get(0)) do if d.severity==vim.diagnostic.severity.ERROR then return false end end;return true]])
                end,60000)
            end,debug.traceback)
            result.seconds=(vim.uv.hrtime()-started)/1e9;info.cases[#info.cases+1]=result
            io.stdout:write(case.id..': '..(result.ok and 'PASS' or 'FAIL')..'\n');io.stdout:flush()
            write(artifacts..'/report.json',{vim.json.encode(info)})
            if not result.ok then io.stdout:write(tostring(result.error)..'\n');io.stdout:flush() end
        end
    end
    for _,case in ipairs(info.cases) do assert(case.ok,case.error) end
    assert(#rpc.api_errors==0,vim.inspect(rpc.api_errors))
end,debug.traceback)
info.ok,info.error=ok,not ok and tostring(err) or nil
local observed,state=pcall(lua,[[return {file=vim.api.nvim_buf_get_name(0),clients=vim.tbl_map(function(c) return {name=c.name,initialized=c.initialized} end,vim.lsp.get_clients()),messages=vim.api.nvim_exec2('messages',{output=true}).output}]])
if observed then info.state=state end
write(artifacts..'/report.json',{vim.json.encode(info)})
write(artifacts..'/screen.txt',rpc:screen_lines())
write(artifacts..'/stderr.txt',vim.split(table.concat(rpc.stderr),'\n'))
local stopped,cleanup=pcall(require('editor_process').stop,rpc,artifacts,info.error)
if not ok or not stopped or not cleanup.ok or cleanup.exit_code~=0 then
    io.stderr:write(tostring(err or cleanup)..'\n');vim.cmd('cquit 1')
end
vim.cmd('qa!')
