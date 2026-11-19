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
 assert(vim.wait(tonumber(vim.env.FORGE_UI_WAIT_MS) or 20000,function() return screen():find(text,1,true) or exitcode()~=nil end,10),'Timeout: '..text..'\n'..screen())
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
 if scenario=='cold-default' then
  local marker,installed,system_done=0,{},false
  local subjects={'Git','SDK go','SDK rust','SDK python','SDK node','Rust Tests · cargo-nextest'}
  while true do
   local selected,review,system
   assert(vim.wait(tonumber(vim.env.FORGE_UI_WAIT_MS) or 180000,function()
    local raw=lua('return _G.ui_raw:sub((...)+1)',{marker})
    for _,subject in ipairs(subjects) do if raw:find(subject..': действие',1,true) then selected=subject;return true end end
    review=raw:find('Продолжить установку IDE с этим планом?',1,true)
      and screen():match('[*◆]%s+Продолжить установку IDE с этим планом%?')
    system=not system_done and raw:find('Установить системные зависимости ОС?',1,true)
    return review or system or exitcode()~=nil
   end,20),'Cold setup progress timeout\n'..screen())
   if exitcode()~=nil then break end
   if system then
    system_done=true
    frame('cold-system-dependencies');marker=lua('return #_G.ui_raw');send('\r')
   elseif review then
    frame('cold-review');marker=lua('return #_G.ui_raw');send('\r')
    -- Wait for the completed prompt: a key redraw can repeat its title in raw
    -- output before the next SDK menu. Do not confirm that menu a second time.
    assert(vim.wait(10000,function()
     return exitcode()~=nil or not screen():match('[*◆]%s+Продолжить установку IDE с этим планом%?')
    end,10),'Cold review did not complete\n'..screen())
   else
    frame(selected)
    assert(not installed[selected],'Native install did not make '..selected..' ready; first failure preserved\n'..screen())
    installed[selected]=true;events[#events+1]='install '..selected
    io.stdout:write('Cold install action: '..selected..'\n');io.stdout:flush()
    marker=lua('return #_G.ui_raw');send('\27[B\r')
    local confirmation='Установить '..selected..' этой командой?'
    assert(vim.wait(30000,function() return lua('return _G.ui_raw:sub((...)+1)',{marker}):find(confirmation,1,true) or exitcode()~=nil end,20),'Cold install confirmation missing\n'..screen())
    assert(exitcode()==nil,'Cold setup exited before confirmation')
    marker=lua('return #_G.ui_raw');send('\27[D\r')
   end
  end
 elseif scenario:sub(1,7)=='system-' then
  waitfor('Установить системные зависимости ОС?');frame('system-dependency-choice')
  if scenario=='system-cancel' then send('\27')
  elseif scenario=='system-decline' then send('\27[C\r')
  elseif scenario=='system-install' then send('\r')
  else error('Unknown system dependency scenario') end
 elseif scenario:sub(1,10)=='go-policy-' then
  waitfor('Разрешить Go скачать toolchain для сборки IDE tools?');frame('go-policy-choice')
  if scenario=='go-policy-allow' then send('\27[D\r')
  elseif scenario=='go-policy-deny' then send('\r')
  elseif scenario=='go-policy-cancel' then send('\27')
  else error('Unknown Go policy scenario '..scenario) end
 elseif scenario:sub(1,4)=='sdk-' or scenario:sub(1,8)=='nextest-' then
  local nextest=scenario:sub(1,8)=='nextest-'
  local subject=nextest and 'Rust Tests · cargo-nextest' or 'SDK node'
  local noun=nextest and 'cargo-nextest' or 'SDK'
  if nextest then scenario='sdk-'..scenario:sub(9) end
  local marker=0
  local function fresh(text)
   assert(vim.wait(tonumber(vim.env.FORGE_UI_WAIT_MS) or 20000,function() return lua('return _G.ui_raw'):sub(marker+1):find(text,1,true) or exitcode()~=nil end,10),'SDK timeout '..text..'\n'..screen())
   assert(exitcode()==nil,'SDK early exit '..tostring(exitcode())..'\n'..screen());frame(text)
  end
  local function input(keys) marker=#lua('return _G.ui_raw');send(keys) end
  local function choose(index) input(string.rep('\27[B',index)..'\r') end
  local function menu() fresh(subject..': действие') end
  local function final() fresh('Продолжить установку IDE с этим планом?');input('\r') end
  local function existing(path)
   choose(0);fresh('Каталог '..subject);type_text(path);input('\r')
  end
  local function install(accept)
   choose(1);fresh('Установить '..subject..' этой командой?');input(accept and '\27[D\r' or '\r')
  end
  local function bootstrap(accept)
   choose(1);fresh('Установить менеджер SDK этой командой?');input(accept and '\27[D\r' or '\r')
  end
  local function sdk_after_bootstrap(accept)
   fresh('Установить SDK node этой командой?');input(accept and '\27[D\r' or '\r')
  end
  menu()
  if scenario=='sdk-cancel' then input('\27')
  elseif scenario=='sdk-existing' then existing(assert(vim.env.FORGE_UI_SDK_INPUT));final()
  elseif scenario=='sdk-invalid-existing' then
   existing(assert(vim.env.FORGE_UI_BAD_SDK_INPUT));fresh(noun..' из каталога не готов');menu();existing(assert(vim.env.FORGE_UI_SDK_INPUT));final()
  elseif scenario=='sdk-skip' then choose(2);fresh('Убрать компоненты:');input('\27[D\r');final()
  elseif scenario=='sdk-decline' then install(false);menu();choose(4)
  elseif scenario=='sdk-install' then install(true);final()
  elseif scenario=='sdk-install-appeared' then
   local target=assert(vim.env.FORGE_UI_NEXTEST_TARGET);vim.fn.mkdir(vim.fs.dirname(target),'p')
   assert(vim.uv.fs_copyfile(assert(vim.env.FORGE_UI_NEXTEST_READY),target))
   if vim.fn.has('win32')~=1 then assert(vim.uv.fs_chmod(target,493)) end
   install(true);final()
  elseif scenario=='sdk-install-conflict' then
   local target=assert(vim.env.FORGE_UI_NEXTEST_TARGET);vim.fn.mkdir(vim.fs.dirname(target),'p');vim.fn.writefile({'user file'},target)
   install(true);fresh('target уже существует и не готов');menu();choose(4)
  elseif scenario=='sdk-install-cancel' then install(true);fresh('Продолжить установку IDE с этим планом?');input('\27[D\r')
  elseif scenario=='sdk-retry' then install(true);menu();install(true);final()
  elseif scenario=='sdk-noop' then install(true);fresh('SDK пока не готов');menu();choose(4)
  elseif scenario=='sdk-no-manager' then
   choose(1)
   if vim.fn.has('win32')==1 or vim.fn.has('macunix')==1 then fresh('Установить менеджер SDK этой командой?');input('\r') else fresh('не найден') end
   menu();choose(4)
  elseif scenario=='sdk-bootstrap-decline' then bootstrap(false);menu();choose(4)
  elseif scenario=='sdk-bootstrap-install' then bootstrap(true);sdk_after_bootstrap(true);final()
  elseif scenario=='sdk-bootstrap-sdk-decline' then bootstrap(true);sdk_after_bootstrap(false);menu();choose(4)
  elseif scenario=='sdk-bootstrap-retry' then bootstrap(true);menu();bootstrap(true);sdk_after_bootstrap(true);final()
  elseif scenario=='sdk-bootstrap-noop' then bootstrap(true);fresh('менеджер SDK не найден');menu();choose(4)
  elseif scenario=='sdk-bootstrap-cancel' then choose(1);fresh('Установить менеджер SDK этой командой?');input('\27');menu();choose(4)
  elseif scenario=='sdk-bootstrap-install-cancel' then bootstrap(true);sdk_after_bootstrap(true);fresh('Продолжить установку IDE с этим планом?');input('\27[D\r')
  elseif scenario=='sdk-inside-kit' then existing(assert(vim.env.FORGE_UI_BAD_SDK_INPUT));fresh('SDK должен находиться вне');menu();choose(4)
  else error('Unknown SDK scenario '..scenario) end
 elseif scenario:sub(1,4)=='git-' then
  local marker=0
  local function fresh(text)
   local deadline=vim.uv.hrtime()+20e9
   repeat
    if lua('return _G.ui_raw'):sub(marker+1):find(text,1,true) then frame(text);return end
    assert(exitcode()==nil,'Git early exit '..tostring(exitcode())..'\n'..screen())
    vim.wait(20)
   until vim.uv.hrtime()>=deadline
   error('Git timeout '..text..'\n'..screen())
  end
  local function input(keys) marker=#lua('return _G.ui_raw');send(keys) end
  local function choose(index) input(string.rep('\27[B',index)..'\r') end
  local function menu() fresh('Git: действие') end
  local function install(accept)
   choose(1);fresh('Установить Git этой командой?');input(accept and '\27[D\r' or '\r')
  end
  menu()
  if scenario=='git-existing' then
   choose(0);fresh('Каталог Git');type_text(assert(vim.env.FORGE_UI_GIT_INPUT));input('\r')
   fresh('Продолжить установку IDE с этим планом?');input('\r')
  elseif scenario=='git-cancel' then choose(3)
  elseif scenario=='git-decline' then install(false);menu();choose(3)
  elseif scenario=='git-install' then install(true);fresh('Продолжить установку IDE с этим планом?');input('\r')
  elseif scenario=='git-noop' then install(true);fresh('Git пока не готов');menu();choose(3)
  else error('Unknown Git scenario '..scenario) end
 elseif scenario=='default' then
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
 assert(vim.wait(tonumber(vim.env.FORGE_UI_EXIT_MS) or 30000,function() return exitcode()~=nil end,10),'UI exit timeout\n'..screen())
 assert(exitcode()==(tonumber(vim.env.FORGE_UI_EXPECTED_EXIT) or (scenario=='cancel' and 130 or 0)),'UI exit '..tostring(exitcode())..'\n'..screen())
 frame('done')
end,debug.traceback)
vim.fn.writefile({vim.json.encode({ok=ok,error=not ok and err or nil,exit=exitcode(),events=events,frames=frames})},assert(vim.env.FORGE_INSTALL_UI_REPORT))
if not ok then pcall(lua,'vim.fn.jobstop(_G.ui_job)') end
pcall(vim.rpcnotify,host,'nvim_command','qa!')
assert(vim.fn.jobwait({host},5000)[1]==0,'Host exit failed')
if not ok then error(err) end
