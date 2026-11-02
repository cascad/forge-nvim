local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local check=require('gitsigns_worktree').check
check('IDE-GIT-8 initial show и удаление worktree не блокируют код, main stage работает',false)
check('IDE-GIT-8 dirty force cancel сохраняет signs и stage правильного linked repo',true)
T.finish()
