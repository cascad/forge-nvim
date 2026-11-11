-- IDE-076: opt-in prototype, реальные Go/Delve/Locals и native RGB grid.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local e,identity,report
local function text(kind)
  return e:lua([[local kind=...;for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].filetype==kind then return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n') end end;return '']],{kind})
end
local function session()
  return e:lua([[local s=require('dap').session();return s and {id=s.id,thread=s.stopped_thread_id,frame=s.current_frame and s.current_frame.id} or false]])
end
local function keys(value)
  local before=e:lua('return _G.frame_keys')
  e:input(value..'<F35>');e:wait('native input consumed',function() return e:lua('return _G.frame_keys')>before end)
end
local function frame()
  return e:lua([[for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].filetype=='dapui_scopes' and vim.api.nvim_win_get_config(w).relative=='editor' then return w end end;return false]])
end
local function checkpoint(label)
  local capture=e.rpc.ui_capture;assert(capture and not capture.error,capture and capture.error)
  local previous=capture.flushes
  local metadata=e:lua([[vim.cmd('redraw!');local windows={}
    for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local info=vim.fn.getwininfo(w)[1];local b=vim.api.nvim_win_get_buf(w)
      windows[#windows+1]={win=w,buf=b,ft=vim.bo[b].filetype,config=vim.api.nvim_win_get_config(w),
        width=vim.api.nvim_win_get_width(w),height=vim.api.nvim_win_get_height(w),
        position=vim.api.nvim_win_get_position(w),winbar=vim.wo[w].winbar,textoff=info.textoff,
        text=table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n')}
    end
    return {windows=windows,current=vim.api.nvim_get_current_win(),mode=vim.api.nvim_get_mode(),
      accent=vim.api.nvim_get_hl(0,{name='ForgeFramePreviewAccent',link=false,create=false}).fg,
      dim=vim.api.nvim_get_hl(0,{name='ForgeFramePreviewDim',link=false,create=false}).fg} ]])
  e:wait('actual native redraw flush',function() return capture.flushes>previous end)
  capture:checkpoint(label,metadata);assert(not capture.error,capture.error)
  metadata.label=label;report.states[#report.states+1]=metadata
  vim.fn.writefile({vim.json.encode(report)},e.dir..'/panel-frame.json')
  T.eq(session(),identity,'prototype changed DAP pause')
end
T.check('SELF: PANEL-FRAME native full border preserves paused Locals and restores',function()
  local ok,err=xpcall(function()
    local tools=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
    local sep=vim.fn.has('win32')==1 and ';' or ':'
    e=require('editor').start(root,{capture_ui=true,timeout=240000,
      env={PATH=tools..'/bin'..sep..tools..'/go/bin'..sep..vim.env.PATH,GOTOOLCHAIN='local',GOPROXY='off',GOENV='off',
        GOMAXPROCS='2',GOFLAGS='-p=2',GOCACHE=require('go_cache').path(root)},
      prepare=function(project)
        for _,file in ipairs({'main.go','go.mod'}) do assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/debug-panels/'..file,project..'/'..file)) end
        vim.fn.mkdir(project..'/.vscode','p')
        vim.fn.writefile({vim.json.encode({version='0.2.0',configurations={{name='Frame preview',type='go',request='launch',mode='debug',
          program=project,cwd=project,outputMode='remote',args={}}}})},project..'/.vscode/launch.json')
      end})
    report={states={}}
    e:wait('real config ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
    e:lua([[_G.frame_keys=0;vim.keymap.set({'n','t'},'<F35>',function() _G.frame_keys=_G.frame_keys+1 end)]])
    for _,file in ipairs({'tests/e2e/panel-frame.test.lua','tests/diagnostics/panel-frame-preview.lua','tests/diagnostics/render-ui.py','tests/lib/ui_grid.py'}) do
      assert(vim.uv.fs_copyfile(root..'/'..file,e.dir..'/'..vim.fn.fnamemodify(file,':t')))
    end
    e:input(':edit main.go<CR>');e:wait('Go source',function()
      -- LSP не нужен этому DAP-прототипу; принимается только известный WARN.
      if e:ack_warning('gopls не найден в PATH') then return false end
      return e:current_ft()=='go'
    end)
    local breakpoint
    for i,line in ipairs(vim.fn.readfile(e.project..'/main.go')) do if line:find('E2E_BREAKPOINT',1,true) then breakpoint=i end end
    e:input(breakpoint..'G<F9><F5>')
    e:wait('real launch picker',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
    e:input('<CR>')
    e:wait('real breakpoint',function() return e:lua([[local s=require('dap').session();return s~=nil and s.stopped_thread_id~=nil and s.current_frame~=nil]]) end,120000)
    identity=session();e:wait('real stdout',function() return text('dap-repl'):find('PANEL_BEFORE 42',1,true)~=nil end)
    keys(' wd');e:wait('Locals focus',function() return e:current_ft()=='dapui_scopes' end)
    e:input('gg/item<CR><CR>')
    e:wait('actual item Value42',function() return text('dapui_scopes'):find('Value',1,true) and text('dapui_scopes'):find('42',1,true) end)
    checkpoint('baseline-split')
    local source=e:lua([[return {width=vim.api.nvim_win_get_width(0),height=vim.api.nvim_win_get_height(0),position=vim.api.nvim_win_get_position(0)}]])
    keys(' wz');e:wait('existing native zoom',function() return frame()~=false end)
    local full=e:lua('return vim.api.nvim_win_get_config(0)')
    checkpoint('baseline-zoom')
    e:lua([[_G.frame_original_refresh=require('ide.controls').refresh;_G.frame_preview=dofile(...);_G.frame_preview.start()]],{root..'/tests/diagnostics/panel-frame-preview.lua'})
    if vim.env.FORGE_FRAME_TRACE=='1' then
      e:lua([[_G.frame_restore_calls={};local c=require('ide.controls');local original=c.restore;c.restore=function(...)
        _G.frame_restore_calls[#_G.frame_restore_calls+1]={args={...},current=vim.api.nvim_get_current_win(),ft=vim.bo.filetype,stack=debug.traceback()}
        return original(...) end]])
    end
    e:wait('prototype border title',function() return e:lua([[local c=vim.api.nvim_win_get_config(0);return vim.wo.winbar=='' and c.title[1][1]:find('Locals',1,true)~=nil]]) end)
    checkpoint('frame-active')
    -- Компактный образец помещается поверх исходного slot; это preview float.
    e:lua([[local s=...;vim.api.nvim_win_set_config(0,{relative='editor',row=s.position[1],col=s.position[2],
      width=math.max(1,s.width-1),height=math.max(1,s.height-1)})]],{source})
    checkpoint('frame-compact')
    keys('?');e:wait('real common help focus',function() return e:current_ft()=='forge-panel-help' end)
    checkpoint('frame-inactive-help')
    if vim.env.FORGE_FRAME_TRACE=='1' then
      report.restore_calls=e:lua('return _G.frame_restore_calls');vim.fn.writefile({vim.json.encode(report)},e.dir..'/panel-frame.json')
    end
    assert(frame(),'common zoom disappeared on help focus')
    keys('q');e:wait('zoom refocused',function() return e:current_ft()=='dapui_scopes' and frame()~=false end)
    checkpoint('frame-refocused')
    e:lua([[local c=...;vim.api.nvim_win_set_config(0,{relative='editor',row=c.row,col=c.col,width=c.width,height=c.height})]],{full})
    e.rpc:request('nvim_ui_try_resize',{100,35});checkpoint('frame-resized')
    keys('<Esc>');e:wait('source restored',function() return e:current_ft()=='dapui_scopes' and not frame() end)
    checkpoint('frame-restored')
    e:lua([[_G.frame_preview.stop();assert(require('ide.controls').refresh==_G.frame_original_refresh);assert(not _G.frame_preview.active())]])
    checkpoint('preview-stopped')
    keys(' w0');e:wait('code focus',function() return e:current_ft()=='go' end)
    e:input('<F5>');e:wait('explicit Continue complete',function() return session()==false end,30000)
    e:wait('real stdout after Continue',function() return text('dap-repl'):find('PANEL_AFTER',1,true)~=nil end)
    report.after_stdout=text('dap-repl');T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3');assert(python~='')
    local converted=vim.system({python,'-B',root..'/tests/diagnostics/render-ui.py',e.rpc.ui_capture.path,'--output',e.dir..'/ui'},
      {text=true,timeout=20000}):wait();T.eq(converted.code,0,(converted.stdout or '')..(converted.stderr or ''))
    local frames=vim.json.decode(table.concat(vim.fn.readfile(e.dir..'/ui/frames.json'),'\n'));T.eq(#frames,9)
    for _,picture in ipairs(frames) do
      if picture.label=='frame-active' or picture.label=='frame-compact' or picture.label=='frame-inactive-help' or picture.label=='frame-refocused' or picture.label=='frame-resized' then
        local expected=picture.label=='frame-inactive-help' and picture.metadata.dim or picture.metadata.accent
        assert(expected and picture.metadata.accent~=picture.metadata.dim)
        local corners={};for row,cells in ipairs(picture.cells) do for col,cell in ipairs(cells) do
          if cell[1]=='╭' or cell[1]=='╮' or cell[1]=='╯' or cell[1]=='╰' then
            local style=picture.highlights[tostring(cell[2])]
            if style.foreground==expected then corners[cell[1]]={row,col} end
          end
        end end
        assert(corners['╭'] and corners['╮'] and corners['╯'] and corners['╰'],'actual four RGB border corners missing: '..picture.label)
        T.eq(corners['╭'][1],corners['╮'][1]);T.eq(corners['╰'][1],corners['╯'][1])
        T.eq(corners['╭'][2],corners['╰'][2]);T.eq(corners['╮'][2],corners['╯'][2])
      end
    end
    for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
  end,debug.traceback)
  if e then
    report=report or {};report.ok=ok;report.error=not ok and tostring(err) or nil
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/panel-frame.json')
    if not ok then pcall(e.lua,e,[[if _G.frame_preview then _G.frame_preview.stop() end;local d=package.loaded.dap;if d and d.session() then d.terminate() end]]) end
    e:snapshot('panel-frame');io.stdout:write('  artifacts: '..e.dir..'\n')
    local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
    if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
    local exited,exit_error=pcall(function()
      if e.rpc.shutdown_result then T.eq(e.rpc.exit_code,0);T.eq(e.rpc.exit_signal,0);T.eq(e.rpc.api_errors,{})
        assert(e.rpc.shutdown_result.ok,vim.inspect(e.rpc.shutdown_result)) end
    end)
    if not exited then ok=false;err=(err and tostring(err)..'\n' or '')..'Native cleanup: '..tostring(exit_error) end
    report.ok=ok;report.error=not ok and tostring(err) or nil
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/panel-frame.json')
  end
  assert(ok,err)
end)
T.finish()
