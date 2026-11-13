-- Native Bash DAP stdin и чтение Output без мыши, IDE-SH-5/WF-06/13.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local win=vim.fn.has('win32')==1
local deps=vim.env.FORGE_E2E_BASH_DAP_DEPS or root..'/.tests/bash-dap-deps'
local node_deps=vim.env.FORGE_E2E_NODE_DEPS or root..'/.tests/node-deps'
local node_manifest=vim.json.decode(table.concat(vim.fn.readfile(node_deps..'/manifest.json'),'\n'))
local node=vim.fs.joinpath(node_deps,node_manifest.node)
local function output(e)
  return e:lua([[local lines={};for _,w in ipairs(vim.api.nvim_list_wins()) do local b=vim.api.nvim_win_get_buf(w)
    if vim.bo[b].filetype=='dap-terminal' then vim.list_extend(lines,vim.api.nvim_buf_get_lines(b,0,-1,false)) end
    end;return table.concat(lines,'\n')]])
end
local function check(stop)
  local label=stop and 'stop на read из terminal-mode' or 'scrollback и Unicode stdin'
  T.check('SELF: BASH-INTERACTIVE '..label,function()
    local e,script,report,sentinel
    local ok,err=xpcall(function()
      local entry=deps..'/extension/out/bashDebug.js'
      assert(vim.fn.filereadable(entry)==1,'Нужен prepare_bash_dap.py --download')
      e=require('editor').start(root,{timeout=90000,
        env={FORGE_NODE_EXECUTABLE=node,FORGE_BASH_DEBUG_ADAPTER=entry},prepare=function(project)
          local dir=project..'/Interactive Bash ü with space';vim.fn.mkdir(dir,'p');script=dir..'/interactive.sh'
          vim.fn.writefile(vim.fn.readfile(root..'/tests/e2e/fixtures/bash-debug/interactive.sh'),script)
          local r=vim.system({'git','init',dir},{text=true}):wait();assert(r.code==0,r.stderr)
        end})
      report={};assert(vim.uv.fs_copyfile(root..'/tests/e2e/bash-interactive.test.lua',e.dir..'/bash-interactive.test.lua'))
      e:input(':edit '..vim.fn.fnameescape(script)..'<CR>')
      e:wait('Bash открыт',function() return e:current_file()==script and e:current_ft()=='sh' end)
      e:lua([[require('dap').set_log_level('TRACE')]])
      report.editor_pid=e:lua('return vim.fn.getpid()')
      sentinel=e:lua([[local node=...;vim.g.forge_bash_sentinel_ready=false
        return vim.fn.jobstart({node,'-e',"console.log('FORGE_INDEPENDENT_READY');setInterval(()=>{},1000)"},
          {detach=false,on_stdout=function(_,lines) for _,line in ipairs(lines) do
            if line=='FORGE_INDEPENDENT_READY' then vim.g.forge_bash_sentinel_ready=true end end end})]],{node})
      assert(sentinel>0)
      e:wait('Отдельный Editor job готов',function() return e:lua('return vim.g.forge_bash_sentinel_ready') end)
      report.sentinel_pid=e:lua('return vim.fn.jobpid(...)',{sentinel})
      e:input('7G<F9><F5>')
      local function paused()
        return e:lua([[local s=require('dap').session();return s and s.stopped_thread_id and s.current_frame and true or false]])
      end
      e:wait('Bash native pause',paused,30000)
      if e:lua([[return require('dap').session().current_frame.line]])~=7 then e:input('<F5>') end
      e:wait('Breakpoint перед read',function() return e:lua([[local s=require('dap').session()
        return s and s.stopped_thread_id and s.current_frame and s.current_frame.line==7]]) end,30000)
      local pids=vim.split(table.concat(vim.fn.readfile(vim.fs.dirname(script)..'/forge-interactive-pids'),' '),'%s+',{trimempty=true})
      assert(#pids==2 and tonumber(pids[1])>1 and tonumber(pids[2])>1);report.pids=pids
      e:wait('120 строк доступны в Output',function() return output(e):find('FORGE_SCROLL_120',1,true)~=nil end)
      if not stop then
        e:input(' wc<C-\\><C-n>')
        e:wait('Output normal-mode',function() return e:current_ft()=='dap-terminal' and e.rpc:request('nvim_get_mode',{}).mode~='t' end)
        e:input('gg/FORGE_SCROLL_010<CR>')
        e:wait('Ранний вывод найден клавиатурой',function() return e:lua([[return vim.api.nvim_get_current_line():find('FORGE_SCROLL_010',1,true)~=nil]]) end)
        report.scrollback=e:lua([[return {line=vim.api.nvim_get_current_line(),view=vim.fn.winsaveview()}]])
        assert(paused(),'Чтение Output продолжило debug')
        T.eq(e:lua([[return require('dap').session().current_frame.line]]),7)
      end
      e:input(' w0<F5>')
      e:wait('Программа ждёт stdin',function() return output(e):find('FORGE_INPUT> ',1,true)~=nil end,15000)
      assert(e:lua([[local s=require('dap').session();return s and not s.stopped_thread_id]]),'read не выполняется')
      e:input(' wc');e:wait('Output выбран',function() return e:current_ft()=='dap-terminal' end)
      e:input('i');e:wait('Terminal input mode',function() return e.rpc:request('nvim_get_mode',{}).mode=='t' end)
      if stop then
        e:input('<S-F5>')
        e:wait('Stop из terminal-mode',function() return e:lua([[return require('dap').session()==nil]]) end,15000)
        assert(not output(e):find('FORGE_AFTER_READ',1,true),'Stop продолжил script после read')
        report.stop=true
      else
        e:input('Ada Lovelace ü<CR>')
        e:wait('Unicode stdin получен Bash',function() return output(e):find('FORGE_ECHO:Ada Lovelace ü',1,true)~=nil end,15000)
        e:wait('Script продолжился и завершился',function() return output(e):find('FORGE_AFTER_READ',1,true)
          and e:lua([[return require('dap').session()==nil]]) end,15000)
        e:input('<C-\\><C-n>gg/FORGE_SCROLL_001<CR>')
        e:wait('Scrollback сохранён после exit',function() return e:lua([[return vim.api.nvim_get_current_line():find('FORGE_SCROLL_001',1,true)~=nil]]) end)
        report.input=true;report.post_exit_history=true
        assert(not output(e):find('Killed',1,true),'Нормальный exit показан как Killed')
      end
      report.sentinel_status=e:lua('return vim.fn.jobwait({...},0)[1]',{sentinel})
      T.eq(report.sentinel_status,-1,'Bash Stop/exit завершил посторонний Editor job')
      -- PID принадлежат fixture; Editor не должен считаться дочерним backend.
      local owned={pids[1]}
      if win or tonumber(pids[2])~=report.editor_pid then owned[#owned+1]=pids[2] end
      report.owned_pids=owned
      -- До e.stop: закрытие Editor не должно скрыть backend leak.
      e:wait('Fixture Unix PID завершены до закрытия IDE',function()
        local cmd=win and {'wsl.exe','--exec'} or {};vim.list_extend(cmd,{'ps','-p',table.concat(owned,','),'-o','pid=,stat=,comm='})
        local r=vim.system(cmd,{text=true,timeout=5000}):wait();report.unix_before_editor_stop={code=r.code,stdout=r.stdout,stderr=r.stderr}
        return r.code==1 and vim.trim(r.stdout or '')==''
      end,10000)
      report.output=output(e)
      for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    end,debug.traceback)
    if e then
      report=report or {};report.ok=ok;report.error=not ok and err or nil
      pcall(function() report.mode=e.rpc:request('nvim_get_mode',{});report.output=output(e) end)
      pcall(e.snapshot,e,'bash-interactive')
      if not ok then
        pcall(function()
          if e.rpc:request('nvim_get_mode',{}).blocking then e:input('<CR>') end
          e:input('<C-\\><C-n>')
          if e:lua([[return require('dap').session()~=nil]]) then
            e:input('<S-F5>');e:wait('Отмена собственного debug после FAIL',function() return e:lua([[return require('dap').session()==nil]]) end,8000)
          end
        end)
      end
      if sentinel then pcall(function() e:lua('if vim.fn.jobwait({...},0)[1]==-1 then vim.fn.jobstop(...) end',{sentinel}) end) end
      for _,path in ipairs(vim.fs.find(function(name) return name:match('^dap.*%.log$')~=nil end,
        {path=e.runtime..'/cache',type='file',limit=30})) do assert(vim.uv.fs_copyfile(path,e.dir..'/'..vim.fs.basename(path))) end
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/bash-interactive.json')
      io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,why=pcall(e.stop,e,not ok and err or nil)
      if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(why) end
    end
    assert(ok,err)
  end)
end
check(false);check(true)

T.check('SELF: BASH-INTERACTIVE explicit SDK preparation',function()
  local e,adapter,script,report
  local patch=vim.json.decode(table.concat(vim.fn.readfile(root..'/nvim_forge/lua/forge/bash_debug_patch.json'),'\n'))
  local function source(path) local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
  local function hash(path) return vim.fn.sha256((source(path):gsub('\r\n','\n'))) end
  local function copy(from,to)
    vim.fn.mkdir(to,'p');for name,kind in vim.fs.dir(from) do
      if kind=='directory' then copy(from..'/'..name,to..'/'..name)
      else assert(vim.uv.fs_copyfile(from..'/'..name,to..'/'..name)) end
    end
  end
  local ok,err=xpcall(function()
    e=require('editor').start(root,{timeout=90000,env={FORGE_NODE_EXECUTABLE=node},prepare=function(project,env)
      env.FORGE_BASH_DEBUG_ADAPTER=nil
      local target=env.XDG_DATA_HOME..'/nvim_forge'..(win and '-data' or '')..'/mason/packages/bash-debug-adapter'
      copy(deps..'/extension',target..'/extension');adapter=target..'/extension/out/bashDebug.js'
      local s=source(adapter):gsub('\r\n','\n')
      for _,replacement in ipairs(patch.replacements) do
        local first,last=assert(s:find(replacement.after,1,true))
        s=s:sub(1,first-1)..replacement.before..s:sub(last+1)
      end
      vim.fn.writefile(vim.split(s,'\n',{plain=true}),adapter,'b')
      local dir=project..'/SDK guard ü';vim.fn.mkdir(dir,'p');script=dir..'/prepare.sh'
      vim.fn.writefile({'#!/usr/bin/env bash','value=42',[[printf 'FORGE_PREPARED_%s\n' "$value"]]},script)
      local r=vim.system({'git','init',dir},{text=true}):wait();assert(r.code==0,r.stderr)
    end})
    report={before=hash(adapter)};T.eq(report.before,patch.payloads[1].before_sha256,'Startup изменил SDK')
    e:input(':edit '..vim.fn.fnameescape(script)..'<CR><F5>')
    local function notify_after(mark,needle)
      e:wait('SDK сообщение '..needle,function() for i=mark+1,#e.rpc.notifications do
        if e.rpc.notifications[i].message:find(needle,1,true) then return true end end end)
      if e.rpc:request('nvim_get_mode',{}).blocking then e:input('<CR>') end
    end
    notify_after(0,'SDK не подготовлен')
    T.eq(hash(adapter),report.before,'F5 изменил SDK');T.eq(e:lua([[return require('dap').session()==nil]]),true)
    e:input(' w0:BashDebugPrepare<CR>');e:wait('Явная подготовка',function() return hash(adapter)==patch.payloads[1].after_sha256 end)
    local ready=source(adapter);local mark=#e.rpc.notifications;e:input(':BashDebugPrepare<CR>');notify_after(mark,'уже готов')
    T.eq(source(adapter),ready,'Repeat записал другой payload')
    vim.fn.writefile(vim.split(ready..'\n// unknown SDK payload\n','\n',{plain=true}),adapter,'b')
    local unknown=source(adapter);mark=#e.rpc.notifications;e:input(':BashDebugPrepare<CR>');notify_after(mark,'Неизвестный SDK')
    T.eq(source(adapter),unknown,'Unknown SDK был изменён')
    vim.fn.writefile(vim.split(ready,'\n',{plain=true}),adapter,'b')
    e:input('3G<F9><F5>');e:wait('Подготовленный SDK запустился',function() return e:lua([[local s=require('dap').session()
      return s and s.stopped_thread_id and s.current_frame and true or false]]) end,30000)
    if e:lua([[return require('dap').session().current_frame.line]])~=3 then e:input('<F5>') end
    e:wait('Breakpoint подготовленного SDK',function() return e:lua([[local s=require('dap').session()
      return s and s.stopped_thread_id and s.current_frame and s.current_frame.line==3]]) end,30000)
    e:input('<F5>');e:wait('Подготовленный SDK завершил файл',function() return output(e):find('FORGE_PREPARED_42',1,true)
      and e:lua([[return require('dap').session()==nil]]) end,15000)
    report.after=hash(adapter);report.no_startup_write=true;report.no_launch_write=true;report.repeat_ok=true;report.unknown_preserved=true
    T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
  end,debug.traceback)
  if e then
    report=report or {};report.ok=ok;report.error=not ok and err or nil
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/bash-sdk-prepare.json');pcall(e.snapshot,e,'bash-sdk-prepare')
    io.stdout:write('  artifacts: '..e.dir..'\n');local stopped,why=pcall(e.stop,e,not ok and err or nil)
    if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(why) end
  end
  assert(ok,err)
end)

T.check('SELF: BASH-INTERACTIVE CLI SDK LF CRLF repeat unknown',function()
  local python=vim.fn.exepath(win and 'python' or 'python3');assert(python~='')
  local patch=vim.json.decode(table.concat(vim.fn.readfile(root..'/nvim_forge/lua/forge/bash_debug_patch.json'),'\n'))
  local f=assert(io.open(deps..'/extension/out/bashDebug.js','rb'));local ready=f:read('*a'):gsub('\r\n','\n');f:close()
  local before=ready
  for _,replacement in ipairs(patch.replacements) do
    local first,last=assert(before:find(replacement.after,1,true))
    before=before:sub(1,first-1)..replacement.before..before:sub(last+1)
  end
  local dir=vim.fn.tempname()..'-bash-sdk';vim.fn.mkdir(dir,'p')
  for _,ending in ipairs({'\n','\r\n'}) do
    local path=dir..'/adapter.js';local original=before:gsub('\n',ending)
    local target=assert(io.open(path,'wb'));assert(target:write(original));target:close()
    local function run() return vim.system({python,'-B',root..'/tests/e2e/prepare_bash_dap.py','--patch-installed',path},{text=true}):wait() end
    T.eq(run().code,0);local r=assert(io.open(path,'rb'));local patched=r:read('*a');r:close()
    T.eq(patched,ready:gsub('\n',ending));T.eq(run().code,0)
    local bad=assert(io.open(path,'ab'));bad:write('\n// unknown');bad:close()
    T.eq(run().code,2);r=assert(io.open(path,'rb'));T.eq(r:read('*a'),patched..'\n// unknown');r:close()
  end
  assert(vim.uv.fs_unlink(dir..'/adapter.js'));assert(vim.uv.fs_rmdir(dir))
end)
T.finish()
