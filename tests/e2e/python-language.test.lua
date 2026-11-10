-- spec: IDE-PY-1 IDE-DAP-5. Реальный Python workflow и adapter lifecycle.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function text(e,ft)
  return e:lua([[local ft=...;local out={};for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype==ft then vim.list_extend(out,vim.api.nvim_buf_get_lines(b,0,-1,false)) end end;return table.concat(out,'\n')]],{ft})
end
local function content(e) return e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]]) end
local function open(e,file)
  e:input(':edit '..vim.fn.fnameescape(e.python_project..'/'..file)..'<CR>')
  e:wait('Python файл '..file,function() return e:current_file():sub(-#file)==file and e:current_ft()=='python' end)
end
local function language(e,file)
  open(e,file)
  e:wait('настоящие pyright/ruff',function() return e:lua([[local found={};for _,c in ipairs(vim.lsp.get_clients({bufnr=0})) do
    if c.initialized then found[c.name]=true end end;return found.pyright and found.ruff and vim.fn.maparg('gd','n',false,true).buffer==1]]) end,25000)
end
local function seek(e,word)
  -- nvim_input читает key notation: буквальный < передаётся как <lt>.
  e:input('gg/\\<lt>'..word..'\\><CR>');e:wait('курсор '..word,function() return e:lua([[return vim.fn.expand('<cword>')]])==word end)
end
local function state(e)
  return e:lua([[local n=package.loaded.neotest;local d=package.loaded.dap;local s=d and d.session();return {
    file=vim.api.nvim_buf_get_name(0),ft=vim.bo.filetype,mode=vim.api.nvim_get_mode(),messages=vim.fn.execute('messages'),
    notifications=vim.g.forge_e2e_notifications,installs=vim.g.forge_e2e_installs,diagnostics=vim.diagnostic.get(0),
    clients=vim.tbl_map(function(c) return {name=c.name,cmd=type(c.config.cmd)=='table' and c.config.cmd or type(c.config.cmd),root=c.root_dir,
      settings=c.settings} end,vim.lsp.get_clients()),adapters=n and n.state.adapter_ids() or {},
    session=s and {type=s.config.type,paused=s.stopped_thread_id,python=s.config.python} or false} ]])
end
local function check(name,fn)
  if vim.env.FORGE_PYTHON_CASE and not name:find(vim.env.FORGE_PYTHON_CASE,1,true) then return end
  T.check(name,function()
    local e
    local ok,err=pcall(function()
      require('python_project').start(root,function(child) e=child end)
      vim.fn.writefile(vim.fn.readfile(root..'/tests/e2e/python-language.test.lua'),e.dir..'/python-language.test.lua')
      assert(vim.uv.fs_copyfile(root..'/tests/lib/python_project.lua',e.dir..'/python_project.lua'))
      fn(e)
      local observed=state(e);vim.fn.writefile({vim.json.encode(observed)},e.dir..'/python-state.json')
      T.eq(observed.installs,0);assert(not observed.mode.blocking,'неожиданный prompt')
      assert(not observed.messages:match('E%d%d%d+:'),observed.messages)
      for _,n in ipairs(observed.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    end)
    if e then
      local got,observed=pcall(state,e)
      if got then vim.fn.writefile({vim.json.encode(observed)},e.dir..'/action-state.json') end
      for _,item in ipairs({{'lsp.log',[[return vim.lsp.log.get_filename()]]},
        {'dap.log',[[return vim.fn.stdpath('cache')..'/dap.log']]},{'neotest.log',[[return vim.fn.stdpath('log')..'/neotest.log']]}}) do
        local has,path=pcall(function() return e:lua(item[2]) end)
        if has and vim.fn.filereadable(path)==1 then vim.uv.fs_copyfile(path,e.dir..'/'..item[1]) end
      end
      for _,source in pairs({e.log_lsp,e.log_cache and e.log_cache..'/dap.log',e.log_state and e.log_state..'/neotest.log'}) do
        if vim.fn.filereadable(source)==1 then assert(vim.uv.fs_copyfile(source,e.dir..'/'..vim.fs.basename(source))) end
      end
      for _,source in ipairs(vim.fn.glob((e.log_cache or e.runtime)..'/dap*.log',false,true)) do
        assert(vim.uv.fs_copyfile(source,e.dir..'/'..vim.fs.basename(source)))
      end
      for _,source in ipairs(vim.fn.glob(e.runtime..'/debugpy-logs/*',false,true)) do
        assert(vim.uv.fs_copyfile(source,e.dir..'/'..vim.fs.basename(source)))
      end
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop(not ok and tostring(err) or nil)
    end
    assert(ok,err)
  end)
end
check('IDE-PY-1 Python LSP definition references rename и project venv',function(e)
  language(e,'src/use.py');e:input('5G0/double<CR>')
  e:wait('вызов double',function() return e:lua([[return vim.api.nvim_win_get_cursor(0)[1]==5 and vim.fn.expand('<cword>')=='double']]) end)
  e:input('gd');e:wait('definition forge_math',function() return e:current_file():sub(-13)=='forge_math.py' end,15000)
  seek(e,'double');e:input('gr');e:wait('references',function() return e:current_ft()=='qf' end,15000)
  assert(e:lua([[local n=0;for _,r in ipairs(vim.fn.getqflist()) do if vim.api.nvim_buf_get_name(r.bufnr):sub(-6)=='use.py' then n=n+1 end end;return n>=2]]))
  e:input(':cclose<CR>');open(e,'src/forge_math.py');seek(e,'double');e:input('<F2>')
  e:wait('rename prompt',function() return e.rpc:request('nvim_get_mode',{}).mode=='c' end)
  e:input('<C-u>twice_forge<CR>');e:wait('rename definition',function() return content(e):find('def twice_forge',1,true)~=nil end,15000)
  e:input(':wall<CR>');e:wait('rename сохранён',function()
    return table.concat(vim.fn.readfile(e.python_project..'/src/use.py'),'\n'):find('twice_forge(21)',1,true)~=nil
      and table.concat(vim.fn.readfile(e.python_project..'/src/forge_math.py'),'\n'):find('def twice_forge',1,true)~=nil
  end)
  open(e,'src/forge_math.py')
  e:wait('venv dependency без import error',function() return e:lua([[for _,d in ipairs(vim.diagnostic.get(0)) do if d.message:find('forge_fixture_dependency',1,true) then return false end end
    for _,c in ipairs(vim.lsp.get_clients({bufnr=0,name='pyright'})) do return c.initialized end;return false]]) end)
  seek(e,'calculate_answer');e:input('gd');e:wait('definition внутри project venv',function()
    local p=e:current_file();return p:find('/.venv/',1,true) and p:find('forge_fixture_dependency.py',1,true)
  end,15000)
end)
check('IDE-PY-1 Python LSP completion diagnostics и исправление',function(e)
  language(e,'src/complete.py');e:input('5G0f0');e:wait('return 0',function() return e:lua([[return vim.fn.expand('<cword>')]])=='0' end)
  e:input('ciw');e:wait('готовый insert/cmp',function() return e.rpc:request('nvim_get_mode',{}).mode=='i' and e:lua([[return not vim.tbl_isempty(vim.fn.maparg('<C-Space>','i',false,true))]]) end)
  e:input('FORGE_A');e:wait('введён FORGE_A',function() return content(e):find('return FORGE_A',1,true)~=nil end)
  e:input('<C-Space>');e:wait('настоящий cmp LSP',function() return e:lua([[for _,v in ipairs(require('cmp').get_entries()) do
    if v.source.name=='nvim_lsp' and v.completion_item.label=='FORGE_ANSWER' then return true end end;return false]]) end,15000)
  for _=1,20 do
    if e:lua([[local v=require('cmp').get_selected_entry();return v and v.source.name=='nvim_lsp' and v.completion_item.label=='FORGE_ANSWER' or false]]) then break end
    e:input('<C-n>');vim.wait(60)
  end
  e:input('<CR>');e:wait('completion принят',function() return content(e):find('return FORGE_ANSWER',1,true)~=nil end)
  e:input('<Esc>5Gcc    return MISSING_FORGE_NAME<Esc>')
  e:wait('реальная диагностика',function() return e:lua([[for _,d in ipairs(vim.diagnostic.get(0)) do if d.severity==1 and d.message:find('MISSING_FORGE_NAME',1,true) then return true end end;return false]]) end,20000)
  e:input('gl');e:wait('ошибка в UI',function() return e:lua([[for _,w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative~='' and table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w),0,-1,false),'\n'):find('MISSING_FORGE_NAME',1,true) then return true end end;return false]]) end)
  e:input('<Esc>5Gcc    return FORGE_ANSWER<Esc>:write<CR>')
  e:wait('диагностика исправлена',function() return e:lua([[return #vim.diagnostic.get(0,{severity=vim.diagnostic.severity.ERROR})==0]]) end,20000)
end)
check('IDE-PY-1 Python explicit Pyright path сохраняется и меняется штатной командой',function(e)
  e:lua([[local original=vim.lsp.handlers['window/logMessage'];_G.forge_python_server_messages={};
    vim.lsp.handlers['window/logMessage']=function(err,result,ctx,config)
      if result and result.message then table.insert(_G.forge_python_server_messages,result.message) end
      if original then return original(err,result,ctx,config) end
    end]])
  e:lua([[vim.lsp.config('pyright',{settings={python={pythonPath=...}}})]],{e.tools_python})
  language(e,'src/forge_math.py')
  e:wait('server принял explicit interpreter',function() return e:lua([[local path=(...):gsub('\\','/'):lower();for _,message in ipairs(_G.forge_python_server_messages) do
    if message:find('Setting pythonPath',1,true) and message:gsub('\\','/'):lower():find(path,1,true) then return true end end;return false]],{e.tools_python}) end,20000)
  T.eq(e:lua([[return vim.lsp.get_clients({name='pyright'})[1].settings.python.pythonPath]]),e.tools_python)
  e:input(':LspPyrightSetPythonPath '..e.project_python..'<CR>')
  e:wait('после смены interpreter импорт разрешён',function() return e:lua([[for _,d in ipairs(vim.diagnostic.get(0)) do
    if d.message:find('forge_fixture_dependency',1,true) then return false end end;return true]]) end,20000)
  seek(e,'calculate_answer');e:input('gd')
  e:wait('explicit command выбрала project dependency',function() local path=e:current_file();return path:find('/.venv/',1,true) and path:find('forge_fixture_dependency.py',1,true) end,15000)
end)
check('IDE-PY-1 Python Ruff manual и format after save',function(e)
  open(e,'src/format.py');e:input(' lf')
  local expected="import os\nimport sys\n\n\ndef environment(value: int):\n    return {'x': value, 'os': os.name, 'platform': sys.platform}"
  e:wait('Ruff imports и project style',function() return content(e)==expected end,15000)
  e:input('ggVGcimport sys<CR>import os<CR><CR>def environment( value:int ):return {"x":value,"os":os.name,"platform":sys.platform}<Esc>:write<CR>')
  e:wait('Ruff сохранён без второго write',function() return table.concat(vim.fn.readfile(e.python_project..'/src/format.py'),'\n')==expected end,15000)
end)
local function choose(e,name)
  e:wait('DAP picker',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
  e:input(name);e:wait('DAP config выбран',function() return e:lua([[local name=...;local v=require('telescope.actions.state').get_selected_entry();return v and v.ordinal:find(name,1,true) and not v.ordinal:find(name..' (args)',1,true) or false]],{name}) end)
  e:input('<CR>')
end
local function paused(e)
  e:wait('реальный Python breakpoint',function() return e:lua([[local s=require('dap').session();return s and s.stopped_thread_id~=nil and s.current_frame~=nil or false]]) end,30000)
  require('output_policy').reopen(e,'dap-repl',' md')
  e:input('<F7>');seek(e,'answer');e:input(' de')
  e:wait('Python eval 42',function() return text(e,'dap-float'):find('42',1,true)~=nil end)
  e:input('q<F7><F5>');e:wait('Python session завершилась',function() return e:lua([[return require('dap').session()==nil]]) end,30000)
end
check('IDE-PY-1 Python debug default/project и реальный interpreter/output',function(e)
  open(e,'app.py');e:input('gg/E2E_BREAKPOINT<CR><F9><F5>');choose(e,'Current Python file');paused(e)
  local out=text(e,'dap-repl');assert(out:find('PY_VALUE',1,true) and out:find('PY_STDERR',1,true) and out:find('PROJECT_VENV_ONLY',1,true))
  assert(out:find('PY_PROJECT_VENV True',1,true),'debug использует project .venv')
  require('output_policy').reopen(e,'dap-repl',' du')
  local cfg={name='Project Python',type='debugpy',request='launch',program='${workspaceFolder}/app.py',cwd=e.python_project,args={'from-launch'},console='internalConsole',redirectOutput=true}
  vim.fn.writefile({vim.json.encode({version='0.2.0',configurations={cfg}})},e.python_project..'/.vscode/launch.json')
  e:input('<F7><F5>');choose(e,'Project Python');paused(e);assert(text(e,'dap-repl'):find('PY_BEFORE from-launch',1,true))
end)
local function counts(e)
  return e:lua([[local n=require('neotest');local out={passed=0,failed=0,running=0};for _,id in ipairs(n.state.adapter_ids()) do local s=n.state.status_counts(id);if s then
    for k in pairs(out) do out[k]=out[k]+(s[k] or 0) end end end;return out]])
end
local function discover(e)
  e:input(' wt');e:wait('Python Tests',function() return e:current_ft()=='neotest-summary' end)
  e:wait('Python tests обнаружены',function() return e:lua([[local n=require('neotest');for _,id in ipairs(n.state.adapter_ids()) do local s=n.state.status_counts(id)
    if s and s.total==2 then return true end end;return false]]) end,25000)
  e:input('<F7>');e:wait('код Python test',function() return e:current_ft()=='python' end)
end
local function results(e)
  e:wait('pytest result',function() local s=counts(e);return s.passed+s.failed>0 and s.running==0 end,40000)
end
check('IDE-PY-1 Python pytest nearest/file результаты/output и venv',function(e)
  open(e,'tests/test_math.py');discover(e)
  local roots=e:lua([[local out={};for _,id in ipairs(require('neotest').state.adapter_ids()) do
    if id:match('^neotest%-python:') then out[#out+1]=id end end;return out]])
  vim.fn.writefile({vim.json.encode(roots)},e.dir..'/pytest-root-ids.json')
  T.eq(#roots,1,'one physical pytest workspace must have one adapter namespace')
  e:input('gg/E2E_BREAKPOINT<CR>')
  e:wait('nearest cursor ready before run',function() return e:lua([[return vim.api.nvim_get_current_line():find('E2E_BREAKPOINT',1,true)~=nil]]) end)
  vim.fn.writefile({vim.json.encode(e:lua([[return {file=vim.api.nvim_buf_get_name(0),cursor=vim.api.nvim_win_get_cursor(0)}]]))},e.dir..'/nearest-caller.json')
  e:input(' Tt')
  results(e)
  T.eq(counts(e).passed,1);T.eq(counts(e).failed,0);T.eq(vim.fn.filereadable(e.python_project..'/neighbor-ran.txt'),0)
  e:wait('pytest Output',function() return text(e,'neotest-output-panel'):find('PYTEST_VALUE',1,true)~=nil end)
  assert(text(e,'neotest-output-panel'):find('PYTEST_PROJECT_VENV True',1,true))
  e:input('<F7> Tf');e:wait('pytest file pass/fail',function() local s=counts(e);return s.passed==1 and s.failed==1 and s.running==0 end,40000)
  T.eq(vim.fn.filereadable(e.python_project..'/neighbor-ran.txt'),1)
end)
check('IDE-DAP-5 Python pytest debug nearest breakpoint/eval/continue',function(e)
  open(e,'tests/test_math.py');discover(e);e:input('gg/E2E_BREAKPOINT<CR><F9>')
  e:lua([[require('dap').set_log_level('TRACE')]])
  e:input(' Td');paused(e)
  e:wait('native adapter process exit записан',function()
    local file=e.log_cache..'/dap.log';return vim.fn.filereadable(file)==1 and table.concat(vim.fn.readfile(file),'\n'):find('"Process exit"',1,true)~=nil
  end,15000)
  results(e)
  T.eq(counts(e).passed,1);T.eq(counts(e).failed,0);T.eq(vim.fn.filereadable(e.python_project..'/neighbor-ran.txt'),0)
  assert(text(e,'dap-repl'):find('PYTEST_VALUE',1,true))
end)
check('IDE-DAP-5 неожиданный adapter exit остаётся видимым',function(e)
  open(e,'app.py')
  local program=[[import sys;sys.stderr.write('FORGE_ADAPTER_FAILURE\n');raise SystemExit(23)]]
  e:lua([[local python,program=...;require('dap').adapters.forge_failure={type='executable',command=python,args={'-c',program}}]],{e.project_python,program})
  local cfg={name='Broken adapter',type='forge_failure',request='launch'}
  vim.fn.writefile({vim.json.encode({version='0.2.0',configurations={cfg}})},e.python_project..'/.vscode/launch.json')
  e:input('<F5>');choose(e,'Broken adapter')
  e:wait('настоящий adapter failure WARN',function()
    if e.rpc:request('nvim_get_mode',{}).blocking then e:ack_warning('of adapter');return false end
    return e:lua([[for _,n in ipairs(vim.g.forge_e2e_notifications) do if n.level==vim.log.levels.WARN and n.message:find('of adapter',1,true) and n.message:find('exited with',1,true) then
      return require('dap').session()==nil end end;return false]])
  end,15000)
  e:wait('stderr настоящей ошибки сохранён',function()
    local file=e.log_cache..'/dap-forge_failure-stderr.log'
    return vim.fn.filereadable(file)==1 and table.concat(vim.fn.readfile(file),'\n'):find('FORGE_ADAPTER_FAILURE',1,true)~=nil
  end)
  e:input('<F7>gg0i# STILL_EDITABLE<CR><Esc>:write<CR>')
  e:wait('редактор доступен после failure',function() return vim.fn.readfile(e.python_project..'/app.py')[1]=='# STILL_EDITABLE' end)
end)
T.finish()
