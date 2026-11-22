-- spec: IDE-PANEL-19. Реальные native shell/PTY; окружение только private child.
local test_source=debug.getinfo(1,'S').source:sub(2)
local root=vim.env.FORGE_REPO or vim.fn.fnamemodify(test_source,':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local P=require('output_policy')
local windows=vim.fn.has('win32')==1
local escape=string.char(28)..string.char(14)
local function mode(e) return e.rpc:request('nvim_get_mode',{}).mode end
local function keys(e,value)
  local before=e:lua('return _G.shell_keys')
  e:input(value..'<F35>');e:wait('input consumed',function() return e:lua('return _G.shell_keys')>before end)
end
local function normal(e)
  if mode(e)=='t' then e:input(escape);e:wait('terminal normal',function() return mode(e):sub(1,1)=='n' end) end
end
local function result(path)
  if vim.fn.filereadable(path)~=1 then return nil end
  return vim.trim(table.concat(vim.fn.readfile(path),'\n'))
end
local function state(e)
  return e:lua([[local all=require('toggleterm.terminal').get_all();assert(#all==1,'expected one managed terminal')
    local t=all[1];local b=t.bufnr;local cfg=require('toggleterm.config').get('shell')
    return {buf=b,channel=t.job_id,pid=vim.fn.jobpid(t.job_id),status=vim.fn.jobwait({t.job_id},0)[1],
      text=table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n'),buftype=vim.bo[b].buftype,
      selected=type(cfg)=='function' and cfg() or cfg,shell=vim.o.shell,pwsh=vim.fn.executable('pwsh'),
      installs=vim.g.forge_e2e_installs,dap=package.loaded.dap and package.loaded.dap.session()~=nil or false}]])
end
local function check(label,posix,present)
  local name='IDE-PANEL-19 '..label
  if windows==posix then T.skip(name,posix and 'POSIX only' or 'Windows only');return end
  local pwsh=windows and vim.fn.exepath('pwsh') or ''
  if windows and present and pwsh=='' then T.skip(name,'pwsh not resolved by exepath; add a real installation to this test PATH');return end
  T.check(name,function()
    local e,report,prepared
    local ok,err=xpcall(function()
      local git=vim.fn.exepath('git');assert(git~='','Git prerequisite')
      e=require('editor').start(root,{timeout=120000,prepare=function(project,env,runtime)
        local bin=runtime..'/shell-bin';vim.fn.mkdir(bin,'p')
        prepared={pwsh_log=project..'/pwsh-started.txt'}
        env.FORGE_TERMINAL_SHELL_LOG=prepared.pwsh_log
        if not windows then
          for _,tool in ipairs({'git','stty'}) do
            local exe=vim.fn.exepath(tool);if exe~='' then assert(vim.uv.fs_symlink(exe,bin..'/'..tool)) end
          end
          env.SHELL=present and '/bin/bash' or '/bin/sh'
          assert(vim.fn.executable(env.SHELL)==1,'real POSIX shell prerequisite')
          env.PATH=bin;prepared.expected=env.SHELL
          if present then
            assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/terminal-shell/pwsh',bin..'/pwsh'))
            assert(vim.uv.fs_chmod(bin..'/pwsh',493))
          end
        else
          local system=(vim.env.SystemRoot or 'C:/Windows')..'/System32'
          env.PATH=vim.fn.fnamemodify(git,':h')..';'..system
          if present then env.PATH=vim.fn.fnamemodify(pwsh,':h')..';'..env.PATH end
          prepared.expected=present and 'pwsh -NoLogo' or nil
        end
        prepared.path=env.PATH
      end})
      assert(vim.uv.fs_copyfile(test_source,e.dir..'/terminal-shell.test.lua'))
      local writer=root..'/tests/e2e/fixtures/terminal-shell/delayed-write.lua'
      assert(vim.uv.fs_copyfile(writer,e.dir..'/delayed-write.lua'))
      if posix and present then assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/terminal-shell/pwsh',e.dir..'/pwsh-fixture')) end
      report={case=label,fixture=prepared,states={}}
      e:wait('real config ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      e:lua([[_G.shell_keys=0;vim.keymap.set({'n','t'},'<F35>',function() _G.shell_keys=_G.shell_keys+1 end)]])
      e:input(':edit file_one.txt<CR>');e:wait('code file',function() return e:current_ft()=='text' end)
      local global=e:lua('return vim.o.shell')
      prepared.expected=prepared.expected or global
      keys(e,' wT');e:wait('real terminal input',function() return e:current_ft()=='toggleterm' and mode(e)=='t' end)
      local command
      if not windows then
        command=[[printf 'FORGE_TERMINAL_BEFORE\n'; printf '%s\n' "]]..(present and '$BASH_VERSION' or '$0')..[[" > terminal-shell.kind]]
      elseif present then
        command='Write-Output FORGE_TERMINAL_BEFORE; Set-Content terminal-shell.kind $PSVersionTable.PSEdition'
      else command='echo FORGE_TERMINAL_BEFORE & echo %ComSpec% > terminal-shell.kind' end
      e:wait('native shell prompt',function()
        return state(e).text:find(windows and '>' or '$',1,true)~=nil
      end,10000)
      e:input(command..'<CR>')
      e:wait('shell wrote actual kind file',function()
        local value=result(e.project..'/terminal-shell.kind');return value~=nil and value~=''
      end,10000)
      local before=state(e);report.states[#report.states+1]=before
      report.kind=vim.trim(table.concat(vim.fn.readfile(e.project..'/terminal-shell.kind'),'\n'))
      report.pwsh_started=vim.fn.filereadable(prepared.pwsh_log)==1
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/terminal-shell.json')
      T.eq(before.selected,prepared.expected,posix and 'POSIX shell replaced by optional pwsh' or 'Windows shell policy changed')
      T.eq(before.pwsh,present and 1 or 0);T.eq(before.shell,global);T.eq(before.status,-1)
      assert(before.pid>0 and before.channel>0)
      if posix then
        T.eq(report.pwsh_started,false,'optional pwsh was executed')
        if present then assert(report.kind:match('^%d+%.'),'actual bash BASH_VERSION missing')
        else assert(report.kind:match('sh$'),'actual sh identity missing') end
      elseif present then T.eq(report.kind,'Core') else assert(report.kind:lower():find('cmd.exe',1,true),'actual cmd expansion missing') end
      e:wait('actual stdout observed',function() return state(e).text:find('FORGE_TERMINAL_BEFORE',1,true)~=nil end)
      normal(e);before=state(e);keys(e,'q')
      e:wait('hidden terminal and code',function() return not e:has_window('toggleterm') and e:current_ft()=='text' end)
      keys(e,' wT');e:wait('same terminal shown',function() return e:current_ft()=='toggleterm' end)
      local after=state(e);report.states[#report.states+1]=after
      for _,key in ipairs({'buf','pid','channel','shell','selected'}) do T.eq(after[key],before[key],key..' changed on reopen') end
      T.eq(after.status,-1);assert(P.history_preserved(before,after),'terminal history lost')
      if mode(e)~='t' then e:input('i');e:wait('shell input resumed',function() return mode(e)=='t' end) end
      local argv={vim.v.progpath:gsub('\\','/'),'--clean','--headless','-l',writer,e.project..'/terminal-shell.again'}
      for i,value in ipairs(argv) do
        assert(not value:find('["$`]'),'Неожиданный shell metacharacter в private fixture path')
        argv[i]='"'..value..'"'
      end
      local again=(windows and present and '& ' or '')..table.concat(argv,' ')
      report.command=again
      report.saw_empty=false
      e:input(again..'<CR>');e:wait('real next command completed',function()
        local value=result(e.project..'/terminal-shell.again')
        if value=='' then report.saw_empty=true end
        return value=='FORGE_AFTER'
      end)
      report.result=result(e.project..'/terminal-shell.again')
      T.eq(report.result,'FORGE_AFTER')
      assert(report.saw_empty,'Delayed fixture не показала границу empty → payload')
      e:wait('actual command stdout completed',function()
        return state(e).text:find('FORGE_TERMINAL_AFTER',1,true)~=nil
      end)
      normal(e);local final=state(e);report.states[#report.states+1]=final
      T.eq(final.pid,before.pid);T.eq(final.channel,before.channel);T.eq(final.installs,0);T.eq(final.dap,false)
      for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    end,debug.traceback)
    if e then
      report=report or {case=label};report.ok=ok;report.error=not ok and tostring(err) or nil
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/terminal-shell.json')
      e:snapshot(label);io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
      if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
      local exited,exit_error=pcall(function()
        T.eq(e.rpc.exit_code,0);T.eq(e.rpc.exit_signal,0);T.eq(e.rpc.api_errors,{})
        assert(e.rpc.shutdown_result and e.rpc.shutdown_result.ok,vim.inspect(e.rpc.shutdown_result))
      end)
      if not exited then ok=false;err=(err and tostring(err)..'\n' or '')..'Native cleanup: '..tostring(exit_error) end
      report.ok=ok;report.error=not ok and tostring(err) or nil
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/terminal-shell.json')
    end
    assert(ok,err)
  end)
end
check('POSIX optional pwsh preserves configured bash',true,true)
check('POSIX no pwsh preserves configured sh',true,false)
check('Windows prefers actual pwsh',false,true)
check('Windows no pwsh uses native fallback',false,false)

T.check('IDE-PANEL-33 choose detected shell custom binary and Auto for new consoles',function()
  local e,custom
  local ok,err=xpcall(function()
    local shell=vim.fn.exepath(windows and 'cmd' or 'sh')
    assert(shell~='', 'Native cmd or sh is required')
    local found=vim.fs.normalize(shell)
    e=require('editor').start(root,{prepare=function(project)
      local dir=project..'/custom shell';vim.fn.mkdir(dir,'p')
      custom=vim.fs.normalize(dir..(windows and '/shell probe.exe' or '/shell probe'))
      assert(vim.uv.fs_copyfile(shell,custom))
      if not windows then assert(vim.uv.fs_chmod(custom,493)) end
    end})
    e:wait('configured editor ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
    local global=e:lua('return vim.o.shell')
    local function saved()
      return e:lua([[local path=vim.fn.stdpath('config')..'/tools.json'
        if vim.fn.filereadable(path)==0 then return false end
        local data=vim.json.decode(table.concat(vim.fn.readfile(path),'\n'))
        return data.tools['terminal-shell'] or false]])
    end
    local function choose(query)
      e:input(' tS');e:wait('shell settings picker',function() return e:current_ft()=='TelescopePrompt' end)
      e:input(query)
      e:wait('matching shell selected',function()
        return e:lua([[local q=...;local item=require('telescope.actions.state').get_selected_entry()
          return item and item.ordinal:find(q,1,true)~=nil]],{query})
      end)
      e:input('<CR>')
    end
    local function input_path(path)
      e:wait('custom shell executable input',function()
        local current=mode(e):sub(1,1)
        return (current=='i' or current=='c') and table.concat(e.rpc:screen_lines(),'\n'):find('Путь к бинарю',1,true)~=nil
      end)
      if mode(e):sub(1,1)=='c' then e:input('<C-u>')
      else e:input('<Home><S-End><BS>') end
      e:input(path..'<CR>')
    end
    local function new_console(needle, command)
      e:input(' tN');e:wait('new terminal ready',function()
        if e:current_ft()~='toggleterm' or mode(e)~='t' then return false end
        return e:lua([[local sign=...;return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find(sign,1,true)~=nil]],
          {windows and '>' or '$'})
      end,10000)
      local job=e:lua('return vim.b.terminal_job_id')
      e:input(command..'<CR>')
      e:wait('shell command executed',function()
        return e:lua([[local needle=...;for _,line in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do
          if vim.trim(line)==needle then return true end end;return false]],{needle})
      end)
      normal(e);e:input('<F7>');e:wait('returned to editor',function() return e:current_ft()~='toggleterm' end)
      return job
    end
    e:input(':edit file_one.txt<CR>');e:wait('source file',function() return e:current_ft()=='text' end)
    local echo=windows and 'echo %OS%' or [[printf '%s\n' "$0"]]
    local old=new_console('FRIDE_AUTO_READY','echo FRIDE_AUTO_READY')
    choose(found);e:wait('found shell persisted',function() return saved()==found end)
    local selected=new_console(windows and 'Windows_NT' or found,echo)
    assert(selected~=old)

    choose('Указать путь');input_path(custom)
    e:wait('custom executable persisted',function() return saved()==custom end)
    local configured=new_console(windows and 'Windows_NT' or custom,echo)
    assert(configured~=old and configured~=selected)
    local managed=e:lua([[local job=...;for _,term in ipairs(require('toggleterm.terminal').get_all()) do
      if term.job_id==job then return term.name end end]],{configured})
    assert(vim.fs.normalize(managed):lower():find(custom:lower(),1,true),'Custom shell path not executed')
    T.eq(e:lua('return vim.fn.jobwait({...},0)',{old,selected,configured}),{-1,-1,-1})

    choose('Указать путь');input_path(custom..'.missing')
    e:wait('invalid path rejected',function()
      for _,n in ipairs(e.rpc.notifications) do
        if n.message:find('Исполняемый файл оболочки не найден',1,true) then return true end
      end
    end)
    T.eq(saved(),custom)
    choose('Auto —');e:wait('Auto removes override',function() return saved()==false end)
    T.eq(e:lua('return vim.o.shell'),global)
    T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
  end,debug.traceback)
  if e then
    e:snapshot('terminal-shell-settings');io.stdout:write('  artifacts: '..e.dir..'\n')
    e:stop(not ok and err or nil)
  end
  assert(ok,err)
end)
T.finish()
