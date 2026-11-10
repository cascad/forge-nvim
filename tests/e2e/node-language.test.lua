local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local deps=vim.env.FORGE_E2E_NODE_DEPS or root..'/.tests/node-deps'
assert(vim.fn.filereadable(deps..'/manifest.json')==1,'Явно выполни prepare_node.py --download')
local manifest=vim.json.decode(table.concat(vim.fn.readfile(deps..'/manifest.json'),'\n'))
local node=deps..'/'..manifest.node
if vim.env.FORGE_NODE_NEAREST_LEGACY then assert(vim.env.FORGE_NODE_CASE=='nearest/file','Legacy replay только для nearest/file') end
local function text(e,ft)
  return e:lua([[local ft=...;local out={};for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype==ft then vim.list_extend(out,vim.api.nvim_buf_get_lines(b,0,-1,false)) end end;return table.concat(out,'\n')]],{ft})
end
local function content(e) return e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]]) end
local function open(e,file)
  e:input(':edit '..vim.fn.fnameescape(e.node_project..'/'..file)..'<CR>')
  e:wait('JS файл '..file,function() return e:current_file():sub(-#file)==file and e:current_ft()=='javascript' end,15000)
end
local function language(e,file)
  open(e,file)
  e:wait('ts_ls с настоящим Node',function() return e:lua([[for _,c in ipairs(vim.lsp.get_clients({bufnr=0,name='ts_ls'})) do
    if c.initialized and vim.fn.maparg('gd','n',false,true).buffer==1 then return true end end;return false]]) end,30000)
  e:wait('TS semantic project загружен',function() return e:lua([[return _G.forge_node_semantic_ready==true]]) end,30000)
end
local function seek(e,word)
  e:input('gg/'..word..'<CR>');e:wait('курсор '..word,function() return e:lua([[return vim.fn.expand('<cword>')]])==word end)
end
local function copy(from,to)
  vim.fn.mkdir(to,'p')
  for name,kind in vim.fs.dir(from) do
    local source,target=from..'/'..name,to..'/'..name
    if kind=='directory' then copy(source,target)
    elseif kind=='file' then assert(vim.uv.fs_copyfile(source,target))
    elseif kind=='link' then
      local real=assert(vim.uv.fs_realpath(source)):gsub('\\','/')
      assert(real:find((deps..'/tools/node_modules/'):gsub('\\','/'),1,true)==1,'внешний symlink в Node deps')
      assert(vim.uv.fs_symlink(assert(vim.uv.fs_readlink(source)),target))
    else error('Неожиданный тип Node deps: '..source) end
  end
end
local function counts(e)
  return e:lua([[local n=require('neotest');local out={passed=0,failed=0,skipped=0,running=0};
    for _,id in ipairs(n.state.adapter_ids()) do local s=n.state.status_counts(id);if s then
      for k in pairs(out) do out[k]=out[k]+(s[k] or 0) end end end;return out]])
end
local function results(e)
  local missing=false
  e:wait('настоящий результат Jest',function()
    missing=e:lua([[for _,n in ipairs(vim.g.forge_e2e_notifications) do if n.message=='No tests found' then return true end end;return false]])
    local s=counts(e);return missing or (s.passed+s.failed>0 and s.running==0)
  end,60000)
  assert(not missing,'Neotest: No tests found при обнаруженных Jest позициях')
end
local function discover(e)
  e:input(' wt');e:wait('Tests открыт',function() return e:current_ft()=='neotest-summary' end)
  e:wait('Jest позиции готовы',function() return e:lua([[local n=require('neotest');for _,id in ipairs(n.state.adapter_ids()) do
    local s=n.state.status_counts(id);if s and (s.total or 0)>=2 then return true end end;return false]]) end,30000)
  local positions=e:lua([[local n=require('neotest');local p,pending={},{};for _,id in ipairs(n.state.adapter_ids()) do
    local tree=n.state.positions(id);if tree then p[id]=tree:to_list() else pending[#pending+1]=id end end
    return {positions=p,pending=pending,expand=vim.fn.maparg('e','n',false,true).desc,cursor=vim.api.nvim_win_get_cursor(0),file=vim.fn.expand('%:p'),ft=vim.bo.filetype}]])
  vim.fn.writefile({vim.json.encode(positions)},e.dir..'/positions.json')
  e:input(' wt');e:wait('Tests фокус после discovery',function() return e:current_ft()=='neotest-summary' and e:lua([[return vim.fn.maparg('e','n',false,true).buffer==1]]) end)
  e:input('Ge')
  e:wait('Jest обнаружил nearest',function() return text(e,'neotest-summary'):find('nearest returns 42',1,true)~=nil end,30000)
  e:input('<F7>');e:wait('код теста',function() return e:current_ft()=='javascript' end)
end
local function check(name,fn,missing)
  if vim.env.FORGE_NODE_CASE and not name:find(vim.env.FORGE_NODE_CASE,1,true) then return end
  T.check(name,function()
    local e
    local ok,err=pcall(function()
      local sep=vim.fn.has('win32')==1 and ';' or ':'
      e=require('editor').start(root,{timeout=180000,site=deps..'/site',snapshot_ignore={node_modules=true},
        env={PATH=vim.fn.fnamemodify(node,':h')..sep..vim.env.PATH,FORGE_NODE_EXECUTABLE=missing=='node' and deps..'/absent-node' or node,
          FORGE_NODE_TOOLS=deps..'/tools',FORGE_JS_DEBUG_SERVER=missing==true and deps..'/missing-debug-server.js' or deps..'/debug/js-debug/src/dapDebugServer.js',
          NODE_OPTIONS='',NODE_PATH='',npm_config_offline='true',npm_config_audit='false',npm_config_update_notifier='false'},
        prepare=function(project,env)
          if vim.env.FORGE_NODE_NEAREST_LEGACY then
            local patch=vim.json.decode(table.concat(vim.fn.readfile(root..'/nvim_forge/patches/plugins.json'),'\n')).neotest
            local data=env.XDG_DATA_HOME..'/nvim_forge'..(vim.fn.has('win32')==1 and '-data' or '')
            local path=data..'/lazy/neotest/'..patch.file
            local f=assert(io.open(path,'rb'));local raw=f:read('*a');f:close();assert(vim.fn.sha256(raw)==patch.after_sha256)
            local a,b=assert(raw:find(patch.after,1,true));raw=raw:sub(1,a-1)..patch.before..raw:sub(b+1)
            assert(vim.fn.sha256(raw)==patch.before_sha256);f=assert(io.open(path,'wb'));f:write(raw);f:close()
          end
          local dir=project..'/Node project ü';vim.fn.mkdir(dir,'p')
          copy(root..'/tests/e2e/fixtures/node-language',dir)
          copy(deps..'/tools/node_modules',dir..'/node_modules')
          local pkg=vim.json.decode(table.concat(vim.fn.readfile(root..'/tests/e2e/node-tools/package.json'),'\n'))
          pkg.scripts={start='node app.js package-script',test='jest --runInBand'}
          vim.fn.writefile({vim.json.encode(pkg)},dir..'/package.json')
          assert(vim.uv.fs_copyfile(root..'/tests/e2e/node-tools/package-lock.json',dir..'/package-lock.json'))
          vim.fn.writefile({'node_modules/','run-cwd.txt','neighbor-ran.txt'},dir..'/.gitignore')
          vim.fn.mkdir(dir..'/.vscode','p')
        end})
      e.node_project=(e.project..'/Node project ü'):gsub('\\','/')
      vim.fn.writefile(vim.fn.readfile(root..'/tests/e2e/node-language.test.lua'),e.dir..'/node-language.test.lua')
      vim.fn.writefile({vim.json.encode(manifest)},e.dir..'/node-dependencies.json')
      assert(vim.uv.fs_copyfile(e:lua([[return vim.fn.stdpath('data')..'/lazy/neotest/lua/neotest/consumers/run.lua']]),e.dir..'/neotest-run-source.lua'))
      e:input(':cd '..vim.fn.fnameescape(e.node_project)..'<CR>')
      e:lua([[vim.lsp.log.set_level('debug')]])
      e:lua([[vim.lsp.config('ts_ls',{init_options={tsserver={logDirectory=...,logVerbosity='verbose'}}})]],{e.dir..'/tsserver'})
      e:lua([[local original=vim.lsp.handlers['$/progress'];local tokens={};
        vim.lsp.handlers['$/progress']=function(err,result,ctx,config)
          if result and result.value then local v=result.value
            if v.kind=='begin' and (v.title or ''):find('JS/TS',1,true) then tokens[result.token]=true end
            if v.kind=='end' and tokens[result.token] then _G.forge_node_semantic_ready=true end
          end
          if original then return original(err,result,ctx,config) end
        end]])
      fn(e)
      local state=e:lua([[return {mode=vim.api.nvim_get_mode(),messages=vim.fn.execute('messages'),
        notifications=vim.g.forge_e2e_notifications,installs=vim.g.forge_e2e_installs,events=_G.forge_node_events,
        clients=vim.tbl_map(function(c) return {name=c.name,cmd=type(c.config.cmd),root=c.root_dir,
          ata=c.config.init_options and c.config.init_options.disableAutomaticTypingAcquisition} end,vim.lsp.get_clients())} ]])
      vim.fn.writefile({vim.json.encode(state)},e.dir..'/node-state.json')
      T.eq(state.installs,0);assert(not state.mode.blocking,'неожиданный prompt')
      assert(not state.messages:match('E%d%d%d+:'),state.messages)
      for _,n in ipairs(state.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    end)
    if e then
      local observed,data=pcall(function() return e:lua([[local d=package.loaded.dap;local s=d and d.session();local n=package.loaded.neotest;
        return {file=vim.fn.expand('%:p'),ft=vim.bo.filetype,events=_G.forge_node_events,adapters=n and n.state.adapter_ids() or {},mode=vim.api.nvim_get_mode(),
          diagnostics=vim.diagnostic.get(0),session=s and {type=s.config.type,request=s.config.request,port=s.adapter.port,paused=s.stopped_thread_id} or false} ]]) end)
      if observed then vim.fn.writefile({vim.json.encode(data)},e.dir..'/action-state.json') end
      for _,item in ipairs({{'lsp.log',[[return vim.lsp.log.get_filename()]]},{'dap.log',[[return vim.fn.stdpath('cache')..'/dap.log']]},
        {'neotest.log',[[return vim.fn.stdpath('log')..'/neotest.log']]}}) do
        local got,path=pcall(function() return e:lua(item[2]) end)
        if got and vim.fn.filereadable(path)==1 then vim.uv.fs_copyfile(path,e.dir..'/'..item[1]) end
      end
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop(not ok and tostring(err) or nil)
    end
    assert(ok,err)
  end)
end
check('IDE-NODE-1 definition references rename и локальный формат',function(e)
  language(e,'src/use.js');e:input('4G0/double<CR>')
  e:wait('вызов double',function() return e:lua('return vim.api.nvim_win_get_cursor(0)[1]')==4 and e:lua([[return vim.fn.expand('<cword>')]])=='double' end)
  e:input('gd')
  e:wait('definition math.js',function() return e:current_file():sub(-7)=='math.js' and e:lua('return vim.api.nvim_get_current_line()'):find('exports.double',1,true) end,20000)
  seek(e,'double');e:input('gr');e:wait('references quickfix',function() return e:current_ft()=='qf' end,20000)
  assert(e:lua([[local seen={};for _,r in ipairs(vim.fn.getqflist()) do seen[vim.fs.basename(vim.api.nvim_buf_get_name(r.bufnr))]=true end
    return seen['use.js'] and seen['app.js'] and seen['math.test.js'] ]]))
  e:input(':cclose<CR>');open(e,'src/math.js');seek(e,'double');e:input('<F2>')
  e:wait('rename prompt',function() return e.rpc:request('nvim_get_mode',{}).mode=='c' end,20000)
  e:input('<C-u>twiceForge<CR>');e:wait('rename definition',function() return content(e):find('exports.twiceForge',1,true) end,20000)
  e:input(':wall<CR>');e:wait('rename всех файлов на диске',function()
    for _,file in ipairs({'src/math.js','src/use.js','app.js','math.test.js'}) do
      if not table.concat(vim.fn.readfile(e.node_project..'/'..file),'\n'):find('twiceForge',1,true) then return false end
    end
    return e:lua([[for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].modified then return false end end;return true]])
  end)
  local renamed=vim.system({node,'-e',"console.log(require(process.argv[1]).use())",e.node_project..'/src/use.js'},{text=true}):wait()
  vim.fn.writefile({vim.json.encode(renamed)},e.dir..'/renamed-process.json')
  assert(renamed.code==0,renamed.stderr);T.eq(vim.trim(renamed.stdout),'42')
  language(e,'src/format.js');e:input(' lf')
  local expected="const items = { answer: 42, text: 'hello' };\nmodule.exports = items;"
  e:wait('локальный Prettier/config',function() return content(e)==expected end,20000)
  e:input(':write<CR>');e:wait('format записан',function() return table.concat(vim.fn.readfile(e.node_project..'/src/format.js'),'\n')==expected end)
  assert(e:lua([[for _,s in ipairs(_G.forge_e2e_spawns) do for _,arg in ipairs(s.args or {}) do if arg:find('Node project',1,true) and arg:find('prettier',1,true) then return true end end end;return false]]))
end)
check('IDE-NODE-1 настоящий LSP completion и diagnostics',function(e)
  language(e,'src/complete.js');e:input('4G0f0');e:wait('значение 0',function() return e:lua([[return vim.fn.expand('<cword>')]])=='0' end)
  e:input('ciw');e:wait('insert',function() return e.rpc:request('nvim_get_mode',{}).mode=='i' end)
  e:input('Forg<C-Space>');e:wait('LSP ForgeAnswer',function() return e:lua([[local c=require('cmp');for _,v in ipairs(c.get_entries()) do if v.source.name=='nvim_lsp' and v.completion_item.label=='ForgeAnswer' then return c.visible() end end;return false]]) end,20000)
  for _=1,30 do
    if e:lua([[local v=require('cmp').get_selected_entry();return v and v.source.name=='nvim_lsp' and v.completion_item.label=='ForgeAnswer' or false]]) then break end
    e:input('<C-n>');vim.wait(60)
  end
  assert(e:lua([[local v=require('cmp').get_selected_entry();return v and v.source.name=='nvim_lsp' and v.completion_item.label=='ForgeAnswer' or false]]))
  e:input('<CR>');e:wait('completion принят',function() return content(e):find('return ForgeAnswer',1,true) end);e:input('<Esc>4Gccreturn MissingForgeName;<Esc>')
  e:wait('диагностика ts_ls',function() return e:lua([[for _,d in ipairs(vim.diagnostic.get(0)) do if d.severity==1 and d.message:find('MissingForgeName',1,true) then return true end end;return false]]) end,20000)
  e:input('gl');e:wait('ошибка видна в UI',function() return e:lua([[for _,w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative~='' and table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w),0,-1,false),'\n'):find('MissingForgeName',1,true) then return true end end;return false]]) end)
  e:input('<Esc>4Gccreturn ForgeAnswer;<Esc>')
  e:wait('исправление убрало ошибку',function() return e:lua([[return #vim.diagnostic.get(0,{severity=vim.diagnostic.severity.ERROR})==0]]) end,20000)
  e:input(':write<CR>');e:wait('completion сохранён',function() return table.concat(vim.fn.readfile(e.node_project..'/src/complete.js'),'\n'):find('return ForgeAnswer',1,true)~=nil end)
  T.eq(e:lua([[return vim.lsp.get_clients({bufnr=0,name='ts_ls'})[1].config.init_options.disableAutomaticTypingAcquisition]]),true)
end)
check('IDE-NODE-2 файл и package script в Tasks',function(e)
  open(e,'app.js');e:input(':NodeRunFile<CR>')
  e:wait('Node job завершён',function() return e:lua([[local a=require('overseer').list_tasks();return #a==1 and a[1].status=='SUCCESS']]) end,20000)
  e:input(' wb');e:wait('Tasks',function() return e:current_ft()=='OverseerList' end)
  e:input('gg/Node:<CR><C-s>');e:wait('вывод Node файла',function() return e:lua([[return vim.bo.buftype=='terminal' and table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('LOCAL_PRETTIER 3.6.2',1,true)~=nil]]) end)
  e:input('<Esc><Esc><F7>');e:wait('код перед script',function() return e:current_ft()=='javascript' end)
  e:input(':NodeRun<CR>');e:wait('scripts picker',function()
    local m=e.rpc:request('nvim_get_mode',{});return m.blocking or m.mode:sub(1,1)=='r' or e:current_ft()=='TelescopePrompt'
  end)
  if e.rpc:request('nvim_get_mode',{}).mode:sub(1,1)=='r' or e.rpc:request('nvim_get_mode',{}).blocking then e:input('1<CR>')
  else
    e:wait('picker принимает ввод',function() return e.rpc:request('nvim_get_mode',{}).mode=='i' end)
    e:input('start');e:wait('start выбран',function() return e:lua([[local v=require('telescope.actions.state').get_selected_entry();return v and v.ordinal:find('start',1,true)~=nil]]) end)
    e:input('<CR>')
  end
  e:wait('npm script завершён',function() return e:lua([[local a=require('overseer').list_tasks();return #a==2 and a[1].status=='SUCCESS' and a[2].status=='SUCCESS']]) end,20000)
  T.eq(table.concat(vim.fn.readfile(e.node_project..'/run-cwd.txt'),'\n'):gsub('\\','/'),e.node_project)
end)
local function observe_dap(e)
  e:lua([[local d=require('dap');d.set_log_level('TRACE');_G.forge_node_events={};
    for _,name in ipairs({'event_initialized','event_output','event_stopped','event_exited','event_terminated'}) do
      d.listeners.after[name].forge_node_e2e=function(_,body) table.insert(_G.forge_node_events,{name=name,body=body}) end end]])
end
local function paused(e)
  e:wait('настоящий Node breakpoint',function() return e:lua([[local s=require('dap').session();return s and s.stopped_thread_id~=nil and s.current_frame~=nil]]) end,40000)
  require('output_policy').reopen(e,'dap-repl',' md')
  e:input('<F7>');seek(e,'answer');e:input(' de')
  e:wait('eval answer=42',function() return text(e,'dap-float'):find('42',1,true)~=nil end,10000)
  e:input('q<F7><F5>');e:wait('Node сессия завершилась',function() return e:lua([[return require('dap').session()==nil]]) end,30000)
end
check('IDE-NODE-3 default F5 и project launch.json',function(e)
  language(e,'app.js');e:input('7G<F9>');observe_dap(e);e:input('<F5>');paused(e)
  assert(text(e,'dap-repl'):find('NODE_BEFORE default',1,true));assert(text(e,'dap-repl'):find('NODE_STDERR',1,true))
  require('output_policy').reopen(e,'dap-repl',' du')
  local cfg={name='Project Node',type='node',request='launch',program='${workspaceFolder}/app.js',cwd=e.node_project,args={'from-launch'},console='internalConsole'}
  vim.fn.writefile({vim.json.encode({version='0.2.0',configurations={cfg}})},e.node_project..'/.vscode/launch.json')
  e:input('<F7><F5>');e:wait('project config picker',function() return e:current_ft()=='TelescopePrompt' end)
  e:wait('DAP picker принимает ввод',function() return e.rpc:request('nvim_get_mode',{}).mode=='i' end)
  e:input('Project Node');e:wait('project выбран',function() return e:lua([[local v=require('telescope.actions.state').get_selected_entry();return v and v.ordinal:find('Project Node',1,true)~=nil]]) end)
  e:input('<CR>');paused(e);assert(text(e,'dap-repl'):find('NODE_BEFORE from-launch',1,true))
end)
check('IDE-NODE-3 отсутствие adapter не оставляет сессию',function(e)
  open(e,'app.js');e:input('<F5>')
  e:wait('понятное сообщение',function()
    if e.rpc:request('nvim_get_mode',{}).blocking then e:ack_warning('js-debug adapter');return false end
    return e:lua([[for _,n in ipairs(vim.g.forge_e2e_notifications) do if n.message:find('js-debug adapter не найден',1,true) then return true end end;return false]])
  end)
  T.eq(e:lua([[return require('dap').session()==nil]]),true)
  e:input('<F7>gg0i// STILL_EDITABLE<Esc>:write<CR>')
  e:wait('редактирование работает',function() return vim.fn.readfile(e.node_project..'/app.js')[1]:find('STILL_EDITABLE',1,true)~=nil end)
end,true)
check('IDE-NODE-1 отсутствующий Node не мешает редактированию',function(e)
  open(e,'src/complete.js');e:input('4Gccreturn 42;<Esc>:write<CR>')
  e:wait('файл сохранён без Node',function() return table.concat(vim.fn.readfile(e.node_project..'/src/complete.js'),'\n'):find('return 42;',1,true)~=nil end)
  T.eq(e:lua([[return #vim.lsp.get_clients({name='ts_ls'})]]),0)
  e:input('<F5>');e:wait('Node отсутствует без сессии',function()
    if e.rpc:request('nvim_get_mode',{}).blocking then e:ack_warning('Node.js');return false end
    return e:lua([[if require('dap').session() then return false end;for _,n in ipairs(vim.g.forge_e2e_notifications) do
      if n.message:find('Node.js не найден',1,true) then return true end end;return false]])
  end)
end,'node')
check('IDE-NODE-4 nearest/file Jest и настоящий вывод',function(e)
  open(e,'math.test.js');discover(e);e:input('7G Tt');results(e)
  T.eq(counts(e).passed,1);T.eq(counts(e).failed,0);T.eq(vim.fn.filereadable(e.node_project..'/neighbor-ran.txt'),0)
  e:wait('Jest output',function() return text(e,'neotest-output-panel'):find('JEST_VALUE',1,true)~=nil end)
  e:input('<F7> Tf');e:wait('file pass/fail',function() local s=counts(e);return s.passed==1 and s.failed==1 and s.running==0 end,60000)
  T.eq(vim.fn.filereadable(e.node_project..'/neighbor-ran.txt'),1)
  e:input(' wt');e:wait('Tests summary',function() return e:current_ft()=='neotest-summary' end)
end)
check('IDE-NODE-4 debug nearest Jest breakpoint/eval/continue',function(e)
  open(e,'math.test.js');discover(e);e:input('7G<F9>');observe_dap(e);e:input(' Td');paused(e)
  results(e);T.eq(counts(e).passed,1);T.eq(counts(e).failed,0);T.eq(vim.fn.filereadable(e.node_project..'/neighbor-ran.txt'),0)
  assert(text(e,'dap-repl'):find('JEST_VALUE',1,true))
end)
T.finish()
