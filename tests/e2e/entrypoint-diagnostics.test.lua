local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
require('python_case').run(root,'tests/shell_diagnostics_test.py','TestCLIProbeContract',
  'CLI diagnostics: exit/output, timeout без retry, ошибка spawn')
