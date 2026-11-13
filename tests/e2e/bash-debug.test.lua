-- IDE-SH-5: настоящий bash-debug/bashdb; Windows использует штатный WSL launcher.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local win=vim.fn.has('win32')==1
local deps=vim.env.FORGE_E2E_BASH_DAP_DEPS or root..'/.tests/bash-dap-deps'
local entry=deps..'/extension/out/bashDebug.js'
local node_deps=vim.env.FORGE_E2E_NODE_DEPS or root..'/.tests/node-deps'
local node_manifest=vim.json.decode(table.concat(vim.fn.readfile(node_deps..'/manifest.json'),'\n'))
local node=vim.fs.joinpath(node_deps,node_manifest.node)
local function unix_command(args)
  local cmd=win and {'wsl.exe','--exec'} or {};vim.list_extend(cmd,args)
  return vim.system(cmd,{text=true,timeout=5000}):wait()
end
local function text(e,ft)
  return e:lua([[local ft=...;local out={};for _,w in ipairs(vim.api.nvim_list_wins()) do
    local b=vim.api.nvim_win_get_buf(w);if vim.bo[b].filetype==ft then
      vim.list_extend(out,vim.api.nvim_buf_get_lines(b,0,-1,false)) end end;return table.concat(out,'\n')]],{ft})
end
local function output(e) return text(e,'dap-terminal')..'\n'..text(e,'dap-repl') end
local function check(missing)
  local label=missing=='node' and 'missing Node' or missing and 'missing adapter' or 'native workflow'
  T.check('IDE-SH-5 '..label,function()
    local e,script,report
    local ok,err=xpcall(function()
      assert(vim.fn.filereadable(entry)==1,'Нужна явная prepare_bash_dap.py --download')
      e=require('editor').start(root,{timeout=90000,env={FORGE_NODE_EXECUTABLE=missing=='node' and root..'/.tests/no-node' or node,
        FORGE_BASH_DEBUG_ADAPTER=missing=='adapter' and root..'/.tests/no-bash-debug.js' or entry},
        prepare=function(project)
          local dir=project..'/Bash debug ü with space';vim.fn.mkdir(dir,'p');script=dir..'/run.sh'
          vim.fn.writefile({'#!/usr/bin/env bash',
            [[printf '%s %s\n' "$$" "$PPID" > forge-debug-pids]],
            'seed=40','answer=$((seed + 2))',
            [[printf 'FORGE_BASH_%s:%s:%s\n' "$answer" "${1:-default}" "${CASE:-plain}"]]},script)
          local r=vim.system({'git','init',dir},{text=true}):wait();assert(r.code==0,r.stderr)
        end})
      report={};e:input(':edit '..vim.fn.fnameescape(script)..'<CR>')
      e:wait('Bash файл открыт',function() return e:current_file()==script and e:current_ft()=='sh' end)
      local spawned=e:lua('return _G.forge_e2e_spawns')
      for _,s in ipairs(spawned) do assert(not tostring(s.cmd):lower():find('wsl',1,true),'WSL запущен до F5') end
      e:lua([[require('dap').set_log_level('TRACE')]])
      if missing then
        local expected=missing=='node' and 'Node не найден' or 'bash-debug adapter не найден'
        e:input('<F5>');e:wait('Понятный '..label,function()
          for _,n in ipairs(e.rpc.notifications) do if n.message:find(expected,1,true) then return true end end
        end)
        local mode=e.rpc:request('nvim_get_mode',{});if mode.blocking then e:input('<CR>') end
        T.eq(e:lua([[return require('dap').session()==nil]]),true)
        T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
        report.missing=true;return
      end
      local function at_breakpoint()
        return e:lua([[local s=require('dap').session();return s and s.stopped_thread_id and s.current_frame and s.current_frame.line==5]])
      end
      report.pids={}
      local function paused()
        e:wait('Native Bash остановлен',function()
          return e:lua([[local s=require('dap').session();return s and s.stopped_thread_id and s.current_frame]])
        end,30000)
        if not at_breakpoint() then e:input('<F5>');e:wait('Bash breakpoint line5',at_breakpoint,30000) end
        assert(e:has_window('dapui_scopes') and (e:has_window('dap-terminal') or e:has_window('dap-repl')),'Общие Debug панели отсутствуют')
        e:wait('Native Local scope',function() return text(e,'dapui_scopes'):find('PWD',1,true)~=nil end,10000)
        local pids=vim.split(table.concat(vim.fn.readfile(vim.fs.dirname(script)..'/forge-debug-pids'),' '),'%s+',{trimempty=true})
        assert(#pids==2 and tonumber(pids[1]) and tonumber(pids[2]))
        report.pids[#report.pids+1]=pids
      end
      local function evaluate(value)
        e:lua([[local s=require('dap').session();vim.g.forge_bash_eval=nil
          s:request('evaluate',{expression='$answer',context='watch',frameId=s.current_frame.id},function(err,res)
            vim.g.forge_bash_eval={error=err,result=res} end)]])
        e:wait('Native evaluate '..value,function()
          local r=e:lua('return vim.g.forge_bash_eval');return r and not r.error and r.result and r.result.result:find(value,1,true)~=nil
        end,10000)
      end
      local function finished(marker)
        e:input('<F5>');e:wait('Bash stdout '..marker,function() return output(e):find(marker,1,true)~=nil end,20000)
        e:wait('Bash DAP завершён',function() return e:lua([[return require('dap').session()==nil]]) end,15000)
        report.last_output=output(e)
      end
      local function choose_case()
        e:input(' w0<F5>');e:wait('Debug configuration picker',function()
          return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
        e:input('Bash explicit case')
        e:wait('Bash case выбран',function() return e:lua([[local s=require('telescope.actions.state');local v=s.get_selected_entry()
          return v and v.value and v.value.text and v.value.text.config.name=='Bash explicit case']]) end)
        e:input('<CR>')
      end
      e:input('5G<F9><F5>');paused();assert(e:has_window('dap-terminal'),'Default Bash не использует native PTY')
      evaluate('42');finished('FORGE_BASH_42:default:plain')
      assert(not report.last_output:find('/dev/stdin:',1,true),'Default Bash показывает native stdin error')
      report.first=true
      e:input(' w0');e:input(':edit '..vim.fn.fnameescape(script)..'<CR>3G0f0r1:write<CR><F5>')
      paused();evaluate('43');finished('FORGE_BASH_43:default:plain');report.repeat_run=true
      -- Native launch.json config и штатный stop на breakpoint, без private state.
      vim.fn.mkdir(e.project..'/.vscode','p')
      vim.fn.writefile({vim.json.encode({version='0.2.0',configurations={{name='Bash explicit case',type='bashdb',request='launch',
        program=script,cwd=vim.fs.dirname(script),args={'casearg'},env={CASE='launch'},
        terminalKind='debugConsole',console='internalConsole'}}})},e.project..'/.vscode/launch.json')
      choose_case();paused();evaluate('43')
      T.eq(e:lua([[return require('dap').session().config.env.CASE]]),'launch')
      e:input('<F5>');e:wait('launch.json args/env stdout',function() return text(e,'dap-repl'):find('FORGE_BASH_43:casearg:launch',1,true)~=nil end,20000)
      e:wait('Explicit session завершена',function() return e:lua([[return require('dap').session()==nil]]) end,15000)
      report.explicit=true
      choose_case();paused();e:input(' dq')
      e:wait('Native stop завершён',function() return e:lua([[return require('dap').session()==nil]]) end,15000)
      report.stop=true
      for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    end,debug.traceback)
    if e then
      report=report or {};report.ok=ok;report.error=not ok and err or nil
      for _,path in ipairs(vim.fs.find(function(name) return name:match('^dap.*%.log$')~=nil end,
          {path=e.runtime..'/cache',type='file',limit=30})) do
        assert(vim.uv.fs_copyfile(path,e.dir..'/'..vim.fs.basename(path)))
      end
      pcall(function() report.dap=e:lua([[local s=require('dap').session();return s and {config=s.config,frame=s.current_frame} or {}]]) end)
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/bash-debug.json')
      pcall(e.snapshot,e,'bash-debug-'..label);io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,why=pcall(e.stop,e,not ok and err or nil);if not stopped then ok=false;err=tostring(err or '')..'\n'..tostring(why) end
      if report.pids and #report.pids>0 then
        local pids={};for _,pair in ipairs(report.pids) do vim.list_extend(pids,pair) end
        local alive=unix_command({'ps','-p',table.concat(pids,','),'-o','pid=,stat=,comm='})
        report.unix_processes_after=alive.stdout;report.unix_probe_code=alive.code
        if alive.code~=1 or vim.trim(alive.stdout or '')~='' then ok=false;err=tostring(err or '')..'\nBash backend processes остались: '..(alive.stdout or alive.stderr or '') end
      end
      report.ok=ok;report.error=not ok and err or nil
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/bash-debug.json')
    end
    assert(ok,err)
  end)
end
check(false);check('adapter');check('node');T.finish()
