local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
T.check('IDE-BOOT-3 launcher CLI передаёт argv, exit и использует SDK своей ОС',function()
  local windows=vim.fn.has('win32')==1
  local python=vim.fn.exepath(windows and 'python' or 'python3')
  assert(python~='','нужен Python 3 для CLI E2E')
  local result=vim.system({python,'-X','utf8','-B',root..'/tests/windows_sdk_test.py',
    windows and 'TestWindowsSDKCLI' or 'TestPOSIXSDKCLI'},{cwd=root,text=true,timeout=30000}):wait()
  assert(result.code==0,'CLI code='..tostring(result.code)..' signal='..tostring(result.signal)..'\n'..(result.stdout or '')..(result.stderr or ''))
end)
T.check('IDE-BOOT-3 native resize после выхода terminal не завершает редактор',function()
  local result=vim.system({vim.v.progpath,'-l',root..'/tests/diagnostics/terminal-resize.lua'},
    {cwd=root,text=true,timeout=20000}):wait()
  assert(result.code==0,(result.stdout or '')..(result.stderr or ''))
  local data=vim.json.decode(vim.trim(result.stdout))
  T.eq(data.completed,50);T.eq(data.child_exit,0);T.eq(data.cleaned,true)
end)
T.finish()
