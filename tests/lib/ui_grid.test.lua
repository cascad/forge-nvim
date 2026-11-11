local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
require('python_case').run(root,'tests/lib/ui_grid_test.py','GridTests','UI-GRID native replay contract')
