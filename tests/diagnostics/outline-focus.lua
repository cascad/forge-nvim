-- IDE-084: наблюдение первой async LSP Outline, без изменения runtime политики.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local deps=vim.env.FORGE_E2E_LSP_DEPS or root..'/.tests/lsp-deps'
local tools=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
local count=tonumber(vim.env.FORGE_OUTLINE_SAMPLES or '3')
assert(count and count>=1 and count<=5 and count%1==0,'samples: 1..5')
assert(vim.fn.filereadable(deps..'/manifest.json')==1,'сначала подготовь LSP SDK')
local sep=vim.fn.has('win32')==1 and ';' or ':'
local path=deps..'/bin'..sep..vim.env.PATH
if vim.fn.isdirectory(tools..'/go/bin')==1 then path=tools..'/go/bin'..sep..path end
local reports={}
local function current(e)
  return e:lua([[local w=vim.api.nvim_get_current_win();return {win=w,ft=vim.bo.filetype,
    file=vim.api.nvim_buf_get_name(0),cursor=vim.api.nvim_win_get_cursor(w)}]])
end
for sample=1,count do
  local e
  local ok,err=xpcall(function()
    e=require('editor').start(root,{timeout=180000,env={PATH=path,
      GOENV='off',GOTOOLCHAIN='local',GOPROXY='off',GOSUMDB='off',GOTELEMETRY='off',
      GOMAXPROCS='2',GOFLAGS='-p=2',CGO_ENABLED='0'},prepare=function(project,env,runtime)
        env.GOPATH=runtime..'/go';env.GOMODCACHE=deps..'/gopath/pkg/mod'
        env.GOCACHE=require('go_cache').path(root)
        local dir=project..'/Outline review ü';vim.fn.mkdir(dir,'p')
        for _,file in ipairs({'go.mod','library.go','use.go'}) do
          assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/go-language/'..file,dir..'/'..file))
        end
      end})
    local project=(e.project..'/Outline review ü'):gsub('\\','/')
    e:input(':cd '..vim.fn.fnameescape(project)..'<CR>:lua require("config.start").open_project(vim.fn.getcwd())<CR>')
    e:wait('Explorer проекта',function() return e:has_window('neo-tree') end)
    e:input(' w0')
    e:wait('main окно',function() return e:current_ft()~='neo-tree' end)
    e:input(':edit '..vim.fn.fnameescape(project..'/use.go')..'<CR>')
    e:wait('настоящий gopls',function()
      return e:current_ft()=='go' and e:lua([[for _,c in ipairs(vim.lsp.get_clients({bufnr=0,name='gopls'})) do
        if c.initialized and not c:is_stopped() then return true end end;return false]])
    end,30000)
    e:lua([[local started=vim.uv.hrtime();_G.forge_outline_events={}
      local function record(kind,extra)
        if #_G.forge_outline_events>=300 then return end
        local w=vim.api.nvim_get_current_win()
        table.insert(_G.forge_outline_events,{ms=(vim.uv.hrtime()-started)/1e6,kind=kind,
          win=w,ft=vim.bo.filetype,extra=extra})
      end
      local set=vim.api.nvim_set_current_win
      vim.api.nvim_set_current_win=function(w)
        record('set_current_win',{target=w,stack=debug.traceback('',2)})
        return set(w)
      end
      vim.api.nvim_create_autocmd({'WinEnter','BufEnter','BufWinEnter'},{callback=function(ev) record(ev.event) end})
      vim.api.nvim_create_autocmd('LspRequest',{callback=function(ev)
        if ev.data.request.method=='textDocument/documentSymbol' then record('LspRequest',ev.data.request.type) end
      end})]])
    local report={sample=sample,artifacts=e.dir,before=current(e)}
    e:input(' lo')
    e:wait('LSP символы Use/OtherUse',function()
      return e:lua([[for _,w in ipairs(vim.api.nvim_list_wins()) do local b=vim.api.nvim_win_get_buf(w)
        if vim.bo[b].filetype=='aerial' then local s=table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n')
          if s:find('Use',1,true) and s:find('OtherUse',1,true) then return true end end end;return false]])
    end,20000)
    report.when_ready=current(e);e:snapshot('first-data-ready')
    report.followup={}
    for _=1,24 do
      report.followup[#report.followup+1]=current(e)
      vim.wait(25)
    end
    report.after_settle=current(e);e:snapshot('first-data-settled')
    report.events=e:lua('return _G.forge_outline_events')
    e:input(' wa')
    e:wait('повторный direct Outline focus',function() return e:current_ft()=='aerial' end)
    report.direct_focus=current(e)
    e:input(' w0')
    e:wait('явный возврат в код',function() return e:current_ft()=='go' end)
    vim.wait(250);report.after_explicit_code=current(e)
    report.notifications=e:lua('return vim.g.forge_e2e_notifications')
    report.installs=e:lua('return vim.g.forge_e2e_installs')
    assert(report.installs==0)
    for _,n in ipairs(report.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/outline-focus.json')
    assert(vim.uv.fs_copyfile(root..'/tests/diagnostics/outline-focus.lua',e.dir..'/outline-focus.lua'))
    reports[#reports+1]=report
    io.stdout:write('sample '..sample..': ready='..report.when_ready.ft..', settled='..report.after_settle.ft..'; artifacts: '..e.dir..'\n')
  end,debug.traceback)
  if e then e:stop(not ok and tostring(err) or nil) end
  if not ok then error(err) end
end
local output=vim.env.FORGE_OUTLINE_OUTPUT or root..'/.tests/outline-focus.json'
vim.fn.writefile({vim.json.encode(reports)},output)
io.stdout:write('Observed '..#reports..' native samples; trace is diagnostic, not a product fix\n')
