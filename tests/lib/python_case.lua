-- Общий запуск Python-проверок с протоколом существующего tests/run.lua.
local M = {}

function M.run(root, test_file, class, title)
  -- Разница только в имени системного интерпретатора; сценарии общие.
  local names = vim.fn.has('win32') == 1 and { 'python', 'python3' } or { 'python3', 'python' }
  local python = ''
  for _, name in ipairs(names) do
    python = vim.fn.exepath(name)
    if python ~= '' then break end
  end
  if python == '' then
    io.stdout:write('  SKIP SELF: ' .. title .. ' -- нет Python 3\n')
    os.exit(0)
  end
  local result = vim.system({ python, '-X', 'utf8', '-B', root .. '/' .. test_file, class }, {
    cwd = root, text = true, timeout = 20000,
  }):wait()
  if result.code ~= 0 then
    io.stdout:write('  FAIL SELF: ' .. title .. ' -- код ' .. tostring(result.code) .. '\n')
    io.stderr:write((result.stdout or '') .. (result.stderr or ''))
    os.exit(1)
  end
  io.stdout:write('  ok   SELF: ' .. title .. '\n')
  os.exit(0)
end

return M
