-- spec: IDE-BOOT-10. Только explicit installer env; обычный каталог прежний.
local M = {}
function M.filter(fallback, column, mask)
    mask = mask or vim.env.FORGE_NVIM_COMPONENTS
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
                if not seen[name] then
                    result[#result + 1] = name; seen[name] = true
                end
            end
        end
    end
    assert(selected.core, 'Installer profile requires core')
    for id in pairs(selected) do assert(known[id], 'Unknown component: ' .. id) end
    return result
end
function M.selected(id)
    for name in (vim.env.FORGE_NVIM_COMPONENTS or ''):gmatch('[^,]+') do if name == id then return true end end
    return false
end
function M.prepared(id)
    local mask=vim.env.FORGE_PREPARE_COMPONENTS or vim.env.FORGE_NVIM_COMPONENTS
    if not mask or mask=='' then return true end
    for name in mask:gmatch('[^,]+') do if name==id then return true end end
    return false
end
function M.sdk_kinds(component)
    local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
    local rows,selected={},{}
    for line in io.lines(root..'/scripts/components.tsv') do
        local fields=vim.split(line:gsub('\r$',''),'\t',{plain=true})
        rows[fields[1]]=fields[3]
    end
    local function visit(id)
        if selected[id] then return end
        assert(rows[id],'Unknown component: '..id);selected[id]=true
        if rows[id]~='-' then for dependency in rows[id]:gmatch('[^,]+') do visit(dependency) end end
    end
    visit(component)
    local result={}
    for _,kind in ipairs({'go','rust','python','node'}) do
        if selected[kind] or selected[kind..'-runtime'] then result[#result+1]=kind end
    end
    return result
end
return M
