local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local T = require('check')
local editor
local core_steps = {}

local function start_editor()
  editor = require('editor').start(root)
  T.eq(editor:lua('return package.loaded["ide"] ~= nil'), true)
  T.eq(editor:lua('return vim.v.errmsg'), '')
  -- Реальный RPC nil — vim.NIL: ожидание не должно принимать его за готовность.
  editor:lua('_G.forge_e2e_ready=nil')
  local ready
  editor:wait('RPC-состояние действительно готово', function()
    ready = editor:lua('return _G.forge_e2e_ready')
    if ready == vim.NIL then editor:lua('_G.forge_e2e_ready=true') end
    return ready
  end)
  T.eq(ready, true)
  local server=editor:lua('return vim.v.servername')
  assert(server~='', 'Native Neovim RPC address is empty; inspect nvim.log')
  local channel=vim.fn.sockconnect('pipe',server,{rpc=true})
  assert(channel>0, 'Cannot connect to native Neovim at '..server)
  local pid=vim.rpcrequest(channel,'nvim_exec_lua','return vim.uv.os_getpid()',{})
  vim.fn.chanclose(channel)
  T.eq(pid,editor:lua('return vim.uv.os_getpid()'))
end
T.check('SELF: EDITOR-STARTUP настоящий nvim_forge и pinned плагины', start_editor)

local function scenario(name, fn)
  local requirement = name:match('^IDE%-BOOT%-') ~= nil
  if not requirement then core_steps[#core_steps + 1] = fn end
  T.check((requirement and '' or 'SELF: ') .. name, function()
    local ok, err = pcall(function()
      -- --id пропускает SELF-случаи. Для выбранного требования те же
      -- пользовательские действия нужны как Given, без ложных отдельных PASS.
      if requirement and T.filter and not editor then
        start_editor()
        for _, step in ipairs(core_steps) do step() end
      end
      assert(editor, 'Предыдущий запуск редактора не удался')
      fn()
    end)
    if not ok then
      if editor then
        editor:snapshot(name)
        editor:input('<Esc><Esc><F7>')
      end
      error(err)
    end
  end)
end

scenario('EDITOR-FILE открыть, изменить и сохранить через ввод', function()
  editor:input(':edit file_one.txt<CR>')
  editor:wait('file_one открыт', function() return editor:current_file():match('/file_one.txt$') end)
  editor:input('Goadded from e2e<Esc><C-s>')
  editor:wait('изменение записано на диск', function()
    return table.concat(vim.fn.readfile(editor.project .. '/file_one.txt'), '\n'):find('added from e2e', 1, true) ~= nil
  end)
end)

scenario('EDITOR-TREE открыть дерево и выбрать файл', function()
  editor:input(' e')
  editor:wait('Neo-tree виден', function() return editor:has_window('neo-tree') end)
  editor:wait('Фокус в Neo-tree', function() return editor:current_ft() == 'neo-tree' end)
  local line
  editor:wait('дерево закончило чтение каталога', function()
    line = editor:lua([[for i,s in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do if s:find('file_two.txt',1,true) then return i end end; return 0]])
    return line > 0
  end)
  editor:input('gg' .. string.rep('j', line - 1) .. '<CR>')
  editor:wait('выбранный файл открыт в коде', function() return editor:current_file():match('/file_two.txt$') end)
end)

scenario('EDITOR-FIND поиск имени через Telescope', function()
  editor:input('<C-p>')
  editor:wait('Telescope prompt готов к вводу', function() return editor:current_ft() == 'TelescopePrompt' and editor:lua('return vim.api.nvim_get_mode().mode') == 'i' end)
  editor:input('file_one.txt')
  editor:wait('результат поиска имени', function()
    return editor:lua([[for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='TelescopeResults' then for _,s in ipairs(vim.api.nvim_buf_get_lines(b,0,-1,false)) do if s:find('file_one.txt',1,true) then return true end end end end; return false]])
  end)
  editor:wait('выбран результат имени', function()
    return editor:lua("return require('telescope.actions.state').get_selected_entry() ~= nil")
  end)
  editor:input('<CR>')
  editor:wait('переход к найденному файлу', function() return editor:current_file():match('/file_one.txt$') end)
end)

scenario('EDITOR-GREP поиск содержимого через настоящий rg', function()
  editor:input(' fg')
  editor:wait('live_grep prompt готов к вводу', function() return editor:current_ft() == 'TelescopePrompt' and editor:lua('return vim.api.nvim_get_mode().mode') == 'i' end)
  editor:input('NEEDLE_FORGE_E2E')
  editor:wait('результат поиска содержимого', function()
    return editor:lua([[for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='TelescopeResults' then for _,s in ipairs(vim.api.nvim_buf_get_lines(b,0,-1,false)) do if s:find('NEEDLE_FORGE_E2E',1,true) then return true end end end end; return false]])
  end)
  editor:wait('выбран результат содержимого', function()
    return editor:lua("return require('telescope.actions.state').get_selected_entry() ~= nil")
  end)
  editor:input('<CR>')
  editor:wait('переход к найденной строке', function() return editor:current_file():match('/file_one.txt$') and editor:current_ft() ~= 'TelescopePrompt' end)
  T.eq(editor:lua('return vim.api.nvim_win_get_cursor(0)[1]'), 2)
end)

scenario('EDITOR-BUFFERS следующий файл и закрытие буфера', function()
  editor:input(' bn')
  editor:wait('следующий файл', function() return editor:current_file():match('/file_two.txt$') end)
  editor:input(' bd')
  editor:wait('возврат к оставшемуся файлу', function() return editor:current_file():match('/file_one.txt$') end)
end)

scenario('EDITOR-FOCUS панель и возврат в код через F6/F7', function()
  if not editor:has_window('neo-tree') then
    editor:input(' e')
    editor:wait('открытая панель получила фокус', function() return editor:current_ft() == 'neo-tree' end)
    editor:input('<F7>')
  end
  editor:wait('фокус в коде', function() return editor:current_file():match('/file_one.txt$') end)
  editor:input('<F6>')
  editor:wait('фокус в панели', function() return editor:current_ft() == 'neo-tree' end)
  editor:input('<F7>')
  editor:wait('фокус вернулся в код', function() return editor:current_file():match('/file_one.txt$') end)
end)

scenario('IDE-BOOT-1 обычная работа не запускает скачивание инструментов', function()
  editor:wait('окно наблюдения после VeryLazy (старый таймер 3000 мс)', function() return editor:lua('return _G.forge_e2e_observed == true') end, 6000)
  T.eq(editor:lua('return vim.g.forge_e2e_installs'), 0)
  local spawns = editor:lua('return _G.forge_e2e_spawns')
  for _, process in ipairs(spawns) do
    local cmd = process.cmd:gsub('\\', '/'):lower():match('([^/]+)$')
    assert(not cmd:match('^curl') and not cmd:match('^wget'),
      'Неявная загрузка при работе редактора: ' .. vim.inspect(process))
  end
  assert(not editor:lua("return vim.fn.execute('messages')"):find('Downloading tree%-sitter'), 'Treesitter скачивает парсеры при запуске')
  T.eq(editor:lua("return vim.fn.exists(':ForgeTreesitterInstall')"), 2)
  T.eq(editor:lua("return vim.fn.exists(':MasonToolsInstall')"), 2)
  T.eq(editor:lua("return vim.fn.exists(':MasonToolsInstallSync')"), 2)
end)

scenario('IDE-BOOT-2 обычные файлы не вызывают предупреждение чужого LSP', function()
  for _, item in ipairs(editor:lua('return vim.g.forge_e2e_notifications')) do
    assert(not item.message:find('gopls не найден', 1, true), 'Go LSP предупреждает при работе с .txt')
  end
end)

scenario('EDITOR-ERRORS нет ошибок конфигурации после UIEnter и действий', function()
  for _, item in ipairs(editor:lua('return vim.g.forge_e2e_notifications')) do
    assert(item.level < vim.log.levels.ERROR, item.message)
  end
  local messages = editor:lua("return vim.fn.execute('messages')")
  assert(not messages:find('Failed to run `config`', 1, true), messages)
  assert(not messages:find('E5113', 1, true), messages)
end)

if editor then
  io.stdout:write('  artifacts: ' .. editor.dir .. '\n')
  editor:stop()
end

T.check('IDE-BOOT-12 checkout fride loads current config and opens a project through Files', function()
  local tui
  local ok, issue = xpcall(function()
    tui = require('session_tui').start(root, { checkout = true })
    tui:launch()
    local host = tui.host
    local function real(path)
      return assert(vim.uv.fs_realpath(path), path):gsub('\\', '/')
    end
    local runtime = vim.fn.has('win32') == 1 and vim.v.progpath or vim.fn.exepath('nvim')
    local launch = tui:lua([[return { config=vim.env.MYVIMRC, executable=vim.v.progpath, version=tostring(vim.version()),
      namespace=vim.env.NVIM_APPNAME, cwd=vim.fn.getcwd(), data=vim.fn.stdpath('data') }]])
    vim.fn.writefile({ vim.json.encode(launch) }, host.dir .. '/checkout-launch.json')
    T.eq(real(launch.config), real(root .. '/nvim_forge/init.lua'))
    T.eq(real(launch.executable), real(runtime))
    T.eq(launch.namespace, 'nvim_forge')
    T.eq(real(launch.cwd), real(tui.a))
    assert(real(launch.data):find(real(host.runtime) .. '/', 1, true) == 1, launch.data)

    host:wait('Files opens for the directory argument', function()
      return tui:lua([[for _,win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(win)].filetype=='neo-tree' then return true end
      end]])
    end)
    tui:send(' we')
    local row
    host:wait('Files renders the fixture with keyboard focus', function()
      row = tui:lua([[if vim.bo.filetype~='neo-tree' then return false end
      for i,line in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do
        if line:find('first.txt',1,true) then return i end
      end; return false]])
      return row
    end)
    tui:send(tostring(row) .. 'Gl')
    host:wait('l opens the selected project file in code', function()
      return tui:lua([[return vim.bo.filetype=='text'
        and vim.api.nvim_buf_get_name(0):gsub('\\','/')==...]], { tui.a .. '/first.txt' })
    end)
    T.eq(tui:lua('return vim.api.nvim_get_current_line()'), 'first.txt line 1 | Project A ü')
    local state = tui:state()
    T.eq(state.installs, 0)
    assert(#state.ui > 0 and not state.mode.blocking, 'Real TUI is not ready')
    assert(not state.messages:match('E%d%d%d+:') and not state.messages:find('Failed to run ',1,true),
      state.messages)
    for _, notice in ipairs(state.notices) do
      assert(notice.level < vim.log.levels.ERROR, notice.message)
    end
    host:snapshot('checkout-launch')
  end, debug.traceback)
  if tui then
    io.stdout:write('  artifacts: ' .. tui.host.dir .. '\n')
    tui:stop(not ok and issue or nil)
  end
  assert(ok, issue)
end)

T.finish()
