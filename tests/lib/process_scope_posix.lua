-- Собственная session/process group; процессы других тестов в неё не входят.
local ffi=require('ffi')
ffi.cdef[[int getpgid(int);]]
local M={}
function M.new()
  local self={kind='posix-group',spawn_options={detach=true}}
  function self:command(argv) return argv end
  function self:attach(pid)
    assert(pid>1 and pid~=vim.uv.os_getpid(),'Недопустимый own PGID')
    assert(ffi.C.getpgid(pid)==pid,'Тестовый child не стал лидером своей process group')
    self.pid=pid
  end
  function self:close()
    if self.result then return self.result end
    local start=vim.uv.hrtime()
    local data={backend=self.kind,pid=self.pid,stages={}}
    local ok,err=xpcall(function()
      if not self.pid then data.active_after=false;return end
      local function alive()
        if not vim.uv.kill(-self.pid,0) then return false end
        -- Orphan zombie не держит файлов и уже не исполняется. В контейнере
        -- PID 1 может не reap его сразу, хотя живых членов группы больше нет.
        local ps=vim.system({'ps','-ax','-o','pgid=','-o','stat='},{text=true,timeout=2000}):wait()
        assert(ps.code==0,'Не удалось проверить состояния own process group: '..tostring(ps.stderr))
        for line in ps.stdout:gmatch('[^\n]+') do
          local group,state=line:match('^%s*(%d+)%s+(%S+)')
          if tonumber(group)==self.pid and state:sub(1,1)~='Z' then return true end
        end
        return false
      end
      data.active_before=alive()
      if data.active_before then
        data.stages[#data.stages+1]='sigterm'
        local sent,why=vim.uv.kill(-self.pid,15)
        assert(sent or not alive(),tostring(why))
        if not vim.wait(2000,function() return not alive() end,25) then
          data.stages[#data.stages+1]='sigkill'
          local killed,failure=vim.uv.kill(-self.pid,9)
          assert(killed or not alive(),tostring(failure))
          assert(vim.wait(2000,function() return not alive() end,25),'Process group всё ещё исполняется')
        end
      end
      data.active_after=alive()
    end,debug.traceback)
    data.ok=ok;data.error=not ok and tostring(err) or nil
    data.elapsed_ms=(vim.uv.hrtime()-start)/1e6
    self.result=data
    return data
  end
  return self
end
return M
