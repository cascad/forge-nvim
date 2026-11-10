-- Собственные группы фиксируются при реальном spawn, до исчезновения parent.
local ffi=require('ffi')
ffi.cdef[[int getpgid(int);]]
local observer=[=[
local ffi=require('ffi');ffi.cdef[[int getpgid(int);]]
local root_group=ffi.C.getpgid(0)
local ledger=__FORGE_SCOPE_LEDGER__
local function register(pid,api)
  if not pid or pid<=1 then return end
  local group=ffi.C.getpgid(pid)
  if group<0 and vim.uv.kill(-pid,0) then group=pid end
  if group>1 and group~=root_group then
    local row=vim.json.encode({pid=pid,group=tonumber(group),api=api})..'\n'
    local file=assert(vim.uv.fs_open(ledger,'a',384))
    local count,err=vim.uv.fs_write(file,row,-1)
    vim.uv.fs_close(file)
    assert(count==#row,err or 'Не записана собственная process group')
  end
end
local spawn=vim.uv.spawn
local function pack(...) return {n=select('#',...),...} end
vim.uv.spawn=function(command,options,...)
  local result=pack(spawn(command,options,...))
  if result[1] then register(result[2],'uv.spawn') end
  return unpack(result,1,result.n)
end
for _,name in ipairs({'jobstart','termopen'}) do
  local original,api=vim.fn[name],name
  vim.fn[name]=function(...)
    local job=original(...)
    if type(job)=='number' and job>0 then register(vim.fn.jobpid(job),api) end
    return job
  end
end
]=]
local M={}
function M.new()
  local self={kind='posix-group',spawn_options={detach=true},groups={}}
  function self:command(argv,options)
    self.ledger=options.artifacts and (options.artifacts..'/process-groups-'..tostring(vim.uv.hrtime())..'.jsonl')
      or (vim.fn.tempname()..'-process-groups.jsonl')
    local file=assert(vim.uv.fs_open(self.ledger,'wx',384));vim.uv.fs_close(file)
    local code=observer:gsub('__FORGE_SCOPE_LEDGER__',function() return vim.inspect(self.ledger) end)
    local prepared={argv[1],'--cmd','lua '..code:gsub('\n',' ')}
    for i=2,#argv do prepared[#prepared+1]=argv[i] end
    return prepared
  end
  function self:attach(pid)
    assert(pid>1 and pid~=vim.uv.os_getpid(),'Недопустимый own PGID')
    local group=ffi.C.getpgid(pid)
    assert(group==pid or (group<0 and ffi.errno()==3),'Child не стал лидером своей process group')
    self.pid=pid
    self.groups[pid]={group=pid,pid=pid,api='root'}
  end
  function self:register(info)
    assert(type(info)=='table' and type(info.group)=='number' and type(info.pid)=='number',
      'Неверный native process group record')
    assert(info.group>1 and info.group%1==0 and info.pid>1 and info.pid%1==0,
      'Недопустимая собственная process group')
    assert(info.group~=ffi.C.getpgid(0),'Запрещена регистрация process group runner')
    assert(info.api=='jobstart' or info.api=='termopen' or info.api=='uv.spawn','Неизвестный источник группы')
    self.groups[info.group]=self.groups[info.group] or vim.deepcopy(info)
  end
  function self:close()
    if self.result then return self.result end
    local start=vim.uv.hrtime()
    local data={backend=self.kind,pid=self.pid,ledger=self.ledger,stages={},groups={}}
    local ok,err=xpcall(function()
      if self.ledger then
        for _,row in ipairs(vim.fn.readfile(self.ledger)) do self:register(vim.json.decode(row)) end
      end
      for _,id in ipairs(vim.tbl_keys(self.groups)) do data.groups[#data.groups+1]=vim.deepcopy(self.groups[id]) end
      table.sort(data.groups,function(a,b) return a.group<b.group end)
      local function active()
        local ps=vim.system({'ps','-ax','-o','pgid=','-o','stat='},{text=true,timeout=2000}):wait()
        assert(ps.code==0,'Не удалось проверить own process groups: '..tostring(ps.stderr))
        local live={}
        for line in ps.stdout:gmatch('[^\n]+') do
          local group,state=line:match('^%s*(%d+)%s+(%S+)')
          group=tonumber(group)
          if self.groups[group] and state:sub(1,1)~='Z' then live[group]=true end
        end
        return live
      end
      local before=active();data.active_before=next(before)~=nil
      local function signal(live,value,label)
        for id in pairs(live) do
          data.stages[#data.stages+1]={group=id,signal=label}
          local sent,why=vim.uv.kill(-id,value)
          assert(sent or not active()[id],tostring(why))
        end
      end
      if next(before) then
        signal(before,15,'sigterm')
        if not vim.wait(2000,function() return not next(active()) end,25) then
          signal(active(),9,'sigkill')
          assert(vim.wait(2000,function() return not next(active()) end,25),'Own process groups ещё исполняются')
        end
      end
      local after=active();data.active_after=next(after)~=nil
      for _,item in ipairs(data.groups) do
        item.active_before=not not before[item.group];item.active_after=not not after[item.group]
      end
    end,debug.traceback)
    data.ok=ok;data.error=not ok and tostring(err) or nil
    data.elapsed_ms=(vim.uv.hrtime()-start)/1e6
    self.result=data
    return data
  end
  return self
end
return M
