-- Actual mksession fixture predating cleanup. Native TUI owns A -> B -> A.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local mode=assert(arg[1],'Expected winfix, hidden or their -direct variants')
local direct=mode:match('%-direct$')~=nil
local variant=mode:gsub('%-direct$','')
assert(variant=='winfix' or variant=='hidden','Unknown legacy variant')
local tui,report
local ok,err=xpcall(function()
  tui=require('session_tui').start(root)
  report={variant=mode,artifacts=tui.host.dir}
  assert(vim.uv.fs_copyfile(root..'/tests/diagnostics/session-legacy.lua',tui.host.dir..'/session-legacy.lua'))
  report.initial=tui:launch()
  tui:command('edit first.txt')
  tui.host:wait('A file',function() return tui:state().file==tui.a..'/first.txt' end)
  if variant=='winfix' then
    tui:command('vsplit second.txt')
    tui.host:wait('second file',function() return tui:state().file==tui.a..'/second.txt' end)
  else
    tui:command('help help')
    tui.host:wait('native help',function() return tui:lua('return vim.bo.buftype')=='help' end)
  end
  local raw=tui.base..'/legacy.vim'
  report.saved=tui:lua([[local path,variant=...;
    if variant=='winfix' then vim.wo.winfixwidth=true end
    if variant=='hidden' then
      for _,w in ipairs(vim.api.nvim_list_wins()) do
        if vim.bo[vim.api.nvim_win_get_buf(w)].buftype=='help' then vim.api.nvim_set_current_win(w);break end
      end
      -- Construct an older help-only layout atomically before Edgy's scheduled
      -- window work. Only fixture construction skips autocmds, restore does not.
      vim.cmd('noautocmd only!')
      assert(vim.bo.buftype=='help','Legacy fixture must show native help')
    end
    local listed={};for _,b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[b].buflisted and vim.bo[b].buftype=='' then listed[#listed+1]=vim.api.nvim_buf_get_name(b) end
    end
    local code=0;for _,w in ipairs(vim.api.nvim_list_wins()) do local b=vim.api.nvim_win_get_buf(w)
      if vim.bo[b].buftype=='' and vim.api.nvim_buf_get_name(b)~='' then code=code+1 end
    end
    vim.cmd('mksession! '..vim.fn.fnameescape(path))
    return {target=require('persistence').current(),listed=listed,visible_files=code}
  ]],{raw,variant})
  assert(#report.saved.listed==(variant=='hidden' and 1 or 2),'Listed file fixture missing')
  if variant=='hidden' then assert(report.saved.visible_files==0,'Hidden file is still visible in raw session') end
  assert(vim.uv.fs_copyfile(raw,tui.host.dir..'/legacy-session.vim'))
  if variant=='winfix' then
    assert(table.concat(vim.fn.readfile(raw),'\n'):find('setlocal winfixwidth',1,true),'Raw session lacks winfix')
  end
  report.before=tui:state();tui.host:snapshot('legacy-before-switch')
  if not direct then
    tui:command('lua require("config.start").open_project('..vim.inspect(tui.b)..')')
    report.switched=tui:connect(report.initial.pid)
    tui.host:wait('B ready',function() return tui:state().cwd==tui.b end)
  end
  -- Ordinary switch saved a clean session. Install the older *real* session
  -- after that save, while B is active; only the owned private state is written.
  local target=vim.fs.normalize(report.saved.target):gsub('\\','/')
  local runtime=vim.fs.normalize(tui.host.runtime):gsub('\\','/')
  assert(target:sub(1,#runtime+1)==runtime..'/','Session target outside owned runtime')
  assert(vim.uv.fs_copyfile(raw,target))
  if direct then
    tui:send(' qs')
    tui.host:wait('native PersistenceLoadPost',function()
      for _,line in ipairs(vim.fn.readfile(tui.base..'/lifecycle.jsonl')) do
        local row=vim.json.decode(line)
        if row.pid==report.initial.pid and row.event=='PersistenceLoadPost' then return true end
      end
    end)
    -- Event-loop barrier after the native LoadPost, without a fixed sleep.
    tui:lua([[vim.schedule(function() _G.forge_legacy_load_scheduled=true end)]])
    tui.host:wait('LoadPost scheduled callbacks',function() return tui:lua('return _G.forge_legacy_load_scheduled') end)
    report.returned={pid=tui:lua('return vim.uv.os_getpid()')}
  else
    tui:command('lua require("config.start").open_project('..vim.inspect(tui.a)..')')
    report.returned=tui:connect(report.switched.pid)
  end
  tui.host:wait('A ready',function() return tui:state().cwd==tui.a end)
  report.after=tui:state();tui.host:snapshot('legacy-after-restore')
  report.tree_path=tui:lua([[local m=package.loaded['neo-tree.sources.manager'];
    local s=m and m.get_state('filesystem');return s and s.path and s.path:gsub('\\','/') or false]])
end,debug.traceback)
if tui then
  report=report or {variant=mode,artifacts=tui.host.dir};report.ok=ok;report.error=not ok and err or nil
  if not ok then
    local captured,state=pcall(tui.state,tui);report.failed_state=captured and state or {error=tostring(state)}
    pcall(tui.host.snapshot,tui.host,'legacy-failure')
  end
  assert(vim.fn.writefile({vim.json.encode(report)},tui.host.dir..'/session-legacy.json')==0)
  local stopped,cleanup=pcall(tui.stop,tui,not ok and err or nil)
  io.stdout:write('artifacts: '..tui.host.dir..'\n')
  if not stopped then err=tostring(err or '')..'\nCleanup: '..tostring(cleanup);ok=false end
end
assert(ok,err)
io.stdout:write('native legacy '..variant..' probe PASS\n')
