local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local T = require('check')
local e

local function file(name) return e.project .. '/' .. name end
local function exists(name) return vim.uv.fs_stat(file(name)) ~= nil end
local function content(name) return vim.fn.readfile(file(name)) end
local function tree_text()
  return e:lua([[for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b=vim.api.nvim_win_get_buf(w);if vim.bo[b].filetype=='neo-tree' then
      return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n') end end;return '']])
end
local function focus(keys, ft)
  e:input(keys)
  e:wait('фокус ' .. keys .. ': ' .. ft, function() return e:current_ft() == ft end)
end
local function tree(keys)
  focus(keys or ' E', 'neo-tree')
  e:wait('дерево отрисовано', function()
    return tree_text():find('file_one.txt',1,true) and e:lua([[local s=require('neo-tree.sources.manager').get_state_for_window();return s and s._ready]])
  end)
end
local function choose(name)
  -- '/' занят штатным fuzzy finder Neo-tree. Читаем видимые строки и
  -- перемещаемся обычным normal G, без вызова tree/focus private actions.
  e:wait('выбран ' .. name, function()
    if e:lua('return vim.api.nvim_get_current_line()'):find(name,1,true) then return true end
    local row=e:lua([[local name=...;for i,line in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do
      if line:find(name,1,true) then return i end end;return false]],{name})
    -- Git/follow могут сдвинуть строки между чтением и G. Повторно найти
    -- видимый элемент после перерисовки, как locator в обычном UI тесте.
    if type(row)=='number' then e:input(row .. 'G') end
    return false
  end)
end
local function popup(key)
  e:input(key)
  e:wait('диалог ' .. key, function()
    return e:current_ft()=='neo-tree-popup' and e.rpc:request('nvim_get_mode',{}).mode:sub(1,1)=='i'
  end)
end
local function submit(text)
  e:input('<C-u>' .. text .. '<CR>')
  e:wait('возврат в дерево', function() return e:current_ft()=='neo-tree' and not e:has_window('neo-tree-popup') end)
end
local function open(name)
  focus(' w0', 'text')
  e:input(':edit ' .. name .. '<CR>')
  e:wait('файл ' .. name, function()
    return e:current_file():gsub('\\','/'):sub(-#name)==name
  end)
end
local function start()
  if e then return end
  e = require('editor').start(root)
  vim.fn.mkdir(file('folder_old'), 'p')
  vim.fn.mkdir(file('destination'), 'p')
  for name, value in pairs({
    ['rename_me.txt']='rename payload', ['move_me.txt']='move payload',
    ['cut_me.txt']='cut payload', ['keep_me.txt']='keep payload',
    ['occupied.txt']='existing target', ['folder_old/child.txt']='child payload',
  }) do vim.fn.writefile({value}, file(name)) end
  e:wait('IDE готова', function() return e:lua('return _G.forge_e2e_observed') end, 10000)
  e:input(':edit file_one.txt<CR>')
  e:wait('первый файл', function() return e:current_ft()=='text' end)
end
local function check(name, fn)
  T.check(name, function()
    local ok, failure = pcall(function()
      start()
      fn()
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
      T.eq(e:lua([[return require('dap').session()~=nil]]),false)
      for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    end)
    if e then
      e:snapshot(name)
      if not ok then pcall(function() e:input('<Esc><Esc> pc w0') end) end
    end
    assert(ok,failure)
  end)
end

check('IDE-FILE-1 создать каталог/файл с Unicode и пробелом, открыть и сохранить', function()
  tree()
  e:input('gg')
  popup('A')
  submit(file('создано space'))
  e:wait('каталог создан', function() return exists('создано space') end)
  choose('создано space')
  popup('a')
  submit(file('создано space/новый файл.txt'))
  e:wait('файл создан', function() return exists('создано space/новый файл.txt') end)
  if not tree_text():find('новый файл.txt',1,true) then
    choose('создано space')
    e:input('l')
  end
  choose('новый файл.txt')
  focus('<CR>', 'text')
  e:input('gg0iFILE_E2E_CONTENT<Esc>:write<CR>')
  e:wait('настоящий файл сохранён', function() return content('создано space/новый файл.txt')[1]=='FILE_E2E_CONTENT' end)
  T.eq(content('file_two.txt'),{'second file'},'соседний файл сохранён')
end)

check('IDE-FILE-1 rename открытого файла и каталога обновляет пути буферов', function()
  open('rename_me.txt')
  tree()
  choose('rename_me.txt')
  popup('r')
  submit('переименован name.txt')
  e:wait('rename на диске', function() return exists('переименован name.txt') and not exists('rename_me.txt') end)
  focus(' w0','text')
  e:wait('путь открытого буфера после rename', function() return e:current_file():find('переименован name.txt',1,true)~=nil end)
  T.eq(content('переименован name.txt'),{'rename payload'})
  open('folder_old/child.txt')
  tree()
  choose('folder_old')
  popup('r')
  submit('folder renamed')
  e:wait('каталог переименован', function() return exists('folder renamed/child.txt') and not exists('folder_old') end)
  focus(' w0','text')
  e:wait('дочерний буфер получил новый путь', function() return e:current_file():gsub('\\','/'):find('folder renamed/child.txt',1,true)~=nil end)
  e:input('GoRENAMED_EDIT<Esc>:write<CR>')
  e:wait('переименованный буфер редактируется',function() return content('folder renamed/child.txt')[2]=='RENAMED_EDIT' end)
end)

check('IDE-FILE-2 move с путём сохраняет открытый буфер и содержимое', function()
  open('move_me.txt')
  tree()
  choose('move_me.txt')
  popup('m')
  submit(file('destination/moved name.txt'))
  e:wait('move на диске',function() return exists('destination/moved name.txt') and not exists('move_me.txt') end)
  focus(' w0','text')
  e:wait('буфер после move',function() return e:current_file():gsub('\\','/'):find('destination/moved name.txt',1,true)~=nil end)
  T.eq(content('destination/moved name.txt'),{'move payload'})
  e:input('GoMOVED_EDIT<Esc>:write<CR>')
  e:wait('запись по новому пути',function() return content('destination/moved name.txt')[2]=='MOVED_EDIT' end)
end)

check('IDE-FILE-2 cut/paste в выбранный каталог и отмена занятого пути', function()
  open('cut_me.txt')
  tree()
  choose('cut_me.txt')
  e:input('x')
  choose('destination')
  e:input('p')
  e:wait('cut/paste на диске',function() return exists('destination/cut_me.txt') and not exists('cut_me.txt') end)
  focus(' w0','text')
  e:wait('путь после cut/paste',function() return e:current_file():gsub('\\','/'):find('destination/cut_me.txt',1,true)~=nil end)
  T.eq(content('destination/cut_me.txt'),{'cut payload'})
  tree()
  choose('keep_me.txt')
  popup('m')
  e:input('<C-u>' .. file('occupied.txt') .. '<CR>')
  e:wait('занятое имя вызывает повторный ввод',function()
    return e:current_ft()=='neo-tree-popup' and table.concat(e.rpc:screen_lines(),'\n'):find('already exists',1,true)~=nil
  end)
  focus('<Esc>','neo-tree')
  T.eq(content('keep_me.txt'),{'keep payload'})
  T.eq(content('occupied.txt'),{'existing target'})
end)

check('IDE-FILE-1 отмена a/r/m и конфликт rename не меняют файлы', function()
  tree()
  choose('keep_me.txt')
  for _,key in ipairs({'a','r','m'}) do
    popup(key)
    e:input('<C-u>q? отменённый ввод')
    focus('<Esc>','neo-tree')
    T.eq(e:has_window('neo-tree-popup'),false)
    T.eq(content('keep_me.txt'),{'keep payload'})
  end
  popup('r')
  e:input('<C-u>occupied.txt<CR>')
  e:wait('отказ rename занятого имени',function()
    if e:ack_warning('already exists, canceling') then return false end
    return e:current_ft()=='neo-tree' and not e:has_window('neo-tree-popup')
  end)
  T.eq(content('keep_me.txt'),{'keep payload'})
  T.eq(content('occupied.txt'),{'existing target'})
end)

check('IDE-PANEL-4 Space w e, источники, помощь, Esc и q', function()
  tree(' we')
  e:wait('фокус и selector видны',function()
    local screen=table.concat(e.rpc:screen_lines(),'\n')
    return screen:find('[focus]',1,true) and screen:find('Fil',1,true) and screen:find('Buf',1,true) and screen:find('Git',1,true)
  end)
  -- Чтение публичного current() во время смены источника не должно стирать
  -- выбор backend из-за краткого промежутка без прежнего окна.
  e:lua([[require('neo-tree.events').subscribe({event='neo_tree_window_after_open',
    id='forge-e2e-source-observer',handler=function() require('ide').current() end})]])
  for _,source in ipairs({{'bb','buffers'},{'bg','git_status'},{'bf','explorer'},
    {'>','buffers'},{'>','git_status'},{'<lt>','buffers'},{'bf','explorer'}}) do
    e:input(source[1])
    e:wait('источник ' .. source[1] .. ': ' .. source[2],function()
      return e:lua([[local id=...;local s=require('neo-tree.sources.manager').get_state_for_window()
        return s and s._ready and require('ide.controls').tree_component(s.name)==id
          and require('ide').current().slots.left==id]],{source[2]})
    end)
  end
  local esc_keys=e:lua([[local s=require('neo-tree.sources.manager').get_state_for_window()
    local aliases={};local esc=vim.api.nvim_replace_termcodes('<Esc>',true,false,true)
    for key,value in pairs(s.window.mappings) do
      if value and vim.api.nvim_replace_termcodes(key,true,false,true)==esc then aliases[#aliases+1]=key end
    end;table.sort(aliases);return aliases]])
  T.eq(#esc_keys,1,'у Esc один владелец в настоящем backend: '..vim.inspect(esc_keys))
  for _=1,5 do
    focus('?','forge-panel-help')
    assert(e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]]):find('a/A',1,true))
    focus('<Esc>','neo-tree')
    focus('<Esc>','text')
    tree(' we')
  end
  T.eq(e:has_window('neo-tree'),true)
  tree(' we')
  focus('q','text')
  T.eq(e:has_window('neo-tree'),false)
  tree(' e')
  focus('q','text')
  T.eq(e:has_window('neo-tree'),false)
end)

check('IDE-PANEL-4 zoom Enter/rename используют выбранную строку, сохраняют раскладку', function()
  tree(' we')
  choose('file_one.txt')
  local wins=e:lua([[local ids={};for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do ids[#ids+1]=w end;return ids]])
  e:input(' wz')
  e:wait('дерево развёрнуто',function() return e:lua([[return vim.api.nvim_win_get_config(0).relative]])=='editor' end)
  choose('file_two.txt')
  focus('<CR>','text')
  e:wait('подтверждён выбранный файл',function() return e:current_file():find('file_two.txt',1,true)~=nil end)
  e:wait('overlay убран',function()
    return e:lua([[for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do if vim.api.nvim_win_get_config(w).relative~='' then return false end end;return true]])
  end)
  T.eq(e:lua([[local ids={};for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do ids[#ids+1]=w end;return ids]]),wins)
  T.eq(content('file_one.txt'),{'first file','NEEDLE_FORGE_E2E'})
  tree(' we')
  choose('file_one.txt')
  e:input(' wz')
  e:wait('zoom перед rename',function() return e:lua([[return vim.api.nvim_win_get_config(0).relative]])=='editor' end)
  choose('keep_me.txt')
  popup('r')
  submit('zoom renamed.txt')
  e:wait('rename именно выбранного файла',function() return exists('zoom renamed.txt') and not exists('keep_me.txt') end)
  T.eq(content('zoom renamed.txt'),{'keep payload'})
  T.eq(content('file_one.txt'),{'first file','NEEDLE_FORGE_E2E'})
end)

if e then io.stdout:write('  artifacts: '..e.dir..'\n');e:stop() end
T.finish()
