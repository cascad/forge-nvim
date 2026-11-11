-- spec: IDE-LOG-2/3/4. Native formatter failure, сообщения, Fidget, живой output.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function text(e)
  return e:lua([[local b=require('forge.logs').buf
    return b and table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n') or '']])
end
local function open(e,source)
  e:input(':ForgeLogs'..(source and ' '..source or '')..'<CR>')
  e:wait('Logs focused',function() return e:current_ft()=='forge-logs'
    and (not source or e:lua('return require("forge.logs").source')==source) end)
end
local function check(name,fn)
  if vim.env.FORGE_LOG_SOURCE_CASE and not name:find(vim.env.FORGE_LOG_SOURCE_CASE,1,true) then return end
  T.check(name,function()
    local e,report
    local ok,err=xpcall(function()
      e=require('editor').start(root)
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/ide-log-sources.test.lua',e.dir..'/ide-log-sources.test.lua'))
      e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      report={case=name};fn(e,report)
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    end,debug.traceback)
    if e then
      report=report or {case=name};report.ok=ok;report.error=not ok and tostring(err) or nil
      local captured,capture_error=pcall(function()
        report.text=text(e)
        report.store=e:lua([[local s=require('forge.log_store');return {session=s.session,path=s.path,
          entries=s.entries(),damaged=s.damaged,error=s.disk_error or false}]])
        report.debug=e:lua([[local d=package.loaded.dap;local s=d and d.session();return {
          events=_G.log_debug_events or {},session=s and {thread=s.stopped_thread_id or false,
          frame=s.current_frame or false,type=s.config.type,program=s.config.program,cwd=s.config.cwd} or false}]])
        for _,source in ipairs(e:lua('return require("forge.log_sources").list()')) do
          if source.path and source.id:match('^dap') and vim.fn.filereadable(source.path)==1 then
            assert(vim.uv.fs_copyfile(source.path,e.dir..'/native-'..vim.fn.fnamemodify(source.path,':t')))
          end
        end
        local dir=vim.fn.fnamemodify(report.store.path,':h')
        vim.fn.mkdir(e.dir..'/forge-history','p')
        for file,kind in vim.fs.dir(dir) do if kind=='file' then assert(vim.uv.fs_copyfile(dir..'/'..file,e.dir..'/forge-history/'..file)) end end
      end)
      if not captured then ok=false;err=tostring(err or '')..'\nCapture: '..tostring(capture_error);report.ok=false;report.error=err end
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/ide-log-sources.json');e:snapshot('ide-log-sources')
      io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,issue=pcall(e.stop,e,not ok and err or nil);assert(stopped,issue)
      assert(e.rpc.exit_code==0 and e.rpc.exit_signal==0 and #e.rpc.api_errors==0,'Native root/API failure')
    end
    assert(ok,err)
  end)
end

check('IDE-LOG-2 real gofmt error and native log stay intact',function(e,r)
  local gofmt=vim.fn.exepath('gofmt');assert(gofmt~='','gofmt prerequisite')
  e:input(':edit file_one.txt<CR>');e:wait('text file',function() return e:current_ft()=='text' end)
  e:lua([[local exe=...;require('conform').setup({
    formatters={forge_log_gofmt={command=exe,stdin=true}},formatters_by_ft={text={'forge_log_gofmt'}}})]],{gofmt})
  e:input(':Format<CR>')
  e:wait('native formatter error',function()
    if e.rpc:request('nvim_get_mode',{}).blocking then e:ack_warning('Форматирование');return false end
    for _,n in ipairs(e.rpc.notifications) do if n.message:find('Форматирование не выполнено',1,true) then return true end end
  end)
  local path=e:lua('return require("conform.log").get_logfile()')
  local before=assert(io.open(path,'rb'));local original=before:read('*a');before:close()
  assert(original:find('gofmt',1,true),original)
  open(e,'format');e:wait('native error log visible',function() return text(e):find('gofmt',1,true)~=nil end)
  assert(text(e):find('Путь:',1,true) and text(e):find('Хвост источника:',1,true))
  e:input('r');e:input('y')
  e:wait('native report copied',function() return e:lua([[return vim.fn.getreg('"')]]):find('gofmt',1,true)~=nil end)
  local after=assert(io.open(path,'rb'));T.eq(after:read('*a'),original,'Console modified native log');after:close()
  assert(vim.uv.fs_copyfile(path,e.dir..'/conform-native.log'))
  r.path=path;r.original=original
  T.eq(vim.fn.readfile(e.project..'/file_one.txt')[1],'first file')
end)

check('IDE-LOG-2 native command failure and absent versus empty source',function(e,r)
  e:input(':edit file_one.txt<CR>');e:wait('text file',function() return e:current_ft()=='text' end)
  e:input(':ForgeNonexistentCommandForLogs<CR>')
  e:wait('native E492 visible',function() return table.concat(e.rpc:screen_lines(),'\n'):find('E492',1,true)~=nil end)
  if e.rpc:request('nvim_get_mode',{}).blocking then e:input('<CR>') end
  open(e);e:wait('native error retained',function() return text(e):find('E492',1,true)~=nil end)
  assert(text(e):find('snapshot',1,true))
  open(e,'lsp')
  local path=e:lua([[for _,s in ipairs(require('forge.log_sources').list()) do if s.id=='lsp' then return s.path end end]])
  assert(not vim.uv.fs_stat(path),'Fixture unexpectedly has an LSP log')
  assert(text(e):find('файл не найден',1,true))
  local f=assert(io.open(path,'wb'));f:close()
  e:input('r');e:wait('existing empty log distinct',function() return text(e):find('доступен; пусто',1,true)~=nil end)
  r.native=e:lua('return vim.fn.execute("messages")')
end)

check('IDE-LOG-2 direct Fidget and credential report redaction',function(e,r)
  e:lua([[require('fidget').notify('FIDGET_DIRECT_LOG',vim.log.levels.WARN)
    vim.notify('password=DO_NOT_EXPORT token="TOKEN_VALUE" https://user:URL_SECRET@example.test Bearer AUTH_SECRET',
      vim.log.levels.WARN,{title='Setup',data={token='OPT_DATA_SECRET'}})]])
  open(e);e:wait('Fidget recorded',function() return text(e):find('FIDGET_DIRECT_LOG',1,true)~=nil end)
  e:input('y');e:wait('report available',function() return e:lua([[return vim.fn.getreg('"')]]):find('[redacted]',1,true)~=nil end)
  local copy=e:lua([[return vim.fn.getreg('"')]])
  for _,secret in ipairs({'DO_NOT_EXPORT','TOKEN_VALUE','URL_SECRET','AUTH_SECRET','OPT_DATA_SECRET'}) do
    assert(not copy:find(secret,1,true),'Secret in report: '..secret)
  end
  r.copy=copy
  T.eq(e:lua([[local count=0;for _,item in ipairs(require('forge.log_store').entries()) do
    if item.message=='FIDGET_DIRECT_LOG' then count=count+1 end end;return count]]),1)
end)

check('IDE-LOG-4 reading actual live terminal does not restart or stop it',function(e,r)
  local fixture=e.project..'/log-output.lua'
  vim.fn.writefile({[[io.stdout:write('LOG_NATIVE_OUTPUT\n');io.stdout:flush();vim.defer_fn(function() vim.cmd('qa!') end,60000)]]},fixture)
  local live=e:lua([[vim.cmd('enew');local path=...;local job=vim.fn.jobstart({vim.v.progpath,'--headless','-u','NONE','-c','luafile '..vim.fn.fnameescape(path)},{term=true})
    _G.log_output_job=job;return {job=job,pid=vim.fn.jobpid(job),buf=vim.api.nvim_get_current_buf()}]],{fixture})
  e:wait('real child stdout',function() return e:lua([[return table.concat(vim.api.nvim_buf_get_lines(...,0,-1,false),'\n')]],{live.buf}):find('LOG_NATIVE_OUTPUT',1,true)~=nil end)
  local before=e:lua('return #_G.forge_e2e_spawns')
  open(e,'buffer:'..live.buf);e:wait('output in console',function() return text(e):find('LOG_NATIVE_OUTPUT',1,true)~=nil end)
  e:input('r');e:input('y')
  e:wait('report copied',function() return e:lua([[return vim.fn.getreg('"')]]):find('LOG_NATIVE_OUTPUT',1,true)~=nil end)
  T.eq(e:lua('return vim.fn.jobpid(_G.log_output_job)'),live.pid)
  T.eq(e:lua('return vim.fn.jobwait({_G.log_output_job},0)[1]'),-1)
  T.eq(e:lua('return #_G.forge_e2e_spawns'),before,'Console spawned a process')
  r.live=live
  e:lua('assert(vim.fn.jobstop(_G.log_output_job)==1)')
  e:wait('own child stopped',function() return e:lua('return vim.fn.jobwait({_G.log_output_job},0)[1]')~=-1 end)
end)

check('IDE-LOG-4 bounded Unicode burst keeps valid persisted records',function(e,r)
  e:lua([[local f=require('fidget');for i=1,220 do
    f.notify('LOG_BURST_'..i..' '..string.rep('Я',512),vim.log.levels.WARN,{hidden=true})
  end;vim.notify('LOG_UNICODE_BOUNDARY',vim.log.levels.WARN,{title=string.rep('Я',45)})]])
  open(e);e:wait('bounded history visible',function() return text(e):find('LOG_BURST_220',1,true)~=nil end)
  local status=e:lua([[local s=require('forge.log_store');return {path=s.path,limit=s.file_limit,
    count=#s.entries(),error=s.disk_error or false,dropped=s.dropped or false,rotated=s.rotated or false}]])
  T.eq(status.count,200);T.eq(status.error,false);assert(status.dropped and status.rotated)
  local bytes=0
  for _,path in ipairs({status.path,status.path..'.1'}) do
    local stat=assert(vim.uv.fs_stat(path));assert(stat.size<=status.limit,'Unbounded history file');bytes=bytes+stat.size
    for _,line in ipairs(vim.fn.readfile(path)) do
      local decoded=vim.json.decode(line);assert(type(decoded.message)=='string' and type(decoded.source)=='string')
    end
  end
  r.bytes=bytes;r.bounds=status
  assert(text(e):find('Старые сообщения ограничены',1,true))
end)

check('IDE-LOG-4 disk failure keeps console and native notifications usable',function(e,r)
  local path=e:lua('return require("forge.log_store").path')
  assert(path:find(e.runtime,1,true)==1,'Storage outside own runtime')
  assert(vim.uv.fs_rename(path,path..'.saved'));assert(vim.uv.fs_mkdir(path,448))
  e:lua([[vim.notify('LOG_PERSISTENCE_FAILED_BUT_VISIBLE',vim.log.levels.WARN,{title='Setup'})]])
  open(e);e:wait('persistence failure visible',function()
    return text(e):find('Ошибка хранения:',1,true) and text(e):find('LOG_PERSISTENCE_FAILED_BUT_VISIBLE',1,true)
  end)
  assert(e:lua('return vim.fn.execute("messages")'):find('LOG_PERSISTENCE_FAILED_BUT_VISIBLE',1,true))
  e:input('q');e:wait('code available',function() return e:current_ft()~='forge-logs' end)
  open(e);assert(text(e):find('LOG_PERSISTENCE_FAILED_BUT_VISIBLE',1,true))
  assert(vim.uv.fs_rmdir(path));assert(vim.uv.fs_rename(path..'.saved',path))
  r.failure=e:lua('return require("forge.log_store").disk_error')
end)

check('IDE-LOG-1 IDE-LOG-3 native source picker details and health',function(e,r)
  open(e)
  e:input('s');e:wait('native source chooser visible',function()
    return table.concat(e.rpc:screen_lines(),'\n'):find('Neovim :messages',1,true)~=nil
      and e.rpc:request('nvim_get_mode',{}).mode~='n'
  end)
  e:snapshot('log-source-picker')
  local picker_mode=e.rpc:request('nvim_get_mode',{})
  if picker_mode.blocking or picker_mode.mode:sub(1,1)=='r' then e:input('2<CR>')
  else
    e:wait('Telescope source input ready',function() return e:current_ft()=='TelescopePrompt'
      and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
    e:input('<C-u>Neovim :messages')
    e:wait('messages selected',function() return e:lua([[local v=require('telescope.actions.state').get_selected_entry()
      return v and v.ordinal:find('Neovim :messages',1,true)~=nil]]) end)
    e:input('<CR>')
  end
  e:wait('selected messages source',function()
    return e:lua('return require("forge.logs").source')=='messages' and text(e):find('Neovim :messages',1,true)~=nil
  end)
  e:lua([[vim.notify('LOG_DETAIL_CONTENT',vim.log.levels.WARN,{title='Setup'})]])
  open(e,'events');e:input('gg/LOG_DETAIL_CONTENT<CR>')
  e:wait('event row selected',function() return e:lua('return vim.fn.getline(".")'):find('LOG_DETAIL_CONTENT',1,true)~=nil end)
  e:input('<CR>');e:wait('details focused',function()
    return e:lua('return vim.api.nvim_win_get_config(0).relative')~=''
      and e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]]):find('LOG_DETAIL_CONTENT',1,true)~=nil
  end)
  e:input('q');e:wait('details return to logs',function() return e:current_ft()=='forge-logs' end)
  e:input('H');e:wait('native Forge health',function() return e:current_ft()=='checkhealth'
    and e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]]):find('forge:',1,true)~=nil end,10000)
  r.health=e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]])
  assert(r.health:find('forge:',1,true),'Wrong health source')
end)

check('IDE-LOG-2 missing Node recovery starts real js-debug without restart',function(e,r)
  local deps=vim.env.FORGE_E2E_NODE_DEPS or root..'/.tests/node-deps'
  local manifest=vim.json.decode(table.concat(vim.fn.readfile(deps..'/manifest.json'),'\n'))
  local node=deps..'/'..manifest.node
  local server=deps..'/debug/js-debug/src/dapDebugServer.js'
  assert(vim.fn.executable(node)==1 and vim.fn.filereadable(server)==1,'Prepared Node/js-debug prerequisite')
  vim.fn.writefile({'console.log("LOG_RECOVERED_DEBUG");','let value = 42;','console.log("LOG_RECOVERY_DONE",value);'},e.project..'/recovery.js')
  e:lua([[local server=...;vim.g.forge_node_executable=vim.fn.getcwd()..'/absent-node';vim.g.forge_js_debug_server=server]],{server})
  e:input(':edit recovery.js<CR>');e:wait('recovery JS',function() return e:current_ft()=='javascript' end)
  e:input('2G<F9>');e:wait('real breakpoint stored',function() return e:lua([[local b=require('dap.breakpoints').get()[vim.api.nvim_get_current_buf()]
    return b and b[1] and b[1].line]])==2 end)
  e:input('<F5>');e:wait('missing warning',function()
    for _,n in ipairs(e.rpc.notifications) do if n.message:find('Node.js не найден',1,true) then return true end end
  end)
  open(e);assert(text(e):find('Node.js не найден',1,true))
  e:lua('vim.g.forge_node_executable=...',{node})
  e:lua([[local d=require('dap');_G.log_debug_events={}
    for _,event in ipairs({'event_initialized','event_thread','event_stopped','event_continued','event_exited','event_terminated'}) do
      d.listeners.after[event].forge_log_recovery=function(_,body) _G.log_debug_events[#_G.log_debug_events+1]={event=event,body=body} end
    end]])
  e:input(' w0');e:wait('recovery code before F5',function() return e:current_ft()=='javascript' and e:current_file():match('/recovery%.js$') end)
  e:input('<F5>');e:wait('real js-debug stopped',function()
    return e:lua([[local s=require('dap').session();return s and s.stopped_thread_id~=nil and s.current_frame~=nil]])
  end,40000)
  local before=e:lua([[local s=require('dap').session();return {id=s.id,thread=s.stopped_thread_id,pid=vim.uv.os_getpid()}]])
  open(e);assert(text(e):find('Node.js не найден',1,true))
  T.eq(e:lua('return require("dap").session().stopped_thread_id'),before.thread,'Logs continued debug')
  e:input(' w0');e:wait('recovery code before continue',function() return e:current_ft()=='javascript' end)
  e:input('<F5>');e:wait('debug finished',function() return e:lua('return require("dap").session()==nil') end,20000)
  e:wait('real stdout after recovery',function() return e:lua([[for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].filetype=='dap-repl' and table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n'):find('LOG_RECOVERY_DONE',1,true) then return true end end;return false]]) end)
  T.eq(e:lua('return vim.uv.os_getpid()'),before.pid)
  r.debug=before;r.node=node;r.server=server
end)
T.finish()
