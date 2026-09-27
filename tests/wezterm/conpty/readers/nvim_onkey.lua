-- Читатель «nvim»: журнал клавиш, которые получил nvim --clean
-- (add-nvim-chords-on-windows, design, решение 6). Строка на клавишу:
-- keytrans(typed) — запись nvim. Путь журнала — $FORGE_KEYLOG.
-- Пишется сразу (flush): стенд читает журнал, пока nvim работает.
local f = assert(io.open(assert(os.getenv('FORGE_KEYLOG')), 'w'))
f:write('ready\n')
f:flush()
vim.on_key(function(key, typed)
  local t = (typed and typed ~= '') and typed or key
  f:write(vim.fn.keytrans(t) .. '\n')
  f:flush()
end)
