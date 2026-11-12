-- WF-10: native gd/gi/gr между модулями go.work, без подмены LSP ответов.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
T.check('SELF: GO-WORKSPACE-LANGUAGE definition/implementation/references через gopls',function()
  local e,report
  local ok,err=xpcall(function()
    local deps=vim.env.FORGE_E2E_LSP_DEPS or root..'/.tests/lsp-deps'
    local tools=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
    assert(vim.fn.filereadable(deps..'/manifest.json')==1,'подготовь lsp-deps явно')
    local sep=vim.fn.has('win32')==1 and ';' or ':'
    e=require('editor').start(root,{timeout=180000,env={
      PATH=deps..'/bin'..sep..tools..'/go/bin'..sep..vim.env.PATH,
      GOTOOLCHAIN='local',GOENV='off',GOWORK='',GOPROXY='off',GOSUMDB='off',
      GOTELEMETRY='off',CGO_ENABLED='0',GOMAXPROCS='2',GOFLAGS='-p=2',
      GOCACHE=require('go_cache').path(root)},prepare=function(project,env,runtime)
        env.GOPATH=runtime..'/go';env.GOBIN=''
        for _,name in ipairs({'go.work','app/go.mod','app/main.go','app/navigation.go',
            'shared/go.mod','shared/answer.go','shared/navigation.go'}) do
          vim.fn.mkdir(vim.fs.dirname(project..'/'..name),'p')
          assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/go-workspace/'..name,project..'/'..name))
        end
      end})
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/go-workspace-language.test.lua',e.dir..'/go-workspace-language.test.lua'))
    report={targets={}}
    e:lua([[vim.lsp.log.set_level('debug');_G.forge_work_requests={}
      vim.api.nvim_create_autocmd('LspRequest',{callback=function(ev)
        local r=ev.data.request;table.insert(_G.forge_work_requests,
          {method=r.method,type=r.type,client=ev.data.client_id}) end})]])
    local function state()
      return e:lua([[local clients={};for _,c in ipairs(vim.lsp.get_clients({name='gopls'})) do
        clients[#clients+1]={id=c.id,root=c.root_dir:gsub('\\','/'),cmd=c.config.cmd,
          initialized=c.initialized,attached=c.attached_buffers[vim.api.nvim_get_current_buf()]==true}
        end;return {file=vim.api.nvim_buf_get_name(0):gsub('\\','/'),line=vim.api.nvim_get_current_line(),
          cursor=vim.api.nvim_win_get_cursor(0),word=vim.fn.expand('<cword>'),clients=clients,
          cwd=vim.fn.getcwd():gsub('\\','/'),requests=_G.forge_work_requests,
          installs=vim.g.forge_e2e_installs,mode=vim.api.nvim_get_mode()}]])
    end
    local client
    local function capture(label)
      local s=state();T.eq(#s.clients,1);T.eq(s.clients[1].id,client)
      T.eq(s.clients[1].root,e.project:gsub('\\','/'));T.eq(s.cwd,e.project:gsub('\\','/'))
      T.eq(s.clients[1].attached,true);T.eq(s.installs,0);assert(not s.mode.blocking)
      report.targets[label]=s
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/go-workspace-language.json')
      return s
    end
    local function open(file)
      e:input(':edit '..file..'<CR>')
      e:wait('Go файл и настоящий gopls '..file,function()
        local s=state()
        return s.file:sub(-#file)==file and #s.clients==1
          and s.clients[1].initialized and s.clients[1].attached
          and e:lua([[return vim.fn.maparg('gi','n',false,true).buffer==1]])
      end,30000)
    end
    local function seek(word)
      e:input('gg/'..word..'<CR>')
      e:wait('курсор на '..word,function() return state().word==word end)
    end
    open('app/main.go');client=state().clients[1].id
    T.eq(e:lua([[for _,b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(b):gsub('\\','/'):find('/shared/',1,true) then return true end end;return false]]),false)
    seek('Answer');e:input('gd')
    e:wait('definition в неоткрытом модуле',function()
      local s=state();return s.file:match('/shared/answer.go$') and s.line:find('func Answer',1,true)
    end,60000)
    capture('definition')
    e:input('<C-o>')
    e:wait('возврат к вызову',function() return state().file:match('/app/main.go$') and state().word=='Answer' end)
    capture('back')
    open('app/navigation.go');seek('Provider');e:input('gi')
    e:wait('implementation интерфейса в shared',function()
      local s=state();return s.file:match('/shared/navigation.go$') and s.line:find('type Counter struct',1,true)
    end,30000)
    capture('implementation-type')
    open('app/navigation.go');seek('ForgeValue');e:input('gi')
    e:wait('implementation метода в shared',function()
      local s=state();return s.file:match('/shared/navigation.go$') and s.line:find('func (Counter) ForgeValue',1,true)
    end,30000)
    capture('implementation-method')
    open('shared/answer.go');seek('Answer');e:input('gr')
    e:wait('native references quickfix',function() return e:current_ft()=='qf' end,30000)
    local refs=e:lua([[local out={};for i,r in ipairs(vim.fn.getqflist()) do
      out[#out+1]={index=i,file=vim.api.nvim_buf_get_name(r.bufnr):gsub('\\','/'),line=r.lnum}
      end;return out]])
    report.references=refs
    local selected
    for _,r in ipairs(refs) do if r.file:match('/app/main.go$') then selected=r end end
    assert(selected,vim.inspect(refs));e:input(tostring(selected.index)..'G<CR>')
    e:wait('reference выбран клавиатурой',function()
      local s=state();return e:current_ft()=='go' and s.file==selected.file and s.cursor[1]==selected.line
    end)
    local final=capture('reference-open')
    for _,method in ipairs({'textDocument/definition','textDocument/implementation','textDocument/references'}) do
      local found=false;for _,r in ipairs(final.requests) do
        if r.method==method and r.type=='complete' and r.client==client then found=true end
      end;assert(found,'нет завершённого native request '..method)
    end
  end,debug.traceback)
  if e then
    report=report or {};report.ok=ok;report.error=not ok and err or nil
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/go-workspace-language.json')
    pcall(function()
      local log=e:lua('return vim.lsp.log.get_filename()')
      if vim.fn.filereadable(log)==1 then assert(vim.uv.fs_copyfile(log,e.dir..'/lsp.log')) end
    end)
    local snapped,why=pcall(e.snapshot,e,'go-workspace-language')
    if not snapped then ok=false;err=tostring(err or '')..'\nSnapshot: '..tostring(why) end
    io.stdout:write('  artifacts: '..e.dir..'\n')
    local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
    if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
  end
  assert(ok,err)
end)
T.finish()
