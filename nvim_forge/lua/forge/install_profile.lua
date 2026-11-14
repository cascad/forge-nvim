-- spec: IDE-BOOT-10. Только explicit installer env; обычный каталог прежний.
local M = {}
function M.filter(fallback, column)
    local mask = vim.env.FORGE_NVIM_COMPONENTS
    if not mask or mask == '' then return fallback end
    local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
    local selected, known, result, seen = {}, {}, {}, {}
    for id in mask:gmatch('[^,]+') do selected[id] = true end
    for line in io.lines(root .. '/scripts/components.tsv') do
        line = line:gsub('\r$', '')
        local fields = vim.split(line, '\t', { plain = true })
        assert(#fields == 5, 'Invalid component table')
        known[fields[1]] = true
        if selected[fields[1]] and fields[column] ~= '-' then
            for name in fields[column]:gmatch('[^,]+') do
                if not seen[name] and not (column == 4 and name == 'codelldb' and vim.fn.has('win32') == 1) then
                    result[#result + 1] = name; seen[name] = true
                end
            end
        end
    end
    assert(selected.core, 'Installer profile requires core')
    for id in pairs(selected) do assert(known[id], 'Unknown component: ' .. id) end
    return result
end
return M
