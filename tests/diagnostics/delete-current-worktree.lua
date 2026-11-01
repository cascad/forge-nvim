-- Известный отдельный сбой Git/Neogit до успешного удаления (IDE-034).
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
vim.env.FORGE_DELETED_CURRENT_WORKTREE='1'
vim.env.FORGE_DELETED_E2E_CASE='после посещения'
dofile(root..'/tests/e2e/deleted-files.test.lua')
