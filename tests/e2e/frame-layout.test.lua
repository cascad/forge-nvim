-- spec: IDE-PANEL-20. Реальные UI/Delve/native controls, без тестовых замен действий.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local e,report
local function lua(code,args) return e:lua(code,args) end
local function text(ft)
  return lua([[for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype==... then return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n') end end;return '']],{ft})
end
local function keys(k)
  vim.fn.writefile({k},e.dir..'/input.txt','a')
  local n=lua('return _G.frame_keys');e:input(k..'<F35>')
  e:wait('input consumed',function() return lua('return _G.frame_keys')>n end)
end
local function paused(line)
  return lua([[local s=require('dap').session();return s and s.stopped_thread_id and s.current_frame and s.current_frame.line==... or false]],{line})
end
local function checkpoint(label)
  local capture=e.rpc.ui_capture;local before=capture.flushes
  local state=lua([[vim.cmd('redraw!');local result={current=vim.api.nvim_get_current_win(),windows={}}
    for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do local b=vim.api.nvim_win_get_buf(w)
      result.windows[#result.windows+1]={win=w,buf=b,ft=vim.bo[b].filetype,config=vim.api.nvim_win_get_config(w),
        width=vim.api.nvim_win_get_width(w),height=vim.api.nvim_win_get_height(w),position=vim.api.nvim_win_get_position(w)} end
    result.pilot=require('forge.frame_pilot').status()
    result.accent=vim.api.nvim_get_hl(0,{name='DiagnosticInfo',link=false}).fg
    result.dim=vim.api.nvim_get_hl(0,{name='Comment',link=false}).fg;return result]])
  e:wait('native UI flush',function() return capture.flushes>before end)
  capture:checkpoint(label,state);state.label=label;report.states[#report.states+1]=state
  return state
end
T.check('IDE-PANEL-20 working bordered Locals step, focus, resize and restore',function()
  local ok,err=xpcall(function()
    local tools=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
    local sep=vim.fn.has('win32')==1 and ';' or ':'
    e=require('editor').start(root,{capture_ui=true,timeout=180000,
      env={PATH=tools..'/bin'..sep..tools..'/go/bin'..sep..vim.env.PATH,GOTOOLCHAIN='local',GOPROXY='off',GOENV='off',
        GOMAXPROCS='2',GOFLAGS='-p=2',GOCACHE=require('go_cache').path(root)},
      prepare=function(project)
        for _,f in ipairs({'main.go','go.mod'}) do assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/frame-layout/'..f,project..'/'..f)) end
        vim.fn.mkdir(project..'/.vscode','p')
        vim.fn.writefile({vim.json.encode({version='0.2.0',configurations={{name='Live frames',type='go',request='launch',mode='debug',program=project,cwd=project,outputMode='remote',args={}}}})},project..'/.vscode/launch.json')
      end})
    report={states={}}
    e:wait('config ready',function() return lua('return _G.forge_e2e_observed') end,10000)
    T.eq(lua("return vim.fn.exists(':ForgeFramePilot')"),2,'explicit pilot command missing')
    lua([[_G.frame_keys=0;vim.keymap.set({'n','t'},'<F35>',function() _G.frame_keys=_G.frame_keys+1 end)]])
    e:input(':edit main.go<CR>');e:wait('Go source',function() if e:ack_warning('gopls не найден в PATH') then return false end;return e:current_ft()=='go' end)
    keys(':ForgeFramePilot<CR>');T.eq(lua("return require('forge.frame_pilot').active()"),false)
    local lines={};for i,line in ipairs(vim.fn.readfile(e.project..'/main.go')) do
      if line:find('FRAME_FIRST',1,true) then lines.first=i end;if line:find('FRAME_SECOND',1,true) then lines.second=i end end
    keys(lines.first..'G<F9>');keys(lines.second..'G<F9>');keys('<F5>')
    e:wait('launch picker selected entry ready',function()
      return e:current_ft()=='TelescopePrompt' and lua([[local state=require('telescope.actions.state');return state.get_selected_entry()~=nil]])
    end);e:input('<CR>')
    e:wait('first breakpoint',function() return paused(lines.first) end,120000)
    keys(' wd');e:wait('native Locals',function() return e:current_ft()=='dapui_scopes' end)
    keys('gg/item<CR><CR>');e:wait('Value42',function() return text('dapui_scopes'):find('Value',1,true) and text('dapui_scopes'):find('42',1,true) end)
    local scopes=lua('return vim.api.nvim_get_current_buf()')
    keys(':ForgeFramePilot<CR>');e:wait('pilot active',function() return lua("return require('forge.frame_pilot').active()") end)
    local initial=checkpoint('pilot-locals');local win=initial.current
    local same=lua("return require('forge.frame_pilot').status().layouts")
    vim.wait(400)
    T.eq(lua("return require('forge.frame_pilot').status().layouts"),same,'idle layout loop')
    report.idle_ms=400
    T.eq(lua('return vim.api.nvim_get_current_buf()'),scopes,'native buffer changed')
    T.eq(lua([[local n=0;for _,w in ipairs(vim.fn.win_findbuf(...)) do n=n+1 end;return n]],{scopes}),1,'shadow source window')
    keys(' wl');T.eq(e:current_ft(),'go');keys(' wh');T.eq(e:current_ft(),'dapui_scopes')
    keys('?');T.eq(e:current_ft(),'forge-panel-help');checkpoint('pilot-help');keys('q');T.eq(lua('return vim.api.nvim_get_current_win()'),win)
    keys(' wz');T.eq(lua('return vim.api.nvim_get_current_win()'),win);checkpoint('pilot-zoom');keys('<Esc>');T.eq(lua('return vim.api.nvim_get_current_win()'),win)
    keys('q');T.eq(e:current_ft(),'go');T.eq(e:has_window('dapui_scopes'),false)
    keys(' wd');T.eq(e:current_ft(),'dapui_scopes');T.eq(lua('return vim.api.nvim_get_current_buf()'),scopes)
    keys(' w0');keys('<F10>');e:wait('step line',function() return paused(lines.first+1) end,30000)
    keys(' wd');e:wait('native live Value43',function() return text('dapui_scopes'):find('43',1,true)~=nil end)
    checkpoint('pilot-stepped');keys(' w0');keys('<F5>');e:wait('second breakpoint',function() return paused(lines.second) end,30000)
    T.eq(lua('return vim.api.nvim_win_get_cursor(0)[1]'),lines.second,'native breakpoint did not select Code')
    keys(' wc');e:wait('Output focus',function() return e:current_ft()=='dap-repl' end);assert(text('dap-repl'):find('FRAME_MIDDLE 43',1,true))
    keys(' wk');assert(e:current_ft()=='go' or e:current_ft()=='dapui_scopes');keys(' w0')
    keys(' wj');T.eq(e:current_ft(),'dap-repl');keys(' w0')
    e.rpc:request('nvim_ui_try_resize',{100,35});e:wait('resize applied',function() return lua('return vim.o.columns')==100 end);checkpoint('pilot-resized')
    keys(':ForgeFramePilot<CR>');T.eq(lua("return require('forge.frame_pilot').active()"),false)
    T.eq(lua("return vim.api.nvim_win_get_config(0).relative"),'');T.eq(e:current_ft(),'go')
    -- Native layout open не должен оставить второй Locals рядом с пилотом.
    keys(' wd');keys(':ForgeFramePilot<CR>');keys(':lua require("dapui").open({layout=1})<CR>')
    e:wait('native open leaves pilot',function() return not lua("return require('forge.frame_pilot').active()") end)
    T.eq(lua([[local n=0;for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do if vim.bo[vim.api.nvim_win_get_buf(w)].filetype=='dapui_scopes' then n=n+1 end end;return n]]),1)
    keys(' w0');keys(':ForgeFramePilot<CR>');e.rpc:request('nvim_ui_try_resize',{60,22})
    e:wait('small size restores',function() return not lua("return require('forge.frame_pilot').active()") end)
    e.rpc:request('nvim_ui_try_resize',{140,45});e:wait('full size',function() return lua('return vim.o.columns')==140 end)
    keys(' w0');keys(':ForgeFramePilot<CR>');keys(' w0')
    keys(':ASToggle<CR>');e:wait('autosave explicitly off',function() return lua("return not require('auto-save').enabled()") end)
    keys('Go// unsaved pilot edit<Esc>')
    keys(':ForgeFramePilot<CR>');T.eq(lua('return vim.bo.modified'),true)
    assert(lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]]):find('// unsaved pilot edit',1,true))
    keys(' wd');keys(':ForgeFramePilot<CR>');keys(' w0');keys(':tabnew<CR>')
    e:wait('tab exit',function() return not lua("return require('forge.frame_pilot').active()") end)
    keys(':tabclose<CR>');keys(' w0');keys(':ForgeFramePilot<CR>')
    -- Настоящий session workflow, включая существующий cleanup callback.
    report.sessions={}
    for attempt=1,8 do
      if attempt>1 then keys(':ForgeFramePilot<CR>') end
      T.eq(lua("return require('forge.frame_pilot').active()"),true,'save cycle did not enter pilot')
      local state=lua([[require('persistence').fire('SavePre');require('persistence').save()
        local result={session=table.concat(vim.fn.readfile(require('persistence').current()),'\n'),buffers={}}
        for _,b in ipairs(vim.api.nvim_list_bufs()) do result.buffers[#result.buffers+1]={buf=b,ft=vim.bo[b].filetype,
          bt=vim.bo[b].buftype,listed=vim.bo[b].buflisted} end;return result]])
      report.sessions[#report.sessions+1]=state
      vim.fn.writefile({vim.json.encode(report.sessions)},e.dir..'/session-states.json')
      T.eq(lua("return require('forge.frame_pilot').active()"),false)
      T.eq(lua([[return vim.fn.exists('#ForgeFramePilot')]]),0)
      vim.fn.writefile(vim.split(state.session,'\n'),e.dir..'/saved-session-'..attempt..'.vim')
      for _,b in ipairs(state.buffers) do
        assert(b.ft~='forge-frame-root' and not b.ft:match('^dapui_'),'tool buffer survived session cleanup attempt '..attempt)
      end
      -- mksession сохраняет также вычисленный statusline, где может остаться
      -- имя прежней панели. Проверяем реальный ft/layout, а не любое упоминание.
      for line in state.session:gmatch('[^\n]+') do
        assert(not line:match('^setlocal filetype=dapui_') and not line:match('^setlocal filetype=forge%-frame%-root'),'tool layout in saved session')
      end
    end
    keys(':write<CR>');e:wait('explicit source save',function() return not lua('return vim.bo.modified') end)
    lua([[vim.cmd('source '..vim.fn.fnameescape(require('persistence').current()))]])
    T.eq(e:current_ft(),'go')
    T.eq(lua([[local n=0;for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local ft=vim.bo[vim.api.nvim_win_get_buf(w)].filetype
      assert(ft~='forge-frame-root' and not ft:match('^dapui_'));if require('ide.state').is_main_window(w) then n=n+1 end end;return n]]),1)
    keys(' w0');keys('<F5>');e:wait('session complete',function() return lua("return require('dap').session()==nil") end,30000)
    e:wait('stdout preserved',function() return text('dap-repl'):find('FRAME_AFTER 50',1,true)~=nil end)
    report.stdout=text('dap-repl');T.eq(lua('return vim.g.forge_e2e_installs'),0)
    local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3')
    local converted=vim.system({python,'-B',root..'/tests/diagnostics/render-ui.py',e.rpc.ui_capture.path,'--output',e.dir..'/ui'},{text=true,timeout=20000}):wait()
    T.eq(converted.code,0,(converted.stdout or '')..(converted.stderr or ''))
    local frames=vim.json.decode(table.concat(vim.fn.readfile(e.dir..'/ui/frames.json'),'\n'))
    for _,picture in ipairs(frames) do
      local state=picture.metadata
      for _,w in ipairs(state.windows) do
        if w.win==state.pilot.locals or (w.win==state.pilot.code and picture.label~='pilot-zoom') then
          local expected=w.win==state.current and state.accent or state.dim
          local row,col=w.position[1],w.position[2]
          -- Help частично перекрывает рамки: четыре угла проверяем вне popup.
          if picture.label~='pilot-help' then
            for _,corner in ipairs({{row,col,'╭'},{row,col+w.width+1,'╮'},
              {row+w.height+1,col,'╰'},{row+w.height+1,col+w.width+1,'╯'}}) do
              local cell=picture.cells[corner[1]+1][corner[2]+1]
              T.eq(cell[1],corner[3],picture.label..' native corner')
              T.eq(picture.highlights[tostring(cell[2])].foreground,expected,picture.label..' RGB focus')
            end
          end
        end
      end
    end
    for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
  end,debug.traceback)
  if e then
    report=report or {};report.ok=ok;report.error=not ok and tostring(err) or nil
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/frame-layout.json')
    if not ok then pcall(e.lua,e,[[local f=package.loaded['forge.frame_pilot'];if f then f.stop() end;local d=package.loaded.dap;if d and d.session() then d.terminate() end]]) end
    e:snapshot('frame-layout');io.stdout:write('  artifacts: '..e.dir..'\n')
    local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
    if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
    local exited,exit_error=pcall(function()
      if e.rpc.shutdown_result then T.eq(e.rpc.exit_code,0);T.eq(e.rpc.exit_signal,0);T.eq(e.rpc.api_errors,{});assert(e.rpc.shutdown_result.ok,vim.inspect(e.rpc.shutdown_result)) end
    end)
    if not exited then ok=false;err=tostring(err or '')..'\nNative cleanup: '..tostring(exit_error) end
    report.ok=ok;report.error=not ok and tostring(err) or nil
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/frame-layout.json')
  end
  assert(ok,err)
end)
T.finish()
