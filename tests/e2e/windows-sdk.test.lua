local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local cases,python
local evidence=root..'/.tests/sdk-cases/'..tostring(vim.uv.hrtime())
vim.fn.mkdir(evidence,'p')
local function run_case(name,args)
  local path=evidence..'/'..name..'.json'
  local data={argv=args,timeout_ms=30000,started=vim.uv.hrtime()}
  local function save() vim.fn.writefile({vim.json.encode(data)},path) end
  save()
  local process=vim.system(args,{cwd=root,text=true,timeout=30000})
  data.pid=process.pid;save()
  local result=process:wait()
  data.elapsed_ms=(vim.uv.hrtime()-data.started)/1e6;data.result=result;save()
  assert(result.code==0,'CLI code='..tostring(result.code)..' signal='..tostring(result.signal)..'\n'..(result.stdout or '')..(result.stderr or '')..'\nartifacts: '..path)
  return result
end
T.check('IDE-BOOT-3 обнаружение CLI сценариев SDK своей ОС',function()
  local windows=vim.fn.has('win32')==1
  python=vim.fn.exepath(windows and 'python' or 'python3')
  assert(python~='','нужен Python 3 для CLI E2E')
  local class=windows and 'TestWindowsSDKCLI' or 'TestPOSIXSDKCLI'
  local result=run_case('discovery',{python,'-X','utf8','-B',root..'/tests/windows_sdk_test.py','--list-cases',class})
  cases=vim.json.decode(result.stdout)
  assert(type(cases)=='table' and #cases>0,'пустой список SDK сценариев')
  for _,name in ipairs(cases) do assert(name:match('^'..class..'%.test_[%w_]+$'),'неверный SDK сценарий: '..tostring(name)) end
end)
-- Каждый независимый сценарий получает прежние 30s; лимит CLI команды остаётся 10s.
-- Раньше весь unittest class разделял один 30s и обрывал ещё допустимую команду.
for _,name in ipairs(cases or {}) do
  T.check('IDE-BOOT-3 '..name,function()
    run_case(name,{python,'-X','utf8','-B',root..'/tests/windows_sdk_test.py',name})
  end)
end
T.check('IDE-BOOT-3 native resize после выхода terminal не завершает редактор',function()
  local result=vim.system({vim.v.progpath,'-l',root..'/tests/diagnostics/terminal-resize.lua'},
    {cwd=root,text=true,timeout=20000}):wait()
  assert(result.code==0,(result.stdout or '')..(result.stderr or ''))
  local data=vim.json.decode(vim.trim(result.stdout))
  T.eq(data.completed,50);T.eq(data.child_exit,0);T.eq(data.cleaned,true)
end)
T.finish()
