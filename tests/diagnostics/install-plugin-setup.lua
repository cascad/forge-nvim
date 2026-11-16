-- Real Lazy/Git tasks; only the plugin source is a local fixture repository.
local before = vim.fn.environ()
local callback
if vim.env.FORGE_PLUGIN_PATCH then
    callback = function()
        local path = vim.env.FORGE_PLUGIN_PATCH
        assert(table.concat(vim.fn.readfile(path), '\n') == 'known patch')
        vim.fn.writefile({'pinned'}, path)
    end
end
local ok, result = pcall(require('forge.plugin_setup').prepare, callback)
local after = vim.fn.environ()
for key, value in pairs(before) do
    if key:match('^GIT_CONFIG_') then assert(after[key] == value, 'Git environment changed: ' .. key) end
end
for key in pairs(after) do
    if key:match('^GIT_CONFIG_') then assert(before[key] == after[key], 'Git environment added: ' .. key) end
end
if not ok then io.stderr:write(tostring(result) .. '\n'); vim.cmd('cquit 1') end
io.stdout:write('Plugin readiness: ' .. vim.json.encode(result) .. '\n')
vim.cmd('qa!')
