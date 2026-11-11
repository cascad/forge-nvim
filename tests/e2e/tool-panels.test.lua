-- spec: IDE-PANEL-17. Настоящие shell, gopls и native Trouble views.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local P=require('output_policy')
local escape=string.char(28)..string.char(14)
local function keys(e,value)
  local before=e:lua('return _G.forge_tool_keys')
  e:input(value..'<F35>')
  e:wait('ввод обработан',function() return e:lua('return _G.forge_tool_keys')>before end)
end
local function mode(e) return e.rpc:request('nvim_get_mode',{}).mode end
local function normal(e)
  if mode(e)=='t' then keys(e,escape) end
  assert(mode(e):sub(1,1)=='n','ожидался normal')
end
local function code(e)
  if e:current_ft()=='text' or e:current_ft()=='go' then return end
  e:input('<F7>');e:wait('код',function() return e:current_ft()=='text' or e:current_ft()=='go' end)
end
local function focus(e,input,kind)
  keys(e,input)
  e:wait('фокус '..kind,function() return e:current_ft()==kind end,5000)
end
local function text(e,buf) return e:lua([[return table.concat(vim.api.nvim_buf_get_lines(...,0,-1,false),'\n')]],{buf or 0}) end
local function relative(e) return e:lua([[return vim.api.nvim_win_get_config(0).relative]]) end
local function state(e)
  return e:lua([[local out={};for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b=vim.api.nvim_win_get_buf(w);local channel=vim.bo[b].channel
    out[#out+1]={win=w,buf=b,ft=vim.bo[b].filetype,relative=vim.api.nvim_win_get_config(w).relative,
      buftype=vim.bo[b].buftype,channel=channel,pid=channel>0 and vim.fn.jobpid(channel) or false,
      text=table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n')}
    end;return {windows=out,mode=vim.api.nvim_get_mode(),current=vim.api.nvim_get_current_win(),
      dap=package.loaded.dap and require('dap').session()~=nil or false,installs=vim.g.forge_e2e_installs} ]])
end
local function check(name,lsp,fn)
  if vim.env.FORGE_TOOL_PANEL_CASE and not name:find(vim.env.FORGE_TOOL_PANEL_CASE,1,true) then return end
  T.check('IDE-PANEL-17 '..name,function()
    local e,report
    local ok,err=xpcall(function()
      local opts={timeout=120000}
      if lsp then
        local deps=vim.env.FORGE_E2E_LSP_DEPS or root..'/.tests/lsp-deps'
        assert(vim.fn.filereadable(deps..'/manifest.json')==1,'Явно подготовь LSP deps')
        local sdk=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
        local sep=vim.fn.has('win32')==1 and ';' or ':'
        opts.env={PATH=deps..'/bin'..sep..sdk..'/go/bin'..sep..vim.env.PATH,
          GOTOOLCHAIN='local',GOENV='off',GOPROXY='off',GOSUMDB='off',GOTELEMETRY='off',
          GOMAXPROCS='2',GOCACHE=require('go_cache').path(root)}
        opts.prepare=function(project)
          vim.fn.writefile({'module forgepanel','go 1.24'},project..'/go.mod')
          vim.fn.writefile({'package forgepanel','','func Alpha() int { return missingAlpha }',
            '','func Omega() int { return missingOmega }'},project..'/broken.go')
        end
      end
      e=require('editor').start(root,opts)
      report={case=name,states={}}
      e:wait('сборка готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      e:lua([[_G.forge_tool_keys=0;vim.keymap.set({'n','t'},'<F35>',function() _G.forge_tool_keys=_G.forge_tool_keys+1 end)]])
      e:input(':edit file_one.txt<CR>');e:wait('текстовый файл',function() return e:current_ft()=='text' end)
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/tool-panels.test.lua',e.dir..'/tool-panels.test.lua'))
      local function capture(label)
        local value=state(e);value.label=label;report.states[#report.states+1]=value
        assert(vim.fn.writefile({vim.json.encode(report)},e.dir..'/tool-panels.json')==0)
        return value
      end
      capture('initial');fn(e,capture,report)
      local final=capture('final');T.eq(final.installs,0);T.eq(final.dap,false)
      for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    end,debug.traceback)
    if e then
      report=report or {case=name};report.ok=ok;report.error=not ok and tostring(err) or nil
      assert(vim.fn.writefile({vim.json.encode(report)},e.dir..'/tool-panels.json')==0)
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
      if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
      if e.rpc.shutdown_result then
        T.eq(e.rpc.exit_code,0);T.eq(e.rpc.exit_signal,0);T.eq(e.rpc.api_errors,{})
        assert(e.rpc.shutdown_result.ok,vim.inspect(e.rpc.shutdown_result))
      end
    end
    assert(ok,err)
  end)
end
local function shell(e,input)
  focus(e,input or string.char(20),'toggleterm')
  if mode(e)~='t' then keys(e,'i') end
  T.eq(mode(e),'t')
  e:input('echo FORGE_TOOL_READY<CR>')
  e:wait('настоящий shell stdout',function()
    return e:lua([[for _,s in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do if s=='FORGE_TOOL_READY' then return true end end;return false]])
  end)
end
local function terminal(e)
  local snapshot=state(e)
  for _,window in ipairs(snapshot.windows) do
    if window.ft=='toggleterm' and window.win==snapshot.current then return window end
  end
  error('текущий terminal не найден')
end
local function terminals(e)
  local out={}
  for _,window in ipairs(state(e).windows) do if window.ft=='toggleterm' then out[#out+1]=window end end
  return out
end
local function preserved(before,after)
  T.eq(after.buf,before.buf);T.eq(after.channel,before.channel);T.eq(after.pid,before.pid)
  assert(P.history_preserved(before,after),'потерян terminal output')
end
local function zoom(e)
  normal(e);local win=e:lua('return vim.api.nvim_get_current_win()')
  local buf=e:lua('return vim.api.nvim_get_current_buf()')
  keys(e,' wz');T.eq(relative(e),'editor','Common zoom missing')
  T.eq(e:lua('return vim.api.nvim_get_current_buf()'),buf)
  return win,e:lua('return vim.api.nvim_get_current_win()')
end
local function help(e,kind,heading)
  focus(e,'?','forge-panel-help');assert(text(e):find(heading..' — Space w',1,true),text(e))
  assert(text(e):find('T / x',1,true),'help route отсутствует')
  focus(e,'q',kind)
end
check('cold Terminal focus is idempotent',false,function(e,capture)
  shell(e,' wT');normal(e);local before=terminal(e);capture('terminal-before')
  keys(e,' wT');T.eq(e:current_ft(),'toggleterm');preserved(before,terminal(e))
  normal(e);code(e);focus(e,' wT','toggleterm');preserved(before,terminal(e))
  capture('terminal-refocused')
end)
check('Terminal input help zoom cancel hide preserve process',false,function(e,capture)
  shell(e);e:input('echo FORGE_TOOL_LITERAL_q?wh')
  e:wait('печатный ввод',function() return text(e):find('FORGE_TOOL_LITERAL_q?wh',1,true)~=nil end)
  T.eq(mode(e),'t');keys(e,escape);local before=terminal(e);capture('terminal-input')
  local original=zoom(e);help(e,'toggleterm','Terminal')
  keys(e,'<Esc>');T.eq(e:lua('return vim.api.nvim_get_current_win()'),original);preserved(before,terminal(e))
  keys(e,'<Esc>');T.eq(e:current_ft(),'text');assert(e:has_window('toggleterm'))
  capture('terminal-after-cancel')
  focus(e,' wT','toggleterm');normal(e);help(e,'toggleterm','Terminal')
  keys(e,'q');T.eq(e:current_ft(),'text');assert(not e:has_window('toggleterm'))
  focus(e,' wT','toggleterm');normal(e);preserved(before,terminal(e))
  keys(e,'i');T.eq(mode(e),'t');e:input('<CR>')
  e:wait('shell завершил прежнюю строку',function()
    return e:lua([[for _,s in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do if s=='FORGE_TOOL_LITERAL_q?wh' then return true end end;return false]])
  end)
  keys(e,escape);keys(e,escape);code(e);capture('terminal-preserved')
end)
check('Terminal hide closes current view only',false,function(e,capture)
  shell(e);normal(e);local first=terminal(e)
  e:input(':2ToggleTerm direction=vertical<CR>');e:wait('два terminal окна',function() return #terminals(e)==2 end)
  normal(e);local current=e:lua('return vim.api.nvim_get_current_buf()');assert(current~=first.buf)
  local all=terminals(e);capture('two-terminals')
  zoom(e);keys(e,' wq');T.eq(e:current_ft(),'text')
  local remaining=terminals(e);T.eq(#remaining,1);T.eq(remaining[1].buf,first.buf)
  for _,s in ipairs(all) do T.eq(e:lua('return vim.fn.jobpid(...)',{s.channel}),s.pid) end
  capture('one-terminal-hidden')
end)
check('cold empty Problems focus help cancel hide',false,function(e,capture)
  focus(e,' wx','trouble');local before=e:lua('return {win=vim.api.nvim_get_current_win(),buf=vim.api.nvim_get_current_buf()}')
  capture('empty-problems');keys(e,' wx');T.eq(e:lua('return vim.api.nvim_get_current_win()'),before.win)
  help(e,'trouble','Problems / Trouble');zoom(e);keys(e,'<Esc>');T.eq(e:lua('return vim.api.nvim_get_current_win()'),before.win)
  keys(e,'<Esc>');T.eq(e:current_ft(),'text');assert(e:has_window('trouble'))
  focus(e,' wx','trouble');keys(e,'q');T.eq(e:current_ft(),'text');assert(not e:has_window('trouble'))
  capture('empty-hidden')
end)
local function seek(e,value)
  keys(e,'gg/'..value..'<CR>')
  e:wait('выбрана строка '..value,function() return e:lua('return vim.api.nvim_get_current_line()'):find(value,1,true)~=nil end)
end
check('gopls Problems selected zoom item jumps to actual diagnostic',true,function(e,capture,report)
  e:input(':edit broken.go<CR>');e:wait('Go файл',function() return e:current_ft()=='go' end)
  e:wait('actual gopls diagnostics',function() return e:lua([[local c=vim.lsp.get_clients({name='gopls',bufnr=0});return #c==1 and #vim.diagnostic.get(0)>=2]]) end,30000)
  report.diagnostics=e:lua('return vim.diagnostic.get(0)')
  focus(e,' xx','trouble');e:wait('оба LSP результата',function() return text(e):find('missingAlpha',1,true) and text(e):find('missingOmega',1,true) end)
  seek(e,'missingAlpha');local original,overlay=zoom(e);seek(e,'missingOmega');capture('diagnostic-selected-in-zoom')
  keys(e,'<CR>');e:wait('native jump в Omega',function() return e:current_ft()=='go' and e:lua('return vim.api.nvim_win_get_cursor(0)[1]')==5 end)
  assert(e:lua('return vim.api.nvim_win_is_valid(...)',{original}))
  T.eq(e:lua('return vim.api.nvim_win_is_valid(...)',{overlay}),false,'временный zoom остался после native действия')
  focus(e,' wx','trouble');seek(e,'missingOmega');zoom(e);keys(e,'zc');T.eq(relative(e),'')
  capture('diagnostic-native-fold');keys(e,'zR');e:wait('native fold открыт',function() return text(e):find('missingOmega',1,true)~=nil end)
  help(e,'trouble','Problems / Trouble');keys(e,' wq');T.eq(e:current_ft(),'go')
  focus(e,' xx','trouble');e:wait('результаты вернулись',function() return text(e):find('missingOmega',1,true)~=nil end)
  capture('diagnostics-preserved')
end)
check('Quickfix Trouble current view native help and zoom jump',false,function(e,capture)
  vim.fn.writefile({'second file','FORGE_QF_TARGET'},e.project..'/file_two.txt')
  e:lua([[local root=...;vim.fn.setqflist({{filename=root..'/file_one.txt',lnum=1,col=1,text='FORGE_QF_ALPHA'},
    {filename=root..'/file_two.txt',lnum=2,col=1,text='FORGE_QF_OMEGA'}})]],{e.project})
  focus(e,' xx','trouble');local diagnostics=e:lua('return vim.api.nvim_get_current_buf()')
  focus(e,' xQ','trouble');e:wait('native Quickfix view',function() return text(e):find('FORGE_QF_OMEGA',1,true)~=nil end)
  local quickfix=e:lua('return vim.api.nvim_get_current_buf()');assert(quickfix~=diagnostics)
  seek(e,'FORGE_QF_ALPHA');zoom(e);seek(e,'FORGE_QF_OMEGA');capture('quickfix-selected-in-zoom')
  keys(e,'<CR>');e:wait('выбран второй файл',function() return e:current_file():find('file_two.txt',1,true)~=nil and e:lua('return vim.api.nvim_win_get_cursor(0)[1]')==2 end)
  e:lua([[vim.api.nvim_set_current_win(vim.fn.bufwinid(...))]],{quickfix})
  keys(e,'g?');e:wait('native Trouble help',function() return relative(e)=='editor' and e:current_ft()~='forge-panel-help' end)
  keys(e,'q');e:wait('возврат из native help',function() return e:current_ft()=='trouble' end)
  zoom(e);keys(e,'q');T.eq(e:current_ft(),'text')
  assert(e:lua('return vim.fn.bufwinid(...)>0',{diagnostics}),'соседняя Trouble view закрылась')
  T.eq(e:lua('return vim.fn.bufwinid(...)',{quickfix}),-1);T.eq(e:lua('return #vim.fn.getqflist()'),2)
  capture('only-current-trouble-hidden')
end)
check('old Terminal aliases and native input remain available',false,function(e,capture)
  shell(e);normal(e);local before=terminal(e)
  keys(e,string.char(20));e:wait('Ctrl-t скрывает',function() return not e:has_window('toggleterm') end)
  code(e);focus(e,' tt','toggleterm');normal(e);preserved(before,terminal(e))
  keys(e,escape);code(e);capture('old-alias-control')
end)
check('existing Terminal show after native toggle is idempotent',false,function(e,capture)
  shell(e);normal(e);local before=terminal(e);code(e);capture('native-toggle-before-show')
  keys(e,':IdeShow terminal<CR>')
  local windows=terminals(e);T.eq(#windows,1,'Existing show hid visible Terminal')
  preserved(before,windows[1]);capture('native-toggle-after-show')
end)
check('native Trouble help remains a popup',false,function(e,capture)
  e:lua([[local root=...;vim.fn.setqflist({{filename=root..'/file_one.txt',lnum=1,text='FORGE_HELP_ITEM'}})]],{e.project})
  focus(e,' xQ','trouble')
  local source=e:lua('return vim.api.nvim_get_current_win()')
  keys(e,':lua require("trouble").help()<CR>')
  e:wait('native help content',function() return text(e):find('# Help',1,true)~=nil end)
  local deadline=vim.uv.hrtime()+300000000
  repeat
    T.eq(relative(e),'editor','Native Trouble help was docked')
    vim.wait(25)
  until vim.uv.hrtime()>=deadline
  capture('native-help-popup');keys(e,'q');T.eq(e:lua('return vim.api.nvim_get_current_win()'),source)
end)
T.finish()
