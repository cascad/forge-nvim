-- Частный runtime e2e: явное владение и удаление только созданного профиля.
local M = {}
local uv = vim.uv
local marker = '.forge-e2e-owner.json'
local function normalized(path) return vim.fs.normalize(path):gsub('\\', '/') end
local function absolute(path)
  return path and path~='' and normalized(path)==normalized(vim.fn.fnamemodify(path, ':p'))
end

function M.create(root)
  local base = vim.env.FORGE_TEST_TMPDIR
  if not base or base=='' then
    if vim.fn.has('win32')==1 then
      -- На Windows место берётся с диска checkout, а не системного C:.
      base = root .. '/.tests/tmp'
    else
      local name = vim.fn.tempname()
      assert(absolute(name), 'Не удалось получить абсолютный путь временной папки')
      base = vim.fn.fnamemodify(name, ':h')
    end
  end
  assert(absolute(base), 'FORGE_TEST_TMPDIR должен быть абсолютным путём')
  vim.fn.mkdir(base, 'p')
  local parent = assert(uv.fs_realpath(base))
  local token = tostring(uv.os_getpid()) .. '-' .. tostring(uv.hrtime())
  local path = base .. '/' .. token .. '-forge-editor'
  assert(not uv.fs_lstat(path), 'Runtime уже существует: '..path)
  assert(uv.fs_mkdir(path, 448))
  local profile = { path=path, canonical=assert(uv.fs_realpath(path)), parent=parent,
    root=assert(uv.fs_realpath(root)), token=token }
  vim.fn.writefile({vim.json.encode({root=profile.root,path=profile.canonical,token=token})},path..'/'..marker)
  return profile
end

function M.remove(profile)
  if profile.removed then return end
  local stat = uv.fs_lstat(profile.path)
  if not stat then profile.removed=true;return end
  assert(stat.type=='directory', 'Runtime заменён ссылкой/файлом: '..profile.path)
  local real = assert(uv.fs_realpath(profile.path))
  assert(real==profile.canonical and absolute(real), 'Runtime сменил путь')
  local parent = normalized(profile.parent)..'/'
  local name = normalized(real)
  assert(name:sub(1,#parent)==parent and not name:sub(#parent+1):find('/',1,true)
    and name:match('%-forge%-editor$'), 'Runtime вне ожидаемой временной папки')
  local owner=vim.json.decode(table.concat(vim.fn.readfile(profile.path..'/'..marker),'\n'))
  assert(owner.root==profile.root and owner.path==profile.canonical and owner.token==profile.token,
    'Маркер владения runtime не совпадает: '..profile.path)
  -- Windows может кратковременно удерживать log/telemetry после завершения
  -- процесса. Маркер сохраняется до удаления остальных данных, чтобы cleanup
  -- можно было безопасно повторить и после частичного удаления.
  local function clear_children()
    local clear=true
    for child,kind in vim.fs.dir(profile.path) do
      if child~=marker then
        local flags=kind=='directory' and 'rf' or ''
        if vim.fn.delete(profile.path..'/'..child,flags)~=0 then clear=false end
      end
    end
    return clear
  end
  assert(vim.wait(5000,clear_children,50), 'Не удалось очистить runtime: '..profile.path)
  assert(vim.fn.delete(profile.path..'/'..marker)==0, 'Не удалось удалить маркер runtime')
  assert(vim.fn.delete(profile.path,'d')==0, 'Не удалось удалить пустой runtime: '..profile.path)
  profile.removed=true
end

return M
