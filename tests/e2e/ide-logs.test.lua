-- spec: IDE-LOG-1/2/3/4. Настоящий Forge, штатные сообщения и keyboard UI.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local e,report
local function text()
  return e:lua([[for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].filetype=='forge-logs' then return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n') end
  end;return '']])
end
local function keys(value) e:input(value) end
local function has(needle) return text():find(needle,1,true)~=nil end
local function open(source)
  assert(e:lua('return vim.fn.exists(":ForgeLogs")')==2,'IDE-106: общая консоль :ForgeLogs отсутствует')
  keys(source and ':ForgeLogs '..source..'<CR>' or ' wi')
  e:wait('IDE Logs focus',function() return e:current_ft()=='forge-logs' end)
end
local function check(name,fn,prepare)
  if vim.env.FORGE_LOG_CASE and not name:find(vim.env.FORGE_LOG_CASE,1,true) then return end
  T.check(name,function()
    report={case=name}
    local ok,err=xpcall(function()
      e=require('editor').start(root,{prepare=prepare})
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/ide-logs.test.lua',e.dir..'/ide-logs.test.lua'))
      e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      fn()
      report.text=text()
      report.installs=e:lua('return vim.g.forge_e2e_installs');T.eq(report.installs,0)
      T.eq(e:lua('return package.loaded.dap and package.loaded.dap.session()~=nil or false'),false)
    end,debug.traceback)
    if e then
      report.ok=ok;report.error=not ok and tostring(err) or nil
      pcall(function() report.last=text() end)
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/ide-logs.json');e:snapshot('ide-logs')
      io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,issue=pcall(e.stop,e,not ok and err or nil);assert(stopped,issue)
      assert(e.rpc.exit_code==0 and e.rpc.exit_signal==0 and #e.rpc.api_errors==0,'Native root/API failure')
    end
    e=nil;assert(ok,err)
  end)
end

check('IDE-LOG-2 real missing Node debug remains in console',function()
  keys(':edit app.js<CR>');e:wait('JS buffer',function() return e:current_ft()=='javascript' end)
  e:lua([[vim.g.forge_node_executable=vim.fn.getcwd()..'/missing-node';vim.g.forge_js_debug_server=vim.fn.getcwd()..'/missing-js-debug']])
  keys('<F5>')
  e:wait('real missing Node warning',function()
    for _,n in ipairs(e.rpc.notifications) do if n.message:find('Node.js не найден',1,true) then return true end end
  end)
  open()
  e:wait('missing tool and action retained',function() return has('Node.js не найден') and has('PATH') end)
  assert(text():match('%d%d:%d%d:%d%d'),'notification timestamp missing')
  keys('q');e:wait('code restored',function() return e:current_ft()=='javascript' end)
  open();assert(has('Node.js не найден'))
end,function(project)
  vim.fn.writefile({'console.log("LOG_PROBE");'},project..'/app.js')
  vim.fn.writefile({'{"name":"forge-log-test","version":"1.0.0"}'},project..'/package.json')
end)

check('IDE-LOG-1 IDE-LOG-3 filters report help zoom and reopen',function()
  keys(':edit file_one.txt<CR>');e:wait('code',function() return e:current_ft()=='text' end)
  e:lua([[vim.notify('LOG_INFO_VISIBLE',vim.log.levels.INFO,{title='Format'})
    vim.notify('LOG_WARN_VISIBLE',vim.log.levels.WARN,{title='Node'})]])
  open();assert(has('LOG_INFO_VISIBLE') and has('LOG_WARN_VISIBLE'))
  keys('v');e:wait('WARN filter',function() return not has('LOG_INFO_VISIBLE') and has('LOG_WARN_VISIBLE') end)
  keys('f');e:wait('native text input is visible',function()
    local mode=e.rpc:request('nvim_get_mode',{}).mode:sub(1,1)
    return (mode=='c' or mode=='i') and table.concat(e.rpc:screen_lines(),'\n'):find('IDE Logs: текст >',1,true)~=nil
  end)
  keys('NOT_A_LOG_MATCH<CR>');e:wait('empty filtered result',function() return has('Нет совпадений') end)
  keys('c');e:wait('filters reset',function() return has('LOG_INFO_VISIBLE') and has('LOG_WARN_VISIBLE') end)
  keys('y');e:wait('report copied',function() return e:lua([[return vim.fn.getreg('"')]]):find('LOG_WARN_VISIBLE',1,true)~=nil end)
  report.copy=e:lua([[return vim.fn.getreg('"')]])
  keys('?');e:wait('common help',function() return e:current_ft()=='forge-panel-help' end)
  keys('q');e:wait('help returns to logs',function() return e:current_ft()=='forge-logs' end)
  local ordinary=e:lua('return vim.api.nvim_get_current_win()')
  keys(' wz');e:wait('zoom',function() return e:lua('return vim.api.nvim_win_get_config(0).relative')~='' end)
  keys(' wz');e:wait('restore',function() return e:lua('return vim.api.nvim_get_current_win()')==ordinary end)
  keys('q');e:wait('hidden logs/code',function() return e:current_ft()=='text' end)
  open();assert(has('LOG_WARN_VISIBLE'))
  T.eq(e:lua('return vim.fn.readfile("file_one.txt")[1]'),'first file')
end)

check('IDE-LOG-2 early and native messages are forwarded',function()
  assert(e:lua('return vim.fn.execute("messages")'):find('LOG_EARLY_BEFORE_LAZY',1,true),'native history lost early notification')
  local height=e:lua('return vim.o.cmdheight')
  e:lua([[vim.api.nvim_echo({{'LOG_NATIVE_ECHO','WarningMsg'}},true,{})]])
  open();e:wait('early/native messages in console',function() return has('LOG_EARLY_BEFORE_LAZY') and has('LOG_NATIVE_ECHO') end)
  T.eq(e:lua('return vim.o.cmdheight'),height)
  assert(e:lua('return vim.fn.execute("messages")'):find('LOG_NATIVE_ECHO',1,true),'console swallowed native message')
end,function(_,env)
  local path=env.FORGE_E2E_CONFIG..'/lua/config/options.lua'
  local f=assert(io.open(path,'rb'));local raw=f:read('*a');f:close()
  f=assert(io.open(path,'wb'));assert(f:write("vim.notify('LOG_EARLY_BEFORE_LAZY',vim.log.levels.WARN,{title='Setup'})\n"..raw));assert(f:close())
end)
T.finish()
