-- Запускает существующий E2E с пассивной трассой public panel/DAP вызовов.
-- Обёртки сохраняют return tuple; данные не подменяют результат API/теста.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local target=arg[1] or 'tests/e2e/debug-panels.test.lua'
assert(target:match('^tests/e2e/[%w_-]+%.test%.lua$'),'Ожидается repo tests/e2e/*.test.lua')
local observer=[=[
local trace={events={},sources={},dropped=0,limit=4096}
_G.forge_panel_trace=trace
local wrappers,memo={},{}
local installing=false
local install
local function pack(...) return {n=select('#',...),...} end
local function emit(row)
  if #trace.events>=trace.limit then trace.dropped=trace.dropped+1;return end
  row.ns=vim.uv.hrtime();trace.events[#trace.events+1]=row
end
local function wrap(object,key,label)
  if type(object)~='table' or type(object[key])~='function' then return end
  local original=object[key]
  if wrappers[original] then return end
  if memo[original] then object[key]=memo[original];return end
  local info=debug.getinfo(original,'S')
  local file=info.source:gsub('\\','/')
  trace.sources[label]={file=file:match('/nvim_forge/(.*)$') or file,line=info.linedefined}
  local function observed(...)
    local first=select(1,...)
    local row={kind='enter',call=label}
    if label:match('^ide%.') or label:match('^controls%.') or label:match('^activities%.') then
      if type(first)=='string' or type(first)=='boolean' then row.arg=first end
    end
    if label:match('^dapui%.') and type(first)=='table' then row.layout=first.layout end
    emit(row)
    local values=pack(original(...))
    emit({kind='return',call=label})
    install()
    return unpack(values,1,values.n)
  end
  memo[original]=observed;wrappers[observed]=true;object[key]=observed
end
install=function()
  if installing then return end;installing=true
  local targets={
    {'ide',{'show','hide','toggle','hide_slot','focus_main','apply_layout'}},
    {'ide.dap',{'show_section','open','close','focus_output','focus_section'}},
    {'ide.controls',{'focus_code','direction','locals','output','hide','cancel','zoom','restore'}},
    {'ide.activities',{'close_activity','close_debug','focus_code_later','stop_debug'}},
    {'dapui',{'open','close'}},{'dap',{'run','continue','terminate','disconnect'}},
    {'dap.repl',{'append','clear'}},{'forge.panel_guard',{'sweep'}},
  }
  for _,spec in ipairs(targets) do
    local object=package.loaded[spec[1]]
    for _,key in ipairs(spec[2]) do
      local prefix=spec[1]=='ide.controls' and 'controls' or spec[1]=='ide.activities' and 'activities' or spec[1]
      wrap(object,key,prefix..'.'..key)
    end
  end
  local registry=package.loaded['ide.registry']
  if registry then for id,component in pairs(registry.all()) do
    if id:match('^dap%.') then
      wrap(component,'open','component.'..id..'.open');wrap(component,'close','component.'..id..'.close')
    end
  end end
  local dap=package.loaded.dap
  if dap then
    if dap.defaults and dap.defaults.fallback then wrap(dap.defaults.fallback,'terminal_win_cmd','dap.terminal_window') end
    for side,events in pairs(dap.listeners or {}) do if type(events)=='table' then
      for event,listeners in pairs(events) do if type(listeners)=='table' then
        for id in pairs(listeners) do if type(id)=='string' and (id:find('forge',1,true) or id=='dapview_config') then
          wrap(listeners,id,'listener.'..side..'.'..event..'.'..id)
        end end
      end end
    end end
  end
  installing=false
end
vim.api.nvim_create_autocmd('User',{pattern='LazyLoad',callback=install})
vim.api.nvim_create_autocmd({'WinNew','WinClosed','WinEnter','BufWinEnter','TermOpen','TermClose'},{callback=function(ev)
  local row={kind='event',event=ev.event,match=ev.match}
  if not vim.in_fast_event() and vim.api.nvim_buf_is_valid(ev.buf) then row.ft=vim.bo[ev.buf].filetype end
  emit(row)
end})
install()
]=]
local editor=require('editor')
local start=editor.start
editor.start=function(...)
  local e=start(...)
  e:lua(observer)
  local stop=e.stop
  e.stop=function(self,...)
    if not self.forge_panel_trace_saved then
      self.forge_panel_trace_saved=true
      local ok,data=pcall(self.lua,self,'return _G.forge_panel_trace')
      vim.fn.writefile({vim.json.encode(ok and data or {capture_error=tostring(data)})},self.dir..'/panel-trace.json')
      assert(vim.uv.fs_copyfile(root..'/tests/diagnostics/trace-panels.lua',self.dir..'/trace-panels.lua'))
    end
    return stop(self,...)
  end
  return e
end
dofile(root..'/'..target)
