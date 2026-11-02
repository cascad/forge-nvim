-- Явная, локальная подготовка. Ни загрузки конфига, ни сети/установок.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
package.path = root .. '/lua/?.lua;' .. package.path
local ok, result = pcall(function()
    local lazy_root, mode, plugin = vim.fn.stdpath('data') .. '/lazy', 'apply', nil
    local i = 1
    while i <= #arg do
        if arg[i] == '--plugin-root' then
            i = i + 1; lazy_root = assert(arg[i], '--plugin-root требует каталог Lazy')
        elseif arg[i] == '--plugin' then
            i = i + 1; plugin = assert(arg[i], '--plugin требует имя плагина')
        elseif arg[i] == '--check' then mode = 'check'
        elseif arg[i] == '--revert' then mode = 'revert'
        else error('Неизвестный аргумент: ' .. tostring(arg[i])) end
        i = i + 1
    end
    local backports = require('ide.backports')
    if plugin then return { [plugin] = backports.run(plugin, lazy_root .. '/' .. plugin, mode) } end
    return backports.all(lazy_root, mode)
end)
if not ok then io.stderr:write(tostring(result) .. '\n'); os.exit(1) end
io.stdout:write(vim.json.encode(result) .. '\n')
