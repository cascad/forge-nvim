local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local T = require('check')
local e

local function text()
  return e:lua([[local out={};for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b=vim.api.nvim_win_get_buf(w);if vim.bo[b].filetype=='aerial' then
      return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n') end end;return '']])
end

local function focus(keys, ft)
  e:input(keys)
  e:wait('фокус ' .. keys .. ': ' .. ft, function() return e:current_ft() == ft end)
end

local function open(name)
  e:input(' w0:edit ' .. name .. '<CR>')
  e:wait('открыт ' .. name, function() return e:current_file():gsub('\\','/'):match('/' .. name:gsub('%.','%%.') .. '$') ~= nil end)
end

local function outline(keys, symbol)
  focus(keys, 'aerial')
  if symbol then e:wait('реальные символы: ' .. symbol, function() return text():find(symbol, 1, true) ~= nil end) end
end

local function select_symbol(symbol)
  -- Публичный поиск/движение в настоящем буфере, не вызов private action.
  e:input('gg/' .. symbol .. '<CR>')
  e:wait('выбран ' .. symbol, function() return e:lua('return vim.api.nvim_get_current_line()'):find(symbol, 1, true) ~= nil end)
end

local function start()
  if e then return end
  e = require('editor').start(root)
  for _, name in ipairs({ 'symbols.lua', 'other.lua' }) do
    assert(vim.uv.fs_copyfile(root .. '/tests/e2e/fixtures/outline/' .. name, e.project .. '/' .. name))
  end
  e:wait('IDE готова', function() return e:lua('return _G.forge_e2e_observed') end, 10000)
  T.eq(e:lua([[return pcall(vim.treesitter.language.add,'lua')]]), true, 'нужен настоящий Lua parser из Neovim')
  -- Открываем первый файл в dashboard-окне, не создавая лишний main split.
  e:input(':edit symbols.lua<CR>')
  e:wait('первый Lua файл', function() return e:current_ft() == 'lua' end)
end

local function check(name, fn)
  T.check('IDE-PANEL-3 ' .. name, function()
    local ok, failure = pcall(function()
      start()
      fn()
      T.eq(e:lua('return vim.g.forge_e2e_installs'), 0, 'панель не запускает установки')
      T.eq(e:lua([[return require('dap').session()~=nil]]), false, 'панель не запускает отладку')
      for _, n in ipairs(e.rpc.notifications) do assert(n.level < vim.log.levels.ERROR, n.message) end
    end)
    if e then
      e:snapshot(name)
      if not ok then pcall(function() e:input('<Esc><Esc> pc w0') end) end
    end
    assert(ok, failure)
  end)
end

check('старые aliases и дерево соблюдают единый левый слот', function()
  e:input(' pf')
  e:wait('Explorer виден', function() return e:has_window('neo-tree') end)
  focus(' w0', 'lua')
  outline(' lo', 'omega')
  e:wait('Explorer заменён Outline', function()
    return not e:has_window('neo-tree') and e:lua([[return require('ide').current().slots.left]]) == 'outline'
  end)
  T.eq(e:lua([[local a=vim.api.nvim_win_get_position(0);local c=vim.api.nvim_win_get_position(require('ide').find_main_window());return a[2]<c[2] ]]), true)
  focus(' so', 'lua')
  T.eq(e:has_window('aerial'), false)
  e:input(' po')
  e:wait('раскладка Outline', function() return e:has_window('aerial') end)
  focus(' wh', 'aerial')
  focus('q', 'lua')
  T.eq(e:has_window('aerial'), false)
end)

check('Enter и h/l, движение по списку не двигает код', function()
  open('symbols.lua')
  e:input('gg')
  outline(' wa', 'nested')
  select_symbol('alpha')
  e:input('h')
  e:wait('дочерняя функция свёрнута', function() return not text():find('nested',1,true) end)
  e:input('l')
  e:wait('дочерняя функция раскрыта', function() return text():find('nested',1,true) ~= nil end)
  e:input('jj')
  e:wait('движение по списку', function() return e:lua('return vim.api.nvim_win_get_cursor(0)[1]') > 1 end)
  T.eq(e:lua([[return vim.api.nvim_win_get_cursor(require('ide').find_main_window())[1] ]]), 1, 'нет autojump')
  select_symbol('omega')
  focus('<CR>', 'lua')
  T.eq(e:lua('return vim.api.nvim_win_get_cursor(0)[1]'), 8)
  T.eq(e:has_window('aerial'), true)
end)

check('фокус, помощь, zoom/Enter и возврат размеров', function()
  outline(' wa', 'omega')
  e:wait('активный заголовок', function()
    local screen=table.concat(e.rpc:screen_lines(),'\n');return screen:find('[focus] Outline',1,true) ~= nil
  end)
  local geometry = e:lua([[local out={};for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(w).relative=='' then out[#out+1]={w,vim.api.nvim_win_get_width(w),vim.api.nvim_win_get_height(w)} end end;return out]])
  focus('?', 'forge-panel-help')
  assert(e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]]):find('Outline',1,true))
  focus('<Esc>', 'aerial')
  local buf = e:lua('return vim.api.nvim_get_current_buf()')
  e:input(' wz')
  e:wait('zoom того же буфера', function() return e:lua([[return vim.api.nvim_win_get_config(0).relative]]) == 'editor' end)
  T.eq(e:lua('return vim.api.nvim_get_current_buf()'), buf)
  focus('<Esc>', 'aerial')
  T.eq(e:lua([[return vim.api.nvim_win_get_config(0).relative]]), '')
  e:input(' wz')
  e:wait('повторный zoom', function() return e:lua([[return vim.api.nvim_win_get_config(0).relative]]) == 'editor' end)
  select_symbol('alpha')
  focus('<CR>', 'lua')
  e:wait('overlay убран после Enter', function()
    return e:lua([[for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do if vim.api.nvim_win_get_config(w).relative~='' then return false end end;return true]])
  end)
  T.eq(e:lua('return vim.api.nvim_win_get_cursor(0)[1]'), 1)
  T.eq(e:lua([[local out={};for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(w).relative=='' then out[#out+1]={w,vim.api.nvim_win_get_width(w),vim.api.nvim_win_get_height(w)} end end;return out]]), geometry)
  focus(' wh', 'aerial')
  focus('<Esc>', 'lua')
  T.eq(e:has_window('aerial'), true)
  outline(' wa', 'alpha')
  e:input(' wzq')
  e:wait('q из zoom скрывает панель', function() return not e:has_window('aerial') and e:current_ft()=='lua' end)
end)

check('смена файла и отсутствие backend не оставляют старые символы', function()
  open('symbols.lua')
  outline(' wa', 'omega')
  open('other.lua')
  e:wait('список второго файла', function() return text():find('other_symbol',1,true) and not text():find('omega',1,true) end)
  open('file_one.txt')
  e:wait('нет старых символов', function() return not text():find('other_symbol',1,true) and not text():find('omega',1,true) end)
  outline(' wa')
  e:wait('панель сообщает об отсутствии символов', function() return text():find('No',1,true) ~= nil end)
  focus('q', 'text')
  open('other.lua')
  outline(' wa', 'other_symbol')
  focus(' w0', 'lua')
  e:input(' pf')
  e:wait('Outline заменён Explorer', function()
    return not e:has_window('aerial') and e:has_window('neo-tree') and e:lua([[return require('ide').current().slots.left]]) == 'explorer'
  end)
end)

check('быстрое повторное открытие дерева сохраняет follow и не вызывает ERROR', function()
  open('symbols.lua')
  -- Только наблюдение на штатном событии: ловим опасную фазу даже если
  -- follow-таймер на быстрой машине не успеет обратиться к старому буферу.
  -- Никаких замен tree/follow/таймеров и вызовов private callback.
  e:lua([[vim.g.forge_e2e_closed_tree_refs={};require('neo-tree.events').subscribe({
    event='neo_tree_window_after_open',id='forge-e2e-observe-tree',handler=function(args)
      local s=require('neo-tree.sources.manager').get_state(args.source,args.tabid)
      if s.tree and #vim.fn.win_findbuf(s.tree.bufnr)==0 then
        local refs=vim.g.forge_e2e_closed_tree_refs
        refs[#refs+1]={source=args.source,tree_buf=s.tree.bufnr,visible_buf=s.bufnr}
        vim.g.forge_e2e_closed_tree_refs=refs
      end
    end})]])
  for cycle = 1, 12 do
    e:input(' pf w0:edit other.lua<CR> wa w0:edit symbols.lua<CR> pf')
    -- Наблюдаем настоящий UI после debounce follow (100 ms), не тормозя
    -- цепочку действий перед переключением и не вызывая его private callback.
    local deadline = vim.uv.hrtime() + 200 * 1000000
    e:wait('отложенные события дерева #' .. cycle, function()
      for _, n in ipairs(e.rpc.notifications) do if n.level >= vim.log.levels.ERROR then return true end end
      e.rpc:request('nvim_get_mode', {})
      return vim.uv.hrtime() >= deadline
    end)
    for _, n in ipairs(e.rpc.notifications) do assert(n.level < vim.log.levels.ERROR, n.message) end
    local stale = e:lua('return vim.g.forge_e2e_closed_tree_refs')
    vim.fn.writefile({vim.json.encode(stale)}, e.dir .. '/closed-tree-refs.json')
    T.eq(#stale, 0, 'после открытия дерево не ссылается на буфер без окна: ' .. vim.inspect(stale))
    focus(' w0', 'lua')
  end
end)

check('q работает и после штатной команды AerialOpen', function()
  e:input(' pc:AerialOpen left<CR>')
  outline('', 'alpha')
  focus('q', 'lua')
  T.eq(e:has_window('aerial'), false)
end)

if e then io.stdout:write('  artifacts: ' .. e.dir .. '\n'); e:stop() end
T.finish()
