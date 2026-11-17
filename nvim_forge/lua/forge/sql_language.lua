-- spec: IDE-BOOT-34. Upstream Sqruff LSP/formatter, no database prerequisites.
local M = {}
function M.tool(name, root)
    local paths = require('forge.tool_paths')
    local path, explicit = paths.override(name, { root = root,
        global = 'forge_' .. name .. '_executable', env = 'FORGE_' .. name:upper() .. '_EXECUTABLE' })
    if explicit then return path end
    local native = require('forge.native_tools')
    return paths.selected(name, native.executable(name), native.owned(name) and 'fride runtime' or 'PATH/Mason', root)
end
function M.dialect_args(path)
    local explicit = vim.g.forge_sql_dialect or vim.env.FORGE_SQL_DIALECT
    if explicit and explicit ~= '' then return { '--dialect', explicit } end
    local directory = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
    if vim.fs.find({ '.sqruff', '.sqlfluff' }, { path = directory, upward = true })[1] then return {} end
    return { '--dialect', 'ansi' }
end
function M.formatter()
    return {
        command = function(_, ctx) return M.tool('sqruff', ctx.filename) or '__missing_sqruff__' end,
        args = function(_, ctx)
            return vim.list_extend({ 'fix', '--quiet' }, vim.list_extend(M.dialect_args(ctx.filename), { '$FILENAME' }))
        end,
    }
end
function M.setup()
    vim.lsp.config('sqruff', {
        root_dir = function(buf, on_dir)
            local file = vim.api.nvim_buf_get_name(buf)
            if M.tool('sqruff', file) then
                on_dir(vim.fs.root(file, { '.sqruff', '.git' }) or vim.fs.dirname(file))
            end
        end,
        cmd = function(dispatchers, config)
            local tool = assert(M.tool('sqruff', config.root_dir), 'Sqruff is not prepared')
            return vim.lsp.rpc.start({ tool, 'lsp' }, dispatchers, { cwd = config.root_dir })
        end,
    })
    vim.lsp.enable('sqruff')
end
return M
