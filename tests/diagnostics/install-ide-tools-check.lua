local root,base=assert(vim.env.FORGE_IDE_ROOT),arg[2]
local context=dofile(root..'/tests/diagnostics/install-ide-tools-registry.lua')
local mode=arg[1]
local before={};for _,name in ipairs({'GOPATH','GOMODCACHE','GOCACHE','GOBIN','GOROOT','CARGO_HOME','RUSTUP_HOME','VIRTUAL_ENV','GOTOOLCHAIN','RUSTUP_AUTO_INSTALL'}) do before[name]=vim.env[name] or vim.NIL end
local ok,err=xpcall(function()
 context.setup()
 local refreshed=false;require('mason-registry').refresh(function() refreshed=true end)
 assert(vim.wait(5000,function() return refreshed end,10))
 if mode=='ready' or mode=='failure' then
  local report=require('forge.setup_readiness').tools(context.names,context.versions)
  vim.fn.writefile({vim.json.encode(report)},base..'/check.json')
 elseif mode=='repeat' then
  require('mason-tool-installer').setup({ensure_installed=vim.tbl_map(function(n) return {n,version=context.versions[n]} end,context.names),run_on_start=false,auto_update=false,integrations={['mason-lspconfig']=false,['mason-null-ls']=false,['mason-nvim-dap']=false}})
  vim.cmd('runtime plugin/mason-tool-installer.lua');vim.cmd('MasonToolsInstallSync')
  require('forge.setup_readiness').tools(context.names,context.versions)
 elseif mode=='format' or mode=='project' then
  require('mason-registry').refresh=function() error('Unexpected registry refresh while formatting') end
  require('mason-core.package').install=function() error('Unexpected tool installation while formatting') end
  vim.opt.rtp:prepend(vim.env.FORGE_E2E_DEPS..'/lazy/conform.nvim')
  local spec=require('plugins.format')[1];spec.config(nil,vim.deepcopy(spec.opts))
  local outputs={}
  for _,item in ipairs(mode=='format' and {{'sample.lua','lua'},{'sample.go','go'},{'sample.json','json'}} or {{'project/sample.json','json'}}) do
   vim.cmd.edit(vim.fn.fnameescape(base..'/'..item[1]));vim.bo.filetype=item[2]
   local failure;require('conform').format({async=false,timeout_ms=15000,lsp_format='never'},function(e) failure=e end)
   assert(not failure,vim.inspect(failure));outputs[item[1]]=table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')
   outputs.available=require('conform').list_formatters(0)
   outputs.script=require('forge.node').script('prettier','bin/prettier.cjs',base..'/'..item[1])
   vim.bo.modified=false
  end
  vim.fn.writefile({vim.json.encode(outputs)},base..'/consumer.json')
 elseif mode=='lsp' then
  require('mason-registry').refresh=function() error('Unexpected registry refresh at LSP startup') end
  require('mason-core.package').install=function() error('Unexpected tool installation at LSP startup') end
  for name in vim.fs.dir(vim.env.FORGE_E2E_DEPS..'/lazy') do vim.opt.rtp:prepend(vim.env.FORGE_E2E_DEPS..'/lazy/'..name) end
  for _,spec in ipairs(require('plugins.lsp')) do if spec[1]=='neovim/nvim-lspconfig' then spec.config() end end
  local path=base..'/project/main.go';vim.cmd.edit(vim.fn.fnameescape(path));vim.bo.filetype='go'
  local client
  assert(vim.wait(30000,function() client=vim.lsp.get_clients({bufnr=0,name='gopls'})[1];return client and client.initialized end,25),'gopls did not attach')
  local line=vim.api.nvim_buf_get_lines(0,1,2,false)[1]
  local response=client:request_sync('textDocument/definition',{textDocument={uri=vim.uri_from_fname(path)},position={line=1,character=assert(line:find('Twice',1,true))-1}},15000,0)
  assert(response and not response.err and response.result and #response.result>0,vim.inspect(response))
  local target=response.result[1].uri or response.result[1].targetUri;assert(target:find('defs.go',1,true),target)
  vim.fn.writefile({vim.json.encode({cmd=client.config.cmd,target=target})},base..'/consumer.json')
  client:stop(true);vim.wait(3000,function() return client:is_stopped() end,20)
 else error('Unknown case '..mode) end
 for name,value in pairs(before) do assert((vim.env[name] or vim.NIL)==value,'SDK env changed: '..name) end
end,debug.traceback)
if not ok then io.stderr:write(err..'\n');vim.cmd('cquit 1') end
vim.cmd('qa!')
