-- Explicit diagnostic, never loaded by the product or ordinary editor startup.
local M={}
function M.start(root,host,runtime,dir,pid,seconds)
  assert(vim.fn.has('win32')==1,'Windows-only native assertion observer')
  vim.fn.mkdir(dir,'p')
  local function read(path) return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end
  local marker=read(runtime..'/.forge-e2e-owner.json')
  local request={root=root,runtime=runtime,token=marker.token,output=dir,pid=pid,
    host_pid=host.process.pid,seconds=seconds or 20}
  local worker=dir..'/native_assert_worker.py'
  assert(vim.uv.fs_copyfile(root..'/tests/diagnostics/native_assert_worker.py',worker))
  assert(vim.uv.fs_copyfile(root..'/tests/lib/native_assert.lua',dir..'/native_assert.lua'))
  -- JSON paths are literals for Python; no shell participates in this launch.
  local command='script import runpy; runpy.run_path('..vim.json.encode(worker)..',run_name="__main__")'
  assert(vim.fn.writefile({command,'quit'},dir..'/capture.lldb')==0)
  local key='capture_'..tostring(vim.uv.hrtime())
  local debugger=root..'/.tests/rust-deps/codelldb/extension/lldb'
  for _,name in ipairs({'bin/lldb.exe','bin/liblldb.dll','bin/python312.dll','bin/python3.dll','lib/encodings/__init__.py'}) do
    assert(vim.fn.filereadable(debugger..'/'..name)==1,'Incomplete prepared CodeLLDB: '..name)
  end
  local debugger_pid=host:request('nvim_exec_lua',{[[local debugger,dir,key,runtime=...
    local ffi=require('ffi');ffi.cdef'unsigned long __stdcall SetErrorMode(unsigned long);'
    local kernel=ffi.load('kernel32');local previous=kernel.SetErrorMode(0x8003)
    local ok,process=pcall(vim.system,{debugger..'/bin/lldb.exe','--no-lldbinit','--batch','--source',dir..'/capture.lldb'},
      {text=true,timeout=45000,env={PYTHONHOME=debugger,PYTHONPATH=debugger..'/lib/lldb-python',
        PYTHONDONTWRITEBYTECODE='1',PYTHONNOUSERSITE='1',FORGE_NATIVE_ASSERT_REQUEST=dir..'/request.json',
        HOME=runtime..'/home',USERPROFILE=runtime..'/home',TEMP=runtime..'/tmp',TMP=runtime..'/tmp',TMPDIR=runtime..'/tmp'}},
      vim.schedule_wrap(function(result) vim.fn.writefile({vim.json.encode(result)},dir..'/debugger-exit.json') end))
    kernel.SetErrorMode(previous);assert(ok,process)
    _G[key]=process;return process.pid]],{debugger,dir,key,runtime}})
  request.job_handle=host.scope:duplicate_query_handle(debugger_pid)
  assert(vim.fn.writefile({vim.json.encode(request)},dir..'/request.tmp')==0)
  assert(vim.uv.fs_rename(dir..'/request.tmp',dir..'/request.json'))
  local self={dir=dir,pid=pid,debugger_pid=debugger_pid}
  function self:wait(name,timeout)
    assert(vim.wait(timeout or 20000,function() return vim.fn.filereadable(dir..'/'..name)==1 end,20),
      'Native capture missing '..name..'; '..dir)
    return read(dir..'/'..name)
  end
  function self:ready()
    assert(vim.wait(20000,function() return vim.fn.filereadable(dir..'/ready.json')==1 or vim.fn.filereadable(dir..'/done.json')==1 end,20),
      'Native debugger attach timeout; '..dir)
    if vim.fn.filereadable(dir..'/ready.json')~=1 then error(vim.inspect(read(dir..'/done.json'))) end
    return read(dir..'/ready.json')
  end
  function self:phase(value)
    assert(vim.fn.writefile({vim.json.encode(value)},dir..'/phase.tmp')==0)
    assert(vim.uv.fs_rename(dir..'/phase.tmp',dir..'/phase.json'))
  end
  function self:stop() assert(vim.fn.writefile({'stop'},dir..'/stop')==0);return self:wait('done.json',5000) end
  return self
end
return M
