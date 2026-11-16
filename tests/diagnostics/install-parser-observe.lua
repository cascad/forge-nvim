local base = arg[1]
local ok, err = xpcall(function()
    local runtime = require('forge.parser_runtime')
    local own = runtime.site()
    local report = runtime.check(require('forge.tool_catalog').parsers())
    local file = base .. '/sample.lua'
    vim.fn.writefile({'local answer = 40 + 2', 'return answer'}, file)
    vim.cmd.edit(vim.fn.fnameescape(file))
    vim.bo.filetype = 'lua'
    local tree = vim.treesitter.get_parser(0, 'lua'):parse()[1]
    assert(not tree:root():has_error(), tree:root():sexpr())
    local query = assert(vim.treesitter.query.get('lua', 'highlights'))
    local captures = 0
    for _ in query:iter_captures(tree:root(), 0) do captures = captures + 1 end
    assert(captures > 0, 'No actual highlight captures')
    local found = vim.api.nvim_get_runtime_file('parser/lua.so', false)[1]
    assert(vim.fs.normalize(found) == vim.fs.normalize(own .. '/parser/lua.so'), 'Owned parser was shadowed: ' .. tostring(found))
    report.captures, report.tree, report.library = captures, tree:root():sexpr(), found
    vim.fn.writefile({vim.json.encode(report)}, base .. '/parser.json')
end, debug.traceback)
if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
