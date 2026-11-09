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
  function self:close()
    if self.result then return self.result end
    local start=vim.uv.hrtime()
    local data={backend=self.kind,pid=self.pid,gate_released=self.released or false}
    local ok,err=xpcall(function()
      local function active()
        local accounting=ffi.new('forge_job_accounting')
        assert(kernel.QueryInformationJobObject(handle,1,accounting,ffi.sizeof(accounting),nil)~=0,
          failure('QueryInformationJobObject'))
        return tonumber(accounting.ActiveProcesses)
      end
      data.active_before=active()
      data.terminated=data.active_before>0
      if data.terminated then
        assert(kernel.TerminateJobObject(handle,1)~=0,failure('TerminateJobObject'))
        assert(vim.wait(2000,function() return active()==0 end,10),'Job Object всё ещё содержит процессы')
      end
      data.active_after=active()
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
