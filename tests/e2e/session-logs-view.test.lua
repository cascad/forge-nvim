-- spec: IDE-LOG-5. Native PTY quit/relaunch/restart и настоящий Logs buffer.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
T.check('IDE-LOG-5 Logs view по вкладкам и проектам',function()
  local tui,report
  local ok,err=xpcall(function()
    tui=require('session_tui').start(root);local e=tui.host
    report={states={},pids={}}
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/session-logs-view.test.lua',e.dir..'/session-logs-view.test.lua'))
    local function metadata(label)
      local source=e:lua([[return vim.fn.stdpath('state')..'/forge-session-views']])
      local target=e.dir..'/session-view-data-'..label;vim.fn.mkdir(target,'p');local data={}
      for name,kind in vim.fs.dir(source) do
        assert(kind=='file');local file=source..'/'..name;assert(vim.uv.fs_copyfile(file,target..'/'..name))
        data[#data+1]=vim.json.decode(table.concat(vim.fn.readfile(file),'\n'))
      end
      return data
    end
    local function views()
      return tui:lua([[local result={};for _,tab in ipairs(vim.api.nvim_list_tabpages()) do
        local item={open=false};for _,win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
          local buf=vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype=='forge-logs' and vim.api.nvim_win_get_config(win).relative=='' then
            local v=vim.api.nvim_win_call(win,vim.fn.winsaveview)
            item={open=true,height=vim.api.nvim_win_get_height(win),topline=v.topline,
              line=vim.api.nvim_buf_get_lines(buf,v.lnum-1,v.lnum,false)[1],lnum=v.lnum,leftcol=v.leftcol,col=v.col}
          end
        end;result[#result+1]=item end
        local logs=require('forge.logs');return {tabs=result,source=logs.source,minimum=logs.minimum,query=logs.query}]])
    end
    local function capture(label)
      local state=tui:state();T.eq(state.installs,0);assert(not state.mode.blocking)
      for _,n in ipairs(state.notices or {}) do assert(n.level<vim.log.levels.ERROR,n.message) end
      local got=views();report.states[label]={view=got,state=state}
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/session-logs-view.json');return got
    end
    local function wait_view(expected)
      e:wait('Logs view восстановлен',function()
        local actual=views();report.comparison={expected=expected,actual=actual}
        return vim.deep_equal(actual,expected)
      end,15000)
    end
    local function logs_focus()
      tui:send(' wi');e:wait('Logs в фокусе',function() return tui:lua([[return vim.bo.filetype=='forge-logs']]) end)
    end
    local function prepare(prefix,row,delta)
      -- Public recorder: настоящая bounded history, не подмена источника/backend.
      tui:lua([[local prefix=...;local store=require('forge.log_store')
        for i=1,60 do store.record(prefix..('%03d'):format(i),vim.log.levels.WARN,'SessionPanel') end]],{prefix})
      tui:command('ForgeLogs events:SessionPanel')
      e:wait('Выбран Logs source',function() return tui:lua([[return vim.bo.filetype=='forge-logs']]) end)
      tui:send('v')
      e:wait('WARN уровень',function() return tui:lua([[return require('forge.logs').minimum==3]]) end)
      tui:send('f');e:wait('Native filter input',function() local mode=tui:mode().mode:sub(1,1);return mode=='i' or mode=='c' end)
      tui:send(prefix..'\r');e:wait('Текстовый фильтр',function() return tui:lua([[return require('forge.logs').query]],{})==prefix end)
      e:wait('Logs зарегистрирован в Edgy',function() return tui:lua([[local w=require('edgy').get_win()
        return w and w.height==vim.api.nvim_win_get_height(0) or false]]) end)
      local before=tui:lua('return vim.api.nvim_win_get_height(0)')
      tui:send(('\23+'):rep(delta/2))
      e:wait('Native Logs resize',function() return tui:lua('return vim.api.nvim_win_get_height(0)')==before+delta end)
      tui:send('gg/'..prefix..('%03d'):format(row)..'\rzz')
      e:wait('Выбрана старая строка',function() return tui:lua([[local needle=...;return vim.api.nvim_get_current_line():find(needle,1,true)~=nil]],{prefix..('%03d'):format(row)}) end)
      tui:send(' w0');e:wait('Фокус в коде',function() return tui:lua([[return vim.bo.buftype=='']]) end)
    end
    local function geometry()
      e:lua([[vim.wo.number=false;vim.wo.relativenumber=false;vim.wo.signcolumn='no';vim.wo.foldcolumn='0']])
    end
    geometry();local first=tui:launch();report.pids[#report.pids+1]=first.pid
    tui:command('edit first.txt');e:wait('A файл',function() return tui:state().file==tui.a..'/first.txt' end)
    prepare('A_PANEL_',40,6)
    tui:command('tabedit second.txt');e:wait('A два tabs',function() return #tui:state().tabs==2 end)
    logs_focus()
    e:wait('Edgy второй вкладки',function() return tui:lua([[return require('edgy').get_win()~=nil]]) end)
    local height=tui:lua('return vim.api.nvim_win_get_height(0)');tui:send('\23+')
    e:wait('Иная высота второго tab',function() return tui:lua('return vim.api.nvim_win_get_height(0)')==height+2 end)
    tui:send('gg/A_PANEL_025\rzz w0')
    e:wait('Второй code focus',function() return tui:lua([[return vim.bo.buftype=='']]) end)
    local before=capture('before-quit');assert(before.tabs[1].topline>1 and before.tabs[2].topline>1)
    assert(before.tabs[1].height~=before.tabs[2].height)
    tui:quit();tui:save_sessions('logs-first-quit');metadata('first-quit')
    local second=tui:launch();report.pids[#report.pids+1]=second.pid;assert(second.pid~=first.pid)
    tui:send(' qs');wait_view(before);capture('reopened')
    assert(tui:lua([[return vim.bo.buftype=='']]),'Logs restore украл code focus')
    logs_focus();tui:send('q');e:wait('Второй Logs скрыт',function() return not views().tabs[2].open end)
    local a_saved=capture('before-b')
    tui:command('lua require("config.start").open_project('..vim.inspect(tui.b)..')')
    local b=tui:connect(second.pid);report.pids[#report.pids+1]=b.pid
    e:wait('B cwd',function() return tui:state().cwd==tui.b end)
    tui:command('edit first.txt');e:wait('B файл',function() return tui:state().file==tui.b..'/first.txt' end)
    prepare('B_PANEL_',42,4)
    -- Скрытые окна тоже сохраняют общий выбор источника/фильтров проекта.
    logs_focus();tui:send('q');e:wait('B Logs скрыт',function() return not views().tabs[1].open end)
    local b_saved=capture('before-return-a')
    tui:command('lua require("config.start").open_project('..vim.inspect(tui.a)..')')
    local a=tui:connect(b.pid);report.pids[#report.pids+1]=a.pid
    e:wait('A cwd',function() return tui:state().cwd==tui.a end);wait_view(a_saved);capture('returned-a')
    tui:command('tabfirst');logs_focus()
    local scroll=views().tabs[1]
    tui:lua([[require('forge.log_store').record('A_PANEL_LATE',vim.log.levels.WARN,'SessionPanel')]])
    T.eq(views().tabs[1],scroll,'Refresh сбросил просматриваемую строку')
    tui:send(' w0')
    tui:command('lua require("config.start").open_project('..vim.inspect(tui.b)..')')
    local again=tui:connect(a.pid);report.pids[#report.pids+1]=again.pid
    e:wait('Снова B cwd',function() return tui:state().cwd==tui.b end);wait_view(b_saved);capture('returned-b-hidden')
    tui:quit()
    -- A сохранялся до перехода в B. Новому backend передаётся меньший реальный UI.
    local saved
    for _,data in ipairs(metadata('before-small')) do if data.logs and data.logs.query=='A_PANEL_' then saved=data.tabs[1].logs end end
    assert(saved,'Сохранённый Logs A отсутствует');local saved_lines=saved.lines
    e.rpc:request('nvim_ui_try_resize',{120,math.max(25,saved_lines-10)});geometry()
    local small=tui:launch();report.pids[#report.pids+1]=small.pid
    local lines=tui:lua('return vim.o.lines');assert(lines<saved_lines,'UI fixture не уменьшен')
    tui:send(' qs')
    local minimum=tui:lua([[return require('edgy.config').options.bottom.size]])
    local expected=math.max(minimum,math.floor(a_saved.tabs[1].height*lines/saved_lines+0.5))
    report.small={saved_lines=saved_lines,lines=lines,expected=expected}
    e:wait('Logs адаптирован к меньшему UI',function()
      local got=views();report.small.actual=got
      return #got.tabs==2 and got.tabs[1].open and got.tabs[1].height==expected
        and not got.tabs[2].open and got.query=='A_PANEL_'
    end,15000)
    capture('smaller-ui');assert(tui:lua([[return vim.bo.buftype=='']]))
    tui:quit();tui:save_sessions('logs-last');metadata('last')
  end,debug.traceback)
  if tui then
    report=report or {};report.ok=ok;report.error=not ok and err or nil
    if not ok then
      local captured,screen=pcall(tui.host.lua,tui.host,[[return vim.api.nvim_buf_get_lines(_G.forge_session_terminal,0,-1,false)]])
      if captured then vim.fn.writefile(screen,tui.host.dir..'/failure-terminal.txt') end
      local observed,state=pcall(tui.state,tui);if observed then report.failure_state=state end
    end
    vim.fn.writefile({vim.json.encode(report)},tui.host.dir..'/session-logs-view.json')
    local stopped,why=pcall(tui.stop,tui,not ok and err or nil)
    io.stdout:write('  artifacts: '..tui.host.dir..'\n')
    if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(why) end
  end
  assert(ok,err)
end)
T.finish()
