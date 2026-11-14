-- spec: IDE-BOOT-12. Только явная регистрация; никогда не пишет существующий файл.
local M = {}
local uv, join = vim.uv, vim.fs.joinpath
local win = uv.os_uname().sysname == 'Windows_NT'
local function canonical(path)
  path = vim.fs.normalize(vim.fn.fnamemodify(path,':p')):gsub('/+$','')
  return win and path:lower() or path
end
local function inside(path, root)
  path,root=canonical(path),canonical(root)
  return path==root or path:sub(1,#root+1)==root..'/'
end
local function bytes(path)
  local file=assert(io.open(path,'rb'));local value=file:read('*a');file:close();return value
end
local function no_links(path)
  local current=vim.fn.fnamemodify(path,':p')
  while current do
    local stat=uv.fs_lstat(current)
    assert(not stat or stat.type~='link','Linked command directory/file: '..current)
    local parent=vim.fs.dirname(current);if parent==current then break end;current=parent
  end
end
local function shell_quote(value) return "'"..value:gsub("'","'\\''").."'" end

function M.plan(kit, directory)
  if not directory or directory=='' then return nil end
  directory=vim.fs.normalize(vim.fn.fnamemodify(directory,':p'))
  assert(not inside(directory,kit),'Command directory must be outside installation')
  no_links(directory)
  local payloads
  if win then
    local ps="& '"..join(kit,'bin/fride.ps1'):gsub("'","''").."' @args\r\nexit $LASTEXITCODE\r\n"
    -- Не публиковать fride.ps1 рядом с fride.cmd: PowerShell выберет script и
    -- заблокирует обычное имя при Restricted, ещё до входа в наш launcher.
    payloads={['.fride-command.ps1']='\239\187\191'..ps,
      ['fride.cmd']='@echo off\r\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0.fride-command.ps1" %*\r\nexit /b %errorlevel%\r\n'}
  else
    payloads={fride='#!/usr/bin/env bash\nexec '..shell_quote(join(kit,'bin/fride'))..' "$@"\n'}
  end
  local receipt_path=join(directory,'.fride-command.json')
  local names=win and {'fride','fride.exe','fride.com','fride.cmd','fride.bat','fride.ps1'} or {'fride'}
  local function conflict(path) error('Command conflict; existing file preserved: '..path,0) end
  local function inspect()
    no_links(directory);no_links(receipt_path)
    local directory_stat=uv.fs_stat(directory)
    assert(not directory_stat or directory_stat.type=='directory','Command directory is not a directory: '..directory)
    local receipt
    if uv.fs_lstat(receipt_path) then
      local ok,value=pcall(function() return vim.json.decode(bytes(receipt_path)) end)
      if not ok or type(value)~='table' or value.schema~=1 or value.product~='forge-nvim'
        or type(value.kit)~='string' or canonical(value.kit)~=canonical(kit) or type(value.files)~='table' then conflict(receipt_path) end
      receipt=value
      for name in pairs(receipt.files) do if not payloads[name] then conflict(receipt_path) end end
      for name,payload in pairs(payloads) do
        if receipt.files[name]~=vim.fn.sha256(payload) then conflict(receipt_path) end
      end
    end
    local local_names=vim.deepcopy(names)
    if win then local_names[#local_names+1]='.fride-command.ps1' end
    for _,name in ipairs(local_names) do
      local path=join(directory,name);local stat=uv.fs_lstat(path)
      if stat and (stat.type~='file' or not receipt or not payloads[name] or bytes(path)~=payloads[name]) then conflict(path) end
    end
    -- Пустой POSIX PATH entry означает cwd; пустой Windows entry не регистрирует cwd.
    for _,dir in ipairs(vim.split(vim.env.PATH or '',win and ';' or ':',{plain=true,trimempty=win})) do
      if dir~='' or not win then
        if dir=='' then dir=uv.cwd() end
        if win and dir:sub(1,1)=='"' and dir:sub(-1)=='"' then dir=dir:sub(2,-2) end
        for _,name in ipairs(names) do
          local path=join(dir,name)
          if uv.fs_stat(path) and not inside(path,join(kit,'bin')) then
            if canonical(dir)~=canonical(directory) or not receipt or not payloads[name] then conflict(path) end
          end
        end
      end
    end
    return receipt
  end
  inspect() -- До любых изменений kit.
  local plan={directory=directory,files=payloads}
  local created={}
  function plan.rollback()
    for _,item in ipairs(created) do
      local stat=uv.fs_lstat(item.path)
      if stat and stat.type=='file' and stat.ino==item.ino then assert(uv.fs_unlink(item.path)) end
    end
    created={}
  end
  function plan.apply()
    local receipt=inspect() -- Setup мог занять время; проверить конфликт повторно.
    assert(vim.fn.mkdir(directory,'p')==1 or uv.fs_stat(directory),'Cannot create command directory')
    local function create(path,payload,mode)
      no_links(path)
      local fd,err=uv.fs_open(path,'wx',mode);assert(fd,err)
      created[#created+1]={path=path,ino=assert(uv.fs_fstat(fd)).ino}
      local written,write_err=uv.fs_write(fd,payload,0);local closed,close_err=uv.fs_close(fd)
      assert(written==#payload,write_err);assert(closed,close_err);assert(uv.fs_chmod(path,mode))
    end
    local ok,err=pcall(function()
      local hashes={}
      for name,payload in pairs(payloads) do
        hashes[name]=vim.fn.sha256(payload)
        local path=join(directory,name)
        if not uv.fs_lstat(path) then create(path,payload,win and 420 or 493) end
      end
      if not receipt then create(receipt_path,vim.json.encode({schema=1,product='forge-nvim',kit=kit,files=hashes})..'\n',420) end
    end)
    if not ok then
      plan.rollback()
      error(err,0)
    end
    return join(directory,win and 'fride.cmd' or 'fride')
  end
  return plan
end

return M
