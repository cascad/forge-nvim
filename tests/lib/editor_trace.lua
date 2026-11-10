-- Test-only quit capture. Write-returned не является подтверждением доставки.
local M={}
local uv=vim.uv
function M.new(options)
  if vim.env.FORGE_E2E_QUIT_TRACE=='0' then return end -- только bounded unhooked control
  if not options.artifacts then return end
  local self={start=uv.hrtime(),detail=options.trace_detail==true or vim.env.FORGE_E2E_RPC_TRACE=='1',count=0,dropped=0,
    controller=options.artifacts..'/quit-controller.jsonl',native=options.artifacts..'/quit-native.jsonl'}
  local lib=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h')
  local copy=options.artifacts..'/driver-source';vim.fn.mkdir(copy,'p')
  local sources={}
  for _,name in ipairs({'editor_rpc.lua','editor_process.lua','editor_trace.lua',
    'process_scope.lua','process_scope_windows.lua','process_scope_posix.lua'}) do
    assert(uv.fs_copyfile(lib..'/'..name,copy..'/'..name))
    local raw=table.concat(vim.fn.readfile(copy..'/'..name,'b'),'\n')
    sources[name]={bytes=#raw,sha256=vim.fn.sha256(raw)}
  end
  vim.fn.writefile({vim.json.encode({sources=sources,nvim=vim.v.progpath,detail=self.detail})},options.artifacts..'/driver-source.json')
  function self:emit(kind,fields,detail)
    if detail and not self.detail then return end
    if detail then
      if self.count>=256 then self.dropped=self.dropped+1;return end
      self.count=self.count+1
    end
    local ok,err=pcall(function()
      local row=vim.json.encode({kind=kind,ms=(uv.hrtime()-self.start)/1e6,fields=fields})..'\n'
      local file=assert(uv.fs_open(self.controller,'a',384))
      local written,problem=uv.fs_write(file,row,-1);uv.fs_close(file)
      assert(written==#row,problem)
    end)
    if not ok then self.error=tostring(err) end
  end
  function self:summary()
    return {controller=self.controller,native=self.native,detail=self.detail,dropped=self.dropped,error=self.error}
  end
  function self:prepare(argv)
    local observer=options.artifacts..'/quit-observer.lua'
    local code=([[
local uv=vim.uv
local path=%s
local start=%s
local function record(kind)
  pcall(function()
    local row=vim.json.encode({kind=kind,ms=(uv.hrtime()-start)/1e6,pid=uv.os_getpid(),
      mode=vim.api.nvim_get_mode(),exiting=vim.v.exiting,dying=vim.v.dying})..'\n'
    local file=assert(uv.fs_open(path,'a',384))
    local written,err=uv.fs_write(file,row,-1);uv.fs_close(file)
    assert(written==#row,err)
  end)
end
record('observer_ready')
vim.api.nvim_create_autocmd({'QuitPre','VimLeavePre','VimLeave'},{callback=function(ev) record(ev.event) end})
]]):format(vim.inspect(self.native),string.format('%.0f',self.start))
    vim.fn.writefile(vim.split(code,'\n',{plain=true}),observer)
    local prepared={argv[1],'--cmd','lua dofile('..vim.inspect(observer)..')'}
    for i=2,#argv do prepared[#prepared+1]=argv[i] end
    return prepared
  end
  self:emit('recorder_ready',{detail=self.detail})
  return self
end
return M
