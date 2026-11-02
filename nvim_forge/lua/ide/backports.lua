-- Временные исправления зависимостей: запись только по явному apply/revert.
local M = {}
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')

local function read(path)
    local f = assert(io.open(path, 'rb'), 'Не найден файл: ' .. path)
    local text = f:read('*a'); f:close()
    return text
end

local patches = vim.json.decode(read(root .. '/patches/plugins.json'))
local lock = vim.json.decode(read(root .. '/lazy-lock.json'))
for name, patch in pairs(patches) do
    assert(lock[name] and lock[name].commit == patch.revision, 'Backport/lock различаются: ' .. name)
end

function M.revision(name)
    return assert(patches[name], 'Неизвестный backport: ' .. name).revision
end

local function plan_file(name, dir, patch, mode)
    local path = dir .. '/' .. patch.file
    local raw = read(path)
    local text = raw:gsub('\r\n', '\n')
    local hash = vim.fn.sha256(text)
    local from
    if hash == patch.before_sha256 then from = patch.before
    elseif hash == patch.after_sha256 then from = patch.after
    else
        -- Явное обновление/снятие прежнего известного backport, без принятия чужих правок.
        for _, previous in ipairs(patch.previous or {}) do
            if hash == previous.sha256 then from = previous.after; break end
        end
    end
    assert(from,
        'Backport: неизвестное содержимое ' .. path .. '; файл сохранён без изменений')
    local wanted = mode == 'revert' and patch.before_sha256 or patch.after_sha256
    if hash ~= wanted then
        assert(mode ~= 'check', 'Backport ' .. name .. ' не подготовлен: выполни :Lazy build ' .. name
            .. ' либо nvim -l nvim_forge/scripts/prepare-plugins.lua')
        local to = mode == 'revert' and patch.before or patch.after
        local first, last = text:find(from, 1, true)
        assert(first and not text:find(from, last + 1, true), 'Неоднозначный участок backport: ' .. name)
        text = text:sub(1, first - 1) .. to .. text:sub(last + 1)
        assert(vim.fn.sha256(text) == wanted, 'Итоговый SHA256 backport не совпал: ' .. name)
        if raw:find('\r\n', 1, true) then text = text:gsub('\n', '\r\n') end
        return {path=path, file=patch.file, text=text, sha256=wanted}
    end
    return {path=path, file=patch.file, sha256=wanted}
end

local function write_file(plan)
    if not plan.text then return end
    local temporary = plan.path .. '.forge-' .. tostring(vim.uv.hrtime())
    local ok, err = pcall(function()
        local f = assert(io.open(temporary, 'wb'))
        local wrote, write_err = f:write(plan.text)
        local closed, close_err = f:close()
        assert(wrote, write_err); assert(closed, close_err)
        assert(vim.uv.fs_chmod(temporary, assert(vim.uv.fs_stat(plan.path)).mode))
        assert(vim.uv.fs_rename(temporary, plan.path))
    end)
    if not ok then vim.uv.fs_unlink(temporary); error(err) end
    assert(vim.fn.sha256((read(plan.path):gsub('\r\n', '\n'))) == plan.sha256,
        'Проверка записанного backport не прошла')
end

function M.run(name, dir, mode)
    local patch = assert(patches[name], 'Неизвестный backport: ' .. name)
    assert(mode == 'apply' or mode == 'check' or mode == 'revert', 'Неизвестный режим backport')
    -- Не искать Git в родительском checkout экспортированного архива.
    if vim.uv.fs_stat(dir .. '/.git') then
        local head = vim.system({ 'git', '-C', dir, 'rev-parse', 'HEAD' }, { text = true }):wait()
        assert(head.code == 0 and vim.trim(head.stdout or '') == patch.revision,
            'Backport: неизвестная ревизия ' .. name .. '; ожидается ' .. patch.revision)
    end
    -- Неизвестный companion отклоняется до записи любого файла плагина.
    local plans = { plan_file(name, dir, patch, mode) }
    for _, extra in ipairs(patch.extra or {}) do plans[#plans+1] = plan_file(name, dir, extra, mode) end
    for _, plan in ipairs(plans) do write_file(plan) end
    local result = { id=patch.id, revision=patch.revision, sha256=plans[1].sha256 }
    if #plans > 1 then
        result.files = {}
        for _, plan in ipairs(plans) do result.files[plan.file] = plan.sha256 end
    end
    return result
end

function M.all(lazy_root, mode)
    local result = {}
    for name in pairs(patches) do result[name] = M.run(name, lazy_root .. '/' .. name, mode) end
    return result
end

return M
