-- spec: IDE-BOOT-30. Explicit setup only; native Lazy tasks may fail without
-- throwing a Lua error. Keep the source lock even when Lazy rewrites it.
local M = {}
local function read(path)
    local file = assert(io.open(path, 'rb'))
    local data = file:read('*a'); file:close()
    return data
end
local function check(lock, pins)
    local config = require('lazy.core.config')
    local errors, count = {}, 0
    for name in pairs(lock) do
        if not config.plugins[name] and not config.spec.disabled[name] and not config.spec.ignore_installed[name] then
            errors[#errors + 1] = name .. ': locked plugin missing from loaded spec'
        end
    end
    for name, plugin in pairs(config.plugins) do
        if not plugin._.is_local then
            count = count + 1
            local reason
            for _, task in ipairs(plugin._.tasks or {}) do
                if task:has_errors() then
                    reason = task.name .. ': ' .. task:output(vim.log.levels.ERROR)
                    break
                end
            end
            if not reason and not plugin._.installed then reason = 'plugin missing' end
            if not reason and pins then
                local pin = lock[name]
                local info = require('lazy.manage.git').info(plugin.dir)
                if not pin then reason = 'lock entry missing'
                elseif not info or info.commit ~= pin.commit then
                    reason = 'HEAD does not match lock: expected ' .. pin.commit .. ', actual ' .. tostring(info and info.commit)
                end
            end
            if reason then errors[#errors + 1] = name .. ': ' .. reason end
        end
    end
    table.sort(errors)
    assert(#errors == 0, 'Plugin readiness failed:\n' .. table.concat(errors, '\n'))
    return {plugins = count}
end
function M.prepare(before_restore)
    local path = require('lazy.core.config').options.lockfile
    local original = read(path)
    local lock = vim.json.decode(original)
    -- Git for Windows supports long paths per process. Append to inherited
    -- parameters and restore them; never write global or project Git config.
    local saved = {}
    if vim.fn.has('win32') == 1 then
        local count = tonumber(vim.env.GIT_CONFIG_COUNT or '0')
        assert(count and count >= 0 and count % 1 == 0, 'Invalid GIT_CONFIG_COUNT')
        local values = {GIT_CONFIG_COUNT = tostring(count + 1)}
        values['GIT_CONFIG_KEY_' .. count] = 'core.longpaths'
        values['GIT_CONFIG_VALUE_' .. count] = 'true'
        for key, value in pairs(values) do saved[key] = vim.env[key] or false; vim.env[key] = value end
    end
    local ok, result = xpcall(function()
        local manager = require('lazy.manage')
        manager.install({wait = true, lockfile = true, show = false})
        check(lock, false)
        if before_restore then before_restore() end
        -- Native install refreshes Lazy's in-memory lock to current HEADs,
        -- including pre-existing plugins. Restore must still use SOURCE pins.
        -- This integration targets the pinned Lazy version, covered by E2E.
        require('lazy.manage.lock').lock = vim.deepcopy(lock)
        manager.restore({wait = true, show = false})
        return check(lock, true)
    end, debug.traceback)
    for key, value in pairs(saved) do vim.env[key] = value or nil end
    if read(path) ~= original then
        local file = assert(io.open(path, 'wb')); assert(file:write(original)); assert(file:close())
    end
    if not ok then error(result, 0) end
    return result
end
return M
