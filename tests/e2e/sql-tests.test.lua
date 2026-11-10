-- spec: IDE-SQL-7 IDE-SQL-8. Real editor + native runner + actual SQLite counters.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function text(e,ft)
  return e:lua([[local ft=...;local out={};for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype==ft then vim.list_extend(out,vim.api.nvim_buf_get_lines(b,0,-1,false)) end end;return table.concat(out,'\n')]],{ft})
end
local function open(e,file)
  local path=e.sql_test_project..'/'..file;e:input(':edit '..vim.fn.fnameescape(path)..'<CR>')
  e:wait('SQL test file '..file,function() return e:current_file():gsub('\\','/')==path end)
end
local function counts(e)
  return e:lua([[local n=require('neotest');local out={total=0,passed=0,failed=0,running=0,skipped=0};
    for _,id in ipairs(n.state.adapter_ids()) do local s=n.state.status_counts(id);if s then
      for k in pairs(out) do out[k]=out[k]+(s[k] or 0) end end end;return out]])
end
local function jobs(e) return e:lua([[return _G.forge_sqltest_jobs]]) end
local function counters(e) return require('sql_test_project').counters(e) end
local function focus(e,keys,ft)
  e:input(keys);e:wait('focus '..ft,function() return e:current_ft()==ft end)
end
local function discover(e,file,total)
  open(e,file or 'basic.slt');focus(e,' wt','neotest-summary')
  e:wait('SQLLogicTest scripts discovered',function() return counts(e).total==(total or 3) end,15000)
  focus(e,'<F7>','sqllogictest')
end
local function run(e,keys,passed,failed)
  local before=#jobs(e);e:input(keys)
  e:wait('new native SQL test process exited',function() local j=jobs(e);return #j>before and j[#j].code~=nil end,15000)
  e:wait('SQL test statuses',function() local s=counts(e);return s.passed==passed and s.failed==failed and s.running==0 end,15000)
end
local function state(e)
  return e:lua([[local n=package.loaded.neotest;local positions,statuses={},{};
    if n then for _,id in ipairs(n.state.adapter_ids()) do local t=n.state.positions(id);if t then positions[id]=t:to_list() end
      statuses[id]=n.state.status_counts(id) end end
    return {mode=vim.api.nvim_get_mode(),messages=vim.fn.execute('messages'),notifications=vim.g.forge_e2e_notifications,
      installs=vim.g.forge_e2e_installs,spawns=_G.forge_e2e_spawns,jobs=_G.forge_sqltest_jobs,
      positions=positions,statuses=statuses,diagnostics=vim.diagnostic.get(),clients=vim.tbl_map(function(c) return c.name end,vim.lsp.get_clients())} ]])
end
local function check(name,fn,mode)
  if vim.env.FORGE_SQL_TEST_CASE and not name:find(vim.env.FORGE_SQL_TEST_CASE,1,true) then return end
  T.check(name,function()
    local e;local ok,err=pcall(function()
      require('sql_test_project').start(root,function(child) e=child end,mode)
      for _,file in ipairs({'tests/e2e/sql-tests.test.lua','tests/lib/sql_test_project.lua'}) do
        assert(vim.uv.fs_copyfile(root..'/'..file,e.dir..'/'..vim.fs.basename(file))) end
      fn(e)
      local s=state(e);T.eq(s.installs,0);T.eq(#s.clients,0,'SLT is not attached as production SQL')
      assert(not s.mode.blocking,'Unexpected prompt');assert(not s.messages:match('E%d%d%d+:'),s.messages)
      assert(not s.messages:find('No active session',1,true),s.messages)
      for _,n in ipairs(s.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
      T.eq(e:lua([[return require('dap').session()==nil]]),true)
    end)
    if e then
      local got,s=pcall(state,e);if got then
        vim.fn.writefile({vim.json.encode(s)},e.dir..'/sql-test-state.json')
        vim.fn.mkdir(e.dir..'/reports','p')
        for i,j in ipairs(s.jobs or {}) do for _,suffix in ipairs({'','.native','.txt'}) do
          if vim.fn.filereadable(j.report..suffix)==1 then assert(vim.uv.fs_copyfile(j.report..suffix,e.dir..'/reports/'..i..suffix..'.json')) end end end
      end
      for _,path in ipairs({e.log_lsp,e.log_state..'/neotest.log'}) do
        if vim.fn.filereadable(path)==1 then assert(vim.uv.fs_copyfile(path,e.dir..'/'..vim.fs.basename(path))) end end
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop(not ok and tostring(err) or nil)
    end
    assert(ok,err)
  end)
end
check('IDE-SQL-7 discovery nearest shared setup without installs or DAP',function(e)
  discover(e);T.eq(#jobs(e),0);T.eq(counters(e).basic,0)
  run(e,'18G Tt',1,0)
  local c=counters(e);T.eq(c.basic,1);T.eq(c.other,0);T.eq(c.wrong,0)
  e:wait('native PASS output',function()
    -- Terminal может перенести заголовок между rows из-за длинного native path.
    local output=text(e,'neotest-output-panel'):gsub('\n','')
    return output:find('PASS',1,true) and output:find('8 SQL checks',1,true)
  end)
end)
check('IDE-SQL-7 failed expected quickfix line edit save and rerun',function(e)
  discover(e,'wrong.slt');run(e,' Tf',0,1)
  e:wait('actual expected mismatch output',function() local out=text(e,'neotest-output-panel');return out:find('42',1,true) and out:find('43',1,true) end)
  e:wait('actual native failure in quickfix',function() local q=e:lua([[return vim.fn.getqflist()]]);return #q>0 and q[1].lnum==7 end)
  focus(e,'<F7>','sqllogictest');e:input(':cfirst<CR>')
  e:wait('jump to failed query',function() return e:current_file():sub(-9)=='wrong.slt' and e:lua([[return vim.api.nvim_win_get_cursor(0)[1] ]])==7 end)
  e:input('gg/^43$<CR>cc42<Esc>:write<CR>')
  e:wait('corrected expected saved',function() return table.concat(vim.fn.readfile(e.sql_test_project..'/wrong.slt'),'\n'):find('----\n42',1,true)~=nil end)
  run(e,' Tt',1,0);T.eq(counters(e).wrong,2)
end)
check('IDE-SQL-7 file Unicode space quote argv selects one script',function(e)
  discover(e,"other ü quote'.slt");run(e,' Tf',1,0)
  local c=counters(e);T.eq(c.other,1);T.eq(c.basic,0);T.eq(c.wrong,0)
  assert(jobs(e)[1].command[5]:find("other ü quote'.slt",1,true))
end)
check('IDE-SQL-7 all scripts independent DB and actual mixed results',function(e)
  discover(e);run(e,' TA',2,1)
  local c=counters(e);T.eq(c.basic,1);T.eq(c.other,1);T.eq(c.wrong,1);T.eq(#jobs(e),3)
end)
check('IDE-TEST-5 all adapters SQL and Bats without opening Tests first',function(e)
  open(e,'basic.slt');run(e,' TA',3,1)
  local c=counters(e);T.eq(c.basic,1);T.eq(c.other,1);T.eq(c.wrong,1);T.eq(#jobs(e),3)
  T.eq(vim.fn.readfile(e.sql_test_project..'/mixed-ran.txt'),{'BATS_MIXED_DONE'})
end,'mixed')
check('IDE-TEST-5 all excludes another open workspace',function(e)
  discover(e);local primary=e.sql_test_project;local foreign=require('sql_test_project').foreign(e)
  e.sql_test_project=foreign;open(e,'foreign.slt');focus(e,' wt','neotest-summary')
  e:wait('foreign scripts discovered',function() return counts(e).total==4 end,15000)
  focus(e,'<F7>','sqllogictest');e.sql_test_project=primary;open(e,'basic.slt')
  run(e,' TA',2,1);T.eq(#jobs(e),3)
  e.sql_test_project=foreign;T.eq(counters(e).basic,0);e.sql_test_project=primary
end)
check('IDE-SQL-7 stop native sleeping process and continue editing tests',function(e)
  discover(e,'slow.slt',4);e:input(' Tt')
  e:wait('own native SQL runner sleeping',function() local j=jobs(e);return #j==1 and j[1].pid and counts(e).running==1 and counters(e).slow==1 end,15000)
  local pid=jobs(e)[1].pid;assert(vim.uv.kill(pid,0),'Native runner must be alive before stop')
  focus(e,'<F7>','sqllogictest');e:input(' Ts')
  e:wait('owned native runner exited',function() return not vim.uv.kill(pid,0) end,7000)
  e:wait('stopped test no longer running',function() return counts(e).running==0 end)
  T.eq(counts(e).passed,0)
  vim.fn.writefile({vim.json.encode(state(e))},e.dir..'/sql-test-state-before-file-switch.json')
  open(e,'basic.slt');run(e,' Tt',1,counts(e).failed);T.eq(counters(e).basic,1)
end,'slow')
check('IDE-SQL-7 missing native runner warns no install or active DAP',function(e)
  discover(e);e:input(' Tt')
  e:wait('SQLLogicTest missing SDK message',function()
    if e.rpc:request('nvim_get_mode',{}).blocking then e:ack_warning('SQLLogicTest');return false end
    return e:lua([[for _,n in ipairs(vim.g.forge_e2e_notifications) do if n.message:find('FORGE_SQLTEST_EXECUTABLE',1,true) then return true end end;return false]])
  end)
  T.eq(#jobs(e),0);T.eq(counters(e).basic,0)
end,'missing')
check('IDE-SQL-7 SQLLogicTest debug request has no DAP session or native run',function(e)
  discover(e);e:input(' Td')
  e:wait('SQLLogicTest DAP guard',function()
    if e.rpc:request('nvim_get_mode',{}).blocking then e:ack_warning('SQLLogicTest');return false end
    return e:lua([[for _,n in ipairs(vim.g.forge_e2e_notifications) do if n.message:find('SQLLogicTest не использует DAP',1,true) then return true end end;return false]])
  end)
  T.eq(#jobs(e),0);T.eq(counters(e).basic,0)
end)
check('IDE-SQL-7 invalid and empty scripts fail visibly',function(e)
  discover(e,'invalid.slt',5);run(e,' Tf',0,1)
  e:wait('native parser output',function() return text(e,'neotest-output-panel'):find('invalid record',1,true)~=nil end)
  focus(e,'<F7>','sqllogictest');open(e,'empty.slt');run(e,' Tf',0,2)
  e:wait('empty script output',function() return text(e,'neotest-output-panel'):find('No SQL assertions executed',1,true)~=nil end)
end,'invalid')
check('IDE-SQL-7 native exit zero with damaged report must fail then rerun',function(e)
  discover(e);e:lua([[vim.g.forge_sqltest_corrupt_report=true]])
  run(e,' Tf',0,1);T.eq(jobs(e)[1].code,0);T.eq(jobs(e)[1].corrupted,true)
  e:wait('invalid report output',function() return text(e,'neotest-output-panel'):find('Invalid SQLLogicTest report',1,true)~=nil end)
  e:lua([[vim.g.forge_sqltest_corrupt_report=false]])
  focus(e,'<F7>','sqllogictest');run(e,' Tf',1,0);T.eq(counters(e).basic,2)
end)
check('IDE-SQL-7 common Tests Output focus help zoom hide preserve result',function(e)
  discover(e);run(e,' Tt',1,0)
  focus(e,' wr','neotest-output-panel');local output=text(e,'neotest-output-panel')
  focus(e,'?','forge-panel-help');focus(e,'q','neotest-output-panel')
  e:input(' wz');e:wait('Test Output zoom',function() return e:lua([[return vim.api.nvim_win_get_config(0).relative]])=='editor' end)
  e:input(' wzq');e:wait('Test Output hidden',function() return not e:has_window('neotest-output-panel') end)
  focus(e,' wt','neotest-summary');focus(e,'?','forge-panel-help');focus(e,'q','neotest-summary')
  focus(e,' wr','neotest-output-panel');T.eq(text(e,'neotest-output-panel'),output)
  focus(e,'<F7>','sqllogictest');T.eq(counters(e).basic,1);T.eq(#jobs(e),1)
end)
T.finish()
