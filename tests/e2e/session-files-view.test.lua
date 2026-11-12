-- spec: IDE-PANEL-25. Настоящий PTY, quit/relaunch и native :restart.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
T.check('IDE-PANEL-25 Files view сохраняется по вкладкам и A→B→A',function()
  local tui,report,save_view_data
  local ok,err=xpcall(function()
    tui=require('session_tui').start(root)
    local e=tui.host
    report={states={},pids={}}
    save_view_data=function(label)
      -- State общий для host/child, доступен даже после quit дочернего TUI.
      local source=e:lua([[return vim.fn.stdpath('state')..'/forge-session-views']])
      if not vim.uv.fs_stat(source) then return end
      local target=e.dir..'/session-view-data-'..label
      vim.fn.mkdir(target,'p')
      for name,kind in vim.fs.dir(source) do
        assert(kind=='file');assert(vim.uv.fs_copyfile(source..'/'..name,target..'/'..name))
      end
    end
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/session-files-view.test.lua',e.dir..'/session-files-view.test.lua'))
    for _,project in ipairs({tui.a,tui.b}) do
      vim.fn.mkdir(project..'/aa-tree/child','p')
      for i=1,45 do vim.fn.writefile({'entry '..i},project..('/aa-tree/child/entry_%02d.txt'):format(i)) end
    end
    local function views()
      return tui:lua([[local result={};for _,tab in ipairs(vim.api.nvim_list_tabpages()) do
        local item={open=false};for _,win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
          local buf=vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype=='neo-tree' and vim.b[buf].neo_tree_source=='filesystem' then
            local s=require('neo-tree.sources.manager').get_state('filesystem',tab)
            if s and s.tree then
              local node=s.tree:get_node(vim.api.nvim_win_get_cursor(win)[1])
              local expanded=require('neo-tree.ui.renderer').get_expanded_nodes(s.tree);table.sort(expanded)
              local v=vim.api.nvim_win_call(win,vim.fn.winsaveview)
              item={open=true,path=s.path,selected=node and node:get_id(),expanded=expanded,
                width=vim.api.nvim_win_get_width(win),topline=v.topline,leftcol=v.leftcol,col=v.col}
            end
          end
        end;result[#result+1]=item end;return result]])
    end
    local function capture(label)
      local state=tui:state()
      T.eq(state.installs,0);assert(not state.mode.blocking)
      for _,n in ipairs(state.notices or {}) do assert(n.level<vim.log.levels.ERROR,n.message) end
      local got=views();report.states[label]={views=got,state=state}
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/session-files-view.json')
      return got
    end
    local function ready_view(row,delta)
      tui:send(' we')
      e:wait('native Files в фокусе',function() return tui:lua([[return vim.bo.filetype=='neo-tree']]) end)
      local function select_visible(name)
        e:wait('выбран видимый узел '..name,function()
          local got=tui:lua([[local name=...;local s=require('neo-tree.sources.manager').get_state_for_window()
            if not s or not s._ready or not s.tree then return {} end
            local n=s.tree:get_node();local row
            for i,line in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do
              if line:find(name,1,true) then row=i;break end end
            return {row=row,selected=n and n.name==name}]],{name})
          if got.selected then return true end
          if got.row then tui:send(got.row..'G') end
          return false
        end)
      end
      select_visible('aa-tree');tui:send('l')
      e:wait('первый каталог раскрыт',function()
        return tui:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('child',1,true)~=nil]])
      end)
      select_visible('child');tui:send('l')
      e:wait('вложенный каталог отрисован',function()
        return tui:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('entry_45.txt',1,true)~=nil]])
      end)
      select_visible(('entry_%02d.txt'):format(row))
      e:wait('Edgy layout готов к native resize',function()
        return tui:lua([[local w=require('edgy').get_win();return w and w.width==vim.api.nvim_win_get_width(0) or false]])
      end)
      local before=tui:lua('return vim.api.nvim_win_get_width(0)')
      report.resize={before=before,delta=delta,expected=before+delta}
      assert(delta%2==0)
      tui:send(('\23>'):rep(delta/2)) -- штатный Edgy Ctrl-w >: +2 колонки
      e:wait('native Edgy resize',function()
        report.resize.actual=tui:lua('return vim.api.nvim_win_get_width(0)')
        return report.resize.actual==report.resize.expected
      end)
    end
    local function wait_views(expected)
      e:wait('восстановлены native Files views',function()
        local actual=views()
        report.view_comparison={expected=expected,actual=actual}
        return vim.deep_equal(actual,expected)
      end,15000)
    end
    -- Внешний host эмулирует терминал без файлового gutter: TermOpen не меняет его ширину позднее.
    local function terminal_geometry()
      e:lua([[vim.wo.number=false;vim.wo.relativenumber=false;vim.wo.signcolumn='no';vim.wo.foldcolumn='0']])
    end
    terminal_geometry()
    local first=tui:launch();report.pids[#report.pids+1]=first.pid
    tui:command('edit first.txt')
    e:wait('A первый файл',function() return tui:state().file==tui.a..'/first.txt' end)
    ready_view(40,6)
    local first_view=views()[1];assert(first_view.topline>1,'fixture не прокручена')
    tui:command('tabedit second.txt')
    e:wait('A вторая вкладка',function() return #tui:state().tabs==2 and tui:state().file==tui.a..'/second.txt' end)
    ready_view(20,2)
    local before=capture('before-quit')
    local saved_columns=tui:lua('return vim.o.columns')
    T.eq(#before,2);assert(before[1].open and before[2].open)
    assert(before[1].selected~=before[2].selected and before[1].width~=before[2].width)
    tui:quit();tui:save_sessions('view-first-quit')
    save_view_data('first-quit')
    local metadata=vim.fn.glob(e.dir..'/session-view-data-first-quit/*.json',false,true)
    T.eq(#metadata,1)
    local saved=vim.json.decode(table.concat(vim.fn.readfile(metadata[1]),'\n'))
    T.eq(saved.tabs[1].files.columns,saved_columns,'quit saved detached UI columns')
    local relaunched=tui:launch();report.pids[#report.pids+1]=relaunched.pid
    assert(relaunched.pid~=first.pid)
    tui:send(' qs');wait_views(before);capture('reopened')
    assert(tui:lua([[return vim.bo.buftype=='' and vim.bo.filetype=='text']]),'restore stole code focus')
    -- Вторая вкладка теперь явно скрывает Files; первая сохраняет свой view.
    tui:send(' we')
    e:wait('Files второй вкладки в фокусе',function() return tui:lua([[return vim.bo.filetype=='neo-tree']]) end)
    tui:send('q')
    e:wait('Files второй вкладки скрыт',function() return not views()[2].open end)
    local a_saved=capture('before-b')
    tui:command('lua require("config.start").open_project('..vim.inspect(tui.b)..')')
    local b=tui:connect(relaunched.pid);report.pids[#report.pids+1]=b.pid
    e:wait('проект B',function() return tui:state().cwd==tui.b end)
    tui:command('edit first.txt')
    e:wait('B первый файл',function() return tui:state().file==tui.b..'/first.txt' end)
    ready_view(38,4)
    local b_saved=capture('before-return-a')
    -- Изменение диска между сеансами: исчез выбранный в A узел.
    assert(a_saved[1].selected:find('entry_',1,true))
    assert(vim.fn.delete(a_saved[1].selected)==0)
    tui:command('lua require("config.start").open_project('..vim.inspect(tui.a)..')')
    local a=tui:connect(b.pid);report.pids[#report.pids+1]=a.pid
    e:wait('A вернулся с двумя вкладками',function() return tui:state().cwd==tui.a and #tui:state().tabs==2 end)
    e:wait('исчезнувший узел не ломает Files',function()
      local got=views();return got[1].open and got[1].selected==a_saved[1].path
        and got[1].width==a_saved[1].width and not got[2].open
    end,15000)
    capture('returned-a-missing-node')
    tui:command('lua require("config.start").open_project('..vim.inspect(tui.b)..')')
    local b_again=tui:connect(a.pid);report.pids[#report.pids+1]=b_again.pid
    e:wait('снова B',function() return tui:state().cwd==tui.b end)
    wait_views(b_saved);capture('returned-b')
    -- Новый native TUI получает меньший размер от настоящего terminal host.
    tui:quit();save_view_data('before-smaller-ui')
    local latest
    for _,file in ipairs(vim.fn.glob(e.dir..'/session-view-data-before-smaller-ui/*.json',false,true)) do
      local data=vim.json.decode(table.concat(vim.fn.readfile(file),'\n'))
      local view=data.tabs[1].files
      if view and view.path==a_saved[1].path then latest=view end
    end
    assert(latest,'latest project A view is missing')
    e.rpc:request('nvim_ui_try_resize',{120,45})
    terminal_geometry()
    local small=tui:launch();report.pids[#report.pids+1]=small.pid
    local columns=tui:lua('return vim.o.columns')
    assert(columns<latest.columns,'native terminal UI did not shrink')
    tui:send(' qs')
    local minimum=tui:lua([[return require('edgy.config').options.left.size]])
    local width=math.max(minimum,math.floor(latest.width*columns/latest.columns+0.5))
    assert(width<latest.width,'fixture does not exercise width adaptation')
    report.small_ui={saved_columns=latest.columns,columns=columns,minimum=minimum,expected_width=width}
    e:wait('Files адаптирован к меньшему UI',function()
      local got=views();report.small_ui.actual=got
      return #got==2 and got[1].open and got[1].width==width and not got[2].open
    end,15000)
    capture('smaller-ui')
    -- Возврат фокуса не должен включать follow того же файла.
    tui:command('tabnext 1')
    e:wait('первая вкладка в коде',function()
      return tui:lua([[return vim.api.nvim_tabpage_get_number(0)==1 and vim.bo.buftype=='']])
    end)
    local selected=views()[1].selected
    tui:send(' we')
    e:wait('Files первой вкладки в фокусе',function() return tui:lua([[return vim.bo.filetype=='neo-tree']]) end)
    tui:send(' w0')
    e:wait('фокус вернулся в код',function() return tui:lua([[return vim.bo.buftype=='']]) end)
    vim.wait(200) -- штатный follow debounce100ms должен успеть выполниться, если ошибочно запущен
    T.eq(views()[1].selected,selected,'same-file focus reset Files selection')
    tui:command('edit third.txt')
    e:wait('новый файл по-прежнему отслеживается',function()
      local id=views()[1].selected;return id and id:gsub('\\','/')==tui.a..'/third.txt'
    end)
    capture('follow-new-file')
    tui:quit()
    save_view_data('last')
    tui:save_sessions('view-last')
  end,debug.traceback)
  if tui then
    report=report or {};report.ok=ok;report.error=not ok and err or nil
    if not ok then
      -- Host RPC доступен и при hit-enter в дочернем TUI; сохранить ДО quit.
      local captured,text=pcall(tui.host.lua,tui.host,[[return vim.api.nvim_buf_get_lines(_G.forge_session_terminal,0,-1,false)]])
      if captured then vim.fn.writefile(text,tui.host.dir..'/failure-terminal.txt') end
      local observed,state=pcall(tui.state,tui)
      if observed then report.failure_state=state end
      if save_view_data then
        local copied,why=pcall(save_view_data,'failure')
        if not copied then report.view_data_error=tostring(why) end
      end
    end
    vim.fn.writefile({vim.json.encode(report)},tui.host.dir..'/session-files-view.json')
    local stopped,cleanup=pcall(tui.stop,tui,not ok and err or nil)
    io.stdout:write('  artifacts: '..tui.host.dir..'\n')
    if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
  end
  assert(ok,err)
end)
T.finish()
