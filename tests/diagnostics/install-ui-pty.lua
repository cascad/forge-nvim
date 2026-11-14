-- spec: IDE-BOOT-13. Native cliclack в настоящем UI-attached PTY.
local command=vim.json.decode(assert(vim.env.FORGE_INSTALL_UI_COMMAND))
local scenario=assert(vim.env.FORGE_UI_SCENARIO)
local host=vim.fn.jobstart({vim.v.progpath,'--embed','-u','NONE','-i','NONE'},{rpc=true})
assert(host>0)
vim.rpcrequest(host,'nvim_ui_attach',tonumber(vim.env.FORGE_UI_COLUMNS) or 100,36,{rgb=true})
local function lua(code,args) return vim.rpcrequest(host,'nvim_exec_lua',code,args or {}) end
local job=lua([[local command=...;_G.ui_exit=nil;_G.ui_raw=''
 _G.ui_job=vim.fn.jobstart(command,{term=true,on_stdout=function(_,data) _G.ui_raw=_G.ui_raw..table.concat(data,'\n') end,
 on_exit=function(_,value) _G.ui_exit=value end});return _G.ui_job]],{command})
assert(job>0)
local function exitcode() local code=lua('return _G.ui_exit');return code~=vim.NIL and code or nil end
local function lines() return lua('return vim.api.nvim_buf_get_lines(0,0,-1,false)') end
local function screen() return table.concat(lines(),'\n') end
local frames,events={},{}
local function frame(title) frames[#frames+1]={title=title,lines=lines(),raw=lua('return _G.ui_raw')} end
local function waitfor(text)
 assert(vim.wait(20000,function() return screen():find(text,1,true) or exitcode()~=nil end,10),'Timeout: '..text..'\n'..screen())
 assert(exitcode()==nil,'Early exit '..tostring(exitcode())..': '..screen())
 events[#events+1]=text
end
local function send(keys) lua('return vim.fn.chansend(_G.ui_job,...)',{keys}) end
local function type_text(value)
 -- ConPTY synthesizes Alt+numpad for characters absent from the host layout;
 -- console::read_key cannot observe their key-up UnicodeChar. Use ConPTY's
 -- native Win32 input records to model actual Unicode key-downs in this driver.
 if vim.fn.has('win32')==1 then
  value=value:gsub("'",'\27[0;0;39;1;0;1_')
 end
 send(value)
end
local ok,err=xpcall(function()
 if scenario=='default' then
  waitfor('Как установить Fride?');frame('welcome');send('\r')
  waitfor('Завершить предпросмотр?');frame('review');send('\r')
 elseif scenario=='cancel' then
  waitfor('Компоненты');frame('components');send('\27')
 elseif scenario=='custom-back' or scenario=='custom-run' or scenario=='custom-core' then
  waitfor('Компоненты');frame('components')
  if scenario=='custom-core' then
   for _=1,7 do send(' ');send('\27[B') end
  else send(' ') end
  send('\r')
  waitfor('Куда установить комплект?');send('\27')
  waitfor('Вернуться или отменить?');frame('back-menu');send('\r')
  waitfor('Компоненты');frame('components-back');send('\r')
  waitfor('Куда установить комплект?');send('\r')
  waitfor('Команда fride');send('\r')
  waitfor(scenario~='custom-back' and 'Начать установку?' or 'Завершить предпросмотр?');frame('review')
  send('\r')
 elseif scenario=='custom-path' then
  waitfor('Компоненты');send('\r')
  waitfor('Куда установить комплект?');send('\27[B');send('\r')
  waitfor('Папка комплекта');type_text(assert(vim.env.FORGE_UI_INSTALL_INPUT));send('\r')
  waitfor('Команда fride');send('\27[B');send('\r')
  waitfor('Каталог команды fride');type_text(assert(vim.env.FORGE_UI_COMMAND_INPUT));send('\r')
  waitfor('Завершить предпросмотр?');frame('custom-paths-review');send('\r')
 else error('Unknown scenario '..scenario) end
 assert(vim.wait(30000,function() return exitcode()~=nil end,10),'UI exit timeout\n'..screen())
 assert(exitcode()==(scenario=='cancel' and 130 or 0),'UI exit '..tostring(exitcode())..'\n'..screen())
 frame('done')
end,debug.traceback)
vim.fn.writefile({vim.json.encode({ok=ok,error=not ok and err or nil,exit=exitcode(),events=events,frames=frames})},assert(vim.env.FORGE_INSTALL_UI_REPORT))
if not ok then pcall(lua,'vim.fn.jobstop(_G.ui_job)') end
pcall(vim.rpcnotify,host,'nvim_command','qa!')
assert(vim.fn.jobwait({host},5000)[1]==0,'Host exit failed')
if not ok then error(err) end
