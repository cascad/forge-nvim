-- Настоящий CLI инструмента, отдельный процесс и временный HOME на любой ОС.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
require('python_case').run(root, 'tests/shell_diagnostics_test.py', 'DiagnosticsCLITest', 'IDE-001 диагностический CLI: e2e на временном HOME')
