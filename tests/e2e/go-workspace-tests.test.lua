-- IDE-TEST-1/5/7: настоящий Go.work, cold discovery двух модулей и объём запусков.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
T.check('IDE-TEST-7 Go.work discovery/nearest/file/all и исправление failing test',function()
  local e,report
  local ok,err=xpcall(function()
    local deps=vim.env.FORGE_E2E_TEST_DEPS or root..'/.tests/test-deps'
    local tools=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
    local lsp=vim.env.FORGE_E2E_LSP_DEPS or root..'/.tests/lsp-deps'
    assert(vim.fn.filereadable(deps..'/manifest.json')==1,'подготовь test-deps явно')
    local sep=vim.fn.has('win32')==1 and ';' or ':'
    local path=deps..'/bin'..sep..tools..'/go/bin'..sep..tools..'/bin'..sep..lsp..'/bin'..sep..lsp..'/format-bin'..sep..vim.env.PATH
    e=require('editor').start(root,{timeout=240000,site=deps..'/site',env={PATH=path,
      GOTOOLCHAIN='local',GOENV='off',GOWORK='',GOPROXY='off',GOSUMDB='off',GOTELEMETRY='off',
      CGO_ENABLED='0',GOMAXPROCS='2',GOFLAGS='-p=2',GOCACHE=require('go_cache').path(root)},
      prepare=function(project,env,runtime)
        env.GOPATH=runtime..'/go';env.GOBIN=''
        for _,name in ipairs({'go.work','app/go.mod','app/main.go','app/main_test.go','shared/go.mod','shared/answer.go','shared/answer_test.go'}) do
          vim.fn.mkdir(vim.fs.dirname(project..'/'..name),'p')
          assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/go-workspace/'..name,project..'/'..name))
        end
      end})
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/go-workspace-tests.test.lua',e.dir..'/go-workspace-tests.test.lua'))
    report={states={}}
    local function state()
      return e:lua([[local n=package.loaded.neotest;local out={counts={passed=0,failed=0,running=0},tests={}}
        if n then for _,id in ipairs(n.state.adapter_ids()) do
          local c=n.state.status_counts(id);if c then for k in pairs(out.counts) do out.counts[k]=out.counts[k]+(c[k] or 0) end end
          local tree=n.state.positions(id);if tree then for _,p in tree:iter() do
            if p.type=='test' then out.tests[p.name]={id=p.id,path=p.path,adapter=id} end end end
        end end;local lines={};for _,b in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype=='neotest-output-panel' then
            vim.list_extend(lines,vim.api.nvim_buf_get_lines(b,0,-1,false)) end end
        out.output=table.concat(lines,'\n');local d=package.loaded.dap
        out.dap=d and d.session()~=nil or false;return out]])
    end
    local function counters()
      local out={}
      for _,name in ipairs({'app/app-runs.txt','shared/shared-runs.txt','shared/expected-runs.txt'}) do
        local f=e.project..'/'..name
        out[#out+1]=vim.fn.filereadable(f)==1 and tonumber(table.concat(vim.fn.readfile(f),'')) or 0
      end
      return out
    end
    local function capture(label)
      local s=state();s.counters=counters();report.states[label]=s
      assert(not s.dap and not e:has_window('dap-float'),'ordinary tests opened DAP')
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/go-workspace-tests.json')
      return s
    end
    local function wait_run(label,expected,passed,failed)
      e:wait(label,function()
        local s=state();local got=counters()
        report.pending_run={label=label,expected=expected,actual=got,state=s}
        return vim.deep_equal(got,expected) and s.counts.running==0
          and s.counts.passed==passed and s.counts.failed==failed
      end,60000)
      capture(label)
    end
    e:input(':edit app/main_test.go<CR>')
    e:wait('app test открыт',function() return e:current_ft()=='go' and e:current_file():match('/app/main_test.go$') end)
    e:input(' Tp')
    e:wait('Summary и3 tests из двух модулей',function()
      local s=state();report.discovery=s
      return e:has_window('neotest-summary') and s.tests.TestApp and s.tests.TestShared and s.tests.TestExpected
    end,20000)
    e:input('<F7>gg/TestApp<CR> Tt')
    wait_run('nearest',{1,0,0},1,0)
    T.eq(e:has_window('neotest-output-panel'),true)
    e:wait('nearest output',function() return state().output:find('APP_WORK_TEST',1,true)~=nil end)
    e:input('<F7> TA')
    wait_run('all-before-shared-open',{2,1,1},2,1)
    e:wait('реальный fail output',function() return state().output:find('WORK_EXPECT_FAILURE',1,true)~=nil end)
    e:input('<F7>:edit shared/answer_test.go<CR>')
    e:wait('shared test открыт',function() return e:current_file():match('/shared/answer_test.go$') end)
    e:input(' Tf')
    wait_run('file',{2,2,2},2,1)
    e:input('<F7>gg/43<CR>ciw42<Esc>:write<CR>')
    e:wait('assertion исправлен',function()
      return table.concat(vim.fn.readfile(e.project..'/shared/answer_test.go'),'\n'):find('got != 42',1,true)~=nil
    end)
    -- Public native suite route, общий TA уже проверен до открытия shared.
    local adapter=state().tests.TestApp.adapter
    e:input(':lua require("neotest").run.run({vim.fn.getcwd(),adapter='..vim.inspect(adapter)..'})<CR>')
    wait_run('all-fixed',{3,3,3},3,0)
    T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
  end,debug.traceback)
  if e then
    report=report or {};report.ok=ok;report.error=not ok and err or nil
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/go-workspace-tests.json')
    pcall(function()
      for _,name in ipairs({'neotest','neotest-golang'}) do
        local log=e:lua([[local name=...;return require('neotest.logging').new(name):get_filename()]],{name})
        if vim.fn.filereadable(log)==1 then assert(vim.uv.fs_copyfile(log,e.dir..'/'..name..'.log')) end
      end
    end)
    local snapped,why=pcall(e.snapshot,e,'go-workspace-tests')
    if not snapped then ok=false;err=tostring(err or '')..'\nSnapshot: '..tostring(why) end
    io.stdout:write('  artifacts: '..e.dir..'\n')
    local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
    if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
  end
  assert(ok,err)
end)
T.finish()
