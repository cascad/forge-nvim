-- IDE-DAP-1: native Go.work, два модуля, edit dependency и повтор F5.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local P=require('output_policy')
T.check('IDE-DAP-1 Go.work запускает пакет и пересобирает соседний модуль после edit',function()
  local e,report
  local ok,err=xpcall(function()
    local tools=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
    local lsp=vim.env.FORGE_E2E_LSP_DEPS or root..'/.tests/lsp-deps'
    local sep=vim.fn.has('win32')==1 and ';' or ':'
    local path=tools..'/bin'..sep..tools..'/go/bin'..sep..lsp..'/bin'..sep..lsp..'/format-bin'..sep..vim.env.PATH
    e=require('editor').start(root,{timeout=240000,env={PATH=path,GOTOOLCHAIN='local',GOENV='off',
      GOWORK='',GOPROXY='off',GOSUMDB='off',GOTELEMETRY='off',CGO_ENABLED='0',GOMAXPROCS='2',
      GOFLAGS='-p=2',GOCACHE=require('go_cache').path(root),FORGE_DLV_PATH='',DLV_PATH=''},
      prepare=function(project,env,runtime)
        env.GOPATH=runtime..'/go';env.GOBIN=''
        for _,name in ipairs({'go.work','app/go.mod','app/main.go','shared/go.mod','shared/answer.go'}) do
          vim.fn.mkdir(vim.fs.dirname(project..'/'..name),'p')
          assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/go-workspace/'..name,project..'/'..name))
        end
      end})
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/go-workspace.test.lua',e.dir..'/go-workspace.test.lua'))
    report={runs={}}
    local project=e.project:gsub('\\','/')
    local env=e:lua([[local r=vim.system({'go','env','GOWORK'},{text=true}):wait();assert(r.code==0,r.stderr)
      return {work=vim.trim(r.stdout):gsub('\\','/'),cwd=vim.fn.getcwd():gsub('\\','/')} ]])
    T.eq(env.work,project..'/go.work');T.eq(env.cwd,project);report.environment=env
    assert(vim.fn.filereadable(e.project..'/.vscode/launch.json')==0)
    e:input(':edit app/main.go<CR>')
    e:wait('Go main готов',function()
      return not e.rpc:request('nvim_get_mode',{}).blocking and e:current_ft()=='go' and e:current_file():match('/app/main.go$')
    end)
    e:lua([[require('dap').set_log_level('TRACE')]])
    e:input('gg/E2E_BREAKPOINT<CR><F9>')
    local function output() local x=P.state(e,'dap-repl')[1];return x and x.text or '' end
    local function run(value)
      e:input('<F7><F5>')
      e:wait('native Go configuration picker',function()
        if e:current_ft()~='TelescopePrompt' then return false end
        return e:lua([[local v=require('telescope.actions.state').get_selected_entry()
          return v and v.ordinal:find('Current Go package  [go]',1,true)~=nil or false]])
      end)
      e:input('<CR>')
      e:wait('реальный Go breakpoint',function()
        return e:lua([[local s=require('dap').session();return s and s.config.type=='go'
          and s.stopped_thread_id~=nil and s.current_frame~=nil or false]])
      end,90000)
      e:wait('stdout/stderr перед паузой',function()
        return e:has_window('dap-repl') and output():find('WORK_BEFORE '..value,1,true)
          and output():find('WORK_STDERR '..value,1,true)
      end)
      if value==43 then assert(not output():find('WORK_BEFORE 42',1,true),'старый stdout во второй сессии') end
      local config=e:lua([[local s=require('dap').session();return {name=s.config.name,
        program=s.config.program:gsub('\\','/'),cwd=s.config.cwd:gsub('\\','/'),frame=s.current_frame.source.path:gsub('\\','/')} ]])
      T.eq(config.name,'Current Go package');T.eq(config.program,project..'/app');T.eq(config.cwd,project)
      T.eq(config.frame,project..'/app/main.go')
      e:lua([[_G.forge_work_value=nil;local s=require('dap').session()
        s:request('evaluate',{expression='value',context='repl',frameId=s.current_frame.id},function(err,body)
          _G.forge_work_value={error=err,body=body} end)]])
      e:wait('Delve evaluate',function() return e:lua('return _G.forge_work_value~=nil') end)
      local evaluated=e:lua('return _G.forge_work_value');assert(not evaluated.error,vim.inspect(evaluated))
      T.eq(evaluated.body.result,tostring(value))
      local at_stop=output()
      e:input('<F7><F5>')
      e:wait('exit сохранил Output',function()
        return e:lua([[return require('dap').session()==nil]]) and output():find('WORK_AFTER '..value,1,true)
      end,20000)
      T.eq(e:has_window('dap-repl'),true)
      report.runs[#report.runs+1]={value=value,config=config,evaluated=evaluated,at_stop=at_stop,after=output()}
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/go-workspace.json')
    end
    run(42)
    e:input('<F7>:edit shared/answer.go<CR>')
    e:wait('соседний модуль открыт',function() return e:current_file():match('/shared/answer.go$') end)
    e:input('gg/42<CR>ciw43<Esc>:write<CR>')
    e:wait('изменение зависимости сохранено',function()
      return table.concat(vim.fn.readfile(e.project..'/shared/answer.go'),'\n'):find('return 43',1,true)~=nil
    end)
    e:input(':edit app/main.go<CR>')
    e:wait('main снова открыт',function() return e:current_file():match('/app/main.go$') end)
    run(43)
    T.eq(#report.runs,2)
    T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
  end,debug.traceback)
  if e then
    report=report or {};report.ok=ok;report.error=not ok and err or nil
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/go-workspace.json')
    pcall(function()
      local log=e:lua([[return require('dap.log').create_logger('dap.log'):get_path()]])
      if vim.fn.filereadable(log)==1 then assert(vim.uv.fs_copyfile(log,e.dir..'/dap.log')) end
    end)
    local snapped,why=pcall(e.snapshot,e,'go-workspace')
    if not snapped then ok=false;err=tostring(err or '')..'\nSnapshot: '..tostring(why) end
    io.stdout:write('  artifacts: '..e.dir..'\n')
    local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
    if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
  end
  assert(ok,err)
end)
T.finish()
