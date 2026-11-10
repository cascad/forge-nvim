-- Bounded native TUI baseline; does not change production root/session glue.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local tui,report
local ok,err=xpcall(function()
  tui=require('session_tui').start(root)
  report={artifacts=tui.host.dir,states={}}
  assert(vim.uv.fs_copyfile(root..'/tests/diagnostics/project-session.lua',tui.host.dir..'/project-session.lua'))
  local function capture(label)
    local state=tui:state();report.states[#report.states+1]={label=label,state=state}
    vim.fn.writefile({vim.json.encode(report)},tui.host.dir..'/project-session.json')
    tui.host:snapshot(label);return state
  end
  report.initial=tui:launch();capture('initial')
  tui:command('edit first.txt')
  tui.host:wait('first file',function() return tui:state().file==tui.a..'/first.txt' end)
  tui:send('23G07l')
  tui:command('vsplit second.txt')
  tui.host:wait('second file',function() return tui:state().file==tui.a..'/second.txt' end)
  tui:send('37G05l')
  tui:send(' e')
  tui.host:wait('Explorer open',function()
    for _,tab in ipairs(tui:state().tabs) do for _,w in ipairs(tab.windows) do if w.ft=='neo-tree' then return true end end end
  end)
  tui:command('tabedit third.txt')
  tui.host:wait('third file in new tab',function() return tui:state().file==tui.a..'/third.txt' and #tui:state().tabs==2 end)
  tui:send('47G03l')
  tui:command([=[cgetexpr ['third.txt:47:1:FORGE_SESSION_QUICKFIX']]=])
  tui:command('copen')
  tui.host:wait('Quickfix open',function()
    for _,tab in ipairs(tui:state().tabs) do for _,w in ipairs(tab.windows) do if w.ft=='qf' then return true end end end
  end)
  capture('before-quit');tui:quit();tui:save_sessions('first-quit')
  report.relaunch=tui:launch();capture('relaunched')
  tui:send(' qs')
  tui.host:wait('restored files',function()
    local count=0;for _,tab in ipairs(tui:state().tabs) do for _,w in ipairs(tab.windows) do if w.bt=='' and w.file:match('%.txt$') then count=count+1 end end end
    return count==3
  end,10000)
  capture('restored')
  tui:command('tabnext 2')
  tui:command('buffer third.txt')
  tui.host:wait('third.txt active',function() return tui:state().file==tui.a..'/third.txt' end)
  tui:send('A_FORGE_MODIFIED')
  tui.host:wait('insert mode',function() return tui:mode().mode=='i' end)
  tui:normal();tui:send('47G03l')
  tui.host:wait('unsaved edit',function()
    for _,b in ipairs(tui:state().buffers) do if b.file==tui.a..'/third.txt' then return b.modified end end
  end)
  capture('before-switch')
  tui:command('lua require("config.start").open_project('..vim.inspect(tui.b)..')')
  report.switched=tui:connect(report.relaunch.pid)
  tui.host:wait('project B',function() return tui:state().cwd==tui.b end,10000)
  capture('project-b')
  report.written_on_switch=vim.fn.readfile(tui.a..'/third.txt')[47]
  tui:save_sessions('switch-b')
  tui:command('edit first.txt')
  tui.host:wait('B file',function() return tui:state().file==tui.b..'/first.txt' end)
  capture('project-b-edit')
  tui:command('lua require("config.start").open_project('..vim.inspect(tui.a)..')')
  report.returned=tui:connect(report.switched.pid)
  tui.host:wait('project A files and tabs',function()
    local s=tui:state();return s.cwd==tui.a and #s.tabs==2 and #s.buffers==3
  end,10000)
  capture('project-a-returned')
  report.loaded_after_return=tui:lua([[for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(b):gsub('\\','/')==... then return vim.api.nvim_buf_get_lines(b,46,47,false)[1] end
  end]],{tui.a..'/third.txt'})
  tui:save_sessions('returned-a')
end,debug.traceback)
if tui then
  report=report or {artifacts=tui.host.dir};report.ok=ok;report.error=not ok and err or nil
  vim.fn.writefile({vim.json.encode(report)},tui.host.dir..'/project-session.json')
  local stopped,cleanup=pcall(tui.stop,tui,not ok and err or nil)
  io.stdout:write('artifacts: '..tui.host.dir..'\n')
  if not stopped then err=tostring(err or '')..'\nCleanup: '..tostring(cleanup);ok=false end
end
assert(ok,err)
io.stdout:write('native project/session baseline PASS\n')
