-- IDE-080: bounded native обзор finders, без изменения production predicates.
-- Не regression контракт: JSON фиксирует текущие решения, в том числе спорные.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local reports={}
local function capture(e,label)
  local value=e:lua([[return _G.forge_window_probe.capture(...)]],{label})
  e:snapshot(label)
  return value
end
local function run(name,fn)
  if vim.env.FORGE_WINDOW_CASE and vim.env.FORGE_WINDOW_CASE~=name then return end
  local e,report
  local ok,err=xpcall(function()
    e=require('editor').start(root,{timeout=45000})
    report={name=name,artifacts=e.dir}
    assert(vim.uv.fs_copyfile(root..'/tests/diagnostics/code-window.lua',e.dir..'/code-window.lua'))
    e:input(':edit file_one.txt<CR>')
    e:wait('Обычный файл в редакторе',function() return e:current_file():sub(-12)=='file_one.txt' end)
    e:lua([[_G.forge_window_probe={events={}}
      local P=_G.forge_window_probe
      function P.capture(label)
        local state=require('ide.state');local windows={}
        for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local b=vim.api.nvim_win_get_buf(w);local c=vim.api.nvim_win_get_config(w)
          local edgy=require('edgy').get_win(w)
          windows[#windows+1]={win=w,buf=b,file=vim.api.nvim_buf_get_name(b),ft=vim.bo[b].filetype,
            bt=vim.bo[b].buftype,floating=c.relative~='',main=state.is_main_window(w),
            marker=not not vim.w[w].forge_panel,component=vim.w[w].forge_component,
            edgy=edgy~=nil,winfixwidth=vim.wo[w].winfixwidth,winfixheight=vim.wo[w].winfixheight,
            edgy_disable=vim.b[b].edgy_disable,lines=vim.api.nvim_buf_get_lines(b,0,math.min(6,vim.api.nvim_buf_line_count(b)),false)}
        end
        return {label=label,windows=windows,current=vim.api.nvim_get_current_win(),
          activities=require('ide.activities').find_code_window() or false,mode=vim.api.nvim_get_mode()}
      end
      P.normal=vim.api.nvim_get_current_win()
    ]])
    report.before=capture(e,'before')
    fn(e,report)
    report.after=capture(e,'after')
    report.events=e:lua('return _G.forge_window_probe.events')
    report.observed=e:lua([[return {messages=vim.fn.execute('messages'),notifications=vim.g.forge_e2e_notifications,
      installs=vim.g.forge_e2e_installs,mode=vim.api.nvim_get_mode()}]])
    assert(report.observed.installs==0,'Неожиданная установка')
    assert(not report.observed.mode.blocking,'Остался blocking prompt')
    for _,n in ipairs(report.observed.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    assert(not report.observed.messages:match('E%d%d%d+:'),report.observed.messages)
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/code-window.json')
    io.stdout:write(name..'; artifacts: '..e.dir..'\n')
  end,debug.traceback)
  if e then
    if not ok then
      pcall(function() vim.fn.writefile({vim.json.encode({error=tostring(err),partial=report})},e.dir..'/probe-error.json') end)
    end
    e:stop(not ok and tostring(err) or nil)
    assert(e.rpc.exit_code==0 and e.rpc.exit_signal==0,'Native quit failed: '..vim.inspect(e.rpc.shutdown_result))
    assert(#e.rpc.api_errors==0,'RPC API errors: '..vim.inspect(e.rpc.api_errors))
  end
  if not ok then error(err) end
  reports[#reports+1]=report
end
local function discover(e,report)
  -- Снимок сразу после создания fixture, до следующего scheduled callback.
  report.discovery=e:lua([[local P=_G.forge_window_probe
    local before=P.capture('synchronous-before-find')
    local found=require('ide.state').find_main_window()
    return {before=before,found=found,after=P.capture('synchronous-after-find')}]])
  vim.wait(200)
  report.settled=capture(e,'settled')
end
run('normal',function(e,report)
  e:input(':vsplit file_two.txt<CR>')
  e:wait('Два обычных файла',function() return e:lua('return #vim.api.nvim_tabpage_list_wins(0)')==2 end)
  report.pre_discovery=capture(e,'two-files')
  discover(e,report)
end)
run('float-only',function(e,report)
  report.fixture=e:lua([[local P=_G.forge_window_probe
    local tool=vim.api.nvim_create_buf(false,true);vim.bo[tool].filetype='forge-window-probe'
    vim.api.nvim_win_set_buf(P.normal,tool)
    local b=vim.fn.bufadd(vim.fn.getcwd()..'/file_two.txt');vim.fn.bufload(b)
    P.float=vim.api.nvim_open_win(b,false,{relative='editor',row=3,col=8,width=65,height=10,style='minimal',border='single'})
    return P.capture('float-and-nofile')]])
  discover(e,report)
end)
run('terminal-only',function(e,report)
  report.fixture=e:lua([[local P=_G.forge_window_probe
    vim.cmd.enew()
    P.job=vim.fn.jobstart({vim.v.progpath,'--clean','--headless','-c',
      'lua vim.defer_fn(function() vim.cmd("qa!") end,60000)'},{term=true})
    assert(P.job>0 and vim.fn.jobwait({P.job},0)[1]==-1,'Настоящий PTY child не стартовал')
    return {job=P.job,pid=vim.fn.jobpid(P.job),state=P.capture('native-terminal')}]])
  discover(e,report)
  e:input('<F7>')
  e:wait('Код перед открытием Debug View',function()
    return e:lua('return vim.api.nvim_get_current_win()')==report.discovery.found
  end)
  e:input(' md')
  e:wait('Настоящий Debug View открыт',function() return e:has_window('dap-repl') end)
  vim.wait(200)
  report.manual_debug=capture(e,'manual-debug-from-code-with-terminal')
  e:lua([[vim.fn.jobstop(_G.forge_window_probe.job)]])
end)
run('live-marker',function(e,report)
  report.sweep=e:lua([[local P=_G.forge_window_probe
    vim.cmd('vsplit file_two.txt');P.marked=vim.api.nvim_get_current_win()
    vim.w[P.marked].forge_panel=true;vim.wo[P.marked].winfixwidth=true
    local before=P.capture('synchronous-marker-before-sweep')
    require('forge.panel_guard').sweep()
    return {marked=P.marked,before=before,after=P.capture('synchronous-marker-after-sweep')}]])
  vim.wait(200)
  report.settled=capture(e,'marker-settled')
end)
run('session-winfix',function(e,report)
  report.saved=e:lua([[local P=_G.forge_window_probe
    vim.cmd('vsplit file_two.txt')
    vim.wo.winfixwidth=true
    -- Native mksession сохраняет window-local options старой раскладки.
    vim.opt.sessionoptions:append('localoptions')
    local persistence=require('persistence');persistence.save()
    local path=persistence.current();local lines=vim.fn.readfile(path)
    assert(table.concat(lines,'\n'):find('setlocal winfixwidth',1,true),'Session не сохранил winfix')
    P.session=path
    vim.api.nvim_create_autocmd('User',{pattern={'PersistenceLoadPre','PersistenceLoadPost'},callback=function(ev)
      P.events[#P.events+1]=P.capture(ev.match)
    end})
    return {path=path,state=P.capture('saved-native-session'),sessionoptions=vim.o.sessionoptions}
  ]])
  assert(vim.uv.fs_copyfile(report.saved.path,e.dir..'/native-session.vim'))
  e:input(':only<CR>:enew<CR>')
  e:lua([[require('persistence').load()]])
  e:wait('Настоящие Persistence LoadPre/Post',function() return e:lua('return #_G.forge_window_probe.events')==2 end)
  e:wait('Explorer после restore',function() return e:has_window('neo-tree') end)
  vim.wait(250)
  report.restored=capture(e,'restored-settled')
  report.loaded=e:lua([[local out={};for _,b in ipairs(vim.api.nvim_list_bufs()) do
    local file=vim.api.nvim_buf_get_name(b)
    if vim.api.nvim_buf_is_loaded(b) and (file:find('file_one.txt',1,true) or file:find('file_two.txt',1,true)) then out[#out+1]=file end
    end;return out]])
  assert(#report.loaded==2,'Persistence не восстановил оба file buffers')
end)
local output=root..'/.tests/code-window-review.json'
vim.fn.writefile({vim.json.encode(reports)},output)
io.stdout:write('review profiles: '..#reports..'; report: '..output..'\n')
