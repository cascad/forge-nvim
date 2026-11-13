-- spec: IDE-PANEL-26. Native Lua Tree-sitter/Aerial, настоящий PTY и restart.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
T.check('IDE-PANEL-26 Outline geometry по вкладкам и проектам',function()
  local tui,report
  local ok,err=xpcall(function()
    tui=require('session_tui').start(root);local e=tui.host;report={states={},pids={}}
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/session-outline-view.test.lua',e.dir..'/session-outline-view.test.lua'))
    for _,row in ipairs({{tui.a,'first','A_FIRST_'},{tui.a,'second','A_SECOND_'},{tui.b,'first','B_FIRST_'}}) do
      local lines={};for i=1,50 do vim.list_extend(lines,{'local function '..row[3]..('%02d'):format(i)..'()', '  return '..i,'end'}) end
      vim.fn.writefile(lines,row[1]..'/'..row[2]..'.lua')
    end
    local function views()
      return tui:lua([[local result={};for _,tab in ipairs(vim.api.nvim_list_tabpages()) do
        local item={open=false};for _,win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
          local buf=vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype=='aerial' and vim.api.nvim_win_get_config(win).relative=='' then
            local names={};for _,line in ipairs(vim.api.nvim_buf_get_lines(buf,0,-1,false)) do
              local name=line:match('([AB]_%u+_%d%d)');if name then names[#names+1]=name end end
            item={open=true,width=vim.api.nvim_win_get_width(win),symbols=names}
          end
        end;result[#result+1]=item end;return result]])
    end
    local function capture(label)
      local state=tui:state();T.eq(state.installs,0);assert(not state.mode.blocking)
      for _,n in ipairs(state.notices or {}) do assert(n.level<vim.log.levels.ERROR,n.message) end
      local got=views();report.states[label]={views=got,state=state}
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/session-outline-view.json');return got
    end
    local function wait_views(expected)
      e:wait('Outline views восстановлены',function()
        local got=views();report.comparison={expected=expected,actual=got};return vim.deep_equal(got,expected)
      end,15000)
    end
    local function outline(prefix,delta)
      tui:send(' wa')
      e:wait('Aerial native symbols готовы',function() return tui:lua([[return vim.bo.filetype=='aerial']])
        and #views()[tui:lua('return vim.api.nvim_tabpage_get_number(0)')].symbols==50 end,15000)
      local names=views()[tui:lua('return vim.api.nvim_tabpage_get_number(0)')].symbols
      T.eq(names[1],prefix..'01');T.eq(names[50],prefix..'50')
      e:wait('Aerial в Edgy',function() return tui:lua([[local w=require('edgy').get_win();return w and w.width==vim.api.nvim_win_get_width(0) or false]]) end)
      local width=tui:lua('return vim.api.nvim_win_get_width(0)');tui:send(('\23>'):rep(delta/2))
      e:wait('Native Outline resize',function() return tui:lua('return vim.api.nvim_win_get_width(0)')==width+delta end)
      tui:send(' w0');e:wait('Lua code focus',function() return tui:lua([[return vim.bo.filetype=='lua']]) end)
    end
    local function geometry() e:lua([[vim.wo.number=false;vim.wo.relativenumber=false;vim.wo.signcolumn='no';vim.wo.foldcolumn='0']]) end
    local function metadata(label)
      local source=e:lua([[return vim.fn.stdpath('state')..'/forge-session-views']])
      local target=e.dir..'/session-view-data-'..label;vim.fn.mkdir(target,'p');local out={}
      for name,kind in vim.fs.dir(source) do assert(kind=='file');assert(vim.uv.fs_copyfile(source..'/'..name,target..'/'..name))
        out[#out+1]=vim.json.decode(table.concat(vim.fn.readfile(source..'/'..name),'\n')) end
      return out
    end
    geometry();local first=tui:launch();report.pids[#report.pids+1]=first.pid
    tui:command('edit first.lua');e:wait('A first Lua',function() return tui:state().file==tui.a..'/first.lua' end)
    tui:send('17G');outline('A_FIRST_',8)
    tui:command('tabedit second.lua');e:wait('A second Lua',function() return tui:state().file==tui.a..'/second.lua' end)
    tui:send('35G');outline('A_SECOND_',4)
    local before=capture('before-quit');assert(before[1].width~=before[2].width)
    tui:quit();tui:save_sessions('outline-first');metadata('first')
    local second=tui:launch();report.pids[#report.pids+1]=second.pid;tui:send(' qs');wait_views(before)
    capture('reopened');assert(tui:lua([[return vim.bo.filetype=='lua']]),'Outline restore украл code focus')
    T.eq(tui:state().cursor[1],35,'Restore изменил code cursor')
    tui:send(' wa');e:wait('Outline focus',function() return tui:lua([[return vim.bo.filetype=='aerial']]) end)
    tui:send('q');e:wait('Второй Outline скрыт',function() return not views()[2].open end)
    local saved_a=capture('before-b')
    tui:command('lua require("config.start").open_project('..vim.inspect(tui.b)..')')
    local b=tui:connect(second.pid);report.pids[#report.pids+1]=b.pid
    e:wait('B cwd',function() return tui:state().cwd==tui.b end)
    tui:command('edit first.lua');e:wait('B Lua',function() return tui:state().file==tui.b..'/first.lua' end)
    outline('B_FIRST_',6);local saved_b=capture('before-return-a')
    tui:command('lua require("config.start").open_project('..vim.inspect(tui.a)..')')
    local a=tui:connect(b.pid);report.pids[#report.pids+1]=a.pid
    e:wait('A cwd',function() return tui:state().cwd==tui.a end);wait_views(saved_a);capture('returned-a')
    tui:command('lua require("config.start").open_project('..vim.inspect(tui.b)..')')
    local again=tui:connect(a.pid);report.pids[#report.pids+1]=again.pid
    e:wait('B снова',function() return tui:state().cwd==tui.b end);wait_views(saved_b);capture('returned-b')
    tui:quit();local saved
    for _,data in ipairs(metadata('before-small')) do if #data.tabs==2 then saved=data.tabs[1].outline end end
    assert(saved,'Сохранённый A Outline отсутствует')
    e.rpc:request('nvim_ui_try_resize',{math.max(80,saved.columns-30),45});geometry()
    local small=tui:launch();report.pids[#report.pids+1]=small.pid
    local columns=tui:lua('return vim.o.columns');assert(columns<saved.columns)
    tui:send(' qs');local minimum=tui:lua([[return require('edgy.config').options.left.size]])
    local width=math.max(minimum,math.floor(saved.width*columns/saved.columns+0.5))
    report.small={columns=columns,saved_columns=saved.columns,expected=width}
    e:wait('Outline адаптирован к меньшему UI',function()
      local got=views();report.small.actual=got;return #got==2 and got[1].open and got[1].width==width
        and #got[1].symbols==50 and not got[2].open
    end,15000)
    capture('smaller-ui');assert(tui:lua([[return vim.bo.filetype=='lua']]))
    tui:quit();metadata('last');tui:save_sessions('outline-last')
  end,debug.traceback)
  if tui then
    report=report or {};report.ok=ok;report.error=not ok and err or nil
    if not ok then local captured,screen=pcall(tui.host.lua,tui.host,[[return vim.api.nvim_buf_get_lines(_G.forge_session_terminal,0,-1,false)]])
      if captured then vim.fn.writefile(screen,tui.host.dir..'/failure-terminal.txt') end
      local observed,state=pcall(tui.state,tui);if observed then report.failure_state=state end end
    vim.fn.writefile({vim.json.encode(report)},tui.host.dir..'/session-outline-view.json')
    local stopped,why=pcall(tui.stop,tui,not ok and err or nil);io.stdout:write('  artifacts: '..tui.host.dir..'\n')
    if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(why) end
  end
  assert(ok,err)
end)
T.finish()
