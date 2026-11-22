-- spec: IDE-FILE-10. Files IO yields while Neo-tree owns prompts and rendering.
local async = require('plenary.async')
local fs = async.uv
local uv = vim.uv
local events = require('neo-tree.events')
local log = require('neo-tree.log')
local paths = require('neo-tree.utils')
local M = {}

local function missing(err)
    return err and vim.startswith(err, 'ENOENT:')
end

M.check_destination = async.void(function(destination, on_checked)
    local origin = vim.api.nvim_get_current_win()
    local err = fs.fs_lstat(destination)
    async.util.scheduler()
    if err and not missing(err) then
        log.error('Could not copy to', destination, ':', err)
        return
    end
    if not err and vim.api.nvim_get_current_win() ~= origin then
        log.warn('Copy destination already exists:', destination)
        return
    end
    on_checked(err ~= nil)
end)

-- Resolve the closest existing parent before creating directories, so a link
-- to the source cannot turn a recursive copy into a copy into itself.
local function destination_parent(destination)
    local parent = paths.split_path(destination)
    local absent = {}
    while parent do
        local err, stat = fs.fs_stat(parent)
        if not err then
            if stat.type ~= 'directory' then return 'Not a directory: ' .. parent end
            return nil, parent, absent
        end
        if not missing(err) then return err end
        absent[#absent + 1] = parent
        parent = paths.split_path(parent)
    end
    return 'Destination has no existing parent: ' .. destination
end

local function is_inside_source(source, stat, parent)
    local err, from = fs.fs_realpath(source)
    if err then return err end
    local parent_err, into = fs.fs_realpath(parent)
    if parent_err then return parent_err end
    from, into = paths.normalize_path(from), paths.normalize_path(into)
    local ancestor = into
    if paths.is_windows then from, into = from:lower(), into:lower() end
    if paths.is_subpath(from, into, true) then return 'Cannot copy a directory into itself: ' .. into end

    -- Filesystems such as case-insensitive APFS can resolve two differently
    -- spelled paths to the same directory even after realpath.
    while ancestor and stat.ino ~= 0 do
        local stat_err, entry = fs.fs_stat(ancestor)
        if stat_err then return stat_err end
        if entry.dev == stat.dev and entry.ino == stat.ino then
            return 'Cannot copy a directory into itself: ' .. into
        end
        ancestor = paths.split_path(ancestor)
    end
end

local function copy_entry(source, destination, kind)
    if kind == 'file' then return fs.fs_copyfile(source, destination, { excl = true }) end
    if kind == 'link' then
        local err, target = fs.fs_readlink(source)
        if err then return err end
        local flags = {}
        if paths.is_windows then
            local _, stat = fs.fs_stat(source)
            flags.dir = stat and stat.type == 'directory' or false
        end
        return fs.fs_symlink(target, destination, flags)
    end
    if kind ~= 'directory' then return 'Unsupported file type: ' .. source end

    local scan_err, scan = fs.fs_scandir(source)
    if scan_err then return scan_err end
    local mkdir_err = fs.fs_mkdir(destination, 493)
    if mkdir_err then return mkdir_err end
    while true do
        local name = uv.fs_scandir_next(scan)
        if not name then return nil end
        local child = paths.path_join(source, name)
        local stat_err, stat = fs.fs_lstat(child)
        if stat_err then return stat_err end
        local err = copy_entry(child, paths.path_join(destination, name), stat.type)
        if err then return err end
    end
end

local function copy(source, destination)
    local stat_err, stat = fs.fs_lstat(source)
    if stat_err then return stat_err end
    local parent_err, parent, absent = destination_parent(destination)
    if parent_err then return parent_err end
    if stat.type == 'directory' then
        local err = is_inside_source(source, stat, parent)
        if err then return err end
    end

    async.util.scheduler()
    local before = events.fire_event(events.BEFORE_FILE_ADD, destination) or {}
    if before.handled then return nil, false end

    for i = #absent, 1, -1 do
        local err = fs.fs_mkdir(absent[i], 493)
        if err then return err end
    end
    return copy_entry(source, destination, stat.type), true
end

local function indicate_copy(source)
    local ok, notification = pcall(require, 'fidget.notification')
    if not ok then return end

    local _, name = paths.split_path(source)
    local group, key = 'Files', uv.hrtime()
    notification.notify('Копируется «' .. name .. '»', vim.log.levels.INFO, {
        group = group, key = key, ttl = math.huge, skip_history = true,
    })
    return function(copied)
        if copied then
            notification.notify('Скопировано «' .. name .. '»', vim.log.levels.INFO, {
                group = group, key = key, ttl = 3,
            })
        else
            notification.remove(group, key)
        end
    end
end

M.run = async.void(function(source, destination, on_copied)
    local indicate_done = indicate_copy(source)
    local err, copied = copy(source, destination)
    async.util.scheduler()
    if indicate_done then indicate_done(not err and copied) end
    if err then
        log.error('Could not copy from', source, 'to', destination, ':', err)
    elseif copied then
        events.fire_event(events.FILE_ADDED, destination)
        if on_copied then on_copied(source, destination) end
    end
end)

return M
