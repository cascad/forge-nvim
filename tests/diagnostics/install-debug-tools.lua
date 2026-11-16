-- IDE-BOOT-23. Real Mason compiler/download/link and existing debugger config.
local root,base=assert(vim.env.FORGE_IDE_ROOT),arg[2]
package.path=root..'/nvim_forge/lua/?.lua;'..package.path
vim.opt.rtp:prepend(root..'/nvim_forge')
local deps=assert(vim.env.FORGE_E2E_DEPS)
vim.fn.mkdir(vim.fn.stdpath('state'),'p')
vim.opt.rtp:prepend(deps..'/lazy/mason.nvim');vim.opt.rtp:prepend(deps..'/lazy/mason-tool-installer.nvim')
local win=vim.fn.has('win32')==1
local osname=win and 'win32' or vim.fn.has('macunix')==1 and 'darwin' or 'linux'
local machine=vim.uv.os_uname().machine:lower()
local arch=(machine:find('arm') or machine=='aarch64') and 'arm64' or 'x64'
local definitions={
 codelldb={schema='registry+v1',name='codelldb',description='Native debugger',homepage='https://github.com/vadimcn/vscode-lldb',licenses={},languages={},categories={},
  source={id='pkg:github/vadimcn/vscode-lldb@v1.12.2',asset={file='codelldb-'..osname..'-'..arch..'.vsix',bin=win and 'extension/adapter/codelldb.exe' or 'exec:extension/adapter/codelldb'}},bin={codelldb='{{source.asset.bin}}'},opt={['lldb/']='extension/lldb/'}},
 ['bash-debug-adapter']={schema='registry+v1',name='bash-debug-adapter',description='Existing Bash debugger',homepage='https://github.com/rogalmic/vscode-bash-debug',licenses={},languages={},categories={},
  source={id='pkg:github/rogalmic/vscode-bash-debug@untagged-438733f35feb8659d939',asset={file='bash-debug-0.3.9.vsix'}},bin={['bash-debug-adapter']='node:extension/out/bashDebug.js'},opt={['bashdb/']='extension/bashdb_dir/'}}}
for name,spec in pairs(definitions) do package.preload['forge_debug_'..name]=function() return spec end end
package.preload.forge_debug_registry=function() return {'forge_debug_codelldb','forge_debug_bash-debug-adapter'} end
local settings={registries={'lua:forge_debug_registry'},max_concurrent_installers=1}
if vim.env.FORGE_IDE_GITHUB_TEMPLATE then settings.github={download_url_template=vim.env.FORGE_IDE_GITHUB_TEMPLATE} end
require('mason').setup(settings)
local ready=false;require('mason-registry').refresh(function() ready=true end);assert(vim.wait(5000,function() return ready end,10))
local names={'codelldb','bash-debug-adapter'}
local ok,err=xpcall(function()
 if arg[1]=='prepare' then
  local versions=require('forge.tool_catalog').versions()
  require('mason-tool-installer').setup({ensure_installed=vim.tbl_map(function(n) return {n,version=versions[n]} end,names),auto_update=false,run_on_start=false,
   integrations={['mason-lspconfig']=false,['mason-null-ls']=false,['mason-nvim-dap']=false}})
  vim.cmd('runtime plugin/mason-tool-installer.lua');vim.cmd('MasonToolsInstallSync')
  require('forge.setup_readiness').tools(names,versions)
 elseif arg[1]=='patch' then
  local status=require('forge.bash_debug').prepare_installed()
  vim.fn.writefile({status},base..'/patch.txt')
 elseif arg[1]=='stage' then
  require('forge.tool_catalog').mason=function() return names end
  vim.env.FORGE_NVIM_COMPONENTS='core,rust,bash'
  vim.api.nvim_create_user_command('Lazy',function()
   vim.api.nvim_create_user_command('MasonToolsInstallSync',function() end,{force=true})
  end,{nargs='*'})
  arg={'tools'};dofile(root..'/nvim_forge/scripts/setup-stage.lua')
 elseif arg[1]=='resolve' or arg[1]=='debug' or arg[1]=='bash-debug' then
  for name in vim.fs.dir(deps..'/lazy') do vim.opt.rtp:prepend(deps..'/lazy/'..name) end
  require('ide').setup()
  require('dapui').setup({})
  for _,spec in ipairs(require('plugins.dap')) do if spec[1]=='mfussenegger/nvim-dap' then spec.config() end end
  local dap=require('dap');local adapter
  dap.adapters.codelldb(function(value) adapter=value end);assert(adapter,'codelldb config missing')
  local report={command=adapter.executable.command}
  if arg[1]=='debug' or arg[1]=='bash-debug' then
   local stopped,terminated,output=false,false,''
   dap.listeners.after.event_stopped.delivery=function() stopped=true end
   dap.listeners.after.event_terminated.delivery=function() terminated=true end
   dap.listeners.after.event_output.delivery=function(_,body) output=output..body.output end
   local bash_mode=arg[1]=='bash-debug'
   vim.cmd.edit(vim.fn.fnameescape(base..(bash_mode and '/script.sh' or '/main.rs')));vim.bo.filetype=bash_mode and 'sh' or 'rust'
   vim.api.nvim_win_set_cursor(0,{bash_mode and 2 or 1,0});dap.toggle_breakpoint()
   if bash_mode then
    dap.run({name='Native Bash delivery',type='bashdb',request='launch',program=base..'/script.sh',cwd=base,stopOnEntry=false,terminalKind='debugConsole',console='internalConsole'})
   else
    dap.run({name='Native delivery',type='codelldb',request='launch',program=assert(vim.env.FORGE_DEBUG_PROGRAM),cwd=base,stopOnEntry=false,terminal='integrated',console='integratedTerminal',sourceLanguages={'rust'}})
   end
   assert(vim.wait(30000,function() return stopped and dap.session() and dap.session().current_frame end,20),'CodeLLDB did not stop with a focused frame')
   report.stopped=true;dap.continue()
   assert(vim.wait(20000,function() return terminated end,20),'CodeLLDB did not terminate')
   local function captured()
    local text=output
    for _,buf in ipairs(vim.api.nvim_list_bufs()) do
     if vim.api.nvim_buf_is_loaded(buf) and (vim.bo[buf].buftype=='terminal' or vim.bo[buf].filetype=='dap-repl') then
      text=text..'\n'..table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n')
     end
    end
    return text
   end
   assert(vim.wait(5000,function() return captured():find(bash_mode and 'FRIDE_BASH_DELIVERY' or 'FRIDE_DEBUG_DELIVERY',1,true) end,20),captured())
   report.output=captured()
   dap.close()
  end
  vim.fn.writefile({vim.json.encode(report)},base..'/dap.json')
 else error('Unknown debug tools mode '..arg[1]) end
end,debug.traceback)
if not ok then io.stderr:write(err..'\n');vim.cmd('cquit 1') end
vim.cmd('qa!')
