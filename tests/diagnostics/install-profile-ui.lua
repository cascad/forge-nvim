-- spec: IDE-BOOT-10. Настоящий PTY и native клавиатурное меню, без UI mocks.
local command=vim.json.decode(assert(vim.env.FORGE_INSTALL_UI_COMMAND))
local action=assert(vim.env.FORGE_INSTALL_UI_ACTION)
local events={}
-- Терминал живёт в настоящем UI-attached Neovim, как в рабочем редакторе.
local host=vim.fn.jobstart({vim.v.progpath,'--embed','-u','NONE','-i','NONE'},{rpc=true})
assert(host>0,'UI host failed')
vim.rpcrequest(host,'nvim_ui_attach',100,32,{rgb=true})
local function lua(code,args) return vim.rpcrequest(host,'nvim_exec_lua',code,args or {}) end
local function exitcode() local value=lua('return _G.install_profile_exit');return value~=vim.NIL and value or nil end
local function lines() return lua('return vim.api.nvim_buf_get_lines(0,0,-1,false)') end
local function text() return table.concat(lines(),'\n') end
local job=lua([[local command=...;_G.install_profile_exit=nil
 _G.install_profile_job=vim.fn.jobstart(command,{term=true,on_exit=function(_,value) _G.install_profile_exit=value end})
 return _G.install_profile_job]],{command})
assert(job>0,'PTY child failed to start')
local function send(keys) lua('return vim.fn.chansend(_G.install_profile_job,...)',{keys}) end
local ok,err=xpcall(function()
    assert(vim.wait(15000,function() return text():find('Select components:',1,true) or exitcode()~=nil end,10),'Menu timeout')
    assert(exitcode()==nil,'Menu exited before input: '..text())
    events[#events+1]='menu ready'
    if action=='cancel' then
        send('q')
    else
        send(' ') -- Core остаётся обязательным.
        send('\27[B') -- Настоящая стрелка вниз через PTY.
        assert(vim.wait(3000,function() return text():find('> [x] Go',1,true)~=nil end,10),'Go focus missing')
        send('kj') -- Дополнительная навигация Vim keys.
        send(' ')
        assert(vim.wait(3000,function() return text():find('> [ ] Go',1,true)~=nil end,10),'Go toggle missing')
        events[#events+1]='Go unchecked'
        send('\r')
    end
    assert(vim.wait(15000,function() return exitcode()~=nil end,10),'PTY exit timeout')
    assert(exitcode()==(action=='cancel' and 1 or 0),'Unexpected exit '..tostring(exitcode())..': '..text())
end,debug.traceback)
vim.fn.writefile({vim.json.encode({ok=ok,error=not ok and err or nil,exit=exitcode(),events=events,lines=lines()})},assert(vim.env.FORGE_INSTALL_UI_REPORT))
if not ok then pcall(lua,'vim.fn.jobstop(_G.install_profile_job)') end
pcall(vim.rpcnotify,host,'nvim_command','qa!')
assert(vim.fn.jobwait({host},5000)[1]==0,'UI host did not exit cleanly')
if not ok then error(err) end
