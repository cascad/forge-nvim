local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')

local function file(e,name) return e.project..'/'..name end
local function focus(e,keys,ft)
  e:input(keys)
  e:wait('фокус '..keys..': '..ft,function() return e:current_ft()==ft end)
end
local function open(e,name)
  e:input(':edit '..name..'<CR>')
  e:wait('открыт '..name,function() return e:current_file():sub(-#name)==name end)
end
local function geometry(e)
  return e:lua([[local out={};for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    out[#out+1]={id=w,buf=vim.api.nvim_win_get_buf(w),pos=vim.api.nvim_win_get_position(w),
      width=vim.api.nvim_win_get_width(w),height=vim.api.nvim_win_get_height(w)} end;return out]])
end
local function prompt(e,keys)
  e:input(keys)
  e:wait('настоящий confirm закрытия',function()
    local mode=e.rpc:request('nvim_get_mode',{})
    return mode.mode=='r?' and table.concat(e.rpc:screen_lines(),'\n'):find('ave',1,true)~=nil
  end)
end
local function answer(e,key)
  e:input(key)
  e:wait('confirm завершён',function() local m=e.rpc:request('nvim_get_mode',{});return not m.blocking and m.mode~='r?' end)
end
local function check(name,fn)
  T.check(name,function()
    local e
    local ok,failure=pcall(function()
      e=require('editor').start(root)
      e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      open(e,'file_one.txt')
      fn(e)
      T.eq(e:lua('return #vim.api.nvim_list_tabpages()'),1,'это файловые tabs, не tabpages')
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
      for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    end)
    if e then
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop()
    end
    assert(ok,failure)
  end)
end

check('IDE-BUF-1 цикл совпадает с вкладками, unloaded/readonly и terminal',function(e)
  e:input(':badd file_two.txt<CR>:badd nested/file_three.txt<CR>')
  e:wait('unloaded зарегистрирован',function()
    return e:lua([[local b=vim.fn.bufnr('file_two.txt');return b>0 and not vim.api.nvim_buf_is_loaded(b)]])
  end)
  focus(e,' bn','text')
  e:wait('unloaded подгружен',function() return e:current_file():find('file_two.txt',1,true)~=nil end)
  e:input(':setlocal readonly<CR> bn')
  e:wait('readonly не мешает циклу',function() return e:current_file():find('file_three.txt',1,true)~=nil end)
  e:input(' bn')
  e:wait('цикл замкнулся',function() return e:current_file():find('file_one.txt',1,true)~=nil end)
  e:input(':botright split<CR>:terminal echo FORGE_BUFFER_TERM<CR>')
  e:wait('настоящий terminal',function() return e:lua([[return vim.bo.buftype]])=='terminal' end)
  local terminal=e:lua('return vim.api.nvim_get_current_buf()')
  focus(e,'<F7>','text')
  local wins=e:lua('return #vim.api.nvim_tabpage_list_wins(0)')
  for _,suffix in ipairs({'file_two.txt','file_three.txt','file_one.txt'}) do
    e:input('<Tab>')
    e:wait('Tab '..suffix,function() return e:current_file():sub(-#suffix)==suffix end)
  end
  e:input('<S-Tab>')
  e:wait('обратный цикл',function() return e:current_file():find('file_three.txt',1,true)~=nil end)
  e:wait('BufferLine исключил terminal',function()
    return e:lua([[local terminal=...;for _,v in ipairs(require('bufferline').get_elements().elements) do
      if v.id==terminal then return false end end;return true]],{terminal})
  end)
  T.eq(e:lua('return #vim.api.nvim_tabpage_list_wins(0)'),wins)
  T.eq(e:lua([[return vim.api.nvim_buf_is_valid(...) and vim.bo[...].buftype=='terminal']],{terminal}),true)
end)

check('IDE-BUF-1 picker из дерева выбирает файл в коде и сохраняет панель',function(e)
  open(e,'file_two.txt');open(e,'nested/file_three.txt')
  e:input(':botright split<CR>:terminal echo FORGE_PICKER_TERM<CR>')
  e:wait('terminal для picker',function() return e:lua([[return vim.bo.buftype]])=='terminal' end)
  focus(e,'<F7>','text')
  focus(e,' we','neo-tree')
  local tree=e:lua('return vim.api.nvim_get_current_buf()')
  local windows=e:lua('return vim.api.nvim_tabpage_list_wins(0)')
  focus(e,' bb','TelescopePrompt')
  e:wait('picker содержит только файлы',function()
    return e:lua([[local p=require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
      if not p.manager then return false end;local count=0;for item in p.manager:iter() do
        count=count+1;if vim.bo[item.bufnr].buftype~='' then return false end end;return count>=3]])
  end)
  e:input('file_two')
  e:wait('файл выбран picker',function()
    return e:lua([[local v=require('telescope.actions.state').get_selected_entry();return v and v.bufnr and vim.api.nvim_buf_get_name(v.bufnr):find('file_two.txt',1,true)~=nil]])
  end)
  focus(e,'<CR>','text')
  e:wait('выбранный файл открыт',function() return e:current_file():find('file_two.txt',1,true)~=nil end)
  T.eq(e:lua([[return vim.bo[...].filetype]],{tree}),'neo-tree')
  T.eq(e:lua('return vim.api.nvim_tabpage_list_wins(0)'),windows)
  focus(e,' fb','TelescopePrompt')
  focus(e,'<Esc>','text')
end)

check('IDE-BUF-2 закрытие сохранённого файла сохраняет split и дерево',function(e)
  e:input(':badd file_two.txt<CR>')
  focus(e,' we','neo-tree');focus(e,' w0','text')
  e:input(' wv')
  e:wait('два окна кода',function() return e:lua('return #vim.api.nvim_tabpage_list_wins(0)')==3 end)
  local ids=e:lua('return vim.api.nvim_tabpage_list_wins(0)')
  e:input(' bd')
  e:wait('оба окна получили соседний файл',function()
    return e:lua([[for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do local b=vim.api.nvim_win_get_buf(w)
      if vim.bo[b].filetype~='neo-tree' and not vim.api.nvim_buf_get_name(b):find('file_two.txt',1,true) then return false end end;return true]])
  end)
  T.eq(e:lua('return vim.api.nvim_tabpage_list_wins(0)'),ids)
  focus(e,' we','neo-tree')
  e:input(' bd')
  e:wait('последний файл закрыт из панели',function() return e:current_ft()=='alpha' end)
  T.eq(e:has_window('neo-tree'),true)
  T.eq(e:lua('return vim.api.nvim_tabpage_list_wins(0)'),ids)
end)

for _,last in ipairs({false,true}) do
  check('IDE-BUF-2 Cancel '..(last and 'последнего' or 'непоследнего')..' файла сохраняет буферы и курсор',function(e)
    if not last then e:input(':badd file_two.txt<CR>') end
    e:input('gg0iUNSAVED_<Esc>2G')
    e:wait('буфер изменён',function() return e:lua('return vim.bo.modified and vim.api.nvim_win_get_cursor(0)[1]==2') end)
    local state=geometry(e)
    local before=e:lua('return {vim.api.nvim_get_current_buf(),vim.api.nvim_win_get_cursor(0),vim.api.nvim_buf_get_lines(0,0,-1,false)}')
    prompt(e,' bd')
    -- Проверка временного инварианта: autosave debounce 500 ms не должен
    -- записать текст, пока native confirm ждёт решения пользователя.
    local deadline=vim.uv.hrtime()+750*1000000
    e:wait('диалог удержан дольше autosave debounce',function()
      T.eq(vim.fn.readfile(file(e,'file_one.txt')),{'first file','NEEDLE_FORGE_E2E'})
      return vim.uv.hrtime()>=deadline
    end)
    answer(e,last and '<CR>' or 'c')
    T.eq(geometry(e),state,'Cancel не меняет окна/буферы/размеры')
    T.eq(e:lua('return {vim.api.nvim_get_current_buf(),vim.api.nvim_win_get_cursor(0),vim.api.nvim_buf_get_lines(0,0,-1,false)}'),before)
    T.eq(e:lua('return vim.bo.modified'),true)
    T.eq(vim.fn.readfile(file(e,'file_one.txt')),{'first file','NEEDLE_FORGE_E2E'})
    e:input('GoAUTOSAVE_RESUMED<Esc>')
    e:wait('autosave после Cancel работает',function()
      local lines=vim.fn.readfile(file(e,'file_one.txt'));return lines[3]=='AUTOSAVE_RESUMED'
    end)
  end)
end

check('IDE-BUF-2 Save и Discard через F4/Alt-w сохраняют правильное содержимое',function(e)
  e:input('gg0iSAVED_<Esc>')
  prompt(e,'<F4>');answer(e,'s')
  e:wait('последний Save закрыт',function() return e:current_ft()=='alpha' end)
  T.eq(vim.fn.readfile(file(e,'file_one.txt')),{'SAVED_first file','NEEDLE_FORGE_E2E'})
  open(e,'file_two.txt');e:input('gg0iDISCARD_<Esc>')
  prompt(e,'<A-w>');answer(e,'d')
  e:wait('Discard закрыт',function() return e:current_ft()=='alpha' end)
  T.eq(vim.fn.readfile(file(e,'file_two.txt')),{'second file'})
end)

check('IDE-BUF-3 последний файл alpha и reopen возвращают курсор в том же окне',function(e)
  focus(e,' we','neo-tree');focus(e,' w0','text')
  e:input('2G3l')
  e:wait('курсор установлен',function() return e:lua('return vim.api.nvim_win_get_cursor(0)') and
    vim.deep_equal(e:lua('return vim.api.nvim_win_get_cursor(0)'),{2,3}) end)
  local cursor=e:lua('return vim.api.nvim_win_get_cursor(0)')
  local ids=e:lua('return vim.api.nvim_tabpage_list_wins(0)')
  e:input(' bd')
  e:wait('alpha после последнего файла',function() return e:current_ft()=='alpha' end)
  e:input(' br')
  e:wait('reopen',function() return e:current_file():find('file_one.txt',1,true)~=nil end)
  T.eq(e:lua('return vim.api.nvim_win_get_cursor(0)'),cursor)
  T.eq(e:lua('return vim.api.nvim_tabpage_list_wins(0)'),ids)
  T.eq(e:has_window('neo-tree'),true)
end)

check('IDE-BUF-2 ошибка Save unnamed оставляет текст открытым, затем запись с именем',function(e)
  e:input(':enew<CR>iUNTITLED_DATA<Esc>')
  local buf=e:lua('return vim.api.nvim_get_current_buf()')
  prompt(e,' bd');e:input('s')
  e:wait('отказ Save без имени',function()
    if e:ack_warning('Не удалось сохранить') then return false end
    return not e.rpc:request('nvim_get_mode',{}).blocking and e:lua('return vim.api.nvim_get_current_buf()')==buf
      and e:lua('return vim.bo.modified')
  end)
  T.eq(e:lua('return vim.api.nvim_get_current_line()'),'UNTITLED_DATA')
  e:input(':file saved_untitled.txt<CR>')
  prompt(e,' bd');answer(e,'s')
  e:wait('файл сохранён и закрыт',function() return e:current_file():find('file_one.txt',1,true)~=nil end)
  T.eq(vim.fn.readfile(file(e,'saved_untitled.txt')),{'UNTITLED_DATA'})
end)

T.finish()
