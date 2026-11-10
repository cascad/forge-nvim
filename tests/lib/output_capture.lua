-- Controller side. Only FORGE_OUTPUT_TRACE=1 installs the native observer.
local M={}
function M.start(e,root)
  if vim.env.FORGE_OUTPUT_TRACE~='1' then return end
  for _,name in ipairs({'output_capture.lua','output_capture_native.lua','output_policy.lua'}) do
    assert(vim.uv.fs_copyfile(root..'/tests/lib/'..name,e.dir..'/'..name))
  end
  e:lua([[dofile(...)]],{root..'/tests/lib/output_capture_native.lua'})
  e.output_inputs={}
  local request=e.rpc.request
  e.rpc.request=function(rpc,method,args)
    local started=vim.uv.hrtime()
    local result=request(rpc,method,args)
    if method=='nvim_input' then e.output_inputs[#e.output_inputs+1]={ns=started,keys=args[1],accepted=result} end
    return result
  end
  e.output_request=request
end
function M.snapshot(e,stop)
  if not e.output_request then return end
  local ok,result=pcall(e.lua,e,stop and [[return _G.forge_output_capture.stop()]] or [[return _G.forge_output_capture.snapshot()]])
  return {native=ok and result or nil,error=not ok and tostring(result) or nil,inputs=vim.deepcopy(e.output_inputs)}
end
function M.finish(e)
  if not e.output_request then return end
  local result=M.snapshot(e,true)
  e.rpc.request=e.output_request;e.output_request=nil
  vim.fn.writefile({vim.json.encode(result)},e.dir..'/output-capture.json')
  assert(not result.error,result.error)
  -- Raw keycodes are bytes, not UTF-8. Keep JSON interoperable for audits.
  for _,row in ipairs(result.native.rows) do
    if row.kind=='key' then
      for _,field in ipairs({'key','typed'}) do
        assert(not row.fields[field]:find('[\128-\255]'),'Non-ASCII key display')
        assert(row.fields[field..'_hex']:match('^[0-9a-f]*$'),'Invalid raw key hex')
      end
    end
  end
end
return M
