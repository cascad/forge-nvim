-- spec: IDE-TEST-10. Fast plan/CLI checks; never starts editor E2E.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local plan=require('batch_plan')
local registry={{file='a.lua',suite='unit',timeout=7},{file='b.lua',suite='e2e',acceptance=true},
  {file='c.py',suite='conpty',kind='py'},{file='d.lua',suite='e2e'}}
T.check('IDE-TEST-10 batch selects exactly files and rejects duplicates unknown',function()
  local selected=plan.select(registry,{'tests/install-a.test.py'},'e2e',{'b.lua','tests/install-a.test.py'},false)
  T.eq(selected.registry,{registry[2]});T.eq(selected.installers,{'tests/install-a.test.py'});T.eq(selected.suites,{'e2e'})
  assert(not pcall(plan.select,registry,{},'e2e',{'missing'},false))
  assert(not pcall(plan.select,registry,{},'e2e',{'a.lua','a.lua'},false))
end)
T.check('IDE-TEST-10 regression includes native installers and native OS suites',function()
  T.eq(#plan.select(registry,{'tests/install-a.test.py'},'regression',{},true).registry,4)
  local linux=plan.select(registry,{'tests/install-a.test.py'},'regression',{},false)
  T.eq(#linux.registry,3);T.eq(linux.installers,{'tests/install-a.test.py'})
  T.eq(plan.select(registry,{'tests/install-a.test.py'},'full',{},false).installers,{})
end)
T.check('IDE-TEST-10 acceptance selects only marked editor suites on both platforms',function()
  for _,windows in ipairs({true,false}) do
    local selected=plan.select(registry,{'tests/install-a.test.py'},'acceptance',{},windows)
    T.eq(selected.registry,{registry[2]})
    T.eq(selected.installers,{})
    T.eq(selected.suites,{'e2e'})
  end
end)
T.finish()
