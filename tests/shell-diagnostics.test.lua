-- Unit-проверки парсера отчёта IDE-001; CLI e2e зарегистрированы отдельно.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
require('python_case').run(root, 'tests/shell_diagnostics_test.py', 'DiagnosticsTest', 'IDE-001 пассивная диагностика: 12 unit-проверок')
