-- spec: IDE-PANEL-27/28. Native Neotest, ToggleTerm, Bash DAP и PTY restart.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function check(label,fn)
  T.check(label,function()
    local tui,report
    local ok,err=xpcall(function()
      tui=require('session_tui').start(root);local e=tui.host;report={states={},pids={}}
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/session-tool-views.test.lua',e.dir..'/session-tool-views.test.lua'))
      local c={tui=tui,e=e,report=report}
      function c:state(label)
        local s=tui:state();T.eq(s.installs,0);assert(not s.mode.blocking)
        for _,n in ipairs(s.notices or {}) do assert(n.level<vim.log.levels.ERROR,n.message) end
        report.states[label]=s;return s
      end
      function c:normal()
        if tui:mode().mode=='t' then tui:send('\28\14') end
        e:wait('Native terminal-normal',function() return tui:mode().mode:sub(1,1)=='n' end)
      end
      function c:code()
        self:normal();tui:send(' w0');e:wait('Main code focus',function() return tui:lua([[return vim.bo.buftype=='']]) end)
      end
      function c:geometry(ft,dimension)
        return tui:lua([[local ft,dimension=...;for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if vim.bo[vim.api.nvim_win_get_buf(w)].filetype==ft and vim.api.nvim_win_get_config(w).relative=='' then
            return vim.api['nvim_win_get_'..dimension](w) end end;return 0]],{ft,dimension})
      end
      function c:resize(ft,dimension,amount)
        self:normal();e:wait('Native Edgy geometry готова',function() return tui:lua([[local w=require('edgy').get_win();return w~=nil]]) end)
        local before=self:geometry(ft,dimension);assert(before>0)
        tui:send(('\23'..(dimension=='width' and '>' or '+')):rep(amount/2))
        e:wait('Native resize '..ft,function() return self:geometry(ft,dimension)==before+amount end)
        return before+amount
      end
      function c:metadata(label)
        local source=e:lua([[return vim.fn.stdpath('state')..'/forge-session-views']])
        local target=e.dir..'/session-view-data-'..label;vim.fn.mkdir(target,'p');local out={}
        for name,kind in vim.fs.dir(source) do assert(kind=='file');assert(vim.uv.fs_copyfile(source..'/'..name,target..'/'..name))
          out[#out+1]=vim.json.decode(table.concat(vim.fn.readfile(source..'/'..name),'\n')) end
        return out
      end
      function c:launch()
        e:lua([[vim.wo.number=false;vim.wo.relativenumber=false;vim.wo.signcolumn='no';vim.wo.foldcolumn='0']])
        local ready=tui:launch();report.pids[#report.pids+1]=ready.pid;return ready
      end
      function c:open(path)
        tui:command('edit '..vim.fn.fnameescape(path));e:wait('File '..path,function() return tui:state().file==tui.a..'/'..path end)
      end
      function c:restore()
        tui:send(' qs');e:wait('Native session restored',function() return tui:state().file:find(tui.a..'/',1,true)==1 end)
      end
      function c:no_process_panels()
        return tui:lua([[local live,panels=0,0;for _,b in ipairs(vim.api.nvim_list_bufs()) do
          if vim.bo[b].buftype=='terminal' then local job=vim.b[b].terminal_job_id
            if job and vim.fn.jobwait({job},0)[1]==-1 then live=live+1 end end end
          for _,w in ipairs(vim.api.nvim_list_wins()) do local ft=vim.bo[vim.api.nvim_win_get_buf(w)].filetype
            if ft=='toggleterm' or ft=='dap-terminal' or ft=='dap-repl' or ft:find('^dapui_') then panels=panels+1 end end
          local d=package.loaded.dap;return {live=live,panels=panels,session=d and d.session()~=nil or false}]])
      end
      fn(c)
    end,debug.traceback)
    if tui then
      report=report or {};report.ok=ok;report.error=not ok and err or nil
      if not ok then local captured,screen=pcall(tui.host.lua,tui.host,[[return vim.api.nvim_buf_get_lines(_G.forge_session_terminal,0,-1,false)]])
        if captured then vim.fn.writefile(screen,tui.host.dir..'/failure-terminal.txt') end
        local observed,s=pcall(tui.state,tui);if observed then report.failure_state=s end
        pcall(function()
          if tui:mode().blocking then tui:send('\r') end
          tui:lua([[local d=package.loaded.dap;if d and d.session() then d.terminate() end]])
          if tui:mode().mode=='t' then tui:send('\28\14') end
          tui.host:wait('Cleanup normal mode',function() return tui:mode().mode:sub(1,1)=='n' end)
          tui:send(' w0');tui.host:wait('Cleanup main mode',function() return tui:mode().mode=='n' end)
        end)
      end
      vim.fn.writefile({vim.json.encode(report)},tui.host.dir..'/session-tool-views.json')
      local stopped,why=pcall(tui.stop,tui,not ok and err or nil);io.stdout:write('  artifacts: '..tui.host.dir..'\n')
      if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(why) end
    end
    assert(ok,err)
  end)
end

check('IDE-PANEL-27 Tests native sidebar после restart',function(c)
  local tui,e=c.tui,c.e
  local lines={};for i=1,50 do vim.list_extend(lines,{'@test "A_CASE_'..('%02d'):format(i)..'" {','  printf run > TEST_EXECUTED','}'}) end
  vim.fn.writefile(lines,tui.a..'/cases.bats')
  local function views()
    return tui:lua([[local out={};for _,tab in ipairs(vim.api.nvim_list_tabpages()) do local item={open=false}
      for _,w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do local b=vim.api.nvim_win_get_buf(w)
        if vim.bo[b].filetype=='neotest-summary' then item={open=true,width=vim.api.nvim_win_get_width(w)} end end
      out[#out+1]=item end;return out]])
  end
  local function positions()
    return tui:lua([[local n=require('neotest');local names={};for _,id in ipairs(n.state.adapter_ids()) do
      local tree=n.state.positions(id);if tree then for _,node in tree:iter_nodes() do local d=node:data()
        if d.type=='test' and d.name:match('^A_CASE_%d%d$') then names[#names+1]=d.name end end end end
      table.sort(names);return names]])
  end
  c:launch();c:open('cases.bats');tui:send(' wt')
  e:wait('Настоящие Bats positions',function() return views()[1].open and #positions()==50 end,20000)
  c.report.positions_before=positions()
  local width=c:resize('neotest-summary','width',8);c:code()
  tui:command('tabedit second.txt');e:wait('Второй code tab',function() return #tui:state().tabs==2 end)
  local before=views();c.report.before=before;assert(before[1].open and not before[2].open)
  c:state('before-quit');tui:quit();c:metadata('first');tui:save_sessions('tests-first')
  c:launch();c:restore()
  e:wait('Tests view восстановлен',function() local v=views();c.report.actual=v;return vim.deep_equal(v,before) end,20000)
  e:wait('Bats discovery после restart',function() return #positions()==50 end,20000);c.report.positions_after=positions()
  T.eq(c:state('reopened').file,tui.a..'/second.txt');T.eq(vim.fn.filereadable(tui.a..'/TEST_EXECUTED'),0)
  tui:command('tabfirst');tui:send(' wt');e:wait('Tests focus',function() return tui:lua([[return vim.bo.filetype=='neotest-summary']]) end)
  T.eq(c:geometry('neotest-summary','width'),width);tui:send('q');e:wait('Tests скрыт',function() return not views()[1].open end)
  tui:quit();c:metadata('hidden');c:launch();c:restore()
  e:wait('Скрытый Tests не открылся',function() return #views()==2 and not views()[1].open and not views()[2].open end)
  T.eq(vim.fn.filereadable(tui.a..'/TEST_EXECUTED'),0);c:state('hidden-reopened');tui:quit();c:metadata('last')
end)

check('IDE-PANEL-28 Terminal hidden size и явный shell',function(c)
  local tui,e=c.tui,c.e
  c:launch();c:open('first.txt');tui:send(' wT')
  e:wait('Native Terminal',function() return tui:lua([[return vim.bo.filetype=='toggleterm']]) end)
  local height=c:resize('toggleterm','height',6);c.report.height=height
  c:code();tui:send(' wT');e:wait('Terminal focus',function() return tui:lua([[return vim.bo.filetype=='toggleterm']]) end)
  c:normal();tui:send('q');e:wait('Terminal скрыт',function() return c:geometry('toggleterm','height')==0 end)
  c:state('hidden-before-quit');tui:quit();c:metadata('first')
  c:launch();c:restore();c.report.before_explicit=c:no_process_panels()
  T.eq(c.report.before_explicit,{live=0,panels=0,session=false},'Restore запустил shell/debug')
  tui:send(' wT');e:wait('Сохранённая Terminal height',function() return c:geometry('toggleterm','height')==height end)
  e:wait('Terminal input',function() return tui:mode().mode=='t' end)
  tui:send('echo FORGE_EXPLICIT_SHELL\r')
  e:wait('Настоящий shell output',function() return tui:lua([[for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b=vim.api.nvim_win_get_buf(w);if vim.bo[b].filetype=='toggleterm' then for _,line in ipairs(vim.api.nvim_buf_get_lines(b,0,-1,false)) do
      if vim.trim(line)=='FORGE_EXPLICIT_SHELL' then return true end end end end;return false]]) end,15000)
  local changed=c:resize('toggleterm','height',2);c:code();tui:send(' wT')
  e:wait('User resize не сброшен фокусом',function() return c:geometry('toggleterm','height')==changed end)
  c:code();c:state('explicit-opened');tui:quit();c:metadata('last')
end)

check('IDE-PANEL-28 Debug hidden sizes и явный F5',function(c)
  local tui,e=c.tui,c.e
  local deps=vim.env.FORGE_E2E_BASH_DAP_DEPS or root..'/.tests/bash-dap-deps'
  local node_deps=vim.env.FORGE_E2E_NODE_DEPS or root..'/.tests/node-deps'
  local manifest=vim.json.decode(table.concat(vim.fn.readfile(node_deps..'/manifest.json'),'\n'))
  e:lua([[local node,adapter=...;vim.env.FORGE_NODE_EXECUTABLE=node;vim.env.FORGE_BASH_DEBUG_ADAPTER=adapter]],
    {vim.fs.joinpath(node_deps,manifest.node),deps..'/extension/out/bashDebug.js'})
  vim.fn.writefile({'#!/usr/bin/env bash','answer=42',[[printf 'FORGE_TOOL_DEBUG_%s\n' "$answer"]]},tui.a..'/debug.sh')
  local function pause()
    tui:command('lua require("dap").clear_breakpoints()');tui:send('3G\27[20~\27[15~') -- F9/F5 legacy xterm
    e:wait('Native Bash pause',function() return tui:lua([[local s=require('dap').session();return s and s.stopped_thread_id and s.current_frame and true or false]]) end,35000)
    if tui:lua([[return require('dap').session().current_frame.line]])~=3 then tui:send('\27[15~') end
    e:wait('Breakpoint3',function() return tui:lua([[local s=require('dap').session();return s and s.stopped_thread_id and s.current_frame and s.current_frame.line==3]]) end,20000)
  end
  local function stop_and_hide()
    c:code();tui:send(' dq');e:wait('Native debug Stop',function() return tui:lua([[return require('dap').session()==nil]]) end,15000)
    tui:send(' wd');e:wait('Sidebar focus',function() return tui:lua([[return vim.bo.filetype=='dapui_scopes']]) end)
    tui:send('q');e:wait('Debug sidebar hidden',function() return c:geometry('dapui_scopes','width')==0 end)
    tui:send(' wc');e:wait('Output focus перед скрытием',function() return tui:lua([[return vim.bo.filetype=='dap-terminal']]) end)
    c:normal();tui:send('q');e:wait('Debug panels hidden',function() return c:no_process_panels().panels==0 end)
  end
  c:launch();c:open('debug.sh');pause();tui:send(' wd')
  e:wait('Locals focus',function() return tui:lua([[return vim.bo.filetype=='dapui_scopes']]) end)
  local width=c:resize('dapui_scopes','width',8);c:code();tui:send(' wc')
  e:wait('Native debug Output',function() return tui:lua([[return vim.bo.filetype=='dap-terminal']]) end)
  local height=c:resize('dap-terminal','height',4);c.report.width=width;c.report.height=height
  stop_and_hide();c:state('hidden-before-quit');tui:quit();c:metadata('first')
  c:launch();c:restore();c.report.before_explicit=c:no_process_panels()
  T.eq(c.report.before_explicit,{live=0,panels=0,session=false},'Restore открыл/запустил debug')
  pause();e:wait('Сохранённые debug sizes',function()
    return c:geometry('dapui_scopes','width')==width and c:geometry('dap-terminal','height')==height end)
  c:state('explicit-debug');stop_and_hide();tui:quit();c:metadata('last')
end)
T.finish()
