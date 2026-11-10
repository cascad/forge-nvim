-- spec: IDE-PANEL-12. Native PTY/float и клавиатура, без fake plugin state.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function state(e)
  return e:lua([[local windows={};for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b=vim.api.nvim_win_get_buf(w);windows[#windows+1]={win=w,buf=b,bt=vim.bo[b].buftype,ft=vim.bo[b].filetype,
      floating=vim.api.nvim_win_get_config(w).relative~='',main=require('ide.state').is_main_window(w)} end
    return {windows=windows,current=vim.api.nvim_get_current_win(),selected=require('ide.activities').find_code_window() or false}]])
end
local function check(name,fn)
  if vim.env.FORGE_CODE_CASE and not name:find(vim.env.FORGE_CODE_CASE,1,true) then return end
  T.check('IDE-PANEL-12 '..name,function()
    local e,observed
    local ok,err=xpcall(function()
      e=require('editor').start(root,{timeout=20000})
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/code-focus.test.lua',e.dir..'/code-focus.test.lua'))
      e:input(':edit file_one.txt<CR>')
      e:wait('Исходный файл',function() return e:current_file():sub(-12)=='file_one.txt' end)
      observed={before=state(e)}
      fn(e,observed)
      observed.after=state(e)
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
      for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    end,debug.traceback)
    if e then
      observed=observed or {};local got,last=pcall(state,e);if got then observed.last=last end
      observed.error=not ok and tostring(err) or nil
      vim.fn.writefile({vim.json.encode(observed)},e.dir..'/code-focus.json')
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n')
      e:stop(not ok and tostring(err) or nil)
      T.eq(e.rpc.exit_code,0);T.eq(e.rpc.exit_signal,0);T.eq(e.rpc.api_errors,{})
    end
    assert(ok,err)
  end)
end
local function terminal(e)
  return e:lua([[vim.cmd.enew();local b=vim.api.nvim_get_current_buf();local w=vim.api.nvim_get_current_win()
    local job=vim.fn.jobstart({vim.v.progpath,'--clean','--headless','-c',
      'lua vim.defer_fn(function() vim.cmd("qa!") end,60000)'},{term=true})
    assert(job>0 and vim.fn.jobwait({job},0)[1]==-1);return {job=job,pid=vim.fn.jobpid(job),buf=b,win=w}]])
end
local function alive(e,t)
  assert(e:lua([[local t=...;return vim.api.nvim_win_is_valid(t.win) and vim.api.nvim_win_get_buf(t.win)==t.buf
    and vim.fn.jobwait({t.job},0)[1]==-1 and vim.fn.jobpid(t.job)==t.pid]],{t}),'PTY/window/process заменён или остановлен')
end
local function passive(e)
  local before=state(e)
  local got=e:lua([[local a=require('ide.activities');return {selected=a.find_code_window() or false,focused=a.focus_code_window()}]])
  local after=state(e)
  T.eq(got,{selected=false,focused=false},'Без main focus-only возвращает false')
  T.eq(after,before,'Focus-only не создаёт окно и не двигает фокус')
end
check('terminal первым: Debug View возвращает в существующий код',function(e,o)
  o.terminal=terminal(e)
  o.code=e:lua([[return require('ide.state').find_main_window()]])
  e:input('<F7>')
  e:wait('F7 выбрал существующий main',function() return e:lua('return vim.api.nvim_get_current_win()')==o.code end)
  e:input(':edit file_one.txt<CR>');e:wait('Файл в новом main',function() return e:current_file():sub(-12)=='file_one.txt' end)
  o.code=e:lua('return vim.api.nvim_get_current_win()');o.before_debug=state(e)
  e:input(' md')
  e:wait('Debug View с фокусом в коде',function() return e:has_window('dap-repl') and e:lua('return vim.api.nvim_get_current_win()')==o.code end)
  -- Проверяем и поздний возврат, не только мгновение до scheduled focus.
  vim.wait(200);T.eq(e:lua('return vim.api.nvim_get_current_win()'),o.code)
  alive(e,o.terminal)
  e:input(' wc');e:wait('Явный Output остаётся доступным',function() return e:current_ft()=='dap-repl' end)
  e:input('<F7>');e:wait('F7 снова в том же main',function() return e:lua('return vim.api.nvim_get_current_win()')==o.code end)
  alive(e,o.terminal);e:lua([[vim.fn.jobstop((...).job)]],{o.terminal})
end)
check('terminal-only: поиск пассивен, Space w 0 создаёт main',function(e,o)
  o.terminal=terminal(e);o.fixture=state(e);passive(e)
  e:input(' w0');e:wait('Новый обычный main',function() return e:lua([[return require('ide.state').is_main_window(vim.api.nvim_get_current_win())]]) end)
  T.eq(#state(e).windows,2);alive(e,o.terminal)
  e:lua([[vim.fn.jobstop((...).job)]],{o.terminal})
end)
check('float-only: preview не main, Space w 0 сохраняет float',function(e,o)
  o.float=e:lua([[local tool=vim.api.nvim_create_buf(false,true);vim.api.nvim_set_current_buf(tool)
    local b=vim.fn.bufadd(vim.fn.getcwd()..'/file_two.txt');vim.fn.bufload(b)
    return vim.api.nvim_open_win(b,false,{relative='editor',row=3,col=8,width=60,height=10,style='minimal',border='single'})]])
  o.fixture=state(e);passive(e)
  e:input(' w0');e:wait('Отдельный normal main',function() return e:lua([[return require('ide.state').is_main_window(vim.api.nvim_get_current_win())]]) end)
  T.eq(#state(e).windows,3)
  assert(e:lua([[return vim.api.nvim_win_is_valid(...) and vim.api.nvim_win_get_config(...).relative~='']],{o.float}))
end)
T.finish()
