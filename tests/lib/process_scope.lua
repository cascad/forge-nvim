-- Системная граница тестового каркаса; пользовательский runtime не меняется.
return require(vim.fn.has('win32')==1 and 'process_scope_windows' or 'process_scope_posix')
