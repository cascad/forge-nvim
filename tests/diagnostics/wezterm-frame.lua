-- IDE-PANEL-20: WezTerm + native remote TUI. CLI ввод, не физические keys.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local e,report,pane,verified
local wezterm=vim.fn.exepath('wezterm')
local function cli(args,input)
  local command={wezterm,'cli','--no-auto-start'};vim.list_extend(command,args)
  local r=vim.system(command,{text=true,stdin=input,timeout=5000}):wait()
  assert(r.code==0,(r.stdout or '')..(r.stderr or ''));return r.stdout
end
local function panes() return vim.json.decode(cli({'list','--format','json'})) end
local function own_pane()
  for _,p in ipairs(panes()) do if p.pane_id==pane then return p end end
end
local function send(text)
  assert(verified and pane,'Private pane not verified')
  cli({'send-text','--no-paste','--pane-id',tostring(pane)},text)
end
local function content() return cli({'get-text','--pane-id',tostring(pane)}) end
local function capture(label)
  local text=content();local styled=cli({'get-text','--pane-id',tostring(pane),'--escapes'})
  vim.fn.writefile(vim.split(text,'\n'),e.dir..'/wezterm-'..label..'.txt')
  vim.fn.writefile(vim.split(styled,'\n'),e.dir..'/wezterm-'..label..'.ansi')
  for _,corner in ipairs({'╭','╮','╰','╯'}) do assert(text:find(corner,1,true),'native border '..corner..' missing') end
  assert(styled:find('\27[',1,true),'native attributes missing')
  report.states[#report.states+1]={label=label,pilot=e:lua("return require('forge.frame_pilot').status()"),
    size=e:lua('return {columns=vim.o.columns,lines=vim.o.lines}'),bytes=#text,styled_bytes=#styled}
end
T.check('IDE-PANEL-20 actual WezTerm frontend receives Locals frame and CLI input',function()
  local ok,err=xpcall(function()
    assert(vim.fn.has('win32')==1,'Windows diagnostic; Mac отдельно')
    assert(wezterm~='' and vim.fn.exepath('node')~='','Нужны установленные WezTerm и Node')
    assert(vim.env.WEZTERM_UNIX_SOCKET and vim.env.WEZTERM_UNIX_SOCKET~='',
      'Запустите из существующего WezTerm: адрес mux обязателен, GUI автоматически не запускается')
    local existing={};for _,p in ipairs(panes()) do existing[p.pane_id]=true end
    local tools=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
    e=require('editor').start(root,{timeout=180000,env={PATH=tools..'/bin;'..tools..'/go/bin;'..vim.env.PATH,
      GOTOOLCHAIN='local',GOENV='off',GOPROXY='off',GOMAXPROCS='2',GOFLAGS='-p=2',GOCACHE=require('go_cache').path(root)},
      prepare=function(project)
        for _,name in ipairs({'main.go','go.mod'}) do assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/frame-layout/'..name,project..'/'..name)) end
        vim.fn.mkdir(project..'/.vscode','p')
        vim.fn.writefile({vim.json.encode({version='0.2.0',configurations={{name='WezTerm frame',type='go',request='launch',
          mode='debug',program=project,cwd=project,outputMode='remote',args={}}}})},project..'/.vscode/launch.json')
      end})
    report={states={},physical_keys=false}
    assert(vim.uv.fs_copyfile(root..'/tests/diagnostics/wezterm-frame.lua',e.dir..'/wezterm-frame.lua'))
    e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
    e:input(':edit main.go<CR>');e:wait('Go source',function() if e:ack_warning('gopls не найден в PATH') then return false end;return e:current_ft()=='go' end)
    local breakpoint
    for i,line in ipairs(vim.fn.readfile(e.project..'/main.go')) do if line:find('FRAME_FIRST',1,true) then breakpoint=i end end
    e:input(breakpoint..'G<F9><F5>')
    e:wait('launch choice ready',function() return e:current_ft()=='TelescopePrompt'
      and e:lua("return require('telescope.actions.state').get_selected_entry()~=nil") end)
    e:input('<CR>');e:wait('real DAP pause',function()
      return e:lua([[local s=require('dap').session();return s and s.stopped_thread_id and s.current_frame and s.current_frame.line==... or false]],{breakpoint})
    end,120000)
    local address=e:lua('return vim.fn.serverstart()');assert(type(address)=='string' and address~='')
    local private=e:lua([[local r={};for _,k in ipairs({'HOME','USERPROFILE','APPDATA','LOCALAPPDATA','TEMP','TMP','TMPDIR',
      'XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME','NVIM_LOG_FILE'}) do r[k]=vim.env[k] end;return r]])
    private.NVIM_LOG_FILE=e.dir..'/remote-ui.log'
    local cfg={exe=vim.v.progpath,args={'--clean','-i','NONE','--server',address,'--remote-ui'},env=private,
      metadata=e.dir..'/frontend-pids.json',exit=e.dir..'/frontend-exit.json'}
    vim.fn.writefile({vim.json.encode(cfg)},e.dir..'/frontend.json')
    local bridge=e.dir..'/frontend.cjs'
    vim.fn.writefile({
      "const fs=require('node:fs'),cp=require('node:child_process');",
      "const c=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));",
      "const child=cp.spawn(c.exe,c.args,{stdio:'inherit',env:{...process.env,...c.env},windowsHide:true});",
      "fs.writeFileSync(c.metadata,JSON.stringify({pid:process.pid,client:child.pid,pane:process.env.WEZTERM_PANE}));",
      "child.on('error',e=>{fs.writeFileSync(c.exit,JSON.stringify({error:String(e)}));process.exit(1)});",
      "child.on('exit',(code,signal)=>{fs.writeFileSync(c.exit,JSON.stringify({code,signal}));process.exit(code??1)});",
    },bridge)
    pane=tonumber(cli({'spawn','--new-window','--cwd',e.project,'--',vim.fn.exepath('node'),bridge,e.dir..'/frontend.json'}))
    assert(pane and not existing[pane],'spawn did not return a new pane id')
    local unique=e.project:gsub('\\','/'):match('([^/]+/project)$'):lower()
    e:wait('new private pane and two UIs',function()
      local p=own_pane();if not p then return false end
      if not tostring(p.cwd):gsub('\\','/'):lower():find(unique,1,true) then return false end
      if e:lua('return #vim.api.nvim_list_uis()')~=2 then return false end
      report.pane=p;verified=true;return true
    end,15000)
    send(' wd');e:wait('native Locals focus',function() return e:current_ft()=='dapui_scopes' end)
    send('gg/item\r\r');e:wait('native Value42',function() return content():find('Value int = 42',1,true) end)
    send(':ForgeFramePilot\r');e:wait('pilot in actual terminal',function()
      local text=content();return e:lua("return require('forge.frame_pilot').active()") and text:find('Locals [focus]',1,true) and text:find('Code',1,true)
    end)
    capture('locals');send(' wl');e:wait('native code focus',function() return e:current_ft()=='go' end)
    send('\27[21~');e:wait('native VT F10 step',function()
      return e:lua([[local s=require('dap').session();return s and s.current_frame and s.current_frame.line==...]],{breakpoint+1})
    end,30000)
    send(' wd');e:wait('native Value43',function() return content():find('Value int = 43',1,true) end)
    capture('stepped');send('?');e:wait('native help',function() return e:current_ft()=='forge-panel-help' end)
    send('q');e:wait('native help returns',function() return e:current_ft()=='dapui_scopes' end)
    send(' wz');e:wait('native zoom',function() return e:lua("return require('forge.frame_pilot').status().zoom") end)
    capture('zoom');send('\27');e:wait('native restore zoom',function() return not e:lua("return require('forge.frame_pilot').status().zoom") end)
    send(':ForgeFramePilot\r');e:wait('native layout restored',function() return not e:lua("return require('forge.frame_pilot').active()") end)
    T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
  end,debug.traceback)
  if e then
    pcall(e.lua,e,[[local d=package.loaded.dap;if d and d.session() then d.terminate() end]])
    report=report or {};e:snapshot('wezterm-frame')
    local stopped,issue=pcall(e.stop,e,not ok and err or nil)
    if not stopped then ok=false;err=tostring(err or '')..'\nEditor cleanup: '..tostring(issue) end
    local exit_file=e.dir..'/frontend-exit.json'
    if pane then
      vim.wait(8000,function() return vim.fn.filereadable(exit_file)==1 end,25)
      local has,p=pcall(own_pane)
      if has and p then cli({'kill-pane','--pane-id',tostring(pane)}) end
      if vim.fn.filereadable(exit_file)==1 then
        report.frontend=vim.json.decode(table.concat(vim.fn.readfile(exit_file),'\n'))
        if report.frontend.code~=0 then ok=false;err=tostring(err or '')..'\nNative frontend did not exit cleanly' end
      else ok=false;err=tostring(err or '')..'\nNative frontend exit missing' end
      if vim.fn.filereadable(e.dir..'/frontend-pids.json')==1 then
        report.pids=vim.json.decode(table.concat(vim.fn.readfile(e.dir..'/frontend-pids.json'),'\n'))
        local gone=vim.wait(2000,function()
          return not vim.uv.kill(report.pids.pid,0) and not vim.uv.kill(report.pids.client,0)
        end,25)
        if not gone then ok=false;err=tostring(err or '')..'\nOwned frontend PID still alive' end
      end
    end
    if e.rpc.exit_code~=0 or e.rpc.exit_signal~=0 or #e.rpc.api_errors~=0 then ok=false;err=tostring(err or '')..'\nNative editor exit/API failure' end
    report.ok=ok;report.error=not ok and tostring(err) or nil
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/wezterm-frame.json');io.stdout:write('  artifacts: '..e.dir..'\n')
  end
  assert(ok,err)
end)
T.finish()
