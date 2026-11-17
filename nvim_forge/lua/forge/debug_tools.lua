-- Passive DAP paths; native Delve version comparison stays in the async adapter.
local M = {}
local paths = require('forge.tool_paths')
function M.dlv_override(root)
    local env = vim.env.FORGE_DLV_PATH
    return paths.override('dlv', {root=root,global='forge_dlv_path',
        env=env and env~='' and 'FORGE_DLV_PATH' or 'DLV_PATH'})
end
function M.report_dlv(root)
    local path, explicit = M.dlv_override(root)
    if explicit then return path end
    return paths.executable('dlv', {root=root,
        source='PATH/Mason availability; full native selection: DapGoDlvInfo'})
end
function M.codelldb(root)
    local path, explicit = paths.override('codelldb', {root=root,
        global='forge_codelldb_path',env='FORGE_CODELLDB_PATH'})
    if explicit then return path end
    local found=vim.fn.exepath('codelldb')
    if found~='' then return paths.selected('codelldb',found,'PATH/Mason',root) end
    if vim.fn.has('win32')==1 then
        found=vim.fs.joinpath(vim.env.LOCALAPPDATA or '', 'codelldb/adapter/codelldb.exe')
        if vim.fn.executable(found)==1 then return paths.selected('codelldb',found,'LOCALAPPDATA',root) end
    end
    local bin=vim.fs.joinpath(vim.fn.stdpath('data'),'mason/bin/codelldb')
    for _,suffix in ipairs(vim.fn.has('win32')==1 and {'.exe','.cmd','.bat'} or {''}) do
        if vim.fn.executable(bin..suffix)==1 then return paths.selected('codelldb',bin..suffix,'Mason',root) end
    end
    return paths.selected('codelldb',nil,'native discovery',root)
end
return M
