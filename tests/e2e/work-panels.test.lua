local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function text(e,kind)
  return e:lua([[local kind=...;local out={};for _,buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype==kind then
      vim.list_extend(out,vim.api.nvim_buf_get_lines(buf,0,-1,false)) end end;return table.concat(out,'\n')]],{kind})
end
local function focus(e,keys,kind)
  e:input(keys)
  e:wait('фокус '..kind,function()
    if e.rpc:request('nvim_get_mode',{}).blocking then e:ack_warning('gopls');return false end
    return e:current_ft()==kind
  end,10000)
end
local function normal(e)
  if e:current_ft()=='grug-far' then
    e:lua([[_G.forge_search_ready=false;require('grug-far').get_instance(vim.api.nvim_get_current_buf()):when_ready(function() _G.forge_search_ready=true end)]])
    e:wait('Search готов к вводу',function() return e:lua('return _G.forge_search_ready') end)
  end
  e:wait('normal mode',function()
    local mode=e.rpc:request('nvim_get_mode',{}).mode
    if mode:sub(1,1)=='i' then e:input('<Esc>');return false
    elseif mode:sub(1,1)=='t' then e:input('<Esc><Esc>');return false end
    return mode:sub(1,1)=='n'
  end)
end
local function healthy(e)
  for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
  local state=e:lua([[return {mode=vim.api.nvim_get_mode(),messages=vim.fn.execute('messages')} ]])
  assert(not state.mode.blocking,'неожиданный prompt')
  assert(not state.messages:match('E%d%d%d+:'),state.messages:sub(-600))
end
local function check(name,fn)
  if vim.env.FORGE_WORK_PANEL_CASE and not name:find(vim.env.FORGE_WORK_PANEL_CASE,1,true) then return end
  T.check(name,function()
    local e
    local ok,err=pcall(function()
      local deps=vim.env.FORGE_E2E_TEST_DEPS or root..'/.tests/test-deps'
      assert(vim.fn.filereadable(deps..'/manifest.json')==1,'Подготовь test-deps явно')
      local sep=vim.fn.has('win32')==1 and ';' or ':'
      local path=deps..'/bin'..sep..vim.env.PATH
      local tools=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
      if vim.fn.isdirectory(tools..'/go/bin')==1 then path=tools..'/bin'..sep..tools..'/go/bin'..sep..path end
      local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3');assert(python~='')
      e=require('editor').start(root,{timeout=180000,site=deps..'/site',env={PATH=path,GOTOOLCHAIN='local',GOPROXY='off',GOENV='off',
        GOCACHE=require('go_cache').path(root),GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=vim.fn.has('win32')==1 and 'NUL' or '/dev/null'},
        prepare=function(project)
          local init=vim.system({'git','-C',project,'init'},{text=true}):wait();assert(init.code==0,init.stderr)
          vim.fn.writefile({'first','FORGE_SEARCH_HIT ALPHA'},project..'/found ü.txt')
          vim.fn.writefile({'FORGE_SEARCH_HIT BETA'},project..'/file_two.txt')
          vim.fn.mkdir(project..'/go project','p')
          for _,file in ipairs({'go.mod','sample_test.go'}) do assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/test-runner/'..file,project..'/go project/'..file)) end
          vim.fn.writefile({
            'from pathlib import Path','import sys,time',
            'name=sys.argv[1]','Path(name+"-started").write_text("started")','print("JOB_STARTED_"+name,flush=True)',
            'deadline=time.monotonic()+90','while name=="beta" and not Path("beta-release").exists():',
            '    if time.monotonic()>deadline: raise TimeoutError("fixture release missing")','    time.sleep(.02)',
            'print("JOB_COMPLETE_"+name,flush=True)',
          },project..'/job.py')
          local tasks={}
          for _,job in ipairs({'alpha','beta'}) do tasks[#tasks+1]={label='forge-e2e-'..job,type='process',command=python,args={'-B',project..'/job.py',job},options={cwd=project},problemMatcher={}} end
          vim.fn.mkdir(project..'/.vscode','p');vim.fn.writefile({vim.json.encode({version='2.0.0',tasks=tasks})},project..'/.vscode/tasks.json')
        end})
      e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      vim.fn.writefile(vim.fn.readfile(root..'/tests/e2e/work-panels.test.lua'),e.dir..'/work-panels.test.lua')
      focus(e,':edit file_one.txt<CR>','text');e.code_file=e:current_file()
      fn(e)
      healthy(e)
    end)
    if e then
      vim.fn.writefile({},e.project..'/beta-release')
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop(not ok and tostring(err) or nil)
    end
    assert(ok,err)
  end)
end
local function help(e,kind)
  focus(e,'?','forge-panel-help');assert(text(e,'forge-panel-help'):find('Space w',1,true))
  focus(e,'q',kind)
end
local function select(e,pattern)
  e:input('gg/'..pattern..'<CR>')
  e:wait('выбран '..pattern,function() return e:lua('return vim.api.nvim_get_current_line()'):find(pattern,1,true)~=nil end)
end
local function search_input(e)
  return e:lua([[return vim.api.nvim_buf_get_lines(0,0,1,false)[1] ]])
end
local function query(e)
  normal(e);e:input('gg0iqq?')
  e:wait('insert q/? остаются текстом',function()
    return e:current_ft()=='grug-far' and e.rpc:request('nvim_get_mode',{}).mode:sub(1,1)=='i'
      and search_input(e)=='qq?'
  end)
  e:input('<Esc>gg0ccFORGE_SEARCH<Esc>')
  e:wait('реальный rg нашёл ALPHA/BETA',function() return text(e,'grug-far'):find('ALPHA',1,true) and text(e,'grug-far'):find('BETA',1,true) end,15000)
  T.eq(search_input(e),'FORGE_SEARCH')
end
local function tasks(e,name)
  return e:lua([[local name=...;if name==vim.NIL then name=nil end;local out={};for _,task in ipairs(require('overseer').list_tasks()) do
    if not name or task.name:find(name,1,true) then out[#out+1]={id=task.id,name=task.name,status=task.status} end end;return out]],{name or vim.NIL})
end
local function counts(e)
  return e:lua([[local n=require('neotest');local out={total=0,passed=0,failed=0,running=0};
    for _,id in ipairs(n.state.adapter_ids()) do local s=n.state.status_counts(id);
      if s then for key in pairs(out) do out[key]=out[key]+(s[key] or 0) end end end;return out]])
end
check('IDE-PANEL-6 четыре маршрута, фокус, помощь, Esc и hide без запуска',function(e)
  for _,item in ipairs({{' wt','neotest-summary'},{' wr','neotest-output-panel'},{' wf','grug-far'},{' wb','OverseerList'}}) do
    focus(e,item[1],item[2]);normal(e);e:input('<Esc>')
    -- Esc в обычной панели возвращает в код, а следующая команда опять фокусирует её.
    e:wait('код после Esc',function() return e:current_file()==e.code_file end)
    focus(e,item[1],item[2]);normal(e)
    local right=item[2]=='neotest-summary'
    local win=e:lua('return vim.api.nvim_get_current_win()')
    e:input(right and ' wh' or ' wk')
    -- Tasks может иметь соседний preview; направление означает соседнее окно.
    e:wait('соседнее окно',function() return e:lua('return vim.api.nvim_get_current_win()')~=win end)
    e:input(' w0');e:wait('код по w0',function() return e:current_file()==e.code_file end)
    focus(e,item[1],item[2]);normal(e)
    help(e,item[2])
    assert(e:lua('return vim.wo.winbar'):find('ide.controls',1,true),'общий индикатор фокуса')
    e:input(' wz');e:wait('zoom',function() return e:lua('return vim.api.nvim_win_get_config(0).relative')=='editor' end)
    e:input('q');e:wait('hide вернул код',function() return e:current_file()==e.code_file end)
    T.eq(e:has_window(item[2]),false)
  end
  T.eq(#tasks(e),0);T.eq(e:lua([[local d=package.loaded.dap;return d and d.session()~=nil or false]]),false)
end)
check('IDE-PANEL-8 legacy поиск переживает смену bottom слота',function(e)
  focus(e,' sF','grug-far');query(e)
  local buf=e:lua('return vim.api.nvim_get_current_buf()')
  e:input(' jj');e:wait('Tasks видимы',function() return e:has_window('OverseerList') end)
  focus(e,' sF','grug-far');normal(e)
  T.eq(search_input(e),'FORGE_SEARCH','смена слота сохраняет запрос')
  T.eq(e:lua('return vim.api.nvim_get_current_buf()'),buf)
end)
check('IDE-PANEL-8 Search insert, hide/reopen, выбор результата из zoom',function(e)
  focus(e,' wf','grug-far');query(e)
  local buf=e:lua('return vim.api.nvim_get_current_buf()');e:input('q')
  e:wait('код после hide',function() return e:current_file()==e.code_file end)
  focus(e,' wf','grug-far');normal(e);T.eq(search_input(e),'FORGE_SEARCH')
  T.eq(e:lua('return vim.api.nvim_get_current_buf()'),buf)
  e:input(' wz');select(e,'ALPHA');e:input('<CR>')
  e:wait('найденное место в коде',function() return e:current_file():sub(-12)=='found ü.txt' and e:lua('return vim.api.nvim_win_get_cursor(0)[1]')==2 end)
  T.eq(e:lua('return vim.api.nvim_win_get_config(0).relative'),'')
  local count=e:lua([[local n=0;for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='grug-far' then n=n+1 end end;return n]])
  T.eq(count,1)
end)
local function go(e)
  focus(e,':cd '..vim.fn.fnameescape(e.project..'/go project')..'<CR>:edit sample_test.go<CR>','go');e.code_file=e:current_file()
end
check('IDE-PANEL-7 Tests summary выбор из zoom не запускает тест',function(e)
  go(e);focus(e,' wt','neotest-summary')
  -- Имя файла появляется до discovery. Ждём и состояние, и его UI render,
  -- иначе Enter попадает в старую строку без дочерних тестов/expand callback.
  e:wait('summary обнаружил два теста',function()
    return counts(e).total==2 and text(e,'neotest-summary'):match('^[^\n]*2')~=nil
      and text(e,'neotest-summary'):find('sample_test.go',1,true)
  end,20000)
  select(e,'sample_test.go')
  local state=e:lua([[return {cursor=vim.api.nvim_win_get_cursor(0),line=vim.api.nvim_get_current_line(),cr=vim.fn.maparg('<CR>','n',false,true).desc,expand=vim.fn.maparg('e','n',false,true).desc,mappings=require('neotest.config').summary.mappings} ]])
  vim.fn.writefile(vim.split(vim.inspect(state),'\n',{plain=true}),e.dir..'/summary-before-expand.txt')
  e:input('<CR>')
  e:wait('summary обнаружил TestNearest',function() return text(e,'neotest-summary'):find('TestNearest',1,true) end,20000)
  e:input(' wz');select(e,'TestNeighbour');e:input('i')
  e:wait('выбранный тест открыт',function() return e:current_file()==e.code_file and e:lua('return vim.api.nvim_get_current_line()'):find('TestNeighbour',1,true) end)
  T.eq(vim.fn.filereadable(e.project..'/go project/neighbour-ran.txt'),0)
  T.eq(counts(e).passed+counts(e).failed+counts(e).running,0)
end)
check('IDE-PANEL-7 настоящий Go output сохраняется после zoom hide и reopen',function(e)
  go(e);e:input('10G Tt')
  e:wait('Go result/output',function() return text(e,'neotest-output-panel'):find('NEAREST_OUTPUT',1,true) end,30000)
  focus(e,' wr','neotest-output-panel');local buf=e:lua('return vim.api.nvim_get_current_buf()')
  help(e,'neotest-output-panel');e:input(' wzq')
  e:wait('код после hide output',function() return e:current_file()==e.code_file end)
  focus(e,' wr','neotest-output-panel');T.eq(e:lua('return vim.api.nvim_get_current_buf()'),buf)
  assert(text(e,'neotest-output-panel'):find('NEAREST_OUTPUT',1,true))
  T.eq(counts(e).passed,1);T.eq(counts(e).failed,0)
  T.eq(vim.fn.filereadable(e.project..'/go project/neighbour-ran.txt'),0)
end)
check('IDE-PANEL-7 selected task из zoom, running job переживает hide',function(e)
  for _,name in ipairs({'alpha','beta'}) do
    e:input(':OverseerRun forge-e2e-'..name..'<CR>')
    e:wait('процесс '..name..' запущен',function() return vim.fn.filereadable(e.project..'/'..name..'-started')==1 end,15000)
  end
  focus(e,' wb','OverseerList');select(e,'forge-e2e-alpha');e:input(' wz');select(e,'forge-e2e-beta');e:input('<C-s>')
  e:wait('output выбранной beta',function() return e:lua([[return vim.bo.buftype=='terminal' and table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('JOB_STARTED_beta',1,true)~=nil]]) end)
  local output=e:lua('return vim.api.nvim_get_current_buf()')
  local job=tasks(e,'forge-e2e-beta')[1].id
  normal(e)
  focus(e,' wb','OverseerList');help(e,'OverseerList');e:input('q')
  e:wait('код после hide Tasks',function() return e:current_file()==e.code_file end)
  T.eq(tasks(e,'forge-e2e-beta')[1].status,'RUNNING')
  T.eq(tasks(e,'forge-e2e-beta')[1].id,job);T.eq(#tasks(e),2)
  vim.fn.writefile({},e.project..'/beta-release')
  e:wait('тот же job завершился',function() return tasks(e,'forge-e2e-beta')[1].status=='SUCCESS' end,15000)
  assert(e:lua([[return table.concat(vim.api.nvim_buf_get_lines(...,0,-1,false),'\n'):find('JOB_COMPLETE_beta',1,true)~=nil]],{output}))
  T.eq(tasks(e,'forge-e2e-beta')[1].id,job);T.eq(#tasks(e),2)
end)
T.finish()
