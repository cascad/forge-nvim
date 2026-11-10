-- IDE-080: ограниченный native baseline проекта/навигации, не benchmark машины.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local deps=vim.env.FORGE_E2E_LSP_DEPS or root..'/.tests/lsp-deps'
assert(vim.fn.filereadable(deps..'/manifest.json')==1,'Сначала явно подготовь lsp-deps')
local tools=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
local sep=vim.fn.has('win32')==1 and ';' or ':'
local path=deps..'/bin'..sep..vim.env.PATH
if vim.fn.isdirectory(tools..'/go/bin')==1 then path=tools..'/go/bin'..sep..path end
local samples=tonumber(vim.env.FORGE_PROJECT_REVIEW_SAMPLES or '3')
assert(samples and samples>=1 and samples<=5 and samples%1==0,'samples: 1..5')
local reports={}
local function now() return vim.uv.hrtime() end
local function ms(started) return (now()-started)/1e6 end
for index=1,samples do
  local e
  local ok,err=xpcall(function()
    local started=now()
    e=require('editor').start(root,{timeout=180000,env={PATH=path,
      GOENV='off',GOTOOLCHAIN='local',GOPROXY='off',GOSUMDB='off',GOTELEMETRY='off',
      GOMAXPROCS='2',GOFLAGS='-p=2',CGO_ENABLED='0'},prepare=function(project,env,runtime)
        env.GOPATH=runtime..'/go';env.GOMODCACHE=deps..'/gopath/pkg/mod'
        env.GOCACHE=require('go_cache').path(root)
        local dir=project..'/Go review ü';vim.fn.mkdir(dir,'p')
        for _,file in ipairs({'go.mod','library.go','use.go'}) do
          assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/go-language/'..file,dir..'/'..file))
        end
      end})
    local report={sample=index,artifacts=e.dir,driver_start_ms=ms(started)}
    report.idle=e:lua([[return {stats=require('lazy').stats(),rss_bytes=vim.uv.resident_set_memory()}]])
    local project=(e.project..'/Go review ü'):gsub('\\','/')
    started=now()
    e:input(':cd '..vim.fn.fnameescape(project)..'<CR>')
    e:wait('выбран Go workspace',function() return e:lua([[return vim.fn.getcwd():gsub('\\','/')]])==project end)
    e:input(':lua require("config.start").open_project(vim.fn.getcwd())<CR>')
    e:wait('текущий проект/Explorer готов',function()
      return e:has_window('neo-tree') and e:lua([[return require('neo-tree.sources.manager').get_state('filesystem').path:gsub('\\','/')]])==project
    end)
    report.current_project_entry_ms=ms(started)
    e:input(' w0')
    e:wait('главное окно',function() return e:current_ft()~='neo-tree' end)
    started=now()
    e:input(':edit '..vim.fn.fnameescape(project..'/use.go')..'<CR>')
    e:wait('Go файл и настоящий gopls',function()
      if e:current_ft()~='go' then return false end
      return e:lua([[for _,c in ipairs(vim.lsp.get_clients({bufnr=0,name='gopls'})) do
        if c.initialized and not c:is_stopped() then return true end end;return false]])
    end,30000)
    report.file_lsp_ready_ms=ms(started)
    started=now();e:input(' lo')
    e:wait('Outline содержит настоящий Use',function()
      return e:lua([[for _,w in ipairs(vim.api.nvim_list_wins()) do
        local b=vim.api.nvim_win_get_buf(w)
        if vim.bo[b].filetype=='aerial' and table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n'):find('Use',1,true) then return true end
        end;return false]])
    end,20000)
    report.outline_ready_ms=ms(started)
    report.first_outline_focus=e:current_ft()
    report.focus_ms={}
    for _=1,3 do
      for _,target in ipairs({{' w0','go'},{' wa','aerial'}}) do
        started=now();e:input(target[1])
        e:wait('фокус '..target[2],function() return e:current_ft()==target[2] end)
        report.focus_ms[#report.focus_ms+1]=ms(started)
      end
    end
    e:input(' w0gg/Double<CR>')
    e:wait('Double в коде',function() return e:current_ft()=='go' and e:lua([[return vim.fn.expand('<cword>')]])=='Double' end)
    e:wait('живой breadcrumb Use',function()
      return e:lua([[return require('nvim-navic').get_location():find('Use',1,true)~=nil]])
    end,10000)
    local function idle_snapshot()
      return e:lua([[return {usage=vim.uv.getrusage(),rss_bytes=vim.uv.resident_set_memory(),
        loaded=require('lazy').stats().loaded,navic=require('nvim-navic').get_location(),
        winbar=vim.wo.winbar,go=vim.fn.exepath('go'),gopls=vim.fn.exepath('gopls')} ]])
    end
    report.project=idle_snapshot()
    started=now();vim.wait(1000)
    report.idle_elapsed_ms=ms(started)
    report.after_idle=idle_snapshot()
    e:snapshot('project-ready')
    started=now();e:input('gpd')
    e:wait('Peek definition показывает library.go',function()
      return e:has_window('Glance') and e:lua([[for _,w in ipairs(vim.api.nvim_list_wins()) do
        local b=vim.api.nvim_win_get_buf(w)
        if vim.api.nvim_buf_get_name(b):match('library%.go$') and
          table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n'):find('func Double',1,true) then return true end
        end;return false]])
    end,20000)
    report.peek_definition_ms=ms(started)
    e:snapshot('peek-definition')
    e:input('q')
    vim.wait(150)
    report.peek_q_closed=not e:has_window('Glance') and e:current_file()==project..'/use.go' and e:current_ft()=='go'
    report.after_peek_q=e:lua([[local m=vim.fn.maparg('q','n',false,true);
      return {messages=vim.fn.execute('messages'),q_rhs=m.rhs,q_callback=type(m.callback),ft=vim.bo.filetype}]])
    e:snapshot('peek-after-q')
    if not report.peek_q_closed then
      -- Q — штатный непереопределённый Glance close, только cleanup после RED q.
      e:input('Q')
      e:wait('штатный Q завершил cleanup Peek',function()
        return not e:has_window('Glance') and e:current_file()==project..'/use.go' and e:current_ft()=='go'
      end)
      report.peek_Q_cleanup=true
    end
    report.final=e:lua([[return {installs=vim.g.forge_e2e_installs,
      notifications=vim.g.forge_e2e_notifications,mode=vim.api.nvim_get_mode()}]])
    assert(report.final.installs==0 and not report.final.mode.blocking)
    for _,notification in ipairs(report.final.notifications) do
      assert(notification.level<vim.log.levels.ERROR,notification.message)
    end
    assert(vim.uv.fs_copyfile(deps..'/manifest.json',e.dir..'/lsp-dependencies.json'))
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/project-profile.json')
    reports[#reports+1]=report
    io.stdout:write('sample '..index..'; artifacts: '..e.dir..'\n')
  end,debug.traceback)
  if e then
    assert(vim.uv.fs_copyfile(root..'/tests/diagnostics/profile-project.lua',e.dir..'/profile-project.lua'))
    e:stop(not ok and tostring(err) or nil)
  end
  if not ok then error(err) end
end
local output=vim.env.FORGE_PROJECT_REVIEW_OUTPUT or root..'/.tests/project-review.json'
vim.fn.writefile({vim.json.encode(reports)},output)
io.stdout:write('Observed '..#reports..' native project samples; no performance threshold\n')
local failed=0
for _,report in ipairs(reports) do if not report.peek_q_closed then failed=failed+1 end end
if failed>0 then error('IDE-083: Peek q failed in '..failed..'/'..#reports..' native samples; collected data preserved') end
