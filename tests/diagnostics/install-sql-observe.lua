local base=arg[1]
local config=assert(vim.env.FRIDE_CONFIG)
vim.opt.rtp:prepend(config);vim.opt.rtp:prepend(assert(vim.env.FORGE_E2E_DEPS)..'/lazy/nvim-lspconfig')
local native=require('forge.native_tools');local report={tools=native.check_sql()}
local sql=require('forge.sql');assert(sql.tool('sqls')==native.owned('sqls'),'Old PATH copy shadowed private sqls')
vim.g.forge_sqls_executable=base..'/shadow/sqls'..(vim.fn.has('win32')==1 and '.exe' or '')
assert(sql.tool('sqls')==vim.fn.exepath(vim.g.forge_sqls_executable),'Explicit override was ignored');vim.g.forge_sqls_executable=nil
local ok,err=xpcall(function()
 sql.setup_lsp();local file=base..'/project/query.sql'
 vim.cmd.edit(vim.fn.fnameescape(file));vim.bo.filetype='sql'
 local client
 assert(vim.wait(20000,function() client=vim.lsp.get_clients({bufnr=0,name='sqls'})[1];return client and client.initialized end,20),'SQLS did not attach')
 local response=client:request_sync('workspace/executeCommand',{command='executeQuery',arguments={vim.uri_from_fname(file)}},15000,0)
 assert(response and not response.err and vim.inspect(response.result):find('42',1,true),vim.inspect(response))
 report.query=response.result;client:stop(true);vim.wait(3000,function() return client:is_stopped() end,20)
 local result=vim.system({native.executable('forge-sqltest'),'--report',base..'/slt.json','--',base..'/project/query.slt'},{text=true}):wait(10000)
 assert(result.code==0,(result.stdout or '')..(result.stderr or ''))
 report.slt=vim.json.decode(table.concat(vim.fn.readfile(base..'/slt.json'),'\n'));assert(report.slt.status=='passed',vim.inspect(report.slt))
 local deps=assert(vim.env.FORGE_E2E_DEPS)
 for _,name in ipairs({'neotest','nvim-nio','plenary.nvim'}) do vim.opt.rtp:prepend(deps..'/lazy/'..name) end
 local complete,adapter_error=false,nil
 require('nio').run(function()
  local success,detail=pcall(function()
   local adapter=require('forge.sql_tests')
   local file=base..'/project/query.slt'
   local tree={data=function() return {id=file,path=file,type='test',range={0,0,0,0}} end}
   local spec=assert(adapter.build_spec({tree=tree}))
   assert(spec.command[1]==native.owned('forge-sqltest'),'Neotest ignored private SQL runner')
   local run=vim.system(spec.command,{text=true,cwd=spec.cwd}):wait(10000)
   local results=adapter.results(spec,{code=run.code});assert(results[file].status=='passed',vim.inspect(results))
   report.neotest={command=spec.command[1],status=results[file].status}
  end)
  if not success then adapter_error=detail end;complete=true
 end)
 assert(vim.wait(15000,function() return complete end,20),'Neotest SQL runner timed out');assert(not adapter_error,adapter_error)
 vim.fn.writefile({vim.json.encode(report)},base..'/sql.json')
end,debug.traceback)
if not ok then io.stderr:write(err..'\n');vim.cmd('cquit 1') end
vim.cmd('qa!')
