-- spec: IDE-BOOT-50 IDE-BOOT-51 IDE-BOOT-52. Actual installed SDK/tools; no replacements.
local base=assert(arg[1],'Expected owned artifact directory')
local kind=arg[2] or 'rust'
assert(kind=='rust' or kind=='go')
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local function write(path,lines)vim.fn.mkdir(vim.fs.dirname(path),'p');assert(vim.fn.writefile(lines,path)==0)end
local project=base..'/project';local artifacts=base..'/observed'
write(project..'/notes.txt',{'before'})
assert(vim.system({'git','init','-q',project},{text=true}):wait(5000).code==0)
vim.fn.mkdir(artifacts,'p')
local rpc=require('editor_rpc').start({vim.v.progpath,'--headless','--embed','-i','NONE',
 '--cmd','lua vim.opt.rtp:prepend(vim.env.FRIDE_CONFIG)','-u',vim.env.FRIDE_CONFIG..'/init.lua'},
 {cwd=project,env=vim.fn.environ(),clear_env=true,artifacts=artifacts,timeout=240000})
local function lua(code,args)return rpc:request('nvim_exec_lua',{code,args or {}})end
local function wait(name,predicate,timeout)
 local value,last;local deadline=vim.uv.hrtime()+(timeout or 30000)*1e6
 repeat
  local ok,result=pcall(predicate);if ok and result then return result end
  if not ok then last=result end;vim.wait(20)
 until vim.uv.hrtime()>=deadline
 error(name..': '..tostring(last))
end
local prompt
local function choose(text)
 wait('language menu',function()return lua([[return vim.bo.filetype=='TelescopePrompt' and vim.api.nvim_get_mode().mode=='i' and vim.api.nvim_get_current_buf()~=...]],{prompt or -1})end)
 rpc:request('nvim_input',{text})
 wait('selected '..text,function()return lua([[local e=require('telescope.actions.state').get_selected_entry();return e and e.ordinal:find(...,1,true)~=nil]],{text})end)
 prompt=lua('return vim.api.nvim_get_current_buf()');rpc:request('nvim_input',{'<CR>'})
end
local function snapshot()
 return lua([[local kind=...;local receipts={}
  for _,file in ipairs(vim.fn.globpath(vim.fn.stdpath('data')..'/mason/packages','*/mason-receipt.json',false,true))do
   receipts[vim.fs.basename(vim.fs.dirname(file))]=vim.fn.sha256(table.concat(vim.fn.readfile(file,'b'),'\n'))
  end
  local tool=kind=='rust' and 'rustc' or 'go';local path=vim.fn.exepath(tool)
  assert(path~='','Prepared SDK missing')
  local result=vim.system({path,kind=='go' and 'version' or '--version'},{text=true}):wait(10000)
  assert(result.code==0,result.stderr)
  return {pid=vim.uv.os_getpid(),path=path,version=result.stdout,receipts=receipts,
   lock=vim.fn.sha256(table.concat(vim.fn.readfile(vim.env.FRIDE_CONFIG..'/lazy-lock.json','b'),'\n'))}]],{kind})
end
local info={language=kind}
local ok,err=xpcall(function()
 rpc:request('nvim_ui_attach',{120,40,{rgb=true,ext_linegrid=true}})
 wait('startup',function()return lua('return vim.v.vim_did_enter==1')end,10000)
 rpc:request('nvim_command',{'edit '..vim.fn.fnameescape(project..'/notes.txt')})
 info.before=snapshot()
 assert(lua('return require("forge.languages").status(...).ready',{kind}),'Existing SDK/tools must be ready')
 rpc:request('nvim_input',{' lS'});choose(kind=='rust' and 'Rust' or 'Go');choose('Подготовить недостающее')
 wait('native task starts',function()return lua('return require("forge.languages").active~=nil')end)
 info.task=lua([[local m=require('forge.languages');local task=assert(m.active).task
  m.prepare(...);assert(m.active.task==task,'Second preparation started');return {id=task.id}]],{kind})
 rpc:request('nvim_input',{'<C-\\><C-n>'})
 lua([[vim.cmd.stopinsert();require('ide').focus_main();vim.cmd.edit(vim.fn.fnameescape(...));return true]],{project..'/notes.txt'})
 wait('normal editing',function()return lua('return vim.bo.buftype=="" and vim.api.nvim_get_mode().mode=="n"')end)
 assert(lua('return require("forge.languages").active~=nil'),'Preparation finished before edit check')
 rpc:request('nvim_input',{'iFRIDE_ASYNC_EDIT <Esc>:write<CR>'})
 wait('edit saved during preparation',function()return vim.fn.readfile(project..'/notes.txt')[1]:find('FRIDE_ASYNC_EDIT',1,true)end)
 local function ready()
  return lua([[local m=require('forge.languages');local state=m.status(...)
   return (m.active==nil and state.prepared and state.prepared.ready and state.ready)==true]],{kind})
 end
 wait('native preparation result',ready,120000);info.prepared=true
 info.cancel=lua([[local m=require('forge.languages');local task=assert(m.prepare(...));local id=task.id;task:stop();return id]],{kind})
 wait('cancellation releases task',function()return lua([[local m=require('forge.languages');local s=m.status(...);return m.active==nil and s.prepared and s.prepared.error~=nil and not s.prepared.ready]],{kind})end)
 info.cancelled=true
 lua('assert(require("forge.languages").prepare(...));return true',{kind})
 wait('retry succeeds',ready,120000);info.retried=true
 info.after=snapshot()
 assert(vim.deep_equal(info.before,info.after),'SDK/version/receipts/lock/editor PID changed')
 assert(vim.fn.readfile(project..'/notes.txt')[1]:find('FRIDE_ASYNC_EDIT',1,true))
 assert(#rpc.api_errors==0,vim.inspect(rpc.api_errors))
 info.logs=lua([[local found={};for _,e in ipairs(require('forge.log_store').memory)do if e.source=='Languages' then found[#found+1]=e.message end end;return found]])
 assert(#info.logs>=4,'Preparation history missing')
end,debug.traceback)
info.ok,info.error=ok,not ok and tostring(err) or nil
local observed,state=pcall(lua,[[local kind,project=...;local m=require('forge.languages')
 return {state=m.status(kind,project),implicit=m.status(kind),results=vim.tbl_keys(m.results),
  active=m.active and {kind=m.active.kind,root=m.active.root},cwd=vim.fn.getcwd(),file=vim.api.nvim_buf_get_name(0),
  tasks=vim.tbl_map(function(t)return {id=t.id,status=t.status}end,require('overseer').list_tasks()),
  messages=vim.api.nvim_exec2('messages',{output=true}).output}]],{kind,project})
if observed then info.observed=state end
write(artifacts..'/report.json',{vim.json.encode(info)})
write(artifacts..'/screen.txt',rpc:screen_lines())
write(artifacts..'/stderr.txt',vim.split(table.concat(rpc.stderr),'\n'))
local stopped,cleanup=pcall(require('editor_process').stop,rpc,artifacts,info.error)
if not ok or not stopped or not cleanup.ok or cleanup.exit_code~=0 then
 io.stderr:write(tostring(err or cleanup)..'\n');vim.cmd('cquit 1')
end
print('Installed async language preparation PASS: '..kind)
