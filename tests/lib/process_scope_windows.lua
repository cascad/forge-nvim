-- Владение потомками тестового Neovim через анонимный Windows Job Object.
local ffi=require('ffi')
ffi.cdef[[
typedef struct {
  int64_t PerProcessUserTimeLimit, PerJobUserTimeLimit;
  uint32_t LimitFlags;
  uintptr_t MinimumWorkingSetSize, MaximumWorkingSetSize;
  uint32_t ActiveProcessLimit;
  uintptr_t Affinity;
  uint32_t PriorityClass, SchedulingClass;
} forge_job_basic_limits;
typedef struct {
  forge_job_basic_limits BasicLimitInformation;
  uint64_t IoInfo[6];
  uintptr_t ProcessMemoryLimit, JobMemoryLimit, PeakProcessMemoryUsed, PeakJobMemoryUsed;
} forge_job_extended_limits;
typedef struct {
  int64_t TotalUserTime, TotalKernelTime, ThisPeriodTotalUserTime, ThisPeriodTotalKernelTime;
  uint32_t TotalPageFaultCount, TotalProcesses, ActiveProcesses, TotalTerminatedProcesses;
} forge_job_accounting;
void* __stdcall CreateJobObjectW(void*, const uint16_t*);
int __stdcall SetInformationJobObject(void*, int, void*, uint32_t);
int __stdcall QueryInformationJobObject(void*, int, void*, uint32_t, uint32_t*);
int __stdcall AssignProcessToJobObject(void*, void*);
int __stdcall TerminateJobObject(void*, unsigned int);
void* __stdcall OpenProcess(uint32_t, int, uint32_t);
int __stdcall CloseHandle(void*);
uint32_t __stdcall GetLastError(void);
void* __stdcall GetCurrentProcess(void);
int __stdcall DuplicateHandle(void*, void*, void*, void**, uint32_t, int, uint32_t);
]]
local kernel=ffi.load('kernel32')
local M={}
local function failure(operation) return operation..': Windows error '..tonumber(kernel.GetLastError()) end
function M.new()
  local handle=kernel.CreateJobObjectW(nil,nil)
  assert(handle~=nil,failure('CreateJobObjectW'))
  handle=ffi.gc(handle,kernel.CloseHandle)
  local limits=ffi.new('forge_job_extended_limits')
  limits.BasicLimitInformation.LimitFlags=0x2000 -- JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE.
  if kernel.SetInformationJobObject(handle,9,limits,ffi.sizeof(limits))==0 then
    local err=failure('SetInformationJobObject')
    ffi.gc(handle,nil);kernel.CloseHandle(handle);error(err)
  end
  local self={kind='windows-job',spawn_options={}}
  function self:command(argv,options)
    self.gate=(options.artifacts and options.artifacts..'/scope-release-'..tostring(vim.uv.hrtime()))
      or (vim.fn.tempname()..'-scope-release')
    local code='lua if not vim.wait(10000,function() return vim.fn.filereadable('..vim.inspect(self.gate)..
      ')==1 end,10) then vim.api.nvim_err_writeln("Process scope startup barrier timeout"); vim.cmd("cquit 125") end'
    local prepared={argv[1],'--cmd',code}
    for i=2,#argv do prepared[#prepared+1]=argv[i] end
    return prepared
  end
  function self:attach(pid)
    local process=kernel.OpenProcess(0x101,0,pid) -- PROCESS_SET_QUOTA | PROCESS_TERMINATE.
    assert(process~=nil,failure('OpenProcess'))
    local assigned=kernel.AssignProcessToJobObject(handle,process)
    local err=assigned==0 and failure('AssignProcessToJobObject') or nil
    kernel.CloseHandle(process)
    assert(assigned~=0,err)
    self.pid=pid
    assert(vim.fn.writefile({'ready'},self.gate)==0,'Не освобождён startup barrier')
    self.released=true
  end
  function self:active_count()
    local accounting=ffi.new('forge_job_accounting')
    assert(kernel.QueryInformationJobObject(handle,1,accounting,ffi.sizeof(accounting),nil)~=0,
      failure('QueryInformationJobObject'))
    return tonumber(accounting.ActiveProcesses)
  end
  -- Explicit diagnostics receive QUERY rights only to this exact fixture Job.
  -- NULL in QueryInformationJobObject would select libuv's nested immediate Job.
  function self:duplicate_query_handle(pid)
    assert(handle~=nil,'Process scope already closed')
    local ids=ffi.new('uint8_t[?]',8+4096*ffi.sizeof('uintptr_t'))
    assert(kernel.QueryInformationJobObject(handle,3,ids,ffi.sizeof(ids),nil)~=0,
      failure('QueryInformationJobObject process list'))
    local count=tonumber(ffi.cast('uint32_t*',ids)[1])
    local members=ffi.cast('uintptr_t*',ids+8)
    local found=false;for i=0,count-1 do if tonumber(members[i])==pid then found=true;break end end
    assert(found,'Debugger is outside the fixture Job')
    local process=kernel.OpenProcess(0x40,0,pid) -- PROCESS_DUP_HANDLE.
    assert(process~=nil,failure('OpenProcess duplicate recipient'))
    local duplicate=ffi.new('void*[1]')
    local copied=kernel.DuplicateHandle(kernel.GetCurrentProcess(),handle,process,duplicate,4,0,0) -- JOB_OBJECT_QUERY.
    local err=copied==0 and failure('DuplicateHandle query Job') or nil
    kernel.CloseHandle(process);assert(copied~=0,err)
    return tonumber(ffi.cast('uintptr_t',duplicate[0]))
  end
  function self:close()
    if self.result then return self.result end
    local start=vim.uv.hrtime()
    local data={backend=self.kind,pid=self.pid,gate_released=self.released or false}
    local ok,err=xpcall(function()
      data.active_before=self:active_count()
      data.terminated=data.active_before>0
      if data.terminated then
        assert(kernel.TerminateJobObject(handle,1)~=0,failure('TerminateJobObject'))
        assert(vim.wait(2000,function() return self:active_count()==0 end,10),'Job Object всё ещё содержит процессы')
      end
      data.active_after=self:active_count()
    end,debug.traceback)
    ffi.gc(handle,nil)
    local closed=kernel.CloseHandle(handle)~=0
    local close_error=not closed and failure('CloseHandle') or nil
    handle=nil
    if self.gate then vim.uv.fs_unlink(self.gate) end
    data.ok=ok and closed
    data.error=not ok and tostring(err) or close_error
    data.elapsed_ms=(vim.uv.hrtime()-start)/1e6
    self.result=data
    return data
  end
  return self
end
return M
