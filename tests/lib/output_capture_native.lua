-- Opt-in observer in the private editor; no files, timers or slot refresh.
local uv=vim.uv
local rows,total,capacity={},0,2048
local restores={}
local ns=vim.api.nvim_create_namespace('forge_output_capture')
local group=vim.api.nvim_create_augroup('ForgeOutputCapture',{clear=true})
local function record(kind,fields)
  total=total+1
  rows[(total-1)%capacity+1]={index=total,ns=uv.hrtime(),kind=kind,fields=fields}
end
local function windows()
  local out={}
  for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b=vim.api.nvim_win_get_buf(w)
    out[#out+1]={win=w,buf=b,ft=vim.bo[b].filetype,relative=vim.api.nvim_win_get_config(w).relative,
      height=vim.api.nvim_win_get_height(w),width=vim.api.nvim_win_get_width(w)}
  end
  local dap=package.loaded.dap;local s=dap and dap.session()
  return {wins=out,current=vim.api.nvim_get_current_win(),mode=vim.api.nvim_get_mode(),
    session=s and {id=s.id,thread=s.stopped_thread_id,frame=s.current_frame and s.current_frame.id} or false}
end
local function pack(...) return {n=select('#',...),...} end
local function wrap(mod,key,label)
  if type(mod)~='table' or type(mod[key])~='function' then return end
  for _,r in ipairs(restores) do if r.mod==mod and r.key==key and mod[key]==r.wrapped then return end end
  local original=mod[key]
  local wrapped=function(...)
    local caller
    for level=2,6 do
      caller=debug.getinfo(level,'Sl')
      if not caller or caller.short_src~='[C]' then break end
    end
    local first=select(1,...)
    record(label..':before',{arg=type(first)=='string' and first or nil,state=windows(),
      caller=caller and {source=caller.short_src,line=caller.currentline}})
    local result=pack(original(...))
    record(label..':after',windows())
    return unpack(result,1,result.n)
  end
  mod[key]=wrapped;restores[#restores+1]={mod=mod,key=key,original=original,wrapped=wrapped}
end
local function attach()
  local ide=package.loaded.ide
  wrap(ide,'show','ide.show');wrap(ide,'hide','ide.hide')
  local dap=package.loaded['ide.dap']
  wrap(dap,'toggle','debug.toggle');wrap(dap,'open','debug.open')
  wrap(dap,'show_section','debug.show_section')
  wrap(package.loaded['ide.activities'],'close_debug','debug.close')
  local backend=package.loaded.dap
  if type(backend)=='table' then
    wrap(backend.listeners.after.event_stopped,'forge_ensure_sidebar','event_stopped.sidebar')
    wrap(backend.listeners.after.event_initialized,'dapview_config','event_initialized.view')
  end
end
local function hex(value) return (value:gsub('.',function(c) return ('%02x'):format(c:byte()) end)) end
local function display(value)
  return (vim.fn.keytrans(value):gsub('[\128-\255]',function(c) return ('\\x%02x'):format(c:byte()) end))
end
vim.on_key(function(key,typed)
  typed=typed or ''
  record('key',{key=display(key),typed=display(typed),key_hex=hex(key),typed_hex=hex(typed)})
end,ns)
vim.api.nvim_create_autocmd({'WinNew','WinClosed','WinEnter','BufWinEnter','BufWinLeave'},
  {group=group,callback=function(ev)
    local buf=ev.buf
    record(ev.event,{match=ev.match,buf=buf,ft=vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype or nil})
  end})
vim.api.nvim_create_autocmd('User',{group=group,pattern='LazyLoad',callback=attach})
attach();record('observer_ready',windows())
local capture={}
function capture.snapshot()
  local out={}
  for n=math.max(1,total-capacity+1),total do out[#out+1]=rows[(n-1)%capacity+1] end
  return {total=total,dropped=math.max(0,total-capacity),rows=out,state=windows()}
end
function capture.stop()
  local result=capture.snapshot()
  vim.on_key(nil,ns);vim.api.nvim_del_augroup_by_id(group)
  for i=#restores,1,-1 do local r=restores[i];if r.mod[r.key]==r.wrapped then r.mod[r.key]=r.original end end
  _G.forge_output_capture=nil
  return result
end
assert(not _G.forge_output_capture,'Duplicate output observer')
_G.forge_output_capture=capture
