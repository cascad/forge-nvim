local M = {}
local extensions = {
    'mp4', 'mkv', 'mov', 'avi', 'webm', 'mp3', 'flac', 'wav', 'ogg',
    'png', 'jpg', 'jpeg', 'gif', 'webp', 'ico', 'pdf',
    'exe', 'dll', 'dylib', 'so', 'o', 'a', 'bin', 'wasm', 'pyc', 'class',
    'zip', 'gz', 'bz2', 'xz', '7z', 'rar', 'vsix',
}

local function inspect(path, fs, value)
    if not path or path == '' or path:match('^%a[%w+.-]*://') then return false end
    local ext = path:lower():match('%.([^./\\]+)$')
    local excluded = ext and vim.list_contains(vim.g.forge_binary_extensions or extensions, ext)
    local stat = value(fs.fs_stat(path))
    if not stat or stat.type ~= 'file' then return false end
    if excluded then return true end
    local fd = value(fs.fs_open(path, 'r', 0))
    if not fd then return false end
    local prefix = value(fs.fs_read(fd, 4096, 0)) or ''
    fs.fs_close(fd)
    -- Let Neovim's BOM detection handle Unicode text.
    if prefix:sub(1, 2) == '\255\254' or prefix:sub(1, 2) == '\254\255'
        or prefix:sub(1, 4) == '\0\0\254\255' then return false end
    return prefix:find('\0', 1, true) ~= nil
end

function M.blocked(path)
    return inspect(path, vim.uv, function(result) return result end)
end

function M.preview(path, buf, opts)
    local async = require('plenary.async')
    async.run(function()
        local blocked = inspect(path, async.uv, function(_, result) return result end)
        async.util.scheduler()
        if not vim.api.nvim_win_is_valid(opts.winid) or vim.api.nvim_win_get_buf(opts.winid) ~= buf then return end
        if blocked then
            require('telescope.previewers.utils').set_preview_message(buf, opts.winid, M.message(path))
        else
            require('telescope.previewers').buffer_previewer_maker(path, buf, opts)
        end
    end)
end

function M.message(path)
    return 'Двоичный файл: ' .. vim.fs.basename(path)
end

function M.refuse(path)
    if not M.blocked(path) then return false end
    vim.notify(M.message(path), vim.log.levels.INFO, { title = 'Files' })
    return true
end

function M.setup()
    vim.api.nvim_create_autocmd('BufReadPre', {
        group = vim.api.nvim_create_augroup('ForgeBinaryFiles', { clear = true }),
        callback = function(ev)
            local bo, vars = vim.bo[ev.buf], vim.b[ev.buf]
            if M.blocked(ev.file) then
                vars.forge_before_binary = vars.forge_before_binary or
                    { readonly = bo.readonly, modifiable = bo.modifiable, buftype = bo.buftype }
                bo.readonly, bo.modifiable, bo.buftype = true, false, 'nowrite'
                -- Returning from BufReadPre would let the native read proceed.
                error(M.message(ev.file), 0)
            end
            local original = vars.forge_before_binary
            if original then
                bo.readonly, bo.modifiable, bo.buftype = original.readonly, original.modifiable, original.buftype
                vars.forge_before_binary = nil
            end
        end,
    })
end

return M
