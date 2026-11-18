-- IDE-BOOT-42. Fixture package/receipt, actual setup stage + Mason process + native Go.
local config=vim.json.decode(table.concat(vim.fn.readfile(assert(vim.env.FRIDE_GO_POLICY_CONFIG)),'\n'))
vim.opt.rtp:append(config.mason)
package.loaded['forge.tool_catalog']={mason=function() return {'gopls'} end,versions=function() return {gopls='fixture'} end}
package.loaded['mason-registry']={get_package=function() error('Fixture package requires build') end}
local report={before_policy=vim.env.GOTOOLCHAIN,policy=vim.env.FRIDE_SETUP_GO_TOOLCHAIN,
  initial=vim.g.fride_go_policy_initial}
local process
if config.late_policy then
  local current=vim.env.GOTOOLCHAIN
  vim.env.GOTOOLCHAIN='local';require('mason-core.process');vim.env.GOTOOLCHAIN=current
end
vim.api.nvim_create_user_command('Lazy',function()
  process=require('mason-core.process')
  local env={}
  for _,entry in ipairs(process.graft_env({})) do local k,v=entry:match('^([^=]+)=(.*)$');env[k]=v end
  report.captured={GOTOOLCHAIN=env.GOTOOLCHAIN,GOENV=env.GOENV,GOPROXY=env.GOPROXY,GOSUMDB=env.GOSUMDB}
end,{nargs='*'})
local readiness=require('forge.setup_readiness')
-- The fixture models one package; native build and exported executable are mandatory.
readiness.tools=function()
  assert(vim.fn.executable(config.binary)==1,'Native Go did not export the IDE tool')
  return {packages=1}
end
vim.api.nvim_create_user_command('MasonToolsInstallSync',function()
  local out,err={},{}
  local done=false
  local handle=process.spawn('go',{args={'install','.'},cwd=config.project,
    env=process.graft_env({GOBIN=config.bin}),stdio_sink={stdout=function(_,v) out[#out+1]=v end,
      stderr=function(_,v) err[#err+1]=v end}},function(success,code,signal)
    report.success=success;report.code=code;report.signal=signal;done=true
  end)
  assert(handle,'Native Go spawn failed')
  if not vim.wait(45000,function() return done end,10) then
    pcall(function() handle:kill(9) end);error('Native Go fixture build timed out')
  end
  report.stdout=table.concat(out);report.stderr=table.concat(err)
  assert(vim.fn.writefile({vim.json.encode(report)},config.report)==0)
  assert(report.success,'Native Go build failed: '..report.stdout..report.stderr)
end,{})
dofile(config.stage)
