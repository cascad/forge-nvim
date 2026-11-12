-- spec: IDE-TEST-7. Граница native adapter: контейнер workspace не является пакетом.
local M = {}

function M.wrap(adapter)
    local build = adapter.build_spec
    local wrapped = vim.tbl_extend('force', {}, adapter)
    wrapped.build_spec = function(args)
        -- Следующий файл после exit может возобновиться в fast event; backend использует vim.fn.
        if vim.in_fast_event() then require('nio').scheduler() end
        if not args.tree then return build(args) end
        local pos = args.tree:data()
        local dir = pos.type == 'dir' and pos.path or vim.fs.dirname(pos.path)
        -- Public nil fallback Neotest разбивает неподдержанный каталог на файлы.
        -- Штатный fs.root завершится на корне диска, в отличие от backend walk до HOME.
        if not vim.fs.root(dir, 'go.mod')
            or (pos.type == 'dir' and vim.fn.filereadable(pos.path .. '/go.work') == 1) then
            return nil
        end
        return build(args)
    end
    return wrapped
end

return M
