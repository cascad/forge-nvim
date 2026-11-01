-- Общий compiler cache; Go сам проверяет ключи/версии и ограничивает его срок.
local M = {}
function M.path(root)
  local path = vim.env.FORGE_E2E_GO_CACHE
  if not path or path == '' then
    -- Windows: один повторно используемый cache на диске checkout, включая
    -- прямой focused запуск. В Docker нужен быстрый native FS гостя.
    path = vim.fn.has('win32') == 1 and (root .. '/.tests/tmp/go-build-cache')
      or (vim.fn.tempname() .. '-forge-go-cache')
  end
  assert(vim.fs.normalize(path) == vim.fs.normalize(vim.fn.fnamemodify(path, ':p')),
    'Go cache должен иметь абсолютный путь')
  return path
end
return M
