local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local edge=string.rep('я',2048)
local function marks(e)
  return e:lua([[local ns=vim.api.nvim_get_namespaces()['illuminate.highlight'];return ns and vim.api.nvim_buf_get_extmarks(0,ns,0,-1,{}) or {}]])
end
local function healthy(e)
  local state=e:lua([[return {errmsg=vim.v.errmsg,messages=vim.fn.execute('messages')} ]])
  assert(not state.messages:match('E%d%d%d+:'),state.messages:sub(-500))
  for _,notice in ipairs(e.rpc.notifications) do assert(notice.level<vim.log.levels.ERROR,notice.message) end
end
local function settle(e)
  -- Наблюдатель очереди после debounce; сам provider/handler не вызывается.
  e:lua([[_G.forge_reference_observed=false;vim.defer_fn(function() _G.forge_reference_observed=true end,require('illuminate.config').delay(0)+500)]])
  e:input('l')
  e:wait('цикл подсветки не блокирует редактор',function() return e:lua('return _G.forge_reference_observed') end,10000)
  healthy(e)
end
local function open(e,name)
  e:input(':edit '..name..'<CR>')
  e:wait('открыт '..name,function() return e:current_file():gsub('\\','/'):sub(-#name)==name end)
end
local function references(e,word,column)
  e:wait('два подсвеченных вхождения',function() return #marks(e)==2 end,10000)
  e:input('<A-n>')
  e:wait('переход к следующему слову',function() return e:lua('return vim.api.nvim_win_get_cursor(0)[2]')==column end)
  e:input('<A-p>')
  e:wait('возврат к первому слову',function() return e:lua('return vim.api.nvim_win_get_cursor(0)[2]')==0 end)
  T.eq(e:lua('return vim.fn.expand("<cword>")'),word)
  healthy(e)
end
local function check(name,fn)
  if vim.env.FORGE_HIGHLIGHT_CASE and not name:find(vim.env.FORGE_HIGHLIGHT_CASE,1,true) then return end
  T.check('IDE-HL-1 '..name,function()
    local e
    local ok,err=pcall(function()
      e=require('editor').start(root,{timeout=120000,prepare=function(project)
        vim.fn.writefile({string.rep('x',524288),'target target'},project..'/long_word.txt')
        vim.fn.writefile({edge..' '..edge},project..'/edge_word.txt')
        vim.fn.writefile({edge..'a '..edge..'a'},project..'/over_word.txt')
        local rows={string.rep('x',524288),'target target'}
        for _=1,5001 do rows[#rows+1]='filler' end
        vim.fn.writefile(rows,project..'/many_lines.txt')
        local line='метка '..string.rep('x ',262144)..'метка'
        vim.fn.writefile({line},project..'/long_line.txt')
      end})
      e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      fn(e)
      healthy(e)
    end)
    if e then e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop(not ok and tostring(err) or nil) end
    assert(ok,err)
  end)
end
check('длинное слово и граница 4096 bytes сохраняют редактирование',function(e)
  open(e,'long_word.txt');settle(e);T.eq(#marks(e),0)
  e:input('j0');references(e,'target',7)
  e:input('gg0iFORGE_<Esc>:write<CR>')
  e:wait('большой файл записан',function() return vim.fn.readfile(e.project..'/long_word.txt')[1]:sub(1,6)=='FORGE_' end)
  settle(e)
  open(e,'over_word.txt');settle(e);T.eq(#marks(e),0)
  open(e,'edge_word.txt');e:input('l');references(e,edge,#edge+1)
end)
check('защита действует после large file cutoff',function(e)
  open(e,'many_lines.txt');T.eq(e:lua('return vim.api.nvim_buf_line_count(0)'),5003)
  settle(e);T.eq(#marks(e),0)
  e:input('j0');references(e,'target',7)
end)
check('длинная строка с короткими словами сохраняет подсветку и переходы',function(e)
  open(e,'long_line.txt')
  e:input('l')
  local column=#('метка '..string.rep('x ',262144))
  references(e,'метка',column)
end)
T.finish()
