local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
T.check('IDE-GIT-9 CLI живой object read сохраняет linked HEAD без cwd worktree',function()
  local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3')
  assert(python~='','Нужен Python 3')
  local result=vim.system({python,'-B',root..'/tests/diagnostics/git-object-read-cwd.py'},
    {cwd=root,text=true,timeout=20000}):wait()
  assert(result.code==0,(result.stdout or '')..(result.stderr or ''))
  T.eq(#vim.json.decode(vim.trim(result.stdout)),5)
end)
local check=require('gitsigns_worktree').check
check('IDE-GIT-9 live show не мешает удалению, main stage работает',false,'live')
check('IDE-GIT-9 live dirty cancel сохраняет linked HEAD и правильный index',true,'live')
check('IDE-GIT-9 current linked cwd не наследуется живым object read',false,'live',true)
T.finish()
