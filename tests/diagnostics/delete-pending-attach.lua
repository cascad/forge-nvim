-- Известная гонка Gitsigns initial attach → удаление cwd (IDE-035).
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
vim.env.FORGE_DELETED_PENDING_ATTACH='1'
vim.env.FORGE_DELETED_E2E_CASE='много открытых'
dofile(root..'/tests/e2e/deleted-files.test.lua')
